import 'dart:math';

import '../identity/uuid_v7.dart';
import 'argon2_params.dart';
import 'kdf.dart';
import 'recovery_code.dart';
import 'secret_bytes.dart';
import 'secret_wrapper.dart';
import 'vault_keys.dart';
import 'vault_meta.dart';

/// 解锁后的 vault。
///
/// 持有一把活着的 DEK。**用完必须 [dispose]** —— 虽然 Dart 的 GC 迟早会回收，
/// 但锁屏后立刻清零能让"设备被拿走时内存里还有明文密钥"这个窗口尽量小。
class UnlockedVault {
  UnlockedVault({
    required this.meta,
    required this.keys,
    this.recoveryCode,
    this.dekForEnrollment,
  });

  final VaultMeta meta;
  final VaultKeys keys;

  /// 仅「本次用主密码 / 恢复码解包」时有值：把原始 DEK 交给系统安全区
  /// 注册生物识别解锁。生物识别解锁路径没有这个值（它从安全区读回后
  /// 直接构造 VaultKeys）。绝不写日志、不落本地文件。
  final SecretBytes? dekForEnrollment;

  /// 仅在"刚创建"或"刚重新生成"时有值。
  ///
  /// 这是恢复码明文**唯一一次**出现在内存里的时机，UI 必须在这时候
  /// 引导用户抄写，之后无法再取回（系统只存被包裹的 DEK，不存词）。
  final RecoveryCode? recoveryCode;

  void dispose() => keys.destroy();
}

/// 解锁失败。
class VaultUnlockException implements Exception {
  const VaultUnlockException(this.message);

  final String message;

  @override
  String toString() => 'VaultUnlockException: $message';
}

/// vault 的创建、解锁、改密码、重置恢复码。
///
/// 这一层只做**密钥学**，不碰数据库、不碰文件系统、不碰 UI。
/// 所以它可以被单元测试完整覆盖，也可以在纯 Dart 环境（无 Flutter）里跑。
abstract final class VaultLock {
  const VaultLock._();

  /// AAD 用途标签。改动会让已发出的 vault 全部解不开，**不要改**。
  static const String dekPurpose = 'dek';
  static const String recoveryDekPurpose = 'recovery-dek';

  /// 首次创建 vault。
  ///
  /// 返回的 [UnlockedVault.recoveryCode] 是 24 个词，**调用方必须展示并让用户确认抄写**。
  static Future<UnlockedVault> create({
    required String passphrase,
    Argon2Params params = Argon2Params.recommended,
    Random? random,
    String? vaultId,
    int? nowMillis,
  }) async {
    final rng = random ?? Random.secure();
    final id = vaultId ?? UuidV7(random: rng).next();

    final dek = SecretBytes.random(length: VaultKeys.dekLength, random: rng);
    final salt = KdfSalt.random(rng);

    final kek = await Kdf.fromPassphrase(passphrase: passphrase, salt: salt, params: params);
    final wrapped = await SecretWrapper.wrap(
      key: kek,
      plaintext: dek,
      aad: SecretWrapper.aadFor(vaultId: id, purpose: dekPurpose),
      random: rng,
    );

    final recovery = RecoveryCode.generate(rng);
    final recoveryEntropy = recovery.toEntropy();
    final recoveryKek = await Kdf.fromRecoveryEntropy(recoveryEntropy);
    final recoveryWrapped = await SecretWrapper.wrap(
      key: recoveryKek,
      plaintext: dek,
      aad: SecretWrapper.aadFor(vaultId: id, purpose: recoveryDekPurpose),
      random: rng,
    );

    final meta = VaultMeta(
      vaultId: id,
      createdAt: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
      kdfParams: params,
      kdfSalt: salt,
      wrappedDek: wrapped,
      recoveryWrappedDek: recoveryWrapped,
    );

    // ── 自检：两条解锁路径都必须真的能解开 ──────────────────────────
    //
    // 不做这一步的风险很具体：如果包裹逻辑有 bug（比如 AAD 拼错、
    // 或者 recovery 分支用了错误的 purpose），用户会拿到一个
    // **看起来创建成功、实际永远打不开**的 vault，而且是在三个月后
    // 换设备时才发现。这里多花 20ms，换掉这个灾难。
    await _verifyUnwraps(
      meta: meta,
      passphrase: passphrase,
      recoveryEntropy: recoveryEntropy,
      expectedDek: dek,
    );

    recoveryEntropy.destroy();
    recoveryKek.destroy();
    kek.destroy();

    return UnlockedVault(
      meta: meta,
      keys: VaultKeys(dek),
      recoveryCode: recovery,
      dekForEnrollment: dek,
    );
  }

