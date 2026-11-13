import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/simple_pdf.dart';

/// docs/05 §8：纯 Dart 简易 PDF 结构测试（不引 pdf 包）。
void main() {
  test('空正文不生成，0 页', () {
    final result = buildSimplePdf('   \n  ');
    expect(result.ok, isFalse);
    expect(result.pageCount, 0);
    expect(result.bytes, isEmpty);
  });

  test('短正文生成 1 页合法 PDF：头 / 尾 / xref / 字体 / 页对象', () {
    final result = buildSimplePdf('# 标题\n\n正文 A B C\n第二行');
    expect(result.ok, isTrue);
    expect(result.pageCount, 1);
    final text = ascii.decode(result.bytes);
    expect(text.startsWith('%PDF-1.4'), isTrue);
    expect(text.trimRight().endsWith('%%EOF'), isTrue);
    expect(text, contains('/Type /Catalog'));
    expect(text, contains('/Type /Pages'));
    expect(text, contains('/BaseFont /Helvetica'));
    expect(text, contains('/MediaBox [0 0 595 842]'));
    expect(text, contains('startxref'));
    // 含中文的行走 UTF-16BE hex，ASCII 文本也在其中编码。
    expect(text.toUpperCase(), contains('00410020004200200043'));
  });

  test('长正文按 A4 分页，xref 条目数 = 对象数 + 1', () {
    final long = List<String>.generate(
      180,
      (int i) => 'line $i content for pagination check',
    ).join('\n');
    final result = buildSimplePdf(long);
    expect(result.ok, isTrue);
    expect(result.pageCount, greaterThan(1));
    final text = ascii.decode(result.bytes);
    final xrefIndex = text.indexOf('xref\n');
    final xrefHeader = text.substring(xrefIndex, text.indexOf('\n', xrefIndex + 5) + 1);
    final size = int.parse(xrefHeader.split('\n')[1].trim().split(' ')[1]);
    // 1 Catalog + 1 Pages + 2 Font + 1 CIDFont + pages Page +
    // pages Contents + 1 空闲
    expect(size, 6 + result.pageCount * 2);
    expect(text, contains('/Count ${result.pageCount}'));
  });

  test('中文 / 特殊字符不崩且转义括号与反斜杠', () {
    final result = buildSimplePdf('中文正文 (括号) \\ 反斜杠');
    expect(result.ok, isTrue);
    final text = ascii.decode(result.bytes);
    // 中文行走 CJK 字体的 UTF-16BE hex：括号/反斜杠以码位出现，
    // 不再需要 PDF 字符串字面量转义。
    expect(text, contains('0028'));
    expect(text, contains('0029'));
    expect(text, contains('005C'));
  });

  test('中文使用标准 CJK 字体与 UTF-16BE 字符串，不再全变问号', () {
    final result = buildSimplePdf('中文正文测试');
    expect(result.ok, isTrue);
    final text = ascii.decode(result.bytes);
    expect(text, contains('/Subtype /Type0'));
    expect(text, contains('/BaseFont /STSong-Light'));
    expect(text, contains('/Encoding /UniGB-UCS2-H'));
    expect(text.toUpperCase(), contains('4E2D6587'));
    expect(text, isNot(contains('????')));
  });
}
