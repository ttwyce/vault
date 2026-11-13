/// 纯 Dart 简易 PDF 生成（docs/05 §8 二级降级 `dartPdf`）。
///
/// 不引 `pdf` / `printing` 包：手写最小 PDF 1.4 字节流
/// （Catalog / Pages / 每页 Page + Contents / Helvetica + 标准 CJK 字体 / xref）。
/// ASCII/Latin-1 行走 Helvetica；含 CJK 的行切到 Adobe 标准简体中文字体
/// STSong-Light + UniGB-UCS2-H，文本用 UTF-16BE 十六进制字符串写入，
/// 中文不再全部变成 `?`。字体由阅读器提供，不嵌入字体文件、不新增依赖；
/// 图片/复杂排版保真快照仍由平台原生 WebView PDF 负责。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'pdf_pagination.dart';

const int kPdfMaxLinesPerPage = 52;
const double kPdfLineHeightPt = 14.0;
const double kPdfMarginPt = 48.0;

class SimplePdfResult {
  const SimplePdfResult({
    required this.ok,
    required this.bytes,
    required this.pageCount,
    required this.hint,
  });

  final bool ok;
  final Uint8List bytes;
  final int pageCount;
  final String hint;
}

/// 每行按可视宽度做保守折行（ASCII 按字符、中文按 2 列宽）。
List<String> _wrapLines(String text, {int columns = 92}) {
  final out = <String>[];
  for (final raw in text.split('\n')) {
    var line = '';
    var width = 0;
    for (final rune in raw.runes) {
      final w = rune > 0x2e80 ? 2 : 1;
      if (width + w > columns && line.isNotEmpty) {
        out.add(line);
        line = '';
        width = 0;
      }
      line += String.fromCharCode(rune);
      width += w;
    }
    out.add(line);
  }
  return out;
}

/// PDF 字符串字面量转义；只保留 Latin-1，其它字符用 `?` 兜底。
String _pdfLiteral(String line) {
  final buffer = StringBuffer();
  for (final unit in line.codeUnits) {
    if (unit == 0x28 || unit == 0x29 || unit == 0x5c) {
      buffer.write('\\');
      buffer.writeCharCode(unit);
    } else if (unit >= 0x20 && unit <= 0x7e) {
      buffer.writeCharCode(unit);
    } else if (unit >= 0xa0 && unit <= 0xff) {
      buffer.write('\\${unit.toRadixString(8).padLeft(3, '0')}');
    } else {
      buffer.write('?');
    }
  }
  return buffer.toString();
}

bool _needsCjk(String line) => line.runes.any((int r) => r > 0xff);

String _pdfUtf16Hex(String line) {
  final units = <int>[
    0xfeff, // BOM，标明 UCS2 大端
    for (final rune in line.runes)
      if (rune <= 0xffff)
        rune
      else ...<int>[
        0xd800 + ((rune - 0x10000) >> 10),
        0xdc00 + ((rune - 0x10000) & 0x3ff),
      ],
  ];
  return <String>[
    for (final unit in units)
      unit.toRadixString(16).toUpperCase().padLeft(4, '0'),
  ].join();
}

String _contentStream(List<String> lines) {
  final buffer = StringBuffer()
    ..writeln('BT')
    ..writeln('/F1 11 Tf')
    ..writeln('${kPdfLineHeightPt.toStringAsFixed(1)} TL')
    ..writeln('1 0 0 1 ${kPdfMarginPt.toStringAsFixed(1)} '
        '${(kA4HeightPt - kPdfMarginPt).toStringAsFixed(1)} Tm');
  for (final line in lines) {
    if (_needsCjk(line)) {
      buffer.writeln('/F2 11 Tf');
      buffer.writeln('<${_pdfUtf16Hex(line)}> Tj T*');
      buffer.writeln('/F1 11 Tf');
    } else {
      buffer.writeln('(${_pdfLiteral(line)}) Tj T*');
    }
  }
  buffer.writeln('ET');
  return buffer.toString();
}

