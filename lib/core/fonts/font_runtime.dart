import 'dart:io';

import 'package:flutter/services.dart';

import 'font_face.dart';

/// 运行时字体注册。
///
/// 三条硬约束，全部来自 Flutter 引擎的现状：
///
/// 1. **`FontLoader` 只能加、不能卸**。同一家族名重复 `load()` 会抛异常，
///    所以这里用 `_loaded` + `_inflight` 双重去重；导入字体的家族名由
///    文件哈希生成，保证不同文件不会撞名。
/// 2. **运行时加载的字体拿不到字重/字形元数据**。一个文件 = 一个家族，
///    粗体由引擎合成。需要真多字重时只能走 pubspec 内置（那才带 `weight`）。
/// 3. **加载后的字体会一直占内存**。所以启动时只加载"当前配置用到的"，
///    不是把所有导入字体全灌进去。
abstract final class FontRuntime {
  const FontRuntime._();

  static final Set<String> _loaded = <String>{};
  static final Map<String, Future<void>> _inflight = <String, Future<void>>{};

  static bool isLoaded(String? family) =>
      family != null && _loaded.contains(family);

  /// 注册一个字体。内置字体已在 pubspec 声明，直接跳过。
  static Future<void> ensure(FontFace face) {
    final family = face.family;
    if (family == null) return Future<void>.value();
    if (face.source == FontSource.bundled) return Future<void>.value();
    if (_loaded.contains(family)) return Future<void>.value();

    return _inflight.putIfAbsent(family, () async {
      try {
        final bytes = await _readBytes(face);
        if (bytes == null) {
          throw FontLoadException('字体文件已丢失：${face.displayName}');
        }
        final loader = FontLoader(family)
          ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
        await loader.load();
        _loaded.add(family);
      } finally {
        _inflight.remove(family);
      }
    });
  }

  /// 批量注册。单个失败不阻塞其它字体 ——
  /// 一个坏文件不应该让整个 App 打不开。
  static Future<List<String>> ensureAll(Iterable<FontFace> faces) async {
    final errors = <String>[];
    for (final face in faces) {
      try {
        await ensure(face);
      } on Object catch (e) {
        errors.add('${face.displayName}：$e');
      }
    }
    return errors;
  }

  static Future<Uint8List?> _readBytes(FontFace face) async {
    final path = face.filePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) return file.readAsBytes();
    }
    final asset = face.assetPath;
    if (asset != null) {
      final data = await rootBundle.load(asset);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    return null;
  }
}

class FontLoadException implements Exception {
  const FontLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
