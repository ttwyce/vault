import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/passphrase_change_policy.dart';

/// docs/18 §9 改主密码 / 重置恢复码判定测试。
void main() {
  test('空当前密码 / 过短 / 不一致 / 与旧相同 / 弱密码一律拒绝', () {
    expect(
      planPassphraseChange(
        currentPassphrase: '',
        newPassphrase: 'NewStrong!234',
        confirmPassphrase: 'NewStrong!234',
      ).allowed,
      isFalse,
    );
    expect(
      planPassphraseChange(
        currentPassphrase: 'OldStrong!234',
        newPassphrase: 'short',
        confirmPassphrase: 'short',
      ).hint,
      contains('8 个'),
    );
    expect(
      planPassphraseChange(
        currentPassphrase: 'OldStrong!234',
        newPassphrase: 'NewStrong!234',
        confirmPassphrase: 'Other!234',
      ).hint,
      contains('不一致'),
    );
    expect(
      planPassphraseChange(
        currentPassphrase: 'SameStrong!234',
        newPassphrase: 'SameStrong!234',
        confirmPassphrase: 'SameStrong!234',
      ).hint,
      contains('相同'),
    );
    expect(
      planPassphraseChange(
        currentPassphrase: 'OldStrong!234',
        newPassphrase: 'password123!',
        confirmPassphrase: 'password123!',
      ).hint,
      contains('弱'),
    );
  });

  test('合法新密码允许且需二次确认；说明 DEK 不变', () {
    final plan = planPassphraseChange(
      currentPassphrase: 'OldStrong!234',
      newPassphrase: 'Zx9!NewLongPass',
      confirmPassphrase: 'Zx9!NewLongPass',
    );
    expect(plan.allowed, isTrue);
    expect(plan.needsSecondConfirm, isTrue);
    expect(plan.hint, contains('DEK'));
    expect(plan.action, VaultCredentialAction.changePassphrase);
  });

  test('重置恢复码未确认拒绝，确认后提示旧码立即失效', () {
    final before = planRecoveryCodeRegeneration(userConfirmed: false);
    expect(before.allowed, isFalse);
    expect(before.hint, contains('二次确认'));
    final after = planRecoveryCodeRegeneration(userConfirmed: true);
    expect(after.allowed, isTrue);
    expect(after.hint, contains('旧码立即失效'));
  });
}
