/// 改主密码 / 重置恢复码的表单判定（docs/18 §9 / docs/16 §5）。
///
/// 不读写 `meta.enc`、不派生密钥：只校验输入并给出可执行的动作与文案，
/// 真实 `VaultLock.changePassphrase` / `regenerateRecoveryCode` 由 UI 调用。
library;

import '../../data/vault/credential_models.dart' show estimatePasswordStrength;

enum VaultCredentialAction { none, changePassphrase, regenerateRecoveryCode }

class VaultCredentialPlan {
  const VaultCredentialPlan({
    required this.action,
    required this.allowed,
    required this.needsSecondConfirm,
    required this.hint,
  });

  final VaultCredentialAction action;
  final bool allowed;
  final bool needsSecondConfirm;
  final String hint;
}

/// 新密码至少 8 字且强度 > 0；与当前密码相同直接拒绝。
VaultCredentialPlan planPassphraseChange({
  required String currentPassphrase,
  required String newPassphrase,
  required String confirmPassphrase,
}) {
  if (currentPassphrase.isEmpty) {
    return const VaultCredentialPlan(
      action: VaultCredentialAction.changePassphrase,
      allowed: false,
      needsSecondConfirm: false,
      hint: '请先输入当前主密码',
    );
  }
  if (newPassphrase.length < 8) {
    return const VaultCredentialPlan(
      action: VaultCredentialAction.changePassphrase,
      allowed: false,
      needsSecondConfirm: false,
      hint: '新主密码至少 8 个字符',
    );
  }
  if (newPassphrase != confirmPassphrase) {
    return const VaultCredentialPlan(
      action: VaultCredentialAction.changePassphrase,
      allowed: false,
      needsSecondConfirm: false,
      hint: '两次输入的新主密码不一致',
    );
  }
  if (newPassphrase == currentPassphrase) {
    return const VaultCredentialPlan(
      action: VaultCredentialAction.changePassphrase,
      allowed: false,
      needsSecondConfirm: false,
      hint: '新主密码不能与当前相同',
    );
  }
  if (estimatePasswordStrength(newPassphrase) <= 0) {
    return const VaultCredentialPlan(
      action: VaultCredentialAction.changePassphrase,
      allowed: false,
      needsSecondConfirm: false,
      hint: '新主密码是常见弱模式，请换一个',
    );
  }
  return const VaultCredentialPlan(
    action: VaultCredentialAction.changePassphrase,
    allowed: true,
    needsSecondConfirm: true,
    hint: '将重新用 KDF 包裹同一把 DEK，条目密文不变；'
        '主密码本身无法找回，请确认已记牢',
  );
}

/// 重置恢复码必须二次确认；旧码立即失效。
VaultCredentialPlan planRecoveryCodeRegeneration({
  required bool userConfirmed,
}) =>
    VaultCredentialPlan(
      action: VaultCredentialAction.regenerateRecoveryCode,
      allowed: userConfirmed,
      needsSecondConfirm: true,
      hint: userConfirmed
          ? '将生成新 24 词恢复码，旧码立即失效；请抄写并离线保存'
          : '重置恢复码会使旧码立即失效，请先二次确认',
    );
