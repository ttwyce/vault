/// 搜索空结果的**纯判定层**（docs/06 §8.2）。
///
/// 不调模型：用确定性规则给 3 个查询改写建议（端侧模型未接入前也可给），
/// 并判断要不要提示「下载语义模型可获得更好效果」。
library;

import 'hybrid_search.dart' show preprocessSearchQuery;

/// 3 个改写建议（按顺序、去重、不含原查询本身）。
List<String> suggestQueryRewrites(String rawQuery, {int nowMs = 0}) {
  final trimmed = rawQuery.trim();
  if (trimmed.isEmpty) return const <String>[];
  final parsed = preprocessSearchQuery(trimmed, nowMs: nowMs);
  final out = <String>[];

  void add(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text == trimmed || out.contains(text)) return;
    out.add(text);
  }

  // ① 用预处理后的纯净短语（已剥类型限定词/停用词/时间词）。
  add(parsed.ftsPhrase);

  // ② 拆成更短的关键词：取最长的一个 token，降低过拟合。
  final tokens = parsed.ftsPhrase
      .replaceAll('"', '')
      .split(RegExp(r'\s+'))
      .where((String t) => t.isNotEmpty)
      .toList()
    ..sort((String a, String b) => b.length.compareTo(a.length));
  if (tokens.isNotEmpty) add(tokens.first);
  if (tokens.length > 1) add(tokens.sublist(0, 2).join(' '));

  // ③ 去掉可能的时间/类型意图，回到最朴素的说法。
  final plain = trimmed
      .replaceAll(RegExp('最近|上周|上个月|今天|昨天|那篇|这篇|日记|笔记|归档|书签'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  add(plain.isEmpty ? trimmed : plain);

  return List<String>.unmodifiable(out.take(3));
}

/// 空结果提示：FTS 有命中但无向量时才提示下载模型；
/// 两边都空时只给「换个说法」。
class EmptySearchHint {
  const EmptySearchHint({
    required this.suggestions,
    required this.showModelTip,
  });

  final List<String> suggestions;
  final bool showModelTip;

  String get headline => '换个说法试试';
  String get modelTip => '已启用关键词匹配，下载语义模型可获得更好效果';
}

EmptySearchHint planEmptySearchHint({
  required String rawQuery,
  required bool ftsHadResults,
  required bool vectorHadResults,
  int nowMs = 0,
}) =>
    EmptySearchHint(
      suggestions: suggestQueryRewrites(rawQuery, nowMs: nowMs),
      showModelTip: ftsHadResults && !vectorHadResults,
    );
