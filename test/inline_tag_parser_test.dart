import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/taxonomy/inline_tag_parser.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';

/// docs/11 §2.5 编辑器 # 行内标签测试。
void main() {
  test('光标前 # 触发建议，词内 # / 空白 / 过长不触发', () {
    expect(
      detectInlineTag('今天研究 #Web', '今天研究 #Web'.length).active,
      isTrue,
    );
    final trigger = detectInlineTag('今天研究 #同步', '今天研究 #同步'.length);
    expect(trigger.query, '同步');
    expect(trigger.start, 5);
    expect(trigger.toJson()['active'], isTrue);

    expect(detectInlineTag('a#b', 3).active, isFalse,
        reason: '# 必须行首或空白后');
    expect(detectInlineTag('#foo bar', 8).active, isFalse,
        reason: '空白后触发器失效');
    expect(detectInlineTag('#${'x' * 21}', 22).active, isFalse);
    expect(detectInlineTag('普通正文', 4).active, isFalse);
  });

  test('抽取行内标签：中文/英文/去重/顺序', () {
    expect(
      extractInlineTags('#同步 #WebDAV #同步 正文 #标签_1'),
      <String>['同步', 'WebDAV', '标签_1'],
    );
    expect(extractInlineTags('word#tag 不算'), isEmpty);
  });

  test('采纳计划去重且上限 8，超出明确标记', () {
    final plan = planInlineTags(<String>[
      '同步', '同步', '工作', 'A', 'B', 'C', 'D', 'E', 'F', 'G',
    ]);
    expect(plan.names, hasLength(TaxonomyRules.maxTagsPerEntry));
    expect(plan.overLimit, isTrue);
    expect(plan.names.first, '同步');

    final short = planInlineTags(<String>['一个', '  ', '两个']);
    expect(short.names, <String>['一个', '两个']);
    expect(short.overLimit, isFalse);
    expect(planInlineTags(const <String>[]).isEmpty, isTrue);
  });
}
