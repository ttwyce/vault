import 'dart:typed_data';

/// 字体文件格式。按文件头 4 字节判定，不看扩展名 ——
/// 用户从网上下载的 `.ttf` 里有大量其实是 woff2 或直接是 HTML 错误页。
enum FontFormat {
  trueType,
  openType,
  collection,
  woff,
  woff2,
  unknown;

  String get label => switch (this) {
        FontFormat.trueType => 'TrueType',
        FontFormat.openType => 'OpenType',
        FontFormat.collection => 'TrueType Collection',
        FontFormat.woff => 'WOFF',
        FontFormat.woff2 => 'WOFF2',
        FontFormat.unknown => '未知',
      };

  /// Flutter 引擎只认裸 sfnt（ttf/otf/ttc），Web 字体容器不支持。
  bool get isSupported =>
      this == FontFormat.trueType ||
      this == FontFormat.openType ||
      this == FontFormat.collection;
}

/// 导入校验。返回 null 表示通过，否则返回给用户看的中文原因。
abstract final class FontValidation {
  const FontValidation._();

  /// 单文件上限。中文字体最大也就 20~30MB，40MB 足够，
  /// 再大基本是把一堆字重打包成一个 ttc，加载进内存会直接 OOM。
  static const int maxBytes = 40 * 1024 * 1024;

  /// 小于 1KB 的一定不是字体。
  static const int minBytes = 1024;

  static FontFormat sniff(Uint8List bytes) {
    if (bytes.length < 4) return FontFormat.unknown;
    final int b0 = bytes[0];
    final int b1 = bytes[1];
    final int b2 = bytes[2];
    final int b3 = bytes[3];

    // 00 01 00 00
    if (b0 == 0x00 && b1 == 0x01 && b2 == 0x00 && b3 == 0x00) {
      return FontFormat.trueType;
    }
    // 'true' / 'ttcf'
    if (b0 == 0x74 && b1 == 0x72 && b2 == 0x75 && b3 == 0x65) {
      return FontFormat.trueType;
    }
    if (b0 == 0x74 && b1 == 0x74 && b2 == 0x63 && b3 == 0x66) {
      return FontFormat.collection;
    }
    // 'OTTO'
    if (b0 == 0x4F && b1 == 0x54 && b2 == 0x54 && b3 == 0x4F) {
      return FontFormat.openType;
    }
    // 'wOFF' / 'wOF2'
    if (b0 == 0x77 && b1 == 0x4F && b2 == 0x46 && b3 == 0x46) {
      return FontFormat.woff;
    }
    if (b0 == 0x77 && b1 == 0x4F && b2 == 0x46 && b3 == 0x32) {
      return FontFormat.woff2;
    }
    return FontFormat.unknown;
  }

  static String? validate(Uint8List bytes, String fileName) {
    if (bytes.length < minBytes) {
      return '$fileName 只有 ${bytes.length} 字节，不是有效的字体文件。';
    }
    if (bytes.length > maxBytes) {
      return '$fileName 超过 40 MB。请换用单字重的版本（可变字体或多字重合集通常过大）。';
    }
    final format = sniff(bytes);
    if (format == FontFormat.woff || format == FontFormat.woff2) {
      return '$fileName 是 ${format.label} 网页字体，引擎不支持。'
          '请用 fonttools 转成 TTF：fonttools ttLib.woff2 decompress 后再另存为 .ttf。';
    }
    if (!format.isSupported) {
      return '$fileName 不是字体文件（可能是网页或压缩包改的扩展名）。';
    }
    return null;
  }
}
