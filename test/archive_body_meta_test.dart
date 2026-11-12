import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_body_meta.dart';

/// docs/05 §10 归档正文派生 meta 测试。
void main() {
  test('空正文：摘要空、时长 0', () {
    final plan = planArchiveBodyMeta('   \n  ');
    expect(plan.excerpt, isEmpty);
    expect(plan.readingTimeMin, 0);
  });

  test('去 Markdown 标记与代码块，摘要取前 200 字', () {
    final plan = planArchiveBodyMeta(
      '# 标题\n\n**加粗**正文 [链接](https://example.com)\n'
      '```code 不该进摘要```\n${'长' * 300}',
    );
    expect(plan.excerpt, isNot(contains('#')));
    expect(plan.excerpt, isNot(contains('```')));
    expect(plan.excerpt, isNot(contains('code 不该进摘要')));
    expect(plan.excerpt.length, kArchiveExcerptChars);
    expect(plan.excerpt, contains('加粗'));
    expect(plan.excerpt, contains('正文'));
    expect(plan.excerpt, contains('链接'));
    expect(plan.excerpt, isNot(contains('\$1')));
  });

  test('阅读时长按中文 300 字/分、英文 200 词/分估算', () {
    expect(planArchiveBodyMeta('文' * 300).readingTimeMin, 1);
    expect(planArchiveBodyMeta('文' * 301).readingTimeMin, 2);
    expect(planArchiveBodyMeta('word ' * 200).readingTimeMin, 1);
    expect(planArchiveBodyMeta('短正文').readingTimeMin, 1);
  });
}
