import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../core/crypto/canonical.dart';
import '../../core/crypto/secret_bytes.dart';
import '../../core/crypto/secret_wrapper.dart';

/// 条目加密信封。
///
/// ## 为什么需要"明文头 + 密文体"这层结构
///
/// 这是整个同步格式里**最容易做错、做错后最难改**的一处，值得说清楚。
///
/// 最初的想法是「AAD = entity + id + rev，密文里什么都不带」。但接收端会卡住：
/// 解密需要 AAD，而 AAD 需要 rev，rev 却在密文里面 —— 鸡生蛋。
///
/// 三条出路，只有第三条成立：
///
/// | 方案 | 问题 |
/// |---|---|
/// | AAD 只绑 id，rev 放进密文 | 旧版本密文可以被重放到新版本位置（回滚攻击） |
/// | rev 编码进文件名 | rev 变了文件就得改名，而文件名是 `HMAC(id)`，一改名就是一次删除+新建 |
/// | **明文头携带 entity/id/rev，AAD = 头部字节本身** | ✅ |
///
/// 第三条还额外得到两个好处：
///
/// 1. **AAD 就是头部原始字节**，不需要"先解析再用解析结果拼 AAD"——
///    少一次可能不一致的推导，篡改头部的任何一个字节都会导致认证失败。
/// 2. **本地 oplog 与云端 item 文件字节完全一致**，推送时可以直接 PUT，
///    不需要「解密 → 重新加密」这一轮 CPU 与明文窗口。
///
/// ## 字节布局
///
/// ```
/// ┌──────┬────────────┬──────────────────┬──────────────────────┐
/// │ 1 B  │   2 B      │      N B         │       剩余            │
/// │ 信封 │ 头部长度    │  头部（JSON）     │  SecretWrapper 封装   │
/// │ 版本 │ 大端 uint16 │  {entity,id,rev} │ 版本+nonce+密文+tag   │
/// └──────┴────────────┴──────────────────┴──────────────────────┘
/// ```
///
/// 头部用 `Canonical.json` 序列化（键排序、无空白），保证同样的
/// (entity, id, rev) 永远产出同样的头部字节 —— 否则 AAD 会随机变化，
/// 同一条数据的两次加密会得到两个互不兼容的密文。
class ItemEnvelope {
  const ItemEnvelope({
    required this.entity,
    required this.entityId,
    required this.rev,
    required this.blob,
  });

  /// 信封格式版本。与 [SecretWrapper.formatVersion] 相互独立：
  /// 前者管"外层怎么装"，后者管"内层怎么加密"，可以分别演进。
  static const int envelopeVersion = 1;

  static const int _headerLengthBytes = 2;

  /// 头部最小长度（`{"entity":"","id":"","rev":1}` 之类）。
  /// 用来在解析时提前拒绝明显损坏的数据。
  static const int _minHeaderLength = 8;

  final String entity;
  final String entityId;
  final int rev;

  /// 内层密文（`SecretWrapper` 的完整输出）。
  final Uint8List blob;

  /// 头部 JSON。键名刻意用短名：头部会随每条记录存进 oplog 与云端，
  /// 而它承载的信息只有三个字段。
  Map<String, Object?> get headerJson => <String, Object?>{
        'e': entity,
        'i': entityId,
        'r': rev,
      };

  /// 头部字节。**同时也是内层密文的 AAD**。
  Uint8List headerBytes() => Uint8List.fromList(utf8.encode(Canonical.json(headerJson)));

  /// 编码成可存储 / 可上传的字节。
  Uint8List encode() {
    final header = headerBytes();
    if (header.length > 0xFFFF) {
      throw StateError('信封头部过长（${header.length} 字节），实体 id 异常');
    }
    final out = Uint8List(1 + _headerLengthBytes + header.length + blob.length);
    out[0] = envelopeVersion;
    out[1] = (header.length >> 8) & 0xFF;
    out[2] = header.length & 0xFF;
    out.setRange(1 + _headerLengthBytes, 1 + _headerLengthBytes + header.length, header);
    out.setRange(1 + _headerLengthBytes + header.length, out.length, blob);
    return out;
  }

  /// 从字节解析出头部。**不验证内层密文** —— 验证发生在 [open]。
  ///
  /// 之所以把解析和验签分开：同步流程里经常只需要知道
  /// "这条远端文件对应哪个 id、哪个 rev"（做冲突预判），
  /// 不需要（也不应该）为此解密整条内容。
  static ItemEnvelope parse(Uint8List bytes) {
    if (bytes.length < 1 + _headerLengthBytes + _minHeaderLength) {
      throw const FormatException('条目信封过短，数据已损坏');
    }
    if (bytes[0] != envelopeVersion) {
      throw FormatException(
        '条目信封版本 ${bytes[0]} 不被支持（当前支持 $envelopeVersion）。'
        '可能是更新版本的 App 写入的，请升级后再试。',
      );
    }

    final headerLength = (bytes[1] << 8) | bytes[2];
    if (headerLength < _minHeaderLength) {
      throw const FormatException('条目信封头部长度异常，数据已损坏');
    }
    final headerEnd = 1 + _headerLengthBytes + headerLength;
    if (headerEnd > bytes.length) {
      throw const FormatException('条目信封头部越界，数据已损坏');
    }

    final headerText = utf8.decode(
      Uint8List.sublistView(bytes, 1 + _headerLengthBytes, headerEnd),
      allowMalformed: false,
    );
    final decoded = jsonDecode(headerText);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('条目信封头部不是对象');
    }

    final entity = decoded['e'];
    final id = decoded['i'];
    final rev = decoded['r'];
    if (entity is! String || entity.isEmpty) {
      throw const FormatException('条目信封头部缺少 entity');
    }
    if (id is! String || id.isEmpty) {
      throw const FormatException('条目信封头部缺少 id');
    }
    if (rev is! int || rev < 1) {
      throw FormatException('条目信封头部 rev 非法：$rev');
    }

    return ItemEnvelope(
      entity: entity,
      entityId: id,
      rev: rev,
      blob: Uint8List.sublistView(bytes, headerEnd),
    );
  }

  /// 加密一段明文并装进信封。
  static Future<ItemEnvelope> seal({
    required SecretBytes key,
    required String entity,
    required String entityId,
    required int rev,
    required List<int> plaintext,
    Random? random,
  }) async {
    final envelope = ItemEnvelope(
      entity: entity,
      entityId: entityId,
      rev: rev,
      blob: Uint8List(0),
    );
    final header = envelope.headerBytes();
    final blob = await SecretWrapper.seal(
      key: key,
      plaintext: plaintext,
      // AAD 就是头部字节：篡改 entity / id / rev 中任何一个字符都会导致解密失败
      aad: header,
      random: random,
    );
    return ItemEnvelope(entity: entity, entityId: entityId, rev: rev, blob: blob);
  }

  /// 解开内层密文。AAD 用**当前信封自己的头部字节**，
  /// 所以头部被改过一个字节，这里就会抛 [SecretUnwrapException]。
  Future<Uint8List> open({required SecretBytes key}) {
    return SecretWrapper.open(key: key, blob: blob, aad: headerBytes());
  }

  @override
  String toString() =>
      'ItemEnvelope($entity/$entityId@$rev, ${blob.length} B)';
}
