/// 同步编排器的输入输出模型与载荷编解码边界。
///
/// 这里只定义「本地内存工作区长什么样」以及「加密/JSON 字节怎么换成对象」。
/// 真实实现使用 DEK 派生密钥的加密 codec；测试用纯 JSON codec，
/// 于是整条同步链路不需要网络、数据库或新依赖。
library;

import 'device_watermark.dart';
import 'hlc.dart';

import '../../data/db/tables/log_tables.dart';
import '../../data/taxonomy/taxonomy_models.dart';
import '../../data/write/entry_snapshot.dart';

/// `/vault/meta.enc` 解密后的最小校验信息。
class SyncVaultMeta {
  const SyncVaultMeta({required this.vaultId, required this.schema});

  final String vaultId;
  final int schema;

  Map<String, Object?> toJson() => <String, Object?>{
        'vault_id': vaultId,
        'schema': schema,
      };

  factory SyncVaultMeta.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('meta 不是 JSON 对象');
    }
    final map = Map<String, Object?>.from(raw);
    final vaultId = map['vault_id'];
    final schema = map['schema'];
    if (vaultId is! String || vaultId.isEmpty) {
      throw const FormatException('meta 缺少 vault_id');
    }
    if (schema is! int || schema < 1) {
      throw FormatException('meta schema 非法：$schema');
    }
    return SyncVaultMeta(vaultId: vaultId, schema: schema);
  }
}

/// `/vault/tombstones/<hmac>.enc` 解密后的墓碑。
class SyncTombstone {
  const SyncTombstone({
    required this.entryId,
    required this.hashedName,
    required this.deletedAt,
    required this.deviceId,
    required this.rev,
  });

  final String entryId;
  final String hashedName;
  final int deletedAt;
  final String deviceId;
  final int rev;

  Map<String, Object?> toJson() => <String, Object?>{
        'entry_id': entryId,
        'hashed_name': hashedName,
        'deleted_at': deletedAt,
        'device_id': deviceId,
        'rev': rev,
      };

  factory SyncTombstone.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('墓碑不是 JSON 对象');
    }
    final map = Map<String, Object?>.from(raw);
    final entryId = map['entry_id'];
    final hashedName = map['hashed_name'];
    final deletedAt = map['deleted_at'];
    final deviceId = map['device_id'];
    final rev = map['rev'];
    if (entryId is! String || entryId.isEmpty) {
      throw const FormatException('墓碑缺少 entry_id');
    }
    if (hashedName is! String || hashedName.isEmpty) {
      throw const FormatException('墓碑缺少 hashed_name');
    }
    if (deletedAt is! int) {
      throw const FormatException('墓碑缺少 deleted_at');
    }
    if (deviceId is! String || deviceId.isEmpty) {
      throw const FormatException('墓碑缺少 device_id');
    }
    if (rev is! int || rev < 1) {
      throw FormatException('墓碑 rev 非法：$rev');
    }
    return SyncTombstone(
      entryId: entryId,
      hashedName: hashedName,
      deletedAt: deletedAt,
      deviceId: deviceId,
      rev: rev,
    );
  }
}

/// `ItemEnvelope` 的明文头。同步层可以只读头做 rev 判定，不必先解密正文。
class SyncEnvelopeHeader {
  const SyncEnvelopeHeader({
    required this.entity,
    required this.entityId,
    required this.rev,
  });

  final String entity;
  final String entityId;
  final int rev;
}

enum SyncPendingOpKind { upsert, delete }

/// 一条待推送的 oplog 操作。编排器也会用它表达「合并结果 / 冲突副本 / 墓碑」。
class SyncPendingOp {
  SyncPendingOp.upsert({
    required this.id,
    required this.hashedName,
    required EntrySnapshot snapshot,
    required this.baseRev,
    List<int>? rawPayload,
  })  : kind = SyncPendingOpKind.upsert,
        entryId = snapshot.id,
        entity = SyncEntity.entry,
        snapshot = snapshot,
        rev = snapshot.rev,
        rawPayload = rawPayload == null ? null : List<int>.from(rawPayload);

  SyncPendingOp.delete({
    required this.id,
    required this.hashedName,
    required this.entryId,
    required this.rev,
    required this.baseRev,
  })  : kind = SyncPendingOpKind.delete,
        entity = SyncEntity.entry,
        snapshot = null,
        rawPayload = null;

  final String id;
  final String hashedName;
  final String entryId;
  final String entity;
  final SyncPendingOpKind kind;

  /// 412 重试后可能被合并结果替换，所以不是 final。
  EntrySnapshot? snapshot;

  /// 直接复用 oplog 里的信封字节。
  ///
  /// docs/04 §2 要求 oplog payload 与云端 item 文件完全一致；非空时
  /// `SyncEngine` 会原样 PUT，不重新加密，也就不制造额外明文窗口。
  final List<int>? rawPayload;

  final int rev;
  final int baseRev;
}

/// 一次同步的本地内存工作区。
///
/// 真实落地时这些字段分别来自 `device_watermark` / `sync_state` /
/// `entry` / `entry_history` / `oplog`；本批用 Map 表达，
/// 让编排顺序和零丢失规则先可测。
class SyncWorkspace {
  SyncWorkspace({
    required this.selfDeviceId,
    required this.vaultId,
    required this.schema,
    required this.localWatermarks,
    required this.deviceEtags,
    required this.syncState,
    required this.entries,
    required this.baseRevs,
    required this.baseSnapshots,
    required this.pendingOps,
    required this.nowMs,
    required this.nextHlc,
    required this.localLabel,
    required this.remoteLabel,
    required this.newConflictCopyId,
    this.maxPreconditionRetries = 3,
    this.syncToken,
  });

