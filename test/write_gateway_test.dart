import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/secret_wrapper.dart';
import 'package:vault/core/crypto/vault_keys.dart';
import 'package:vault/core/identity/uuid_v7.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/data/db/database_key.dart';
import 'package:vault/data/db/database_opener.dart';
import 'package:vault/data/db/tables/log_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/search/cjk_segmenter.dart';
import 'package:vault/data/write/entry_snapshot.dart';
import 'package:vault/data/write/item_envelope.dart';
import 'package:vault/data/write/write_gateway.dart';

/// `WriteGateway` 的测试。
///
/// 这里验证的不是"能不能写进去"，而是**"写进去的东西是不是自洽的"**：
/// oplog 与实体是否同生共死、rev 是否单调、历史是否被正确归档、
/// 密文是否真的绑定到了正确的实体与版本。
///
/// 后几条如果错了，单元测试照样全绿，但用户会在同步时丢数据。
void main() {
  late VaultDatabaseOpener opener;
  late VaultDatabase db;
  late VaultKeys keys;
  late HlcClock clock;
  late WriteGateway gateway;

  var nowMillis = 1731052800000;

  setUp(() async {
    opener = VaultDatabaseOpener(key: DatabaseKey.random(Random(7)), inMemory: true);
    db = await opener.open();
    keys = VaultKeys.generate();
    nowMillis = 1731052800000;
    clock = HlcClock(node: 'devA', now: () => nowMillis);
    gateway = WriteGateway(
      db: db,
      keys: keys,
      clock: clock,
      deviceId: 'devA',
      now: () => nowMillis,
      uuid: UuidV7(random: Random(42), now: () => nowMillis),
    );
  });

  tearDown(() async {
    keys.destroy();
    await opener.close();
  });

  Future<int> count(String table) async {
    final row = await db.customSelect('SELECT count(*) AS c FROM $table;').getSingle();
    return row.read<int>('c');
  }

  group('创建', () {
    test('写入实体与 oplog，rev=1，索引可检索', () async {
      final result = await gateway.writeEntry(
        EntryWrite.create(title: '增量同步的坑', body: 'WebDAV 限流很严'),
      );

      expect(result.changed, isTrue);
      expect(result.oplogSeq, greaterThan(0));
      expect(result.snapshot.rev, 1);
      expect(result.snapshot.deleted, isFalse);
      expect(result.snapshot.createdAt, result.snapshot.updatedAt);

      expect(await count('entry'), 1);
      expect(await count('oplog'), 1);
      expect(await count('entry_history'), 0, reason: '新建没有旧版本可归档');

      final row = await db.select(db.entries).getSingle();
      expect(row.title, '增量同步的坑');
      expect(row.rev, 1);
      expect(row.hlc, clock.last!.encode());
      expect(row.contentHash.length, 64);

      // 中文检索必须能命中 —— 这是切分与索引写入是否对齐的端到端验证
      final hits = await db.searchEntryIds(CjkSegmenter.matchQuery('同步'));
      expect(hits, <String>[result.snapshot.id]);
    });

    test('meta 不是合法 JSON 时拒绝写入，且不留任何痕迹', () async {
      await expectLater(
        gateway.writeEntry(EntryWrite.create(title: 'x', meta: '{不是 json')),
        throwsA(isA<ArgumentError>()),
      );
      expect(await count('entry'), 0);
      expect(await count('oplog'), 0);
    });

    test('重复创建同一 id 被拒绝（不静默覆盖）', () async {
      final id = '0192f0aa-1111-7222-8333-444455556666';
      await gateway.writeEntry(EntryWrite.create(id: id, title: 'a'));

      await expectLater(
        gateway.writeEntry(EntryWrite.create(id: id, title: 'b')),
        throwsA(
          isA<WriteException>().having((WriteException e) => e.code, 'code', 'exists'),
        ),
      );

      final row = await db.select(db.entries).getSingle();
      expect(row.title, 'a', reason: '原内容不能被覆盖');
      expect(await count('oplog'), 1);
    });

    test('HLC 与水位被持久化（重启后时钟不倒退）', () async {
      await gateway.writeEntry(EntryWrite.create(title: 'a'));
      final watermark = await db.select(db.deviceWatermarks).getSingle();
      expect(watermark.deviceId, 'devA');
      expect(watermark.maxHlc, clock.last!.encode());
    });
  });

  group('更新', () {
    test('rev 递增、旧版本进历史、oplog 记 baseRev', () async {
      final created = await gateway.writeEntry(
        EntryWrite.create(title: 'v1', body: '第一版'),
      );
      nowMillis += 1000;

      final updated = await gateway.writeEntry(
        EntryWrite.update(id: created.snapshot.id, title: 'v2', body: '第二版'),
      );

      expect(updated.changed, isTrue);
      expect(updated.snapshot.rev, 2);
      expect(updated.snapshot.createdAt, created.snapshot.createdAt,
          reason: '创建时间不能变');

      final oplog = await (db.select(db.oplogs)
            ..orderBy(<OrderClauseGenerator<dynamic>>[(t) => OrderingTerm.desc(t.seq)])
            ..limit(1))
          .getSingle();
      expect(oplog.op, OplogOp.update.code);
      expect(oplog.baseRev, 1, reason: 'baseRev 是三方合并的基准');

      final history = await db.select(db.entryHistory).getSingle();
      expect(history.rev, 1);
      expect(history.entryId, created.snapshot.id);
    });

    test('内容没变时不产生新版本（避免空变更刷屏同步）', () async {
      final created = await gateway.writeEntry(
        EntryWrite.create(title: '同一份', body: '内容'),
      );
      nowMillis += 5000;

      final again = await gateway.writeEntry(
        EntryWrite.update(id: created.snapshot.id, title: '同一份', body: '内容'),
      );

      expect(again.changed, isFalse);
      expect(again.oplogSeq, -1);
      expect(again.snapshot.rev, 1, reason: 'rev 不能因为一次无变化的保存而递增');
      expect(await count('oplog'), 1);
    });

    test('meta 键顺序不同但语义相同时，视为内容未变', () async {
      final created = await gateway.writeEntry(
        EntryWrite.create(title: 't', meta: '{"a":1,"b":2}'),
      );
      final again = await gateway.writeEntry(
        EntryWrite.update(id: created.snapshot.id, title: 't', meta: '{"b":2,"a":1}'),
      );
      expect(again.changed, isFalse,
          reason: 'content_hash 必须先解码 meta 再哈希，否则键顺序会制造假冲突');
    });

    test('更新不存在的条目报 not_found', () async {
      await expectLater(
        gateway.writeEntry(EntryWrite.update(id: 'nope', title: 'x')),
        throwsA(isA<WriteException>().having((WriteException e) => e.code, 'code', 'not_found')),
      );
    });

    test('更新已删除的条目被拒绝，引导用户先恢复', () async {
      final created = await gateway.writeEntry(EntryWrite.create(title: 'a'));
      await gateway.writeEntry(EntryWrite.delete(id: created.snapshot.id));

      await expectLater(
        gateway.writeEntry(EntryWrite.update(id: created.snapshot.id, title: 'b')),
        throwsA(
          isA<WriteException>().having((WriteException e) => e.code, 'code', 'already_deleted'),
        ),
      );
    });
  });

  group('删除与恢复', () {
    test('删除：软删除 + 进回收站 + 索引移除 + oplog 记 delete', () async {
      final created = await gateway.writeEntry(
        EntryWrite.create(title: '要删掉的', body: '内容'),
      );

      final deleted = await gateway.writeEntry(EntryWrite.delete(id: created.snapshot.id));
      expect(deleted.changed, isTrue);
      expect(deleted.snapshot.deleted, isTrue);
      expect(deleted.snapshot.deletedAt, isNotNull);
      expect(deleted.snapshot.rev, 2);

      final row = await db.select(db.entries).getSingle();
      expect(row.deleted, 1);
      expect(row.deletedAt, isNotNull);

      final trash = await db.select(db.trashRows).getSingle();
      expect(trash.entryId, created.snapshot.id);
      expect(
        trash.expireAt - trash.deletedAt,
        const Duration(days: 30).inMilliseconds,
        reason: '回收站保留期必须是 30 天',
      );

      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('删掉')), isEmpty,
          reason: '已删除条目不能出现在检索结果里');

      final oplog = await (db.select(db.oplogs)
            ..orderBy(<OrderClauseGenerator<dynamic>>[(t) => OrderingTerm.desc(t.seq)])
            ..limit(1))
          .getSingle();
      expect(oplog.op, OplogOp.delete.code);
    });

    test('重复删除是幂等空操作，不写 oplog', () async {
      final created = await gateway.writeEntry(EntryWrite.create(title: 'a'));
      await gateway.writeEntry(EntryWrite.delete(id: created.snapshot.id));
      final before = await count('oplog');

      final again = await gateway.writeEntry(EntryWrite.delete(id: created.snapshot.id));
      expect(again.changed, isFalse);
      expect(await count('oplog'), before);
    });

    test('恢复：清掉 deleted 标记、移出回收站、重新进索引', () async {
      final created = await gateway.writeEntry(
        EntryWrite.create(title: '回来吧', body: '内容'),
      );
      await gateway.writeEntry(EntryWrite.delete(id: created.snapshot.id));
      nowMillis += 1000;

      final restored = await gateway.writeEntry(EntryWrite.restore(id: created.snapshot.id));
      expect(restored.changed, isTrue);
      expect(restored.snapshot.deleted, isFalse);
      expect(restored.snapshot.deletedAt, isNull);
      expect(restored.snapshot.rev, 3);

      expect(await count('trash'), 0);
      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('回来')), isNotEmpty);

      final oplog = await (db.select(db.oplogs)
            ..orderBy(<OrderClauseGenerator<dynamic>>[(t) => OrderingTerm.desc(t.seq)])
            ..limit(1))
          .getSingle();
      expect(oplog.op, OplogOp.restore.code);
    });

    test('恢复未删除的条目是空操作', () async {
      final created = await gateway.writeEntry(EntryWrite.create(title: 'a'));
      final result = await gateway.writeEntry(EntryWrite.restore(id: created.snapshot.id));
      expect(result.changed, isFalse);
    });
  });

  group('事务原子性', () {
    test('中途失败时实体、oplog、历史全部回滚', () async {
      // 让索引写入抛错。此时 oplog 与 entry 都已经写过 ——
      // 如果它们不在同一个事务里，数据库里就会留下一条"推不出去的变更"
      // 或"有实体但没有 oplog"的幽灵记录。
      final broken = WriteGateway(
        db: db,
        keys: keys,
        clock: clock,
        deviceId: 'devA',
        now: () => nowMillis,
        segmenter: (String _) => throw StateError('索引写入故意失败'),
      );

      await expectLater(
        broken.writeEntry(EntryWrite.create(title: '会失败', body: '内容')),
        throwsA(isA<StateError>()),
      );

      expect(await count('entry'), 0, reason: '实体必须回滚');
      expect(await count('oplog'), 0, reason: 'oplog 必须回滚');
      expect(await count('entry_history'), 0);
    });

    test('更新失败时旧版本不能被留在历史里', () async {
      final created = await gateway.writeEntry(EntryWrite.create(title: 'v1'));
      final broken = WriteGateway(
        db: db,
        keys: keys,
        clock: clock,
        deviceId: 'devA',
        now: () => nowMillis,
        segmenter: (String _) => throw StateError('boom'),
      );

      await expectLater(
        broken.writeEntry(EntryWrite.update(id: created.snapshot.id, title: 'v2')),
        throwsA(isA<StateError>()),
      );

      expect(await count('entry_history'), 0);
      final row = await db.select(db.entries).getSingle();
      expect(row.title, 'v1');
      expect(row.rev, 1);
    });
  });

  group('历史裁剪', () {
    test('只保留最近 5 个版本', () async {
      final created = await gateway.writeEntry(EntryWrite.create(title: 'v1'));
      for (var i = 2; i <= 9; i++) {
        nowMillis += 1000;
        await gateway.writeEntry(
          EntryWrite.update(id: created.snapshot.id, title: 'v$i'),
        );
      }

      expect(await count('entry_history'), WriteGateway.historyDepth);

      final revs = await db.customSelect(
        'SELECT rev FROM entry_history ORDER BY rev ASC;',
      ).get();
      expect(
        revs.map((QueryRow r) => r.read<int>('rev')).toList(),
        <int>[4, 5, 6, 7, 8],
        reason: '保留的是最近的 5 个历史版本（当前版本 v9 不在历史表里）',
      );
    });
  });

  group('oplog 回放', () {
    test('payload 能解回与写入时一致的快照', () async {
      final created = await gateway.writeEntry(
        EntryWrite.create(title: '快照', body: '正文', meta: '{"tag":"x"}'),
      );
      final oplog = await db.select(db.oplogs).getSingle();
      final snapshot = await gateway.readSnapshot(oplog);

      expect(snapshot.id, created.snapshot.id);
      expect(snapshot.rev, 1);
      expect(snapshot.title, '快照');
      expect(snapshot.body, '正文');
      expect(snapshot.meta, '{"tag":"x"}');
      expect(snapshot.contentHash, created.snapshot.contentHash);
    });

    test('latestSnapshot 取到最新版本', () async {
      final created = await gateway.writeEntry(EntryWrite.create(title: 'v1'));
      nowMillis += 1000;
      await gateway.writeEntry(EntryWrite.update(id: created.snapshot.id, title: 'v2'));

      final latest = await gateway.latestSnapshot(created.snapshot.id);
      expect(latest!.rev, 2);
      expect(latest.title, 'v2');
    });

    test('把 A 的 payload 塞进 B 的行会被发现', () async {
      final a = await gateway.writeEntry(EntryWrite.create(title: 'A'));
      final b = await gateway.writeEntry(EntryWrite.create(title: 'B'));

      final rowA = await (db.select(db.oplogs)..where((t) => t.entityId.equals(a.snapshot.id)))
          .getSingle();

      // 模拟攻击者 / bug：直接把 payload 搬过去
      await (db.update(db.oplogs)..where((t) => t.entityId.equals(b.snapshot.id)))
          .write(OplogsCompanion(payload: Value<Uint8List?>(rowA.payload)));

      final rowB = await (db.select(db.oplogs)..where((t) => t.entityId.equals(b.snapshot.id)))
          .getSingle();

      await expectLater(
        gateway.readSnapshot(rowB),
        throwsA(isA<StateError>()),
      );
    });

    test('pending / markApplied / pendingCount', () async {
      await gateway.writeEntry(EntryWrite.create(title: 'a'));
      await gateway.writeEntry(EntryWrite.create(title: 'b'));

      expect(await gateway.pendingCount(), 2);
      final pending = await gateway.pending();
      expect(pending.length, 2);
      expect(pending.first.seq, lessThan(pending.last.seq), reason: '必须按 seq 升序');

      await gateway.markApplied(<int>[pending.first.seq]);
      expect(await gateway.pendingCount(), 1);

      // 已推送的记录不能被删除 —— 它是审计链与回滚依据
      expect(await count('oplog'), 2);
    });
  });

  group('ItemEnvelope', () {
    test('编码 / 解析往返', () async {
      final key = await keys.item();
      final envelope = await ItemEnvelope.seal(
        key: key,
        entity: SyncEntity.entry,
        entityId: 'entry-1',
        rev: 3,
        plaintext: <int>[1, 2, 3, 4, 5],
        random: Random(1),
      );

      final bytes = envelope.encode();
      final parsed = ItemEnvelope.parse(bytes);
      expect(parsed.entity, SyncEntity.entry);
      expect(parsed.entityId, 'entry-1');
      expect(parsed.rev, 3);

      final clear = await parsed.open(key: key);
      expect(clear, <int>[1, 2, 3, 4, 5]);
    });

    test('头部被改一个字节就解不开（AAD = 头部字节）', () async {
      final key = await keys.item();
      final envelope = await ItemEnvelope.seal(
        key: key,
        entity: SyncEntity.entry,
        entityId: 'entry-1',
        rev: 1,
        plaintext: <int>[9, 9, 9],
        random: Random(2),
      );

      final bytes = Uint8List.fromList(envelope.encode());
      // 改头部里的 '1'（rev 字段）→ 解析出的 rev 变了，AAD 也就变了
      final idx = bytes.indexOf(0x31);
      expect(idx, greaterThan(0));
      bytes[idx] = 0x32;

      final tampered = ItemEnvelope.parse(bytes);
      await expectLater(
        tampered.open(key: key),
        throwsA(isA<SecretUnwrapException>()),
      );
    });

    test('信封版本不认识时给出可读错误', () {
      final bytes = Uint8List(64);
      bytes[0] = 99;
      expect(
        () => ItemEnvelope.parse(bytes),
        throwsA(isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          contains('版本'),
        )),
      );
    });

    test('过短的字节被拒绝', () {
      expect(() => ItemEnvelope.parse(Uint8List(4)), throwsA(isA<FormatException>()));
    });
  });

  group('EntrySnapshot', () {
    test('JSON 往返', () {
      final snapshot = EntrySnapshot(
        id: 'e1',
        kind: 1,
        title: 't',
        body: 'b',
        meta: '{"a":1}',
        createdAt: 1,
        updatedAt: 2,
        hlc: '0000000000000001:0000:devA',
        rev: 3,
        contentHash: 'x' * 64,
        deleted: true,
        deletedAt: 5,
      );

      final back = EntrySnapshot.fromJson(snapshot.toJson());
      expect(back.id, snapshot.id);
      expect(back.kind, snapshot.kind);
      expect(back.title, snapshot.title);
      expect(back.meta, snapshot.meta);
      expect(back.rev, snapshot.rev);
      expect(back.deleted, isTrue);
      expect(back.deletedAt, 5);
    });

    test('content_hash 不含 rev / hlc / updated_at', () {
      final a = EntrySnapshot.computeContentHash(kind: 1, title: 't', body: 'b');
      final b = EntrySnapshot.computeContentHash(kind: 1, title: 't', body: 'b');
      expect(a, b);
      expect(a.length, 64);
    });

    test('content_hash 对 kind 敏感（同文本不同类型不能同哈希）', () {
      final note = EntrySnapshot.computeContentHash(kind: 1, title: 't');
      final diary = EntrySnapshot.computeContentHash(kind: 3, title: 't');
      expect(note, isNot(diary));
    });

    test('确定性字节：同一快照两次序列化完全一致', () {
      final snapshot = EntrySnapshot(
        id: 'e1',
        kind: 1,
        title: 't',
        createdAt: 1,
        updatedAt: 1,
        hlc: 'h',
        rev: 1,
        contentHash: 'c',
      );
      expect(snapshot.toCanonicalBytes(), snapshot.toCanonicalBytes());
    });
  });
}
