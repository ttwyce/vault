import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'font_catalog.dart';
import 'font_face.dart';
import 'font_role.dart';
import 'font_runtime.dart';
import 'font_state.dart';
import 'font_store.dart';
import 'font_validation.dart';

/// 待导入的一个字体来源。
///
/// 用「名字 + 读取字节的闭包」而不是 `File`，是为了让 core 层不依赖
/// file_picker：Android 从 SAF 选出来的文件不一定有本地路径，
/// 但一定能 `readAsBytes()`（见 docs/15 §7.2）。
class FontImportSource {
  const FontImportSource({required this.name, required this.read});

  final String name;
  final Future<Uint8List> Function() read;
}

/// 一次导入的结果。
class FontImportReport {
  const FontImportReport({required this.added, required this.skipped, required this.errors});

  final List<FontFace> added;

  /// 已经导入过的（同内容），不算失败。
  final List<String> skipped;

  final List<String> errors;

  bool get isClean => errors.isEmpty;

  String get summary {
    final parts = <String>[];
    if (added.isNotEmpty) parts.add('导入 ${added.length} 个');
    if (skipped.isNotEmpty) parts.add('跳过 ${skipped.length} 个重复');
    if (errors.isNotEmpty) parts.add('失败 ${errors.length} 个');
    return parts.isEmpty ? '没有选中文件' : parts.join('，');
  }
}

/// 字体服务的对外门面：装配存储、运行时注册、状态变更通知。
///
/// 在 `main()` 里 `await FontService.boot()`，然后通过 `Provider` 注入。
/// 这样首帧渲染时字体已经就绪，不会出现"先系统字体、后手写体"的闪动。
class FontService extends ChangeNotifier {
  FontService._(this._store, this._state);

  final FontStore _store;
  FontState _state;

  FontState get state => _state;

  /// 启动阶段注册失败的字体（文件损坏等）。UI 可以用来提示，但不阻塞。
  List<String> bootErrors = const <String>[];

  static Future<FontService> boot() async {
    final store = await FontStore.open();
    final state = await store.load();

    // 只加载当前配置真正用到的导入字体，不把所有导入字体全灌进内存。
    final needed = <String, FontFace>{};
    for (final role in FontRole.values) {
      final face = state.faceFor(role);
      if (face.isImported && face.family != null) needed[face.id] = face;
    }
    final errors = await FontRuntime.ensureAll(needed.values);

    final service = FontService._(store, state);
    service.bootErrors = errors;
    return service;
  }

  // ---------------------------------------------------------------------------
  // 切换
  // ---------------------------------------------------------------------------

  Future<void> applyPreset(FontPreset preset) async {
    await _ensureRoles(preset.roles.values);
    await _commit(_state.withPreset(preset));
  }

  Future<void> setRoleFont(FontRole role, String fontId) async {
    final face = _state.faceById(fontId);
    if (face == null) return;
    if (face.isImported) await FontRuntime.ensure(face);
    await _commit(_state.withRoleFont(role, fontId));
  }

  Future<void> reset() async {
    await _commit(FontState.defaults().copyWith(imported: _state.imported));
  }

  Future<void> _ensureRoles(Iterable<String> fontIds) async {
    for (final id in fontIds) {
      final face = _state.faceById(id);
      if (face != null && face.isImported) {
        try {
          await FontRuntime.ensure(face);
        } on Object {
          // 单个字体加载失败不影响整套预设，SketchTypography 会回退。
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 导入
  // ---------------------------------------------------------------------------

  /// 导入若干字体。逐个校验、逐个落盘，互不影响。
  Future<FontImportReport> importSources(List<FontImportSource> sources) async {
    final added = <FontFace>[];
    final skipped = <String>[];
    final errors = <String>[];
    final imported = List<FontFace>.from(_state.imported);

    for (final source in sources) {
      final name = source.name;
      try {
        final bytes = await source.read();
        final invalid = FontValidation.validate(bytes, name);
        if (invalid != null) {
          errors.add(invalid);
          continue;
        }

        final hash = sha256.convert(bytes).toString();
        final shortId = hash.substring(0, 12);
        final id = 'imported:$shortId';

        if (imported.any((FontFace f) => f.id == id)) {
          skipped.add('$name（已导入过）');
          continue;
        }

        final extension = switch (FontValidation.sniff(bytes)) {
          FontFormat.openType => '.otf',
          FontFormat.collection => '.ttc',
          _ => '.ttf',
        };
        final path = await _store.writeFile(bytes, shortId, extension);

        final face = FontFace(
          id: id,
          displayName: _prettyName(name),
          // 家族名用哈希，保证不同文件永不同名（FontLoader 不能重名、不能卸载）
          family: 'imp_$shortId',
          fallback: FontCatalog.cjkFallback,
          // 导入时不知道用户想拿它干什么，三个角色都给上，让用户自己挑。
          roles: const <FontRole>{
            FontRole.ui,
            FontRole.display,
            FontRole.mono,
          },
          source: FontSource.imported,
          filePath: path,
          bytes: bytes.length,
          license: '由用户提供，请自行确认授权',
          note: '导入字体 · ${FontValidation.sniff(bytes).label}',
          originName: name,
          importedAt: DateTime.now(),
        );

        await FontRuntime.ensure(face);
        imported.add(face);
        added.add(face);
      } on Object catch (e) {
        errors.add('$name：$e');
      }
    }

    if (added.isNotEmpty) {
      await _commit(_state.copyWith(imported: List<FontFace>.unmodifiable(imported)));
    }
    return FontImportReport(added: added, skipped: skipped, errors: errors);
  }

  Future<void> renameImported(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final next = <FontFace>[
      for (final face in _state.imported)
        face.id == id ? face.copyWith(displayName: trimmed) : face,
    ];
    await _commit(_state.copyWith(imported: List<FontFace>.unmodifiable(next)));
  }

  /// 删除导入字体。若它正在被某个角色使用，该角色回退到系统默认。
  Future<void> removeImported(String id) async {
    final face = _state.faceById(id);
    if (face == null || !face.isImported) return;

    final roles = Map<FontRole, String>.from(_state.roles);
    final systemFallback = <FontRole, String>{
      FontRole.ui: FontCatalog.systemUi.id,
      FontRole.display: FontCatalog.systemDisplay.id,
      FontRole.mono: FontCatalog.systemMono.id,
    };
    for (final role in FontRole.values) {
      if (roles[role] == id) roles[role] = systemFallback[role]!;
    }

    final next = _state.imported.where((FontFace f) => f.id != id).toList();
    await _commit(
      _state.copyWith(
        imported: List<FontFace>.unmodifiable(next),
        roles: Map<FontRole, String>.unmodifiable(roles),
        presetId: FontState.customId,
      ),
    );
    await _store.deleteFile(face.filePath);
  }

  Future<void> _commit(FontState next) async {
    _state = next;
    await _store.save(next);
    notifyListeners();
  }

  /// 文件名 → 展示名。去掉常见的字重/格式后缀，太长的截断。
  static String _prettyName(String fileName) {
    var stem = p.basenameWithoutExtension(fileName);
    stem = stem.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    stem = stem.replaceAll(
      RegExp(r'[-_ ](Regular|Normal|Book|Roman|Medium|Light|Bold|Italic)$',
          caseSensitive: false),
      '',
    );
    stem = stem.replaceAll(RegExp(r'[-_]+'), ' ').trim();
    if (stem.isEmpty) return fileName;
    return stem.length > 28 ? '${stem.substring(0, 28)}…' : stem;
  }
}
