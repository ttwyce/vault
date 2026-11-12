/// 纯 Dart 简易 PDF 生成（docs/05 §8 二级降级 `dartPdf`）。
///
/// 不引 `pdf` / `printing` 包：手写最小 PDF 1.4 字节流
/// （Catalog / Pages / 每页 Page + Contents / Helvetica 字体 / xref）。
/// 按 `planPdfPagination` 的 A4 分页把 L1 正文逐行排进内容流；
/// 非 Latin-1 字符用八进制转义或 `?` 兜底 —— **不保真但可用**，
/// 保真快照仍由平台原生 WebView PDF 负责。
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

String _contentStream(List<String> lines) {
  final buffer = StringBuffer()
    ..writeln('BT')
    ..writeln('/F1 11 Tf')
    ..writeln('${kPdfLineHeightPt.toStringAsFixed(1)} TL')
    ..writeln('1 0 0 1 ${kPdfMarginPt.toStringAsFixed(1)} '
        '${(kA4HeightPt - kPdfMarginPt).toStringAsFixed(1)} Tm');
  for (final line in lines) {
    buffer.writeln('(${_pdfLiteral(line)}) Tj T*');
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

  // object 1 Catalog, 2 Pages, 3 Font, 4..(3+pages) Page,
  // 之后每页一个 Contents stream。
  final fontObj = 3;
  final firstPageObj = 4;
  final firstContentObj = firstPageObj + plan.pageCount;
  final objectCount = firstContentObj + plan.pageCount - 1;

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
  for (var i = 0; i < plan.pageCount; i++) {
    final pageObj = firstPageObj + i;
    final contentObj = firstContentObj + i;
    objects[pageObj] = ascii.encode(
      '<< /Type /Page /Parent 2 0 R '
      '/MediaBox [0 0 ${kA4WidthPt.toStringAsFixed(0)} '
      '${kA4HeightPt.toStringAsFixed(0)}] '
      '/Resources << /Font << /F1 $fontObj 0 R >> >> '
      '/Contents $contentObj 0 R >>',
    );
    final stream = ascii.encode(_contentStream(pageLines[i]));
    objects[contentObj] = <int>[
      ...ascii.encode('<< /Length ${stream.length} >>\nstream\n'),
      ...stream,
      ...ascii.encode('\nendstream'),
    ];
  }

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
