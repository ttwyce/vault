import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'font_face.dart';
import 'font_state.dart';

/// 字体配置的磁盘存储。
///
/// 目录布局：
/// ```
/// <appSupport>/fonts/
///   index.json          配置 + 导入字体清单（不含绝对路径）
///   files/<sha256>.ttf  导入的字体文件，内容寻址，同名即同文件
/// ```
///
/// 为什么不用数据库：字体是**纯本地、不参与同步**的配置，
/// 且必须在数据库打开之前就能读到（否则会先闪一下系统字体再切过来）。
/// 一个 JSON 文件在这里比一张表更合适。
class FontStore {
  FontStore._(this.root, this.filesDir);

  final Directory root;
  final Directory filesDir;

  static Future<FontStore> open() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory(p.join(base.path, 'fonts'));
    final files = Directory(p.join(root.path, 'files'));
    if (!await files.exists()) {
      await files.create(recursive: true);
    }
    return FontStore._(root, files);
  }

  File get _indexFile => File(p.join(root.path, 'index.json'));

  Future<FontState> load() async {
    try {
      if (!await _indexFile.exists()) return FontState.defaults();
      final raw = await _indexFile.readAsString();
      if (raw.trim().isEmpty) return FontState.defaults();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return FontState.defaults();
      var state = FontState.fromJson(
        decoded.cast<String, Object?>(),
        filesDir.path,
      );
      // 文件被用户或系统清掉时，条目必须同步消失，
      // 否则界面会列出点不动的字体。
      final alive = <FontFace>[];
      for (final face in state.imported) {
        final path = face.filePath;
        if (path != null && await File(path).exists()) {
          alive.add(face);
        }
      }
      if (alive.length != state.imported.length) {
        state = state.copyWith(imported: List<FontFace>.unmodifiable(alive));
        await save(state);
      }
      return state;
    } on Object {
      // 配置文件损坏不应该让 App 打不开 —— 退回默认字体，用户重设即可。
      return FontState.defaults();
    }
  }

  Future<void> save(FontState state) async {
    if (!await root.exists()) await root.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final tmp = File('${_indexFile.path}.tmp');
    await tmp.writeAsString(encoder.convert(state.toJson()), flush: true);
    // 先写临时文件再 rename：断电或崩溃时不会留下半截 JSON。
    await tmp.rename(_indexFile.path);
  }

  /// 写入字体文件，返回绝对路径。文件名用内容哈希，重复导入同一个文件
  /// 不会产生第二份副本。
  Future<String> writeFile(Uint8List bytes, String hash, String extension) async {
    if (!await filesDir.exists()) await filesDir.create(recursive: true);
    final file = File(p.join(filesDir.path, '$hash$extension'));
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }

  Future<void> deleteFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 清掉没有被任何条目引用的文件（删除字体或换目录后调用）。
  Future<int> sweep(Set<String> keepFileNames) async {
    if (!await filesDir.exists()) return 0;
    var removed = 0;
    await for (final entity in filesDir.list()) {
      if (entity is! File) continue;
      if (keepFileNames.contains(p.basename(entity.path))) continue;
      await entity.delete();
      removed++;
    }
    return removed;
  }
}
