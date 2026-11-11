/// 解锁失败计数与锁定策略（docs/08 §6）。
///
/// 不碰安全存储、不调生物识别 API：只做「连续失败几次该锁多久、
/// 生物识别失败何时强制主密码、倒计时文案怎么显示」。
/// 真实计数持久化由平台层按 [UnlockPolicyState.toJson] 落本地设置。
library;

/// 阈值。
const int kMaxPassphraseFailures = 10;
const int kMaxBiometricFailures = 5;
const int kLockoutMs = 300000; // 5 分钟

enum UnlockMethod { passphrase, recovery, biometric }

enum UnlockGate { allowed, locked, forcePassphrase }

class UnlockPolicyState {
  const UnlockPolicyState({
    this.passphraseFailures = 0,
    this.biometricFailures = 0,
    this.lockedUntilMs,
  });

  final int passphraseFailures;
  final int biometricFailures;
  final int? lockedUntilMs;

  UnlockPolicyState copyWith({
    int? passphraseFailures,
    int? biometricFailures,
    int? lockedUntilMs,
    bool clearLock = false,
  }) =>
      UnlockPolicyState(
        passphraseFailures: passphraseFailures ?? this.passphraseFailures,
        biometricFailures: biometricFailures ?? this.biometricFailures,
        lockedUntilMs:
            clearLock ? null : (lockedUntilMs ?? this.lockedUntilMs),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'passphrase_failures': passphraseFailures,
        'biometric_failures': biometricFailures,
        'locked_until': lockedUntilMs,
      };

  factory UnlockPolicyState.fromJson(Object? raw) {
    if (raw is! Map) return const UnlockPolicyState();
    final p = raw['passphrase_failures'];
    final b = raw['biometric_failures'];
    final locked = raw['locked_until'];
    return UnlockPolicyState(
      passphraseFailures: p is num ? p.toInt() : 0,
      biometricFailures: b is num ? b.toInt() : 0,
      lockedUntilMs: locked is num ? locked.toInt() : null,
    );
  }
}

class UnlockDecision {
  const UnlockDecision({
    required this.gate,
    required this.hint,
    required this.remainingMs,
  });

  final UnlockGate gate;
  final String hint;
  final int remainingMs;

  bool get allowed => gate == UnlockGate.allowed;
}

/// 当前能否尝试解锁。
UnlockDecision decideUnlockGate(
  UnlockPolicyState state, {
  required UnlockMethod method,
  required int nowMs,
}) {
  final until = state.lockedUntilMs;
  if (until != null && nowMs < until) {
    final remaining = until - nowMs;
    return UnlockDecision(
      gate: UnlockGate.locked,
      hint: '连续输错，${(remaining / 1000).ceil()} 秒后重试',
      remainingMs: remaining,
    );
  }
  if (state.biometricFailures >= kMaxBiometricFailures &&
      method == UnlockMethod.biometric) {
    return const UnlockDecision(
      gate: UnlockGate.forcePassphrase,
      hint: '生物识别失败 5 次，请改用主密码',
      remainingMs: 0,
    );
  }
  return const UnlockDecision(
    gate: UnlockGate.allowed,
    hint: '',
    remainingMs: 0,
  );
}

/// 一次失败后推进状态。主密码错误 10 次 → 锁 5 分钟；
/// 恢复码错误也计入主密码失败（同一把 DEK 的暴力面）。
UnlockPolicyState recordUnlockFailure(
  UnlockPolicyState state, {
  required UnlockMethod method,
  required int nowMs,
}) {
  if (method == UnlockMethod.biometric) {
    return state.copyWith(biometricFailures: state.biometricFailures + 1);
  }
  final failures = state.passphraseFailures + 1;
  if (failures >= kMaxPassphraseFailures) {
    return UnlockPolicyState(
      passphraseFailures: failures,
      biometricFailures: state.biometricFailures,
      lockedUntilMs: nowMs + kLockoutMs,
    );
  }
  return state.copyWith(passphraseFailures: failures);
}

/// 成功后清零全部计数（生物识别失败数也随成功解锁重置）。
UnlockPolicyState recordUnlockSuccess() => const UnlockPolicyState();

/// 锁定窗口过期后开启新一轮计数（5 分钟结束即给新的 10 次机会）。
UnlockPolicyState expireLockIfNeeded(
  UnlockPolicyState state, {
  required int nowMs,
}) {
  final until = state.lockedUntilMs;
  if (until != null && nowMs >= until) {
    return const UnlockPolicyState();
  }
  return state;
}