  /// 用主密码解锁。
  static Future<UnlockedVault> unlock({
    required VaultMeta meta,
    required String passphrase,
  }) async {
    final kek = await Kdf.fromPassphrase(
      passphrase: passphrase,
      salt: meta.kdfSalt,
      params: meta.kdfParams,
    );

    final SecretBytes dek;
    try {
      dek = await SecretWrapper.unwrap(
        key: kek,
        blob: meta.wrappedDek,
        aad: SecretWrapper.aadFor(vaultId: meta.vaultId, purpose: dekPurpose),
      );
    } on SecretUnwrapException catch (e) {
      throw VaultUnlockException(e.message);
    } finally {
      kek.destroy();
    }

    return _finishUnlock(meta, dek);
  }

  /// 用 24 词恢复码解锁。
  ///
  /// 注意这里**不跑 Argon2id**：恢复码本身是 256 bit 随机熵，
  /// 无可爆破空间，慢哈希只会让灾难恢复多等几秒。
  static Future<UnlockedVault> unlockWithRecoveryCode({
    required VaultMeta meta,
    required String input,
  }) async {
    if (!meta.hasRecoveryCode) {
      throw const VaultUnlockException(
        '这个 vault 没有设置恢复码，只能用主密码解锁。',
      );
    }

    final RecoveryCode code;
    try {
      code = RecoveryCode.parse(input);
    } on RecoveryCodeException catch (e) {
      throw VaultUnlockException(e.reason);
    }

    final entropy = code.toEntropy();
    final kek = await Kdf.fromRecoveryEntropy(entropy);

    final SecretBytes dek;
    try {
      dek = await SecretWrapper.unwrap(
        key: kek,
        blob: meta.recoveryWrappedDek!,
        aad: SecretWrapper.aadFor(vaultId: meta.vaultId, purpose: recoveryDekPurpose),
      );
    } on SecretUnwrapException catch (e) {
      throw VaultUnlockException(e.message);
    } finally {
      kek.destroy();
      entropy.destroy();
    }

    return _finishUnlock(meta, dek);
  }

  /// 改主密码。
  ///
  /// 只重新包裹 DEK，**不 rekey 数据库** —— 这是"DEK 与主密码分离"
  /// 这个设计的全部价值：几百 MB 的库改密码只要毫秒级。
  ///
  /// **会换新盐**：不换盐的话，新密码和旧密码共享同一个 KEK 派生上下文，
  /// 让"同一个旧密码在别处被复用"这件事变得更容易关联。
  static Future<VaultMeta> changePassphrase({
    required VaultMeta meta,
    required String currentPassphrase,
    required String newPassphrase,
    Random? random,
  }) async {
    if (newPassphrase.isEmpty) {
      throw ArgumentError('新密码不能为空');
    }
    final rng = random ?? Random.secure();

    final oldKek = await Kdf.fromPassphrase(
      passphrase: currentPassphrase,
      salt: meta.kdfSalt,
      params: meta.kdfParams,
    );

    final SecretBytes dek;
    try {
      dek = await SecretWrapper.unwrap(
        key: oldKek,
        blob: meta.wrappedDek,
        aad: SecretWrapper.aadFor(vaultId: meta.vaultId, purpose: dekPurpose),
      );
    } on SecretUnwrapException catch (e) {
      throw VaultUnlockException('当前主密码不正确。${e.message}');
    } finally {
      oldKek.destroy();
    }

    final newSalt = KdfSalt.random(rng);
    final newKek = await Kdf.fromPassphrase(
      passphrase: newPassphrase,
      salt: newSalt,
      params: meta.kdfParams,
    );

    final newWrapped = await SecretWrapper.wrap(
      key: newKek,
      plaintext: dek,
      aad: SecretWrapper.aadFor(vaultId: meta.vaultId, purpose: dekPurpose),
      random: rng,
    );
    newKek.destroy();
    dek.destroy();

    return meta.copyWith(kdfSalt: newSalt, wrappedDek: newWrapped);
  }

