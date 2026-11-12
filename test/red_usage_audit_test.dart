import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/red_usage_audit.dart';

/// docs/10 §12 U4 测试。
void main() {
  test('3 处以内且用途合法 → 通过', () {
    final report = auditRedUsage(const <RedUsage>[
      RedUsage.primaryButton,
      RedUsage.currentState,
      RedUsage.aiAction,
    ]);
    expect(report.count, 3);
    expect(report.passed, isTrue);
    expect(report.suggestions, isEmpty);
  });

  test('超过 3 处给降级建议', () {
    final report = auditRedUsage(const <RedUsage>[
      RedUsage.primaryButton,
      RedUsage.currentState,
      RedUsage.dangerBadge,
      RedUsage.aiAction,
    ]);
    expect(report.passed, isFalse);
    expect(report.suggestions.join(), contains('ghost'));
    expect(kMaxRedPerScreen, 3);
  });

  test('用途不合法即使只有 1 处也不通过', () {
    final report = auditRedUsage(const <RedUsage>[RedUsage.other]);
    expect(report.passed, isFalse);
    expect(report.suggestions.join(), contains('改用蓝'));
  });

  test('空屏通过', () {
    expect(auditRedUsage(const <RedUsage>[]).passed, isTrue);
  });
}
