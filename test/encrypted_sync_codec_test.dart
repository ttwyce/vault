import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/vault_keys.dart';
import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/device_watermark.dart';
import 'package:vault/core/sync/encrypted_sync_codec.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/core/sync/sync_payloads.dart';
import 'package:vault/data/db/tables/log_tables.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/write/entry_snapshot.dart';
import 'package:vault/data/write/item_envelope.dart';

EntrySnapshot _snapshot({
  String id = 'entry-1',
  int rev = 3,
  String body = '加密同步正文',
}) {
  return EntrySnapshot(
    id: id,
    kind: 1,
    title: '标题',
    body: body,
    createdAt: 1000,
    updatedAt: 2000,
    hlc: Hlc(millis: 2000, counter: 0, node: 'devA').encode(),
    rev: rev,
    contentHash: EntrySnapshot.computeContentHash(
      kind: 1,
      title: '标题',
      body: body,
    ),
  );
}

TaxonomySnapshot _taxonomy({
  String entity = SyncEntity.category,
  String id = 'cat-1',
  int rev = 2,
}) {
  return TaxonomySnapshot(
    entity: entity,
    id: id,
    rev: rev,
    hlc: Hlc(millis: 2000, counter: 0, node: 'devA').encode(),
    updatedAt: 2000,
    deleted: false,
    fields: <String, Object?>{
      'name': '工作',
      'kind': 1,
      'parent_id': null,
      'sort_order': 0,
    },
  );
}

