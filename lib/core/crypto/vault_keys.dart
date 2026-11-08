import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secret_bytes.dart';

/// vault 主密钥（DEK）及其派生子密钥。
///
/// ## 一把 DEK，多条用途，互不相干
///
/// 所有加密都从同一个 32 字节 DEK 出发，但**从不直接用 DEK 加密任何东西**。
/// 每一类数据用一条 HKDF 派生的子密钥：
///
/// ```
/// DEK (32B, 随机)
///  ├─ HKDF("item")      → 条目快照（oplog payload / entry_history / trash / 云端 item 文件）
///  ├─ HKDF("blob")      → 快照与附件分块
///  ├─ HKDF("name")      → 云端文件名 HMAC
///  ├─ HKDF("meta")      → meta.enc 里的敏感字段
///  └─ HKDF("local-db")  → 本地 SQLCipher 密钥
/// ```
///
/// **没有单独的 oplog 子密钥**，这是刻意的：oplog 里存的就是条目快照，
/// 与云端 item 文件是同一份明文。用同一把 `item` 子密钥意味着
/// 推送时可以直接 PUT oplog 里的字节，不需要「用 A 解密再用 B 加密」
/// 那一轮多余的 CPU，也不需要在那段时间里让明文出现在内存里。
/// 域分离靠 AAD（见 `ItemEnvelope`），不靠换密钥。
///
/// 为什么不直接用 DEK：密钥复用会放大任何一次算法层的失误。
/// 更实际的理由是 **SQLCipher 的密钥必须与内容密钥分开** ——
/// 本地库密钥一旦泄露（比如调试时被 dump），不该连带泄露云端密文的解密能力。
///
/// ## 为什么本地库密钥是从 DEK 派生的，而不是单独包裹一把
///
/// 文档 03 §2 原本写的是"另外包裹一把 DEK_local"。实现时改成派生，理由：
///
/// - 恢复码只需要恢复**一个**秘密。两个被包裹的 DEK 意味着恢复码也要
///   包裹两份，任何一份丢失都会让"换设备后本地库打不开"变成一个
///   无法自愈的状态。
/// - 派生是零成本的，而多存一份被包裹的密钥就多一份不一致的可能。
///
/// 代价是：换 DEK 必须连带 rekey 本地库。但 DEK 只在"全量重新加密"
/// 这种极端场景才换，正常路径（改主密码）只重新包裹 DEK，不碰这里。
class VaultKeys {
  VaultKeys(this._dek) {
    if (_dek.length != dekLength) {
      throw ArgumentError('DEK 必须是 $dekLength 字节，实际 ${_dek.length}');
    }
  }

  /// 生成一个全新的 vault（首次创建时用）。
  factory VaultKeys.generate() => VaultKeys(SecretBytes.random(length: dekLength));

  static const int dekLength = 32;

  final SecretBytes _dek;

  /// 子密钥缓存。HKDF 是异步的，而调用点往往在热路径上。
  final Map<String, SecretBytes> _cache = <String, SecretBytes>{};

  /// DEK 的指纹，用于诊断"两个设备是不是同一个 vault"。
  /// 不可逆，可安全写进日志。
  String get fingerprint => _dek.fingerprint;

  Future<SecretBytes> _derive(String purpose) async {
    final cached = _cache[purpose];
    if (cached != null) return cached;

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(_dek.internalView),
      // 盐留空：输入已经是 256 bit 均匀随机，HKDF-Extract 没有可提取的熵，
      // 直接用 RFC 5869 的全零盐即可。这是标准做法，不是偷懒。
      info: utf8.encode('vault/$purpose/v1'),
    );
    final key = SecretBytes(Uint8List.fromList(derived.bytes));
    _cache[purpose] = key;
    return key;
  }

  /// 条目字段加密（第 2 层 AEAD，同步边界用）。
  Future<SecretBytes> item() => _derive('item');

  /// 快照 / 附件分块加密。
  Future<SecretBytes> blob() => _derive('blob');

  /// 云端文件名 HMAC（`HMAC(K_name, entry_id)` 取前 32 hex）。
  Future<SecretBytes> name() => _derive('name');

  /// `meta.enc` 内敏感字段。
  Future<SecretBytes> meta() => _derive('meta');

  /// 本地 SQLCipher 密钥。
  ///
  /// 与内容密钥分离，见类注释。
  Future<SecretBytes> localDatabase() => _derive('local-db');

  /// 会话结束：清掉 DEK 与全部子密钥。
  void destroy() {
    for (final key in _cache.values) {
      key.destroy();
    }
    _cache.clear();
    _dek.destroy();
  }

  @override
  String toString() => 'VaultKeys($fingerprint)';
}