  final String selfDeviceId;
  final String vaultId;
  final int schema;

  /// deviceId → 上次见到的 HLC。
  final Map<String, Hlc?> localWatermarks;

  /// deviceId → 上次见到的水位文件 ETag。
  final Map<String, String> deviceEtags;

  /// path → ETag。同时供 L2 diff 与条件 PUT 使用。
  final Map<String, String?> syncState;

  /// hashedName → 当前本地快照。
  final Map<String, EntrySnapshot> entries;

  /// entryId → base rev。
  final Map<String, int> baseRevs;

  /// entryId → base 快照；null 表示没有共同祖先。
  final Map<String, EntrySnapshot?> baseSnapshots;

  final List<SyncPendingOp> pendingOps;

  final int nowMs;
  final String nextHlc;
  final String localLabel;
  final String remoteLabel;

  /// 每次需要冲突副本时生成新的 UUIDv7；保持编排器纯函数化。
  final String Function() newConflictCopyId;

  final int maxPreconditionRetries;
  final String? syncToken;
}

/// 载荷边界：真实实现用加密信封，测试实现用 JSON。
abstract interface class SyncPayloadCodec {
  /// entryId → `[0-9a-f]{32}.enc`。真实实现是 HMAC(entry_id)。
  String hashedName(String entryId);

  List<int> encodeEntry(EntrySnapshot snapshot);
  EntrySnapshot decodeEntry(List<int> bytes);

  List<int> encodeMeta(SyncVaultMeta meta);
  SyncVaultMeta decodeMeta(List<int> bytes);

  List<int> encodeTombstone(SyncTombstone tombstone);
  SyncTombstone decodeTombstone(List<int> bytes);

  List<int> encodeWatermark(DeviceWatermark watermark);
  DeviceWatermark decodeWatermark(List<int> bytes, {String? etag});
}

/// 真实加密 codec 的异步边界。
///
/// `ItemEnvelope.seal/open` 与 HKDF 都是异步的，不能把真实密钥实现硬塞进
/// [SyncPayloadCodec] 的同步签名。纯测试仍用同步接口，再通过
/// [SyncPayloadCodecAdapter] 适配到 `SyncEngine`。
abstract interface class AsyncSyncPayloadCodec {
  Future<String> hashedName(String entryId);

  Future<List<int>> encodeEntry(EntrySnapshot snapshot);
  Future<EntrySnapshot> decodeEntry(List<int> bytes);

  Future<List<int>> encodeMeta(SyncVaultMeta meta);
  Future<SyncVaultMeta> decodeMeta(List<int> bytes);

  Future<List<int>> encodeTombstone(SyncTombstone tombstone);
  Future<SyncTombstone> decodeTombstone(List<int> bytes);

  /// 设备水位按 docs/04 §2 保持明文；ETag 来自 WebDAV 响应头，不进文件。
  Future<List<int>> encodeWatermark(DeviceWatermark watermark);
  Future<DeviceWatermark> decodeWatermark(List<int> bytes, {String? etag});
}

/// 非 entry 实体的独立载荷边界。
///
/// category / tag / entry_taxonomy 共享同一套 `ItemEnvelope`，但文件名
/// 用 `HMAC(K_name, entity/id)` 做域分离，避免与正文条目撞名；
/// 它们不进 `merge3`，由写入网关按实体直接落库。
abstract interface class SyncEntityPayloadCodec {
  Future<String> hashedEntityName(String entity, String id);

  Future<SyncEnvelopeHeader> peekEntity(List<int> bytes);

  Future<List<int>> encodeTaxonomy(TaxonomySnapshot snapshot);
  Future<TaxonomySnapshot> decodeTaxonomy(List<int> bytes);
}

/// 把已有的同步 codec 包成异步接口，供内存后端测试与简单适配器复用。
class SyncPayloadCodecAdapter implements AsyncSyncPayloadCodec {
  const SyncPayloadCodecAdapter(this.inner);

  final SyncPayloadCodec inner;

  @override
  Future<String> hashedName(String entryId) async => inner.hashedName(entryId);

  @override
  Future<List<int>> encodeEntry(EntrySnapshot snapshot) async =>
      inner.encodeEntry(snapshot);

  @override
  Future<EntrySnapshot> decodeEntry(List<int> bytes) async =>
      inner.decodeEntry(bytes);

  @override
  Future<List<int>> encodeMeta(SyncVaultMeta meta) async =>
      inner.encodeMeta(meta);

  @override
  Future<SyncVaultMeta> decodeMeta(List<int> bytes) async =>
      inner.decodeMeta(bytes);

  @override
  Future<List<int>> encodeTombstone(SyncTombstone tombstone) async =>
      inner.encodeTombstone(tombstone);

  @override
  Future<SyncTombstone> decodeTombstone(List<int> bytes) async =>
      inner.decodeTombstone(bytes);

  @override
  Future<List<int>> encodeWatermark(DeviceWatermark watermark) async =>
      inner.encodeWatermark(watermark);

  @override
  Future<DeviceWatermark> decodeWatermark(
    List<int> bytes, {
    String? etag,
  }) async =>
      inner.decodeWatermark(bytes, etag: etag);
}
