/// 生物识别解锁的会话策略（docs/18 §9）。
///
/// 不碰平台通道：只把 [UnlockPolicyState] 与「是否注册 / 是否可用」
/// 合成一个用户可理解的闸门，供解锁页决定按钮与提示。
library;

import 'unlock_policy.dart';

enum BiometricGate { available, unavailable, notEnrolled, forcePassphrase, locked }

class BiometricDecision {
  const BiometricDecision(this.gate, this.hint);
  final BiometricGate gate;
  final String hint;
}

BiometricDecision decideBiometricGate({
  required bool platformAvailable,
  required bool enrolled,
  required UnlockPolicyState policy,
  required int nowMs,
}) {
  final base = decideUnlockGate(
    policy,
    method: UnlockMethod.biometric,
    nowMs: nowMs,
  );
  if (base.gate == UnlockGate.locked) {
    return BiometricDecision(BiometricGate.locked, base.hint);
  }
  if (base.gate == UnlockGate.forcePassphrase) {
    return BiometricDecision(
      BiometricGate.forcePassphrase,
      base.hint,
    );
  }
  if (!platformAvailable) {
    return const BiometricDecision(
      BiometricGate.unavailable,
      '此设备暂不支持生物识别，请用主密码',
    );
  }
  if (!enrolled) {
    return const BiometricDecision(
      BiometricGate.notEnrolled,
      '请先用主密码登录一次以启用生物识别',
    );
  }
  return const BiometricDecision(
    BiometricGate.available,
    '可用指纹 / 面容解锁，跳过主密码派生',
  );
}