  /// 重新生成恢复码。**旧恢复码立即失效**。
  ///
  /// 需要主密码：不能允许"手上只有恢复码的人"换掉恢复码，
  /// 否则恢复码一旦泄露就等于永久接管。
  static Future<({VaultMeta meta, RecoveryCode code})> regenerateRecoveryCode({
    required VaultMeta meta,
    required String passphrase,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();

    final kek = await Kdf.fromPassphrase(
      passphrase: passphrase,
      salt: meta.kdfSalt,
      params: meta.kdfParams,
    );

    final SecretBytes dek;
    try {
      dek = await SecretWrapper.unwrap(
        key: kek,
        blob: meta.wrappedDek,
        aad: SecretWrapper.aadFor(vaultId: meta.vaultId, purpose: dekPurpose),
      );
    } on SecretUnwrapException catch (e) {
      throw VaultUnlockException('主密码不正确。${e.message}');
    } finally {
      kek.destroy();
    }

    final code = RecoveryCode.generate(rng);
    final entropy = code.toEntropy();
    final recoveryKek = await Kdf.fromRecoveryEntropy(entropy);

    final wrapped = await SecretWrapper.wrap(
      key: recoveryKek,
      plaintext: dek,
      aad: SecretWrapper.aadFor(vaultId: meta.vaultId, purpose: recoveryDekPurpose),
      random: rng,
    );

    entropy.destroy();
    recoveryKek.destroy();
    dek.destroy();

    return (meta: meta.copyWith(recoveryWrappedDek: wrapped), code: code);
  }

  // ── 内部 ──────────────────────────────────────────────────────────

  static UnlockedVault _finishUnlock(VaultMeta meta, SecretBytes dek) {
    if (dek.length != VaultKeys.dekLength) {
      dek.destroy();
      throw VaultUnlockException(
        '解出的 DEK 长度异常（${dek.length} 字节，应为 ${VaultKeys.dekLength}）。'
        'meta.enc 可能被篡改。',
      );
    }
    return UnlockedVault(
      meta: meta,
      keys: VaultKeys(dek),
      dekForEnrollment: dek,
    );
  }

  static Future<void> _verifyUnwraps({
    required VaultMeta meta,
    required String passphrase,
    required SecretBytes recoveryEntropy,
    required SecretBytes expectedDek,
  }) async {
    final kek1 = await Kdf.fromPassphrase(
      passphrase: passphrase,
      salt: meta.kdfSalt,
      params: meta.kdfParams,
    );
    final viaPassphrase = await SecretWrapper.unwrap(
      key: kek1,
      blob: meta.wrappedDek,
      aad: SecretWrapper.aadFor(vaultId: meta.vaultId, purpose: dekPurpose),
    );
    final ok1 = viaPassphrase.equalsConstantTime(expectedDek);
    viaPassphrase.destroy();
    kek1.destroy();

    final kek2 = await Kdf.fromRecoveryEntropy(recoveryEntropy);
    final viaRecovery = await SecretWrapper.unwrap(
      key: kek2,
      blob: meta.recoveryWrappedDek!,
      aad: SecretWrapper.aadFor(vaultId: meta.vaultId, purpose: recoveryDekPurpose),
    );
    final ok2 = viaRecovery.equalsConstantTime(expectedDek);
    viaRecovery.destroy();
    kek2.destroy();

    if (!ok1 || !ok2) {
      throw StateError(
        'vault 自检失败：${ok1 ? '' : '主密码路径'}${ok2 ? '' : '恢复码路径'}'
        '解出的 DEK 与创建时不一致。这是实现 bug，绝不能把这个 vault 交给用户。',
      );
    }
  }
}