/// 生成 PDF 字节；正文为空返回 0 页（不假装生成了快照）。
SimplePdfResult buildSimplePdf(String markdown) {
  if (markdown.trim().isEmpty) {
    return SimplePdfResult(
      ok: false,
      bytes: Uint8List(0),
      pageCount: 0,
      hint: '正文为空，未生成 PDF',
    );
  }
  final allLines = _wrapLines(markdown);
  final contentHeight = allLines.length * kPdfLineHeightPt;
  final plan = planPdfPagination(contentHeight);
  if (plan.pageCount == 0) {
    return SimplePdfResult(
      ok: false,
      bytes: Uint8List(0),
      pageCount: 0,
      hint: '分页计划为空，未生成 PDF',
    );
  }
  final pageLines = <List<String>>[
    for (var i = 0; i < plan.pageCount; i++)
      allLines
          .skip(i * kPdfMaxLinesPerPage)
          .take(kPdfMaxLinesPerPage)
          .toList(),
  ];

  // object 1 Catalog, 2 Pages, 3 Helvetica, 4 CJK Type0,
  // 5..(4+pages) Page，之后每页一个 Contents stream。
  final fontObj = 3;
  final cjkFontObj = 4;
  final firstPageObj = 5;
  final firstContentObj = firstPageObj + plan.pageCount;
  var objectCount = firstContentObj + plan.pageCount - 1;

  final objects = <int, List<int>>{};
  objects[1] = ascii.encode('<< /Type /Catalog /Pages 2 0 R >>');
  final kids = <String>[
    for (var i = 0; i < plan.pageCount; i++)
      '${firstPageObj + i} 0 R',
  ].join(' ');
  objects[2] = ascii.encode(
    '<< /Type /Pages /Count ${plan.pageCount} /Kids [$kids] >>',
  );
  objects[fontObj] = ascii.encode(
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
    '/Encoding /WinAnsiEncoding >>',
  );
  objects[cjkFontObj] = ascii.encode(
    '<< /Type /Font /Subtype /Type0 /BaseFont /STSong-Light '
    '/Encoding /UniGB-UCS2-H '
    '/DescendantFonts [${cjkFontObj + plan.pageCount * 2 + 1} 0 R] >>',
  );
  for (var i = 0; i < plan.pageCount; i++) {
    final pageObj = firstPageObj + i;
    final contentObj = firstContentObj + i;
    objects[pageObj] = ascii.encode(
      '<< /Type /Page /Parent 2 0 R '
      '/MediaBox [0 0 ${kA4WidthPt.toStringAsFixed(0)} '
      '${kA4HeightPt.toStringAsFixed(0)}] '
      '/Resources << /Font << /F1 $fontObj 0 R /F2 $cjkFontObj 0 R >> >> '
      '/Contents $contentObj 0 R >>',
    );
    final stream = ascii.encode(_contentStream(pageLines[i]));
    objects[contentObj] = <int>[
      ...ascii.encode('<< /Length ${stream.length} >>\nstream\n'),
      ...stream,
      ...ascii.encode('\nendstream'),
    ];
  }

  final descendantFontObj = cjkFontObj + plan.pageCount * 2 + 1;
  objects[descendantFontObj] = ascii.encode(
    '<< /Type /Font /Subtype /CIDFontType0 /BaseFont /STSong-Light '
    '/CIDSystemInfo << /Registry (Adobe) /Ordering (GB1) /Supplement 4 >> '
    '/DW 1000 >>',
  );
  objectCount = descendantFontObj;

  final out = BytesBuilder(copy: false);
  void write(String s) => out.add(ascii.encode(s));
  void writeBytes(List<int> b) => out.add(b);
  final offsets = <int, int>{};
  write('%PDF-1.4\n');
  for (var n = 1; n <= objectCount; n++) {
    offsets[n] = out.length;
    write('$n 0 obj\n');
    writeBytes(objects[n]!);
    write('\nendobj\n');
  }
  final xrefOffset = out.length;
  write('xref\n0 ${objectCount + 1}\n');
  write('0000000000 65535 f \n');
  for (var n = 1; n <= objectCount; n++) {
    write('${offsets[n]!.toString().padLeft(10, '0')} 00000 n \n');
  }
  write('trailer\n<< /Size ${objectCount + 1} /Root 1 0 R >>\n');
  write('startxref\n$xrefOffset\n%%EOF\n');
  return SimplePdfResult(
    ok: true,
    bytes: out.takeBytes(),
    pageCount: plan.pageCount,
    hint: '已生成简易 PDF（${plan.pageCount} 页，不保真但可用）',
  );
}
