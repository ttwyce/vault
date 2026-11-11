import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/search_suggestions.dart';

/// docs/06 §8.2 空结果改写建议测试。
void main() {
  test('空查询不给建议', () {
    expect(suggestQueryRewrites('  '), isEmpty);
  });

  test('普通查询给至多 3 条、去重且不含原查询', () {
    final suggestions = suggestQueryRewrites('增量同步的限流策略');
    expect(suggestions, isNotEmpty);
    expect(suggestions.length, lessThanOrEqualTo(3));
    expect(suggestions.toSet().length, suggestions.length);
    expect(suggestions, isNot(contains('增量同步的限流策略')));
  });

  test('类型限定词被剥离，时间意图不进建议', () {
    final suggestions =
        suggestQueryRewrites('最近那篇同步笔记');
    expect(suggestions.join(' '), isNot(contains('最近')));
    expect(suggestions.join(' '), isNot(contains('笔记')));
    expect(suggestions, isNotEmpty);
  });

  test('FTS 有结果但无向量时才显示模型提示', () {
    final withFts = planEmptySearchHint(
      rawQuery: '同步',
      ftsHadResults: true,
      vectorHadResults: false,
    );
    expect(withFts.showModelTip, isTrue);
    final bothEmpty = planEmptySearchHint(
      rawQuery: '不存在的词',
      ftsHadResults: false,
      vectorHadResults: false,
    );
    expect(bothEmpty.showModelTip, isFalse);
    expect(withFts.headline, '换个说法试试');
    expect(withFts.modelTip, contains('下载语义模型'));
  });
}
