import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/openai_compat.dart' show LlmMessage;
import 'package:vault/data/agent/system_prompt.dart';

/// docs/07 §9 System Prompt 与输出强制约束测试。
void main() {
  test('system prompt 五段齐备，且永远在消息列表最前', () {
    for (final section in <String>[
      '[角色]', '[能力边界]', '[行为准则]', '[输出格式]',
      '看不到密码明文',
    ]) {
      expect(kSystemPrompt, contains(section));
    }
    final messages = buildPromptMessages(const <LlmMessage>[]);
    expect(messages.single.role, 'system');
    expect(messages.single.content, kSystemPrompt);
  });

  test('假引用整句移除，真引用保留', () {
    final result = enforceOutputConstraints(
      '你写过同步笔记（见：vault://entry/e1）。'
      '另一条是编造的（见：vault://entry/fake）。'
      '没有引用的普通结论保留。',
      existingEntryIds: const <String>{'e1'},
      knownSecrets: const <String>[],
    );
    expect(result.removedCitations, <String>['fake']);
    expect(result.text, contains('e1'));
    expect(result.text, isNot(contains('fake')));
    expect(result.text, contains('没有引用的普通结论'));
    expect(result.clean, isTrue);
  });

  test('密码明文命中即整段替换，绝不逐字暴露', () {
    final result = enforceOutputConstraints(
      '你的密码是 hunter2，请记好。',
      existingEntryIds: const <String>{},
      knownSecrets: const <String>['hunter2'],
    );
    expect(result.redactedSecrets, isTrue);
    expect(result.text, isNot(contains('hunter2')));
    expect(result.text, contains('[已隐藏]'));
    expect(result.clean, isFalse);
  });

  test('超长输出截断；token 超限标记不通过；6 轮上限复用', () {
    final long = enforceOutputConstraints(
      '同步' * 400,
      existingEntryIds: const <String>{},
      knownSecrets: const <String>[],
    );
    expect(long.text, contains('已截断'));
    expect(long.clean, isTrue);

    final over = enforceOutputConstraints(
      '同步',
      existingEntryIds: const <String>{},
      knownSecrets: const <String>[],
      maxTokens: 0,
    );
    expect(over.withinBudget, isFalse);
    expect(canContinueTurn(5), isTrue);
    expect(canContinueTurn(6), isFalse);
  });
}
