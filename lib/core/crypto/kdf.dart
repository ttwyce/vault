import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'argon2_params.dart';
import 'secret_bytes.dart';

/// 密钥派生。
///
/// 两个入口，对应两种完全不同的威胁模型：
///
/// | 入口 | 输入熵 | 是否需要 Argon2 | 原因 |
/// |---|---|---|---|
/// | [fromPassphrase] | 用户记忆，可能只有 20~40 bit | **必须** | 慢哈希把离线爆破的成本抬到不可行 |
/// | [fromRecoveryEntropy] | 256 bit 真随机 | **不需要** | 256 bit 无从爆破，再套 Argon2 只是让用户白等几秒 |
///
/// 这个区分很重要：很多实现会对恢复码也跑一遍 Argon2，
/// 结果是"灾难恢复时用户要在一台陌生设备上等 5 秒解锁，还可能因为内存不足失败"，
/// 而换来的安全增益是零。
abstract final class Kdf {
  const Kdf._();

  /// 主密码 → KEK。
  ///
  /// ## 为什么不归一化密码
  ///
  /// 密码**不做** Unicode 归一化，按原样 UTF-8 编码。理由是：
  /// 归一化会让"看起来不同但 NFC 等价"的两个密码变成同一个，
  /// 而用户对自己输入的字符是有预期的。代价是跨端输入法差异可能导致
  /// 组合字符不一致 —— 这个风险靠"输入框不做自动转换 + 显示字符数"来规避，
  /// 不靠静默改用户的密码。
  ///
  /// （恢复码走的是另一条路，那里做 NFKD，因为 BIP-39 规范要求。）
  static Future<SecretBytes> fromPassphrase({
    required String passphrase,
    required KdfSalt salt,
    Argon2Params params = Argon2Params.recommended,
  }) async {
    if (passphrase.isEmpty) {
      throw ArgumentError('主密码不能为空');
    }
    if (!params.isValid) {
      throw ArgumentError('Argon2id 参数不合法：$params');
    }

    final algorithm = Argon2id(
      parallelism: params.parallelism,
      memory: params.memoryKb,
      iterations: params.iterations,
      hashLength: params.hashLength,
    );

    final derived = await algorithm.deriveKey(
      // 对 Argon2 而言，secretKey 就是密码，nonce 就是盐
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt.internalView,
    );

    return SecretBytes(Uint8List.fromList(await derived.extractBytes()));
  }

  /// 恢复码熵 → KEK'。
  ///
  /// 用 HKDF 而不是直接拿熵当密钥：一个是"域分离"，
  /// 保证这把 KEK' 与其它任何用途的密钥在密码学上无关；
  /// 另一个是留下版本号，将来换算法时能识别旧格式。
  static Future<SecretBytes> fromRecoveryEntropy(SecretBytes entropy) async {
    if (entropy.length < 16) {
      throw ArgumentError('恢复码熵太短：${entropy.length} 字节');
    }
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(entropy.internalView),
      info: utf8.encode(_recoveryKekInfo),
    );
    return SecretBytes(Uint8List.fromList(derived.bytes));
  }

  static const String _recoveryKekInfo = 'vault/recovery-kek/v1';
}
