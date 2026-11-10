import 'package:flutter/material.dart';

/// 把命中查询词的字符染成另一种样式。
///
/// 中文检索是**按字切分 + 短语查询**（见 docs/06 §1.3），所以高亮也按字做，
/// 不能拿整个词去 `String.indexOf` —— 用户搜「同步」，正文里写「一同步伐」
/// 里的「同」「步」也会亮，这与 FTS 的召回行为保持一致。
///
/// 刻意做成纯函数：高亮逻辑没有 widget 依赖，单测不用搭界面。
List<TextSpan> highlightSpans(
  String text,
  String query, {
  required TextStyle base,
  required TextStyle hit,
}) {
  final chars = query
      .trim()
      .split('')
      .where((String c) => c.trim().isNotEmpty)
      .toSet();
  if (chars.isEmpty || text.isEmpty) {
    return <TextSpan>[TextSpan(text: text, style: base)];
  }

  final spans = <TextSpan>[];
  final plain = StringBuffer();
  void flush() {
    if (plain.isEmpty) return;
    spans.add(TextSpan(text: plain.toString(), style: base));
    plain.clear();
  }

  for (final ch in text.split('')) {
    if (chars.contains(ch)) {
      flush();
      spans.add(TextSpan(text: ch, style: hit));
    } else {
      plain.write(ch);
    }
  }
  flush();
  return spans;
}
