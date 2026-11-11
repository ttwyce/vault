/// 真实加密载荷 codec：把同步模型封进项目既有的 `ItemEnvelope`。
///
/// 这一层不新增依赖：`VaultKeys` 负责 HKDF 子密钥，`ItemEnvelope` 负责
/// 明文头 + XChaCha20-Poly1305，`crypto` 负责云端文件名 HMAC。
/// 设备水位按 docs/04 §2 保持明文。
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show Hmac, sha256;

import '../crypto/canonical.dart';
import '../crypto/vault_keys.dart';
import '../../data/db/tables/log_tables.dart';
import '../../data/taxonomy/taxonomy_models.dart';
import '../../data/write/entry_snapshot.dart';
import '../../data/write/item_envelope.dart';
import 'cloud_layout.dart';
import 'device_watermark.dart';
import 'sync_payloads.dart';

const Set<String> _taxonomyEntities = <String>{
  SyncEntity.category,
  SyncEntity.tag,
  SyncEntity.entryTaxonomy,
};

class EncryptedSyncPayloadCodec
    implements AsyncSyncPayloadCodec, SyncEntityPayloadCodec {
  EncryptedSyncPayloadCodec(this.keys, {math.Random? random})
      : _random = random ?? math.Random.secure();

  final VaultKeys keys;

  /// 加密 nonce 的随机源。测试可注入确定性 Random；生产必须用安全随机。
  final math.Random _random;

  @override
  Future<String> hashedName(String entryId) =>
      hashedEntityName(SyncEntity.entry, entryId);

  @override
  Future<String> hashedEntityName(String entity, String id) async {
    final key = await keys.name();
    final input = 'vault/name/v1/$entity/$id';
    final digest = Hmac(sha256, key.internalView)
        .convert(utf8.encode(input))
        .toString()
        .substring(0, 32);
    final name = '$digest.enc';
    if (!CloudLayout.isValidItemName(name)) {
      throw StateError('生成的云端文件名不合法');
    }
    return name;
  }

  @override
  Future<SyncEnvelopeHeader> peekEntity(List<int> bytes) async {
    final envelope = _parse(bytes);
    return SyncEnvelopeHeader(
      entity: envelope.entity,
      entityId: envelope.entityId,
      rev: envelope.rev,
    );
  }

  @override
  Future<List<int>> encodeEntry(EntrySnapshot snapshot) async {
    final envelope = await ItemEnvelope.seal(
      key: await keys.item(),
      entity: SyncEntity.entry,
      entityId: snapshot.id,
      rev: snapshot.rev,
      plaintext: snapshot.toCanonicalBytes(),
      random: _random,
    );
    return envelope.encode();
  }

  @override
  Future<EntrySnapshot> decodeEntry(List<int> bytes) async {
    final envelope = _parse(bytes);
    _requireEntity(envelope, SyncEntity.entry);
    final snapshot = EntrySnapshot.fromJson(
      _jsonMap(await envelope.open(key: await keys.item())),
    );
    if (snapshot.id != envelope.entityId || snapshot.rev != envelope.rev) {
      throw const FormatException('条目快照与信封头不一致');
    }
    final expectedHash = EntrySnapshot.computeContentHash(
      kind: snapshot.kind,
      title: snapshot.title,
      body: snapshot.body,
      meta: snapshot.meta,
    );
    if (snapshot.contentHash != expectedHash) {
      throw const FormatException('条目 content_hash 不匹配');
    }
    return snapshot;
  }

  @override
  Future<List<int>> encodeMeta(SyncVaultMeta meta) async {
    final envelope = await ItemEnvelope.seal(
      key: await keys.meta(),
      entity: SyncEntity.syncMeta,
      entityId: meta.vaultId,
      rev: meta.schema,
      plaintext: utf8.encode(Canonical.json(meta.toJson())),
      random: _random,
    );
    return envelope.encode();
  }

  @override
  Future<SyncVaultMeta> decodeMeta(List<int> bytes) async {
    final envelope = _parse(bytes);
    _requireEntity(envelope, SyncEntity.syncMeta);
    final meta = SyncVaultMeta.fromJson(
      _jsonMap(await envelope.open(key: await keys.meta())),
    );
    if (meta.vaultId != envelope.entityId || meta.schema != envelope.rev) {
      throw const FormatException('同步 meta 与信封头不一致');
    }
    return meta;
  }

  @override
  Future<List<int>> encodeTombstone(SyncTombstone tombstone) async {
    final envelope = await ItemEnvelope.seal(
      key: await keys.item(),
      entity: SyncEntity.tombstone,
      entityId: tombstone.entryId,
      rev: tombstone.rev,
      plaintext: utf8.encode(Canonical.json(tombstone.toJson())),
      random: _random,
    );
    return envelope.encode();
  }

  @override
  Future<SyncTombstone> decodeTombstone(List<int> bytes) async {
    final envelope = _parse(bytes);
    _requireEntity(envelope, SyncEntity.tombstone);
    final tombstone = SyncTombstone.fromJson(
      _jsonMap(await envelope.open(key: await keys.item())),
    );
    if (tombstone.entryId != envelope.entityId ||
        tombstone.rev != envelope.rev) {
      throw const FormatException('墓碑与信封头不一致');
    }
    return tombstone;
  }

  @override
  Future<List<int>> encodeTaxonomy(TaxonomySnapshot snapshot) async {
    if (!_taxonomyEntities.contains(snapshot.entity)) {
      throw ArgumentError.value(snapshot.entity, 'entity', '不是同步 taxonomy 实体');
    }
    final envelope = await ItemEnvelope.seal(
      key: await keys.item(),
      entity: snapshot.entity,
      entityId: snapshot.id,
      rev: snapshot.rev,
      plaintext: snapshot.toCanonicalBytes(),
      random: _random,
    );
    return envelope.encode();
  }

  @override
  Future<TaxonomySnapshot> decodeTaxonomy(List<int> bytes) async {
    final envelope = _parse(bytes);
    if (!_taxonomyEntities.contains(envelope.entity)) {
      throw FormatException('信封实体 ${envelope.entity} 不是 taxonomy');
    }
    final snapshot = TaxonomySnapshot.fromJson(
      _jsonMap(await envelope.open(key: await keys.item())),
    );
    if (snapshot.entity != envelope.entity ||
        snapshot.id != envelope.entityId ||
        snapshot.rev != envelope.rev) {
      throw const FormatException('taxonomy 快照与信封头不一致');
    }
    return snapshot;
  }

  @override
  Future<List<int>> encodeWatermark(DeviceWatermark watermark) async =>
      utf8.encode(Canonical.json(watermark.toJson()));

  @override
  Future<DeviceWatermark> decodeWatermark(
    List<int> bytes, {
    String? etag,
  }) async =>
      DeviceWatermark.fromJson(_jsonMap(Uint8List.fromList(bytes)), etag: etag);

  ItemEnvelope _parse(List<int> bytes) =>
      ItemEnvelope.parse(Uint8List.fromList(bytes));

  void _requireEntity(ItemEnvelope envelope, String entity) {
    if (envelope.entity != entity) {
      throw FormatException(
        '信封实体是 ${envelope.entity}，期望 $entity',
      );
    }
  }

  Map<String, Object?> _jsonMap(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('载荷顶层不是 JSON 对象');
    }
    return Map<String, Object?>.from(decoded);
  }
}
