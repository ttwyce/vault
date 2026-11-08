import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secret_bytes.dart';

/// 解包失败。
///
/// **无法区分"密码错"和"文件被改"** —— 这是 AEAD 的性质，不是实现缺陷。
/// 密文、nonce、AAD、密钥这四者任何一个不对，校验都会失败，
/// 而失败信息里不含任何可用于区分的信息。
///
/// 这个类存在的意义是把这条事实**明确地**告诉上层：
/// UI 文案必须写「主密码不正确，或该文件已损坏」，
/// 不能写「密码错误」—— 否则用户会一直重试一个其实正确的密码。
class SecretUnwrapException implements Exception {
  const SecretUnwrapException(this.message);

  final String message;

  @override
  String toString() => 'SecretUnwrapException: $message';
}

/// 带认证的加密封装（AEAD box）。
///
/// 算法：XChaCha20-Poly1305（192 bit nonce + 128 bit tag）。
///
/// 两个用途共用同一套实现，因为它们的**安全需求完全一致**：
///
/// | 用途 | 明文 | 入口 |
/// |---|---|---|
/// | 包裹 DEK（32 字节密钥） | `SecretBytes` | [wrap] / [unwrap] |
/// | 加密条目快照（KB 级 JSON） | `List<int>` | [seal] / [open] |
///
/// 不分成两个类是因为分离只会产生两份需要同步维护的 nonce/版本/布局逻辑，
/// 而这类代码一旦分叉，其中一份迟早会忘记加 AAD。
///
/// ## 为什么是 XChaCha 而不是 ChaCha
///
/// 普通 ChaCha20-Poly1305 只有 96 bit nonce，随机生成时 birthday bound
/// 在 2^48 次加密后就出现碰撞风险。XChaCha 的 192 bit nonce 允许
/// **每次都用纯随机 nonce**，不需要计数器、不需要协调状态。
/// 这一点在多设备各自加密的场景里很关键。
///
/// ## 字节布局
///
/// ```
/// ┌──────┬────────────┬──────────────────┬──────────┐
/// │ 1 B  │   24 B     │      N B         │   16 B   │
/// │ 版本 │   nonce    │      密文         │   tag    │
/// └──────┴────────────┴──────────────────┴──────────┘
/// ```
///
/// 版本字节放在最前面而不是塞进 AAD：将来若要换算法，
/// 老版本 App 能立刻识别出"这不是我能解的格式"并给出明确提示，
/// 而不是拿错算法去解、最后报一个含糊的认证失败。
///
/// ## 为什么要 AAD
///
/// AAD 把密文**绑定到上下文**上。没有它的话，攻击者可以把
/// `recovery_wrapped_dek` 和 `wrapped_dek` 互换位置 —— 两者都是
/// 「某把密钥包裹的 32 字节」，密文长度一样、都能通过认证。
/// 绑定 `vault_id + purpose` 之后，任何搬运都会导致认证失败。
abstract final class SecretWrapper {
  const SecretWrapper._();

  static const int formatVersion = 1;
  static const int nonceLength = 24;
  static const int tagLength = 16;

  /// 封装后的固定开销。`32 字节 DEK → 73 字节密文`。
  static const int overhead = 1 + nonceLength + tagLength;

  /// 构造 DEK 包裹用的 AAD：绑定「哪个 vault 的哪个用途」。
  ///
  /// 格式固定为 `vault/<版本>/<用途>/<vaultId>`。
  /// `vaultId` 是 UUID，不含分隔符，所以拼接不会有歧义。
  static List<int> aadFor({required String vaultId, required String purpose}) {
    if (vaultId.isEmpty) throw ArgumentError('vaultId 不能为空');
    if (purpose.isEmpty) throw ArgumentError('purpose 不能为空');
    if (vaultId.contains('/')) throw ArgumentError('vaultId 不能包含斜杠');
    return utf8.encode('vault/v1/$purpose/$vaultId');
  }

  /// 构造条目快照的 AAD：绑定「哪类实体的哪一条的哪个版本」。
  ///
  /// 三个维度缺一不可：
  /// - `entity` 防"把笔记密文塞进密码槽位"
  /// - `id` 防"把 A 条目的密文挪到 B 条目"
  /// - `rev` 防"把旧版本密文重放到新版本位置"（回滚攻击）
  static List<int> aadForItem({
    required String entity,
    required String entityId,
    required int rev,
  }) {
    if (entity.isEmpty) throw ArgumentError('entity 不能为空');
    if (entityId.isEmpty) throw ArgumentError('entityId 不能为空');
    if (rev < 1) throw ArgumentError('rev 必须 ≥ 1，实际 $rev');
    if (entityId.contains('/')) throw ArgumentError('entityId 不能包含斜杠');
    return utf8.encode('vault/item/v1/$entity/$entityId/$rev');
  }

  /// 加密任意字节。返回值即完整封装（版本 + nonce + 密文 + tag）。
  static Future<Uint8List> seal({
    required SecretBytes key,
    required List<int> plaintext,
    required List<int> aad,
    Random? random,
  }) async {
    if (key.length != 32) {
      throw ArgumentError('加密密钥必须是 32 字节，实际 ${key.length}');
    }

    final rng = random ?? Random.secure();
    final nonce = Uint8List(nonceLength);
    for (var i = 0; i < nonceLength; i++) {
      nonce[i] = rng.nextInt(256);
    }

    final algorithm = Xchacha20.poly1305Aead();
    final box = await algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(key.internalView),
      nonce: nonce,
      aad: aad,
    );

    final out = Uint8List(overhead + box.cipherText.length);
    out[0] = formatVersion;
    out.setRange(1, 1 + nonceLength, nonce);
    out.setRange(1 + nonceLength, 1 + nonceLength + box.cipherText.length, box.cipherText);
    out.setRange(out.length - tagLength, out.length, box.mac.bytes);
    return out;
  }

  /// 解密任意字节。
  static Future<Uint8List> open({
    required SecretBytes key,
    required Uint8List blob,
    required List<int> aad,
  }) async {
    if (key.length != 32) {
      throw ArgumentError('加密密钥必须是 32 字节，实际 ${key.length}');
    }
    if (blob.length < overhead) {
      throw const SecretUnwrapException('密文长度不足，文件已损坏');
    }
    if (blob[0] != formatVersion) {
      throw SecretUnwrapException(
        '密文格式版本 ${blob[0]} 不被支持（当前支持 $formatVersion）。'
        '可能是更新版本的 App 写入的，请升级后再试。',
      );
    }

    final nonce = Uint8List.sublistView(blob, 1, 1 + nonceLength);
    final cipherText = Uint8List.sublistView(blob, 1 + nonceLength, blob.length - tagLength);
    final mac = Uint8List.sublistView(blob, blob.length - tagLength);

    final algorithm = Xchacha20.poly1305Aead();
    try {
      final clear = await algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key.internalView),
        aad: aad,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const SecretUnwrapException(
        '密钥不正确，或该文件已损坏。两者无法区分 —— 认证失败时不泄露原因。',
      );
    }
  }

  /// 封装一段密钥字节（DEK）。
  static Future<Uint8List> wrap({
    required SecretBytes key,
    required SecretBytes plaintext,
    required List<int> aad,
    Random? random,
  }) {
    return seal(key: key, plaintext: plaintext.internalView, aad: aad, random: random);
  }

  /// 解出被包裹的密钥字节。
  static Future<SecretBytes> unwrap({
    required SecretBytes key,
    required Uint8List blob,
    required List<int> aad,
  }) async {
    return SecretBytes(await open(key: key, blob: blob, aad: aad));
  }
}
