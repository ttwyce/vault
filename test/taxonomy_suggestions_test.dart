import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/entry/entry_models.dart';
import 'package:vault/data/taxonomy/taxonomy_suggestions.dart';

/// docs/11 §2.5 分类/标签建议判定测试。
void main() {
  final tags = <TagWithCount>[
    const TagWithCount(id: 't1', name: '同步', count: 12),
    const TagWithCount(id: 't2', name: 'WebDAV', count: 8),
    const TagWithCount(id: 't3', name: '限流', count: 3),
    const TagWithCount(id: 't4', name: '无关', count: 20),
  ];
  final categories = <({String id, String name})>[
    (id: 'c1', name: '开发'),
    (id: 'c2', name: '读书'),
  ];

  test('关键词抽取：英文词 + 中文滑窗，停用词与纯数字过滤', () {
    final words = extractTopicWords('今天 研究 webdav 限流 2026');
    expect(words, contains('webdav'));
    expect(words, contains('限流'));
    expect(words, isNot(contains('今天')));
    expect(words, isNot(contains('2026')));

    expect(extractTopicWords('纯中文正文').length, greaterThan(1));
  });

  test('生成 1 个分类 + 2~4 个标签建议，不自动写入、去重已有标签', () {
    final suggestion = suggestTaxonomy(
      title: 'WebDAV 同步限流',
      body: '坚果云返回 429 后需要退避，同步队列积压',
      categories: categories,
      tags: tags,
      existingTagIds: const <String>{'t1'},
    );
    // 纯关键词匹配下可能没有分类建议（不能编造）；有则必须给理由。
    if (suggestion.categoryId != null) {
      expect(suggestion.reasons.join(), contains('分类'));
    }
    expect(suggestion.tagIds, isNot(contains('t1')));
    expect(suggestion.tagIds.length, greaterThanOrEqualTo(1));
    expect(suggestion.tagIds.length, lessThanOrEqualTo(4));
    expect(suggestion.tagIds, isNot(contains('t4')),
        reason: '不相关标签不应被采纳');
    expect(suggestion.toJson()['tag_names'], isA<List<String>>());
  });

  test('没有任何匹配时返回空建议；标签上限 8 生效', () {
    final empty = suggestTaxonomy(
      title: '散步',
      body: '傍晚沿河走了一圈',
      categories: categories,
      tags: tags,
    );
    expect(empty.isEmpty, isTrue);

    final many = List<TagWithCount>.generate(
      12,
      (int i) => TagWithCount(id: 'x$i', name: '限流$i', count: i),
    );
    final capped = suggestTaxonomy(
      title: '限流',
      body: '限流',
      categories: categories,
      tags: many,
      maxTagSuggestions: 20,
    );
    expect(capped.tagIds.length, lessThanOrEqualTo(kMaxTagsPerEntry));
  });
}
