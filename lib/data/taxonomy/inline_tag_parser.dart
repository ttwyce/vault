/// 编辑器内 `#` 行内标签的**纯判定层**（docs/11 §2.5）。
///
/// 不写库、不改正文：只做「输入到 `#` 时是否弹建议、提取哪些标签、
/// 去重与上限 8、是否触发搜索」。真实标签创建/关联由编辑器写入口执行。
library;

import '../taxonomy/taxonomy_models.dart' show TaxonomyRules;

class InlineTagTrigger {
  const InlineTagTrigger({
    required this.active,
    required this.query,
    required this.start,
  });

  final bool active;
  final String query;
  final int start;

  Map<String, Object?> toJson() => <String, Object?>{
        'active': active,
        'query': query,
        'start': start,
      };
}

/// 光标前最近的 `#xxx`：要求 `#` 在行首或空白之后，词内只允许
/// 中文/字母/数字/_-，且长度 ≤ 20；遇到空白/换行即失效。
InlineTagTrigger detectInlineTag(String text, int cursor) {
  final clamped = cursor.clamp(0, text.length);
  var i = clamped - 1;
  while (i >= 0) {
    final ch = text[i];
    if (ch == '\n' || ch == ' ' || ch == '\t') break;
    if (ch == '#') break;
    i--;
  }
  if (i < 0 || text[i] != '#') {
    return const InlineTagTrigger(active: false, query: '', start: -1);
  }
  if (i > 0 && !RegExp(r'[\s]').hasMatch(text[i - 1])) {
    return const InlineTagTrigger(active: false, query: '', start: -1);
  }
  final query = text.substring(i + 1, clamped);
  if (query.length > 20 || RegExp(r'[\s#]').hasMatch(query)) {
    return const InlineTagTrigger(active: false, query: '', start: -1);
  }
  return InlineTagTrigger(active: true, query: query, start: i);
}

/// 从一段正文里抽出全部行内标签（按出现顺序去重）。
List<String> extractInlineTags(String body) {
  final out = <String>[];
  final seen = <String>{};
  for (final match in RegExp(r'(?<![\S])#([\u4e00-\u9fffA-Za-z0-9_-]{1,20})')
      .allMatches(body)) {
    final name = match.group(1)!;
    if (name.isEmpty || seen.contains(name)) continue;
    seen.add(name);
    out.add(name);
  }
  return List<String>.unmodifiable(out);
}

class InlineTagPlan {
  const InlineTagPlan({
    required this.names,
    required this.overLimit,
  });

  final List<String> names;
  final bool overLimit;

  bool get isEmpty => names.isEmpty;
}

/// 采纳建议：去重、最多 8 个，超出部分明确标记而不是静默丢弃。
InlineTagPlan planInlineTags(
  Iterable<String> candidates, {
  int maxTags = TaxonomyRules.maxTagsPerEntry,
}) {
  final seen = <String>{};
  final names = <String>[];
  for (final raw in candidates) {
    final name = raw.trim();
    if (name.isEmpty || seen.contains(name)) continue;
    seen.add(name);
    names.add(name);
  }
  return InlineTagPlan(
    names: List<String>.unmodifiable(
      names.length > maxTags ? names.sublist(0, maxTags) : names,
    ),
    overLimit: names.length > maxTags,
  );
}
