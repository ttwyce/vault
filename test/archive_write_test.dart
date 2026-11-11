import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/vault_keys.dart';
import 'package:vault/core/identity/uuid_v7.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/db/database_key.dart';
import 'package:vault/data/db/database_opener.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/write/write_gateway.dart';

/// M4 归档派生表的唯一写入口测试。
const int _now = 1731052800000;

void main() {
  late VaultDatabaseOpener opener;
  late VaultDatabase db;
  late VaultKeys keys;
  late WriteGateway gateway;
  final String hash = 'a' * 64;

  setUp(() async {
    opener = VaultDatabaseOpener(
      key: DatabaseKey.random(Random(211)),
      inMemory: true,
    );
    db = await opener.open();
    keys = VaultKeys.generate();
    gateway = WriteGateway(
      db: db,
      keys: keys,
      clock: HlcClock(node: 'devA', now: () => _now),
      deviceId: 'devA',
      now: () => _now,
      uuid: UuidV7(random: Random(212), now: () => _now),
    );
    await gateway.writeEntry(EntryWrite.create(
      id: 'arc-1',
      kind: EntryKind.bookmark,
      title: '归档条目',
    ));
  });

  tearDown(() async {
    keys.destroy();
    await opener.close();
  });

  test('recordArchiveBlob 默认仅云端，local=0 且 hash 严格校验', () async {
    await gateway.recordArchiveBlob(
      entryId: 'arc-1',
      blobHash: hash,
      kind: ArchiveBlobKind.pdf.code,
      bytes: 412000,
    );
    final rows = await db.select(db.blobRefs).get();
    expect(rows, hasLength(1));
    expect(rows.single.local, 0);
    expect(rows.single.kind, 2);
    expect(
      () => gateway.recordArchiveBlob(
        entryId: 'arc-1',
        blobHash: 'ABC',
        kind: 1,
        bytes: 1,
      ),
      throwsA(isA<WriteException>()),
    );
  });

  test('markArchiveBlobLocal 只把 local 置 1，不改内容寻址 hash', () async {
    await gateway.recordArchiveBlob(
      entryId: 'arc-1',
      blobHash: hash,
      kind: 1,
      bytes: 100,
    );
    await gateway.markArchiveBlobLocal(entryId: 'arc-1', blobHash: hash);
    final row = await db.select(db.blobRefs).getSingle();
    expect(row.local, 1);
    expect(row.blobHash, hash);
    expect(row.bytes, 100);
  });

  test('缓存清理只置 local=0，不删云端 blob_ref 行', () async {
    await gateway.recordArchiveBlob(
      entryId: 'arc-1',
      blobHash: hash,
      kind: 2,
      bytes: 300,
      local: true,
    );
    await (db.update(db.blobRefs)..where((t) => t.blobHash.equals(hash)))
        .write(const BlobRefsCompanion(local: Value<int>(0)));
    final row = await db.select(db.blobRefs).getSingle();
    expect(row.local, 0);
    expect(row.blobHash, hash);
  });

  test('recordLinkCheck 记录状态与 simhash；同 entry 同时间幂等', () async {
    await gateway.recordLinkCheck(
      entryId: 'arc-1',
      checkedAt: _now,
      result: LinkCheckResult.dead.wire,
      httpStatus: 404,
      finalUrl: 'https://example.com/new',
      simhash: 'ff00',
    );
    await gateway.recordLinkCheck(
      entryId: 'arc-1',
      checkedAt: _now,
      result: LinkCheckResult.dead.wire,
      httpStatus: 404,
    );
    final rows = await db.select(db.linkChecks).get();
    expect(rows, hasLength(1));
    expect(rows.single.result, 'dead');
    expect(rows.single.httpStatus, 404);
    expect(rows.single.finalUrl, 'https://example.com/new');
    expect(rows.single.simhash, 'ff00');
  });

  test('enqueueArchiveJob 排可中断续跑任务，默认 pending', () async {
    final id = await gateway.enqueueArchiveJob(
      type: 'deadlink',
      payload: '{"entry_id":"arc-1"}',
      nextRunAt: _now + 1000,
    );
    expect(id, greaterThan(0));
    final row = await (db.select(db.jobQueues)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(row.type, 'deadlink');
    expect(row.state, 0);
    expect(row.nextRunAt, _now + 1000);
  });

  test('purgeTrashEntry 清掉该条目的 blob_ref / link_check 派生行', () async {
    await gateway.recordArchiveBlob(
      entryId: 'arc-1',
      blobHash: hash,
      kind: 1,
      bytes: 10,
    );
    await gateway.recordLinkCheck(
      entryId: 'arc-1',
      checkedAt: _now,
      result: 'ok',
    );
    await gateway.writeEntry(EntryWrite.delete(id: 'arc-1'));
    await gateway.purgeTrashEntry('arc-1');

    expect(await db.select(db.blobRefs).get(), isEmpty);
    expect(await db.select(db.linkChecks).get(), isEmpty);
  });
}
