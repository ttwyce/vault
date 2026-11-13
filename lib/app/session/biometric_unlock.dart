/// 生物识别解锁（docs/18 §9）。
///
/// 不新增 pubspec 依赖：平台传感器与受 Keystore/Keychain 保护的 DEK
/// 经 MethodChannel 实现。认证成功后原生层才把 DEK 明文返回 Dart，
/// 跳过 Argon2id 直接装配 [UnlockedVault]；认证不通过拿不到任何密钥。
/// Windows / 原生层未就绪时明确返回「不可用」，不假装通过认证。
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/crypto/secret_bytes.dart';
import '../../core/crypto/vault_keys.dart';
import '../../core/crypto/vault_lock.dart';
import '../../core/crypto/vault_meta.dart';

const String kVaultBiometricChannel = 'vault/biometric';
const MethodChannel _channel = MethodChannel(kVaultBiometricChannel);

class BiometricUnlockResult {
  const BiometricUnlockResult({
    required this.ok,
    required this.hint,
    this.unlocked,
  });

  final bool ok;
  final String hint;
  final UnlockedVault? unlocked;
}

/// 认证器抽象：生产走 MethodChannel，测试可注入 fake，不需要真机传感器。
abstract class BiometricAuthenticator {
  Future<bool> isAvailable();
  Future<bool> hasEnrollment();
  Future<bool> enroll(String dekBase64);
  Future<String?> authenticate();
  Future<void> disable();
}

class PlatformBiometricAuthenticator implements BiometricAuthenticator {
  const PlatformBiometricAuthenticator({this.channel = _channel});

  final MethodChannel channel;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<bool> isAvailable() async =>
      await _invoke<bool>('isAvailable') ?? false;

  @override
  Future<bool> hasEnrollment() async =>
      await _invoke<bool>('hasEnrollment') ?? false;

  @override
  Future<bool> enroll(String dekBase64) async =>
      await _invoke<bool>('enroll', <String, Object?>{'dek': dekBase64}) ??
      false;

  @override
  Future<String?> authenticate() => _invoke<String>('authenticate');

  @override
  Future<void> disable() async {
    await _invoke<bool>('disable');
  }
}

class BiometricVaultUnlock {
  const BiometricVaultUnlock({
    this.authenticator = const PlatformBiometricAuthenticator(),
  });

  final BiometricAuthenticator authenticator;

  Future<bool> isAvailable() => authenticator.isAvailable();
  Future<bool> hasEnrollment() => authenticator.hasEnrollment();
  Future<void> disable() => authenticator.disable();

  /// 主密码解锁成功后调用：把这次解出的原始 DEK 交给原生层，由
  /// Android Keystore / iOS Keychain 绑定到生物识别认证后加密保存。
  Future<bool> enroll({required SecretBytes dek}) =>
      authenticator.enroll(base64.encode(dek.bytes));

  /// 认证 + 读回 DEK + 装配会话。任何一步失败都返回明确原因。
  Future<BiometricUnlockResult> unlock(VaultMeta meta) async {
    final available = await isAvailable();
    if (!available) {
      return const BiometricUnlockResult(
        ok: false,
        hint: '此设备暂不支持生物识别，请用主密码',
      );
    }
    final raw = await authenticator.authenticate();
    if (raw == null) {
      return const BiometricUnlockResult(
        ok: false,
        hint: '生物识别未通过，请重试或用主密码',
      );
    }
    final List<int> dekBytes;
    try {
      dekBytes = base64.decode(raw);
    } on Object {
      await disable();
      return const BiometricUnlockResult(
        ok: false,
        hint: '生物识别凭据损坏，已清除，请用主密码登录',
      );
    }
    if (dekBytes.length != VaultKeys.dekLength) {
      await disable();
      return const BiometricUnlockResult(
        ok: false,
        hint: '生物识别凭据长度异常，已清除，请用主密码登录',
      );
    }
    final keys = VaultKeys(SecretBytes(Uint8List.fromList(dekBytes)));
    return BiometricUnlockResult(
      ok: true,
      hint: '生物识别解锁成功',
      unlocked: UnlockedVault(meta: meta, keys: keys),
    );
  }
}
