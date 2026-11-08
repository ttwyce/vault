import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/canonical.dart';
import 'package:vault/core/identity/uuid_v7.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/data/db/database_key.dart';
import 'package:vault/data/db/database_opener.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/search/cjk_segmenter.dart';

/// 数据库层测试。
///
/// 全部走 `VaultDatabaseOpener`，因为它是全项目唯一的 open 入口 ——
/// 测试如果绕过它，就测不到加密断言这条最关键的防线。
void main() {
  late VaultDatabaseOpener opener;
  late VaultDatabase db;
  late HlcClock clock;
  final uuid = UuidV7(random: Random(42), now: () => 1731052800000);

  setUp(() async {
    opener = VaultDatabaseOpener(
      key: DatabaseKey.random(Random(7)),
      inMemory: true,
    );
    db = await opener.open();
    clock = HlcClock(node: 'test-device', now: () => 1731052800000);
  });

  tearDown(() async {
    await opener.close();
  });

  Future<String> insertEntry({
    required String title,
    required String body,
    int kind = 1,
    int deleted = 0,
  }) async {
    final id = uuid.next();
    final now = 1731052800000;
    final hash = Canonical.contentHash(<String, Object?>{
      'title': title,
      'body': body,
      'kind': kind,
    });
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: id,
            kind: kind,
            title: Value<String>(title),
            body: Value<String>(body),
            createdAt: now,
            updatedAt: now,
            hlc: clock.tick().encode(),
            contentHash: hash,
            deleted: Value<int>(deleted),
          ),
        );
    return id;
  }

  group('加密', () {
    test('opener 打开的库确实是 SQLCipher', () async {
      expect(await db.cipherVersion(), isNotEmpty);
    });

    test('opener 打开的库 cipher_salt 非空（key 真的生效）', () async {
      // 只查 cipher_version 不够：本项目全局用 SQLCipher，
      // "忘了设 key"的连接也会报出版本号。salt 才区分得开。
      final salt = await db.customSelect('PRAGMA cipher_salt;').get();
      expect(salt, isNotEmpty);
    });

    test('绕过 opener 直接开未加密库会被拦住（工程红线 4）', () async {
      final plain = VaultDatabase(NativeDatabase.memory());
      await expectLater(
        plain.customSelect('SELECT 1;').get(),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('cipher_salt'),
          ),
        ),
      );
      try {
        await plain.close();
      } on Object {
        // 已经抛错的连接，关闭时报错也无所谓
      }
    });

    test('落盘文件头不是明文 SQLite 标记', () async {
      final dir = Directory.systemTemp.createTempSync('vault_db_header');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      final fileOpener = VaultDatabaseOpener(
        key: DatabaseKey.random(Random(11)),
        storageDir: dir,
      );
      final fileDb = await fileOpener.open();
      final now = 1731052800000;
      await fileDb.into(fileDb.entries).insert(
            EntriesCompanion.insert(
              id: uuid.next(),
              kind: 6,
              title: const Value<String>('这是密码条目'),
              createdAt: now,
              updatedAt: now,
              hlc: clock.tick().encode(),
              contentHash: 'z' * 64,
            ),
          );
      // WAL 里可能还没回写主库，先 checkpoint
      await fileDb.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
      await fileOpener.close();

      final file = File(p.join(dir.path, 'vault.db'));
      expect(file.existsSync(), isTrue);
      final header = file.readAsBytesSync().take(16).toList();
      expect(
        String.fromCharCodes(header).startsWith('SQLite format 3'),
        isFalse,
        reason: '文件头仍是明文标记，说明没有真正加密',
      );
    });
  });

  group('schema', () {
    test('22 张实体表全部建成', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%';",
          )
          .get();
      final names = rows
          .map((QueryRow r) => r.read<String>('name'))
          .where((String n) => !n.startsWith('entry_fts') &&
              !n.startsWith('conversation_fts'))
          .toSet();

      for (final expected in <String>[
        'entry',
        'entry_history',
        'trash',
        'category',
        'tag',
        'entry_category',
        'entry_tag',
        'category_field_template',
        'credential',
        'conversation',
        'message',
        'oplog',
        'activity',
        'sync_state',
        'device_watermark',
        'sync_log',
        'diary_index',
        'entry_vec',
        'embedding_model',
        'blob_ref',
        'link_check',
        'job_queue',
      ]) {
        expect(names, contains(expected), reason: '缺少表：$expected');
      }
    });

    test('两个 FTS5 虚拟表建成', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name IN ('entry_fts','conversation_fts');",
          )
          .get();
      expect(rows.length, 2);
    });
  });

  group('条目读写', () {
    test('写入后能读回，字段完整', () async {
      final id = await insertEntry(title: 'WebDAV 增量同步', body: '用 sync-collection');
      final row = await (db.select(db.entries)..where((t) => t.id.equals(id)))
          .getSingle();

      expect(row.title, 'WebDAV 增量同步');
      expect(row.kind, 1);
      expect(row.rev, 1);
      expect(row.deleted, 0);
      expect(row.contentHash.length, 64);
      expect(Hlc.tryParse(row.hlc), isNotNull);
      expect(UuidV7.isValid(row.id), isTrue);
    });

    test('content_hash 对相同内容稳定', () async {
      final a = await insertEntry(title: 'T', body: 'B');
      final b = await insertEntry(title: 'T', body: 'B');
      final rowA = await (db.select(db.entries)..where((t) => t.id.equals(a))).getSingle();
      final rowB = await (db.select(db.entries)..where((t) => t.id.equals(b))).getSingle();
      expect(rowA.contentHash, rowB.contentHash);
    });
  });

  group('oplog 事务原子性', () {
    test('实体与 oplog 必须同生共死', () async {
      final id = uuid.next();
      final now = 1731052800000;

      await db.transaction(() async {
        await db.into(db.entries).insert(
              EntriesCompanion.insert(
                id: id,
                kind: 1,
                createdAt: now,
                updatedAt: now,
                hlc: clock.tick().encode(),
                contentHash: 'x' * 64,
              ),
            );
        await db.into(db.oplogs).insert(
              OplogsCompanion.insert(
                hlc: clock.tick().encode(),
                deviceId: 'test-device',
                entity: 'entry',
                entityId: id,
                op: 1,
                createdAt: now,
              ),
            );
      });

      expect(await db.select(db.entries).get(), hasLength(1));
      expect(await db.select(db.oplogs).get(), hasLength(1));
    });

    test('事务中抛错时两边都不落库', () async {
      final now = 1731052800000;

      await expectLater(
        db.transaction(() async {
          await db.into(db.entries).insert(
                EntriesCompanion.insert(
                  id: uuid.next(),
                  kind: 1,
                  createdAt: now,
                  updatedAt: now,
                  hlc: clock.tick().encode(),
                  contentHash: 'y' * 64,
                ),
              );
          await db.into(db.oplogs).insert(
                OplogsCompanion.insert(
                  hlc: clock.tick().encode(),
                  deviceId: 'test-device',
                  entity: 'entry',
                  entityId: 'whatever',
                  op: 1,
                  createdAt: now,
                ),
              );
          throw StateError('模拟合并失败');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await db.select(db.entries).get(), isEmpty);
      expect(await db.select(db.oplogs).get(), isEmpty);
    });

    test('待推送的 oplog 可以按 seq 顺序取出', () async {
      final now = 1731052800000;
      for (var i = 0; i < 3; i++) {
        await db.into(db.oplogs).insert(
              OplogsCompanion.insert(
                hlc: clock.tick().encode(),
                deviceId: 'test-device',
                entity: 'entry',
                entityId: 'e$i',
                op: 2,
                createdAt: now + i,
              ),
            );
      }
      final pending = await (db.select(db.oplogs)
            ..where((t) => t.applied.equals(0))
            ..orderBy(<OrderClauseGenerator<$OplogsTable>>[
              ($OplogsTable t) => OrderingTerm.asc(t.seq),
            ]))
          .get();
      expect(pending.map((OplogRow r) => r.entityId).toList(), <String>['e0', 'e1', 'e2']);
    });
  });

  group('全文检索', () {
    Future<void> indexEntry(String id, String title, String body) =>
        db.putSearchDocument(
          entryId: id,
          title: CjkSegmenter.indexText(title),
          body: CjkSegmenter.indexText(body),
          tags: '',
        );

    test('中文两字词能搜到（unicode61 原样索引搜不到）', () async {
      final id = await insertEntry(title: 'WebDAV 增量同步', body: '用 sync-collection 一次拿到全部变更');
      await indexEntry(id, 'WebDAV 增量同步', '用 sync-collection 一次拿到全部变更');

      final hits = await db.searchEntryIds(CjkSegmenter.matchQuery('同步'));
      expect(hits, <String>[id]);
    });

    test('中文四字词与跨词边界都能命中', () async {
      final a = await insertEntry(title: '增量同步', body: 'x');
      final b = await insertEntry(title: '冲突合并与删除策略', body: 'y');
      await indexEntry(a, '增量同步', 'x');
      await indexEntry(b, '冲突合并与删除策略', 'y');

      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('增量同步')), <String>[a]);
      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('删除策略')), <String>[b]);
    });

    test('英文与中英混排', () async {
      final id = await insertEntry(title: 'RFC 6578 增量同步', body: 'sync-collection');
      await indexEntry(id, 'RFC 6578 增量同步', 'sync-collection');

      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('webdav')), isEmpty);
      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('sync-collection')), <String>[id]);
      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('6578')), <String>[id]);
    });

    test('短语语义：不相邻的中文不应命中', () async {
      final id = await insertEntry(title: '冲突合并与删除策略', body: '');
      await indexEntry(id, '冲突合并与删除策略', '');

      // 「同步删除」在原文里不连续，必须搜不到
      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('同步删除')), isEmpty);
    });

    test('更新索引后旧内容不再命中', () async {
      final id = await insertEntry(title: '旧标题', body: '');
      await indexEntry(id, '旧标题', '');
      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('旧标题')), <String>[id]);

      await indexEntry(id, '新标题', '');
      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('旧标题')), isEmpty);
      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('新标题')), <String>[id]);
    });

    test('删除索引后不再命中', () async {
      final id = await insertEntry(title: '待删除', body: '');
      await indexEntry(id, '待删除', '');
      await db.removeSearchDocument(id);
      expect(await db.searchEntryIds(CjkSegmenter.matchQuery('待删除')), isEmpty);
    });

    test('空查询直接返回空列表，不抛 FTS 语法错', () async {
      expect(await db.searchEntryIds(''), isEmpty);
      expect(await db.searchEntryIds('   '), isEmpty);
    });

    test('带高亮片段', () async {
      final id = await insertEntry(title: 'WebDAV 增量同步', body: '用 sync-collection 一次拿到全部变更');
      await indexEntry(id, 'WebDAV 增量同步', '用 sync-collection 一次拿到全部变更');

      final hits = await db.searchWithSnippet(CjkSegmenter.matchQuery('增量'));
      expect(hits, hasLength(1));
      expect(hits.first.entryId, id);
      expect(hits.first.snippet, contains('⟦'));
    });

    test('索引可从 entry 全量重建', () async {
      final a = await insertEntry(title: '第一篇 笔记', body: '内容');
      final b = await insertEntry(title: '第二篇 笔记', body: '内容');
      await insertEntry(title: '已删除', body: '内容', deleted: 1);

      final count = await db.rebuildEntryIndex(CjkSegmenter.indexText);
      expect(count, 3, reason: '重建扫全表，含已删除行');

      final hits = await db.searchEntryIds(CjkSegmenter.matchQuery('笔记'));
      expect(hits.toSet(), <String>{a, b}, reason: '已删除条目不进索引');
    });
  });

  group('活动埋点', () {
    test('可以写入并按时间倒序读取', () async {
      for (var i = 0; i < 3; i++) {
        await db.into(db.activities).insert(
              ActivitiesCompanion.insert(
                ts: 1731052800000 + i * 1000,
                kind: 1,
                entryId: Value<String>('e$i'),
                dwellMs: Value<int>(500 * (i + 1)),
              ),
            );
      }
      final rows = await (db.select(db.activities)
            ..orderBy(<OrderClauseGenerator<$ActivitiesTable>>[
              ($ActivitiesTable t) => OrderingTerm.desc(t.ts),
            ]))
          .get();
      expect(rows.map((ActivityRow r) => r.entryId).toList(), <String>['e2', 'e1', 'e0']);
    });
  });
}
