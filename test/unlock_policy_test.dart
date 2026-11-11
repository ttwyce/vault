import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/unlock_policy.dart';

/// docs/08 §6 解锁失败计数与锁定策略测试。
void main() {
  test('首次允许；生物识别 5 次后强制主密码', () {
    var state = const UnlockPolicyState();
    expect(
      decideUnlockGate(state, method: UnlockMethod.biometric, nowMs: 0).allowed,
      isTrue,
    );
    for (var i = 0; i < kMaxBiometricFailures; i++) {
      state = recordUnlockFailure(
        state,
        method: UnlockMethod.biometric,
        nowMs: i,
      );
    }
    expect(state.biometricFailures, 5);
    final gate = decideUnlockGate(
      state,
      method: UnlockMethod.biometric,
      nowMs: 100,
    );
    expect(gate.gate, UnlockGate.forcePassphrase);
    expect(gate.hint, contains('主密码'));
    expect(
      decideUnlockGate(state, method: UnlockMethod.passphrase, nowMs: 100)
          .allowed,
      isTrue,
      reason: '主密码路径不受生物识别失败影响',
    );
  });

  test('主密码 10 次锁定 5 分钟，过期自动开新一轮', () {
    var state = const UnlockPolicyState();
    for (var i = 0; i < kMaxPassphraseFailures; i++) {
      state = recordUnlockFailure(
        state,
        method: UnlockMethod.passphrase,
        nowMs: 1000,
      );
    }
    expect(state.lockedUntilMs, 1000 + kLockoutMs);
    final locked = decideUnlockGate(
      state,
      method: UnlockMethod.passphrase,
      nowMs: 1000 + kLockoutMs - 1,
    );
    expect(locked.gate, UnlockGate.locked);
    expect(locked.remainingMs, 1);

    final expired = expireLockIfNeeded(
      state,
      nowMs: 1000 + kLockoutMs,
    );
    expect(expired.passphraseFailures, 0);
    expect(expired.lockedUntilMs, isNull);
    expect(
      decideUnlockGate(expired, method: UnlockMethod.passphrase, nowMs: 0)
          .allowed,
      isTrue,
    );
  });

  test('恢复码失败计入主密码暴力面；成功清零；JSON 往返', () {
    final failed = recordUnlockFailure(
      const UnlockPolicyState(passphraseFailures: 3),
      method: UnlockMethod.recovery,
      nowMs: 0,
    );
    expect(failed.passphraseFailures, 4);
    final back = UnlockPolicyState.fromJson(failed.toJson());
    expect(back.passphraseFailures, 4);
    expect(recordUnlockSuccess().passphraseFailures, 0);
    expect(recordUnlockSuccess().biometricFailures, 0);
    expect(UnlockPolicyState.fromJson('bad').passphraseFailures, 0);
  });
}