void main() {
  late VaultKeys keys;
  late VaultKeys otherKeys;

  setUp(() {
    keys = VaultKeys.generate();
    otherKeys = VaultKeys.generate();
  });

  tearDown(() {
    keys.destroy();
    otherKeys.destroy();
  });

  test('HMAC 文件名稳定、域分离且符合 32 位十六进制规范', () async {
    final codec = EncryptedSyncPayloadCodec(keys);
    final a = await codec.hashedName('entry-1');
    final b = await codec.hashedName('entry-1');
    final c = await codec.hashedName('entry-2');
    final category = await codec.hashedEntityName(
      SyncEntity.category,
      'entry-1',
    );
    final entryAsEntity = await codec.hashedEntityName(
      SyncEntity.entry,
      'entry-1',
    );

    expect(CloudLayout.isValidItemName(a), isTrue);
    expect(b, a);
    expect(c, isNot(a));
    expect(category, isNot(a));
    expect(entryAsEntity, a);
  });

  test('条目信封可解密，头部与 AAD 绑定 entity / id / rev', () async {
    final codec = EncryptedSyncPayloadCodec(keys, random: Random(7));
    final snapshot = _snapshot();
    final bytes = await codec.encodeEntry(snapshot);

    final envelope = ItemEnvelope.parse(Uint8List.fromList(bytes));
    expect(envelope.entity, SyncEntity.entry);
    expect(envelope.entityId, snapshot.id);
    expect(envelope.rev, snapshot.rev);
    expect(await codec.decodeEntry(bytes), isA<EntrySnapshot>());
    expect((await codec.decodeEntry(bytes)).body, snapshot.body);

    final tamperedHeader = ItemEnvelope(
      entity: envelope.entity,
      entityId: envelope.entityId,
      rev: envelope.rev + 1,
      blob: envelope.blob,
    ).encode();
    await expectLater(
      codec.decodeEntry(tamperedHeader),
      throwsA(isA<Exception>()),
    );

    final tamperedTag = List<int>.from(bytes);
    tamperedTag[tamperedTag.length - 1] ^= 0x01;
    await expectLater(
      codec.decodeEntry(tamperedTag),
      throwsA(isA<Exception>()),
    );

    final wrongKey = EncryptedSyncPayloadCodec(otherKeys);
    await expectLater(
      wrongKey.decodeEntry(bytes),
      throwsA(isA<Exception>()),
    );
  });

  test('相同输入和 nonce 序列产生完全相同的信封字节', () async {
    final snapshot = _snapshot();
    final left = EncryptedSyncPayloadCodec(keys, random: Random(11));
    final right = EncryptedSyncPayloadCodec(keys, random: Random(11));

    expect(
      await left.encodeEntry(snapshot),
      await right.encodeEntry(snapshot),
    );
  });

  test('meta.enc 用 K_meta，vault_id / schema 绑定信封头', () async {
    final codec = EncryptedSyncPayloadCodec(keys, random: Random(3));
    const meta = SyncVaultMeta(vaultId: 'vault-alpha', schema: 2);
    final bytes = await codec.encodeMeta(meta);

    final envelope = ItemEnvelope.parse(Uint8List.fromList(bytes));
    expect(envelope.entity, SyncEntity.syncMeta);
    expect(envelope.entityId, meta.vaultId);
    expect(envelope.rev, meta.schema);
    expect((await codec.decodeMeta(bytes)).vaultId, meta.vaultId);

    final forged = await ItemEnvelope.seal(
      key: await keys.item(),
      entity: SyncEntity.syncMeta,
      entityId: meta.vaultId,
      rev: meta.schema,
      plaintext: utf8.encode(jsonEncode(meta.toJson())),
      random: Random(3),
    );
    await expectLater(
      codec.decodeMeta(forged.encode()),
      throwsA(isA<Exception>()),
    );
  });

  test('墓碑用 K_item 且 entity=tombstone，篡改头部后拒绝解密', () async {
    final codec = EncryptedSyncPayloadCodec(keys, random: Random(5));
    final name = await codec.hashedName('entry-1');
    final tombstone = SyncTombstone(
      entryId: 'entry-1',
      hashedName: name,
      deletedAt: 1731052800000,
      deviceId: 'devA',
      rev: 4,
    );
    final bytes = await codec.encodeTombstone(tombstone);

    final envelope = ItemEnvelope.parse(Uint8List.fromList(bytes));
    expect(envelope.entity, SyncEntity.tombstone);
    expect(envelope.entityId, tombstone.entryId);
    expect(envelope.rev, tombstone.rev);
    expect((await codec.decodeTombstone(bytes)).hashedName, name);

    final tampered = ItemEnvelope(
      entity: SyncEntity.entry,
      entityId: envelope.entityId,
      rev: envelope.rev,
      blob: envelope.blob,
    ).encode();
    await expectLater(
      codec.decodeTombstone(tampered),
      throwsA(isA<Exception>()),
    );
  });

  test('taxonomy 快照与明文头交叉校验，换实体名会认证失败', () async {
    final codec = EncryptedSyncPayloadCodec(keys, random: Random(9));
    final snapshot = _taxonomy();
    final bytes = await codec.encodeTaxonomy(snapshot);

    final header = await codec.peekEntity(bytes);
    expect(header.entity, SyncEntity.category);
    expect(header.entityId, snapshot.id);
    expect((await codec.decodeTaxonomy(bytes)).name, '工作');

    final envelope = ItemEnvelope.parse(Uint8List.fromList(bytes));
    final swapped = ItemEnvelope(
      entity: SyncEntity.tag,
      entityId: envelope.entityId,
      rev: envelope.rev,
      blob: envelope.blob,
    ).encode();
    await expectLater(
      codec.decodeTaxonomy(swapped),
      throwsA(isA<Exception>()),
    );
  });

  test('设备水位保持明文，ETag 只来自响应头而不进文件', () async {
    final codec = EncryptedSyncPayloadCodec(keys);
    final watermark = DeviceWatermark(
      deviceId: 'devA',
      maxHlc: Hlc(millis: 1731052800000, counter: 1, node: 'devA'),
      lastSeen: 1731052800000,
      schema: 1,
    );
    final bytes = await codec.encodeWatermark(watermark);
    final text = utf8.decode(bytes);

    expect(text, contains('"device_id":"devA"'));
    expect(text, contains('"schema":1'));
    expect(text, isNot(contains('etag')));
    final decoded = await codec.decodeWatermark(bytes, etag: 'dev-e1');
    expect(decoded.etag, 'dev-e1');
    expect(decoded.maxHlc, watermark.maxHlc);
  });
}
