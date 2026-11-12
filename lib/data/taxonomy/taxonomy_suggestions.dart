/// 分类 / 标签建议的**纯判定层**（docs/11 §2.5）。
///
/// 不调模型、不写库：从标题 + 正文抽关键词，匹配已有分类/标签，
/// 给出 1 个分类建议 + 2~4 个标签建议（**不自动写入**），标签上限 8。
/// 采纳动作由 UI 走唯一写入口执行。
library;

import '../entry/entry_models.dart' show TagWithCount;

/// 标签上限（docs/11 §2.5）。
const int kMaxTagsPerEntry = 8;

class TaxonomySuggestion {
  const TaxonomySuggestion({
    required this.categoryId,
    required this.categoryName,
    required this.tagIds,
    required this.tagNames,
    required this.reasons,
  });

  /// 0~1 个分类建议；空串表示没有匹配。
  final String? categoryId;
  final String? categoryName;
  final List<String> tagIds;
  final List<String> tagNames;
  final List<String> reasons;

  bool get isEmpty =>
      (categoryId == null || categoryId!.isEmpty) && tagIds.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'category_id': categoryId,
        'category_name': categoryName,
        'tag_ids': tagIds,
        'tag_names': tagNames,
        'reasons': reasons,
      };
}

/// 关键词抽取：中文按 2~4 字滑窗、英文按词；去掉停用词与纯数字。
List<String> extractTopicWords(String text, {int maxWords = 40}) {
  final normalized = text.toLowerCase();
  final out = <String>[];
  final seen = <String>{};
  void add(String word) {
    if (word.isEmpty || _stopWords.contains(word) || seen.contains(word)) return;
    if (RegExp(r'^\d+$').hasMatch(word)) return;
    seen.add(word);
    out.add(word);
  }

  // 英文 / 数字混合词。
  for (final match in RegExp(r'[a-z][a-z0-9_-]{2,}').allMatches(normalized)) {
    add(match.group(0)!);
  }
  // 中文 2~4 字滑窗，只取连续汉字片段。
  for (final match in RegExp(r'[\u4e00-\u9fff]{2,}').allMatches(normalized)) {
    final run = match.group(0)!;
    for (var size = 2; size <= 4 && size <= run.length; size++) {
      for (var i = 0; i + size <= run.length; i++) {
        add(run.substring(i, i + size));
        if (out.length >= maxWords) {
          return List<String>.unmodifiable(out);
        }
      }
    }
  }
  return List<String>.unmodifiable(out);
}

const Set<String> _stopWords = <String>{
  'the', 'and', 'for', 'with', 'this', 'that', '今天', '昨天', '一个',
  '我们', '可以', '这个', '什么', '怎么', '笔记', '正文',
};

/// 生成建议：按「名称包含关键词」+ 使用次数加权的顺序取 top。
TaxonomySuggestion suggestTaxonomy({
  required String title,
  required String body,
  required List<({String id, String name})> categories,
  required List<TagWithCount> tags,
  Set<String> existingTagIds = const <String>{},
  int maxTagSuggestions = 4,
}) {
  final words = extractTopicWords('$title $body');
  final reasons = <String>[];

  ({String id, String name})? bestCategory;
  var bestScore = 0;
  for (final category in categories) {
    final score = _matchScore(category.name.toLowerCase(), words);
    if (score > bestScore) {
      bestScore = score;
      bestCategory = category;
    }
  }
  if (bestCategory != null) {
    reasons.add('分类「${bestCategory.name}」与正文关键词匹配');
  }

  final ranked = tags.toList()
    ..sort((TagWithCount a, TagWithCount b) {
      final byScore = _matchScore(b.name.toLowerCase(), words)
          .compareTo(_matchScore(a.name.toLowerCase(), words));
      return byScore != 0 ? byScore : b.count.compareTo(a.count);
    });
  final suggestions = <TagWithCount>[];
  for (final tag in ranked) {
    if (existingTagIds.contains(tag.id)) continue;
    if (_matchScore(tag.name.toLowerCase(), words) == 0) continue;
    suggestions.add(tag);
    if (suggestions.length >= maxTagSuggestions ||
        existingTagIds.length + suggestions.length >= kMaxTagsPerEntry) {
      break;
    }
  }
  if (suggestions.isNotEmpty) {
    reasons.add('匹配到 ${suggestions.length} 个已有标签（按使用次数加权）');
  }
  return TaxonomySuggestion(
    categoryId: bestCategory?.id,
    categoryName: bestCategory?.name,
    tagIds: <String>[for (final tag in suggestions) tag.id],
    tagNames: <String>[for (final tag in suggestions) tag.name],
    reasons: List<String>.unmodifiable(reasons),
  );
}

int _matchScore(String name, List<String> words) {
  var score = 0;
  for (final word in words) {
    if (word.length < 2) continue;
    if (name.contains(word) || word.contains(name)) score += word.length;
  }
  return score;
}
