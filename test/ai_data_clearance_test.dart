import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/ai_data_clearance.dart';

/// docs/07 §7.3 清除所有 AI 数据测试。
void main() {
  test('未确认不允许执行，提示不可逆与用户内容安全', () {
    final plan = planAiDataClearance(userConfirmed: false);
    expect(plan.allowed, isFalse);
    expect(plan.hint, contains('不可逆'));
    expect(plan.hint, contains('不会被删除'));
  });

  test('确认后给出 5 个数据域与有序步骤', () {
    final plan = planAiDataClearance(userConfirmed: true);
    expect(plan.allowed, isTrue);
    expect(plan.domains, hasLength(5));
    expect(plan.domains, contains(AiDataDomain.apiKey));
    expect(plan.steps.first, contains('停掉'));
    expect(plan.steps.join(), contains('用户日记不动'));
    expect(plan.toJson()['domains'], isA<List<String>>());
  });

  test('keepUserNotes=false 一律拒绝（防止误删用户手写内容）', () {
    final plan = planAiDataClearance(
      userConfirmed: true,
      keepUserNotes: false,
    );
    expect(plan.allowed, isFalse);
  });
}
