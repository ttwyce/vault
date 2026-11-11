import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/vault_keys.dart';
import 'package:vault/core/identity/uuid_v7.dart';
import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/entity_sync_engine.dart';
import 'package:vault/core/sync/encrypted_sync_codec.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/core/sync/retention_policy.dart';
import 'package:vault/core/sync/sync_runtime.dart';
import 'package:vault/core/sync/webdav_backend.dart';
import 'package:vault/data/db/database_key.dart';
import 'package:vault/data/db/database_opener.dart';
import 'package:vault/data/db/tables/log_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/sync/db_entity_sync_port.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/write/write_gateway.dart';

/// #15：taxonomy 独立通道 + 保留策略。
///
/// 重点不是「能不能跑通」，而是四条红线：
/// 1. 所有 PUT 都带 `If-Match` / `If-None-Match`，且路径固定在 `/vault/entities/`；
/// 2. 远端 taxonomy 不跑 merge3，同 rev 或更旧直接跳过；
/// 3. 30 天清理必须等本条墓碑被 `sync_state` 确认，条目恢复 / 有待推 oplog
///    都不准删；
/// 4. 墓碑 90 天 TTL 与本地 30 天清理是两套独立判定。
const int _now = 1731052800000;
const Duration _day = Duration(days: 1);

class _File {
  const _File(this.bytes, this.etag);

  final List<int> bytes;
  final String etag;
}

class _FakeBackend implements WebDavBackend {
  _FakeBackend({Map<String, _File>? files})
      : files = files ?? <String, _File>{},
        listings = <String, List<WebDavListing>>{
          for (var i = 0; i < CloudLayout.shardCount; i++)
            CloudLayout.entitiesDir(i.toRadixString(16)):
                <WebDavListing>[],
        };

  final Map<String, _File> files;
  final Map<String, List<WebDavListing>> listings;
  final List<WebDavCondition> conditions = <WebDavCondition>[];
  final List<String> calls = <String>[];
  int _etagCounter = 700;

  void add(String path, List<int> bytes, {String etag = 'entity-e1'}) {
    files[path] = _File(bytes, etag);
    final dir = path.substring(0, path.lastIndexOf('/'));
    listings.putIfAbsent(dir, () => <WebDavListing>[]);
    if (!listings[dir]!.any((WebDavListing l) => l.path == path)) {
      listings[dir]!.add(WebDavListing(path: path, etag: etag));
    }
  }

  @override
  Future<Map<String, String>> options(String path) async => <String, String>{
        'DAV': '1',
        'Allow': 'PROPFIND, GET, PUT, DELETE',
      };

  @override
  Future<List<WebDavListing>> propfind(String path, {int depth = 1}) async {
    calls.add('PROPFIND $path');
    return listings[path] ?? const <WebDavListing>[];
  }

  @override
  Future<SyncCollectionDelta> reportSyncCollection(
    String path, {
    String? syncToken,
  }) async =>
      const SyncCollectionDelta(
        changed: <String, String?>{},
        deleted: <String>{},
        syncToken: 'tok',
      );

  @override
  Future<WebDavGetResult> get(String path) async {
    calls.add('GET $path');
    final file = files[path];
    if (file == null) {
      throw WebDavException(statusCode: 404, method: 'GET', path: path);
    }
    return WebDavGetResult(bytes: file.bytes, etag: file.etag);
  }

  @override
  Future<WebDavPutResult> put(
    String path,
    List<int> bytes, {
    required WebDavCondition condition,
  }) async {
    calls.add('PUT $path');
    conditions.add(condition);
    if (!condition.isValid) {
      throw ArgumentError('条件写不能同时为空');
    }
    final current = files[path];
    if (condition.isCreateOnly && current != null) {
      throw WebDavPreconditionFailed(method: 'PUT', path: path);
    }
    if (!condition.isCreateOnly &&
        (current == null || current.etag != condition.ifMatchEtag)) {
      throw WebDavPreconditionFailed(method: 'PUT', path: path);
    }
    final etag = 'e${_etagCounter++}';
    files[path] = _File(List<int>.from(bytes), etag);
    // 真实服务器会立刻把 PUT 出来的文件列进 PROPFIND；fake 必须同步维护。
    add(path, bytes, etag: etag);
    return WebDavPutResult(
      etag: etag,
      statusCode: current == null ? 201 : 204,
    );
  }

  @override
  Future<void> delete(String path, {required String ifMatch}) async {
    calls.add('DELETE $path');
    files.remove(path);
  }

  @override
  Future<void> mkcol(String path) async {
    calls.add('MKCOL $path');
  }
}

class _Env {
  _Env({
    required this.opener,
    required this.db,
    required this.keys,
    required this.codec,
    required this.gateway,
    required this.port,
  });

  final VaultDatabaseOpener opener;
  final VaultDatabase db;
  final VaultKeys keys;
  final EncryptedSyncPayloadCodec codec;
  final WriteGateway gateway;
  final DbEntitySyncPort port;

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT count(*) AS c FROM $table;')
        .getSingle();
    return row.read<int>('c');
  }
}

Future<_Env> _createEnv() async {
  final opener = VaultDatabaseOpener(
    key: DatabaseKey.random(Random(37)),
    inMemory: true,
  );
  final db = await opener.open();
  final keys = VaultKeys.generate();
  final clock = HlcClock(node: 'devA', now: () => _now);
  final uuid = UuidV7(random: Random(41), now: () => _now);
  final codec = EncryptedSyncPayloadCodec(keys, random: Random(43));
  final gateway = WriteGateway(
    db: db,
    keys: keys,
    clock: clock,
    deviceId: 'devA',
    now: () => _now,
    uuid: uuid,
  );
  return _Env(
    opener: opener,
    db: db,
    keys: keys,
    codec: codec,
    gateway: gateway,
    port: DbEntitySyncPort(db: db, gateway: gateway, codec: codec),
  );
}

TaxonomySnapshot _category({
  String id = 'cat-remote',
  String name = '远端分类',
  int rev = 2,
  bool deleted = false,
}) {
  return TaxonomySnapshot(
    entity: SyncEntity.category,
    id: id,
    rev: rev,
    hlc: Hlc(millis: _now, counter: 0, node: 'devB').encode(),
    updatedAt: _now,
    deleted: deleted,
    fields: <String, Object?>{
      'name': name,
      'kind': 1,
      'parent_id': null,
      'sort_order': 0,
    },
  );
}

Future<String> _path(
  EncryptedSyncPayloadCodec codec,
  TaxonomySnapshot snapshot,
) async =>
    CloudLayout.entityItemPath(
      await codec.hashedEntityName(snapshot.entity, snapshot.id),
    );

void main() {
  late _Env env;

  setUp(() async {
    env = await _createEnv();
  });

  tearDown(() async {
    env.keys.destroy();
    await env.opener.close();
  });

  group('EntitySyncEngine 推送', () {
    test('本地 category oplog 条件推送到 /vault/entities/ 并标记 applied=1',
        () async {
      final created = await env.gateway.writeCategory(
        CategoryWrite.create(id: 'cat-local', name: '本地分类'),
      );
      final backend = _FakeBackend();

      final result = await EntitySyncEngine(
        backend: backend,
        codec: env.codec,
        port: env.port,
      ).run();

      expect(result.skipped, isFalse);
      expect(result.isFailed, isFalse);
      expect(result.pushedPaths, hasLength(1));
      final path = result.pushedPaths.single;
      expect(path.startsWith('${CloudLayout.root}/entities/'), isTrue);
      expect(CloudLayout.isValidItemName(path.split('/').last), isTrue);
      expect(
        backend.conditions.every((WebDavCondition c) => c.isValid),
        isTrue,
      );
      expect(backend.conditions.single.isCreateOnly, isTrue);
      expect(
        backend.files[path]!.bytes,
        (await (env.db.select(env.db.oplogs)
              ..where((t) => t.seq.equals(created.oplogSeq)))
            .getSingle())
            .payload!
            .toList(),
        reason: 'taxonomy 也复用 oplog 信封字节，不重新加密',
      );

      final op = await (env.db.select(env.db.oplogs)
            ..where((t) => t.seq.equals(created.oplogSeq)))
          .getSingle();
      expect(op.applied, 1);
      final state = await (env.db.select(env.db.syncStates)
            ..where((t) => t.path.equals(path)))
          .getSingle();
      expect(state.etag, isNotNull);
      final logs = await env.db.select(env.db.syncLogs).get();
      expect(logs.single.trigger, 'entity_push');
      expect(logs.single.pushed, 1);
    });

    test('已有 ETag 时第二次推送用 If-Match，不做无条件 PUT', () async {
      await env.gateway.writeCategory(
        CategoryWrite.create(id: 'cat-local', name: '本地分类'),
      );
      final first = _FakeBackend();
      await EntitySyncEngine(
        backend: first,
        codec: env.codec,
        port: env.port,
      ).run();
      final path = first.calls
          .firstWhere((String call) => call.startsWith('PUT '))
          .substring(4);

      // 手动制造一次新的待推 taxonomy 变更（改名会写新 oplog）。
      await env.gateway.writeCategory(
        CategoryWrite.update(id: 'cat-local', name: '改名后'),
      );
      final second = _FakeBackend()
        ..add(path, first.files[path]!.bytes, etag: first.files[path]!.etag);

      final result = await EntitySyncEngine(
        backend: second,
        codec: env.codec,
        port: env.port,
      ).run();

      expect(result.isFailed, isFalse);
      expect(result.pushedPaths, hasLength(1));
      expect(second.conditions.single.isCreateOnly, isFalse);
      expect(second.conditions.single.ifMatchEtag, first.files[path]!.etag);
    });

    test('单飞锁忙时直接跳过，零请求且不写日志', () async {
      final lock = SingleFlightLock()..tryAcquire();
      final backend = _FakeBackend();

      final result = await EntitySyncEngine(
        backend: backend,
        codec: env.codec,
        port: env.port,
        lock: lock,
      ).run();

      expect(result.skipped, isTrue);
      expect(result.requestCount, 0);
      expect(backend.calls, isEmpty);
      expect(await env.count('sync_log'), 0);
      lock.release();
    });
  });

  group('EntitySyncEngine 拉取', () {
    test('远端 category 落库、不跑 merge3、oplog 直接 applied=1', () async {
      final snapshot = _category();
      final path = await _path(env.codec, snapshot);
      final backend = _FakeBackend()
        ..add(path, await env.codec.encodeTaxonomy(snapshot));

      final result = await EntitySyncEngine(
        backend: backend,
        codec: env.codec,
        port: env.port,
      ).run();

      expect(result.pulledPaths, <String>[path]);
      expect(result.isFailed, isFalse);
      final category = await (env.db.select(env.db.categories)
            ..where((t) => t.id.equals(snapshot.id)))
          .getSingle();
      expect(category.name, '远端分类');
      expect(category.deleted, 0);
      final op = await (env.db.select(env.db.oplogs)
            ..where((t) => t.entity.equals(SyncEntity.category)))
          .getSingle();
      expect(op.applied, 1);
      expect(op.entityId, snapshot.id);
      final state = await (env.db.select(env.db.syncStates)
            ..where((t) => t.path.equals(path)))
          .getSingle();
      expect(state.etag, 'entity-e1');
      expect(await env.port.pending(), isEmpty);
    });

    test('损坏载荷隔离到 sync_quarantine，原始字节完整且不覆盖本地', () async {
      final snapshot = _category();
      final path = await _path(env.codec, snapshot);
      final badBytes = <int>[0, 17, 255, 3];
      final backend = _FakeBackend()..add(path, badBytes);

      final result = await EntitySyncEngine(
        backend: backend,
        codec: env.codec,
        port: env.port,
      ).run();

      expect(result.quarantinedPaths, <String>{path});
      expect(result.quarantinePayloads[path], badBytes);
      final quarantined = await env.gateway.quarantine();
      expect(quarantined, hasLength(1));
      expect(quarantined.single.path, path);
      expect(quarantined.single.bytes.toList(), badBytes);
      expect(await env.count('category'), 0);
      expect(await env.count('oplog'), 0);
    });

    test('同 rev 或更旧的远端 taxonomy 不重复写 oplog', () async {
      final snapshot = _category();
      final path = await _path(env.codec, snapshot);
      final backend = _FakeBackend()
        ..add(path, await env.codec.encodeTaxonomy(snapshot));
      final engine = EntitySyncEngine(
        backend: backend,
        codec: env.codec,
        port: env.port,
      );

      await engine.run();
      final afterFirst = await env.count('oplog');
      // 第二轮 ETag 未变：added/modified 都为空，不会再 GET。
      await engine.run();
      final afterSecond = await env.count('oplog');

      expect(afterFirst, 1);
      expect(afterSecond, afterFirst);

      // 换个 ETag 但 rev 更小，仍不得写 oplog。
      backend.files[path] = _File(
        await env.codec.encodeTaxonomy(_category(rev: 1, name: '旧版本')),
        'entity-e2',
      );
      backend.listings[path.substring(0, path.lastIndexOf('/'))] =
          <WebDavListing>[WebDavListing(path: path, etag: 'entity-e2')];
      await engine.run();
      expect(await env.count('oplog'), afterFirst);
      final category = await (env.db.select(env.db.categories)
            ..where((t) => t.id.equals(snapshot.id)))
          .getSingle();
      expect(category.name, '远端分类', reason: '更旧的 rev 不能覆盖本地');
    });

    test('T22：同 rev 但远端 HLC 更大时应用远端，不再静默丢更新', () async {
      final newer = _category(name: '远端新名字');
      // _category 的 HLC 固定 devB@_now；本地先灌一条同 rev、HLC 更小的。
      final local = _category(name: '本地旧名字');
      final localWithOlderHlc = TaxonomySnapshot(
        entity: local.entity,
        id: local.id,
        rev: local.rev,
        hlc: Hlc(millis: _now - 1000, counter: 0, node: 'devA').encode(),
        updatedAt: local.updatedAt,
        deleted: false,
        fields: local.fields,
      );
      final localPath = await _path(env.codec, localWithOlderHlc);
      final first = _FakeBackend()
        ..add(localPath, await env.codec.encodeTaxonomy(localWithOlderHlc));
      await EntitySyncEngine(
        backend: first,
        codec: env.codec,
        port: env.port,
      ).run();

      // 同一路径换成同 rev 但 HLC 更大的远端版本，ETag 也变。
      final second = _FakeBackend()
        ..add(localPath, await env.codec.encodeTaxonomy(newer), etag: 'e2');
      // 清掉本地 sync_state 让 diff 判定为 added（否则 ETag 相同会跳过）。
      await env.port.commitPulls(
        const <RemoteTaxonomyFile>[],
        <String, String?>{},
        const <String, List<int>>{},
      );
      await EntitySyncEngine(
        backend: second,
        codec: env.codec,
        port: env.port,
      ).run();

      final row = await (env.db.select(env.db.categories)
            ..where((t) => t.id.equals(local.id)))
          .getSingle();
      expect(row.name, '远端新名字');
      expect(await env.count('oplog'), 2);
    });

    test('T21：两设备各建同名标签，拉取后自动合并且条目关联不丢', () async {
      // 本地标签挂了两条笔记。
      final localTag = await env.gateway.writeTag(
        TagWrite.create(id: 'tag-local', name: 'WebDAV'),
      );
      final e1 = await env.gateway.writeEntry(
        EntryWrite.create(id: 'note-1', title: '一'),
      );
      final e2 = await env.gateway.writeEntry(
        EntryWrite.create(id: 'note-2', title: '二'),
      );
      await env.gateway.setEntryTaxonomy(
        entryId: e1.snapshot.id,
        tagIds: <String>['tag-local'],
      );
      await env.gateway.setEntryTaxonomy(
        entryId: e2.snapshot.id,
        tagIds: <String>['tag-local'],
      );
      expect(localTag.changed, isTrue);

      // 远端同名标签 id 不同、usage_count=0（本地 usage=2 更大 → 保留本地）。
      final remoteTag = TaxonomySnapshot(
        entity: SyncEntity.tag,
        id: 'tag-remote',
        rev: 1,
        hlc: Hlc(millis: _now, counter: 0, node: 'devB').encode(),
        updatedAt: _now,
        deleted: false,
        fields: <String, Object?>{
          'name': 'webdav', // 大小写不同，taxonomyNameKey 仍视为同名
          'usage_count': 0,
        },
      );
      final path = await _path(env.codec, remoteTag);
      final backend = _FakeBackend()
        ..add(path, await env.codec.encodeTaxonomy(remoteTag));

      await EntitySyncEngine(
        backend: backend,
        codec: env.codec,
        port: env.port,
      ).run();

      final tags = await (env.db.select(env.db.tags)
            ..where((t) => t.deleted.equals(0)))
          .get();
      expect(tags, hasLength(1), reason: '同名活标签必须只剩一个');
      expect(tags.single.id, 'tag-local', reason: 'usage 大的一方保留');
      final kept = await (env.db.select(env.db.entryTags)
            ..where((t) => t.tagId.equals('tag-local')))
          .get();
      expect(kept.map((row) => row.entryId).toSet(),
          <String>{'note-1', 'note-2'}, reason: '关联不丢');
      final remoteRow = await (env.db.select(env.db.tags)
            ..where((t) => t.id.equals('tag-remote')))
          .getSingleOrNull();
      expect(remoteRow, isNull, reason: '保留本地时远端 id 不能复活成活标签');
    });

    test('部分分片扫描不推断删除，其它通道的 sync_state 不被清掉', () async {
      await env.db.into(env.db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: CloudLayout.entityItemPath(
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.enc',
              ),
              etag: const Value<String?>('old-etag'),
            ),
          );
      await env.db.into(env.db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: '/vault/items/0/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.enc',
              etag: const Value<String?>('item-etag'),
            ),
          );
      final backend = _FakeBackend();
      // budgetLimit=15：只能扫完 15 个分片，第 16 个请求预算不足。
      final result = await EntitySyncEngine(
        backend: backend,
        codec: env.codec,
        port: env.port,
        budgetLimit: 15,
      ).run();

      expect(result.isFailed, isFalse);
      expect(result.reason, contains('预算不足'));
      final state = await env.port.syncState();
      expect(
        state[CloudLayout.entityItemPath(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.enc',
        )],
        'old-etag',
        reason: '没扫到的分片里文件「不见」不是删除',
      );
      expect(
        state['/vault/items/0/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.enc'],
        'item-etag',
      );
    });
  });

  group('保留策略：30 天清理与墓碑联动', () {
    test('未到期 / 条目已恢复 / 有待推 oplog 都不准物理清空', () async {
      final now = _now + 31 * _day.inMilliseconds;
      final expireAt = _now + 30 * _day.inMilliseconds;

      expect(
        evaluateTrashPurge(
          nowMs: _now + 29 * _day.inMilliseconds,
          expireAt: expireAt,
          entryStillDeleted: true,
          tombstoneConfirmed: true,
          hasPendingOps: false,
          hasUnconfirmedDelete: false,
        ).decision,
        TrashPurgeDecision.keep,
      );
      expect(
        evaluateTrashPurge(
          nowMs: now,
          expireAt: expireAt,
          entryStillDeleted: false,
          tombstoneConfirmed: true,
          hasPendingOps: false,
          hasUnconfirmedDelete: false,
        ).decision,
        TrashPurgeDecision.keep,
      );
      expect(
        evaluateTrashPurge(
          nowMs: now,
          expireAt: expireAt,
          entryStillDeleted: true,
          tombstoneConfirmed: true,
          hasPendingOps: true,
          hasUnconfirmedDelete: true,
        ).decision,
        TrashPurgeDecision.waitForTombstone,
      );
    });

    test('只有本条墓碑拿到 ETag 才允许清空；任意别的墓碑不算', () async {
      final codec = env.codec;
      final name = await codec.hashedName('entry-1');
      final path = CloudLayout.tombstonePath(name);
      final state = <String, String?>{
        '/vault/tombstones/cccccccccccccccccccccccccccccccc.enc': 'other-etag',
      };

      expect(isTombstoneConfirmed(state, path), isFalse);
      state[path] = 'confirmed-etag';
      expect(isTombstoneConfirmed(state, path), isTrue);
      expect(
        evaluateTrashPurge(
          nowMs: _now + 31 * _day.inMilliseconds,
          expireAt: _now + 30 * _day.inMilliseconds,
          entryStillDeleted: true,
          tombstoneConfirmed: false,
          hasPendingOps: false,
          hasUnconfirmedDelete: false,
        ).decision,
        TrashPurgeDecision.waitForTombstone,
      );
      expect(
        evaluateTrashPurge(
          nowMs: _now + 31 * _day.inMilliseconds,
          expireAt: _now + 30 * _day.inMilliseconds,
          entryStillDeleted: true,
          tombstoneConfirmed: true,
          hasPendingOps: false,
          hasUnconfirmedDelete: false,
        ).canPurge,
        isTrue,
      );
    });

    test('清理任务只在闸门全通过时删本地行，并写 sync_log', () async {
      // 建立一条真实删除：entry( deleted=1 ) + trash + 待推 delete oplog。
      final created = await env.gateway.writeEntry(
        EntryWrite.create(id: 'entry-trash', title: '会过期的内容'),
      );
      await env.gateway.writeEntry(
        EntryWrite.delete(id: created.snapshot.id),
      );
      final trash = await env.db.select(env.db.trashRows).getSingle();
      expect(trash.expireAt - trash.deletedAt, 30 * _day.inMilliseconds);

      final nowMs = trash.expireAt + 1000;
      // 第一次：delete oplog 还没推 → 必须等待墓碑确认。
      final blocked = await env.port.purgeExpiredTrash(nowMs: nowMs);
      expect(blocked.purged, isEmpty);
      expect(blocked.skipped[created.snapshot.id], contains('未推送'));
      expect(await env.count('entry'), 1);
      expect(await env.count('trash'), 1);

      // 标记 oplog 已推，但云端墓碑还没确认 → 仍不准删。
      await env.gateway.markApplied(
        (await env.gateway.pending()).map((row) => row.seq),
      );
      final waiting = await env.port.purgeExpiredTrash(nowMs: nowMs);
      expect(waiting.purged, isEmpty);
      expect(waiting.skipped[created.snapshot.id], contains('墓碑未确认'));

      // 记录**本条**墓碑的确认 ETag。
      final tombPath = CloudLayout.tombstonePath(
        await env.codec.hashedName(created.snapshot.id),
      );
      await env.db.into(env.db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: tombPath,
              etag: const Value<String?>('tomb-e1'),
            ),
          );

      final purged = await env.port.purgeExpiredTrash(nowMs: nowMs);
      expect(purged.purged, <String>[created.snapshot.id]);
      expect(purged.skipped, isEmpty);
      expect(await env.count('entry'), 0);
      expect(await env.count('trash'), 0);
      final logs = await env.db.select(env.db.syncLogs).get();
      expect(logs.single.trigger, 'trash_retention');
      expect(logs.single.result, 'ok');
    });

    test('物理清空会一并清掉所有引用该 entry 的派生表，不留孤儿行', () async {
      final created = await env.gateway.writeEntry(
        EntryWrite.create(id: 'entry-orphans', title: '带派生数据'),
      );
      final id = created.snapshot.id;
      final db = env.db;

      // 直接插入各类派生行（这些表多数还没有业务写入口，但物理清理
      // 必须覆盖它们，否则会留下指向不存在条目的孤儿数据）。
      await db.into(db.credentials).insert(
            CredentialsCompanion.insert(id: id, username: const Value<String?>(null)),
          );
      await db.into(db.entryVecs).insert(
            EntryVecsCompanion.insert(
              entryId: id,
              chunkIdx: const Value<int>(0),
              modelId: 'model-a',
              dim: 768,
              vec: Uint8List.fromList(<int>[1, 2]),
              computedAt: _now,
            ),
          );
      await db.into(db.blobRefs).insert(
            BlobRefsCompanion.insert(
              entryId: id,
              blobHash: 'a' * 64,
              kind: 1,
              bytes: 10,
              createdAt: _now,
            ),
          );
      await db.into(db.linkChecks).insert(
            LinkChecksCompanion.insert(
              entryId: id,
              checkedAt: _now,
              result: 'ok',
            ),
          );
      await db.into(db.activities).insert(
            ActivitiesCompanion.insert(ts: _now, kind: 1, entryId: Value<String?>(id)),
          );
      await db.into(db.diaryIndexes).insert(
            DiaryIndexesCompanion.insert(
              date: '2026-11-08',
              userEntryId: Value<String?>(id),
              aiEntryId: const Value<String?>('entry-ai-kept'),
            ),
          );
      await db.into(db.entryCategories).insert(
            EntryCategoriesCompanion.insert(entryId: id, categoryId: 'cat-x'),
          );
      await db.into(db.entryTags).insert(
            EntryTagsCompanion.insert(entryId: id, tagId: 'tag-x'),
          );

      await env.gateway.writeEntry(EntryWrite.delete(id: id));
      await env.gateway.markApplied(
        (await env.gateway.pending()).map((row) => row.seq),
      );
      await db.into(db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: CloudLayout.tombstonePath(await env.codec.hashedName(id)),
              etag: const Value<String?>('tomb-e1'),
            ),
          );
      final report = await env.port.purgeExpiredTrash(nowMs: _now + 40 * _day.inMilliseconds);

      expect(report.purged, <String>[id]);
      for (final table in <String>[
        'entry', 'trash', 'entry_history', 'entry_category', 'entry_tag',
        'credential', 'entry_vec', 'blob_ref', 'link_check', 'activity',
      ]) {
        expect(await env.count(table), 0, reason: '$table 不能留下孤儿行');
      }
      final diary = await db.select(db.diaryIndexes).getSingle();
      expect(diary.userEntryId, isNull, reason: '只清空命中的列');
      expect(diary.aiEntryId, 'entry-ai-kept',
          reason: '同一天的 AI 日记索引不能被一起抹掉');
    });

    test('条目恢复后即使墓碑已确认也不清空', () async {
      final created = await env.gateway.writeEntry(
        EntryWrite.create(id: 'entry-restored', title: '会恢复'),
      );
      await env.gateway.writeEntry(
        EntryWrite.delete(id: created.snapshot.id),
      );
      await env.gateway.writeEntry(
        EntryWrite.restore(id: created.snapshot.id),
      );
      await env.gateway.markApplied(
        (await env.gateway.pending()).map((row) => row.seq),
      );
      final tombPath = CloudLayout.tombstonePath(
        await env.codec.hashedName(created.snapshot.id),
      );
      await env.db.into(env.db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: tombPath,
              etag: const Value<String?>('tomb-e1'),
            ),
          );
      // 恢复会清掉 trash 行；这里手工补一行，模拟「恢复与清理任务竞态」。
      final expireAt = _now + 30 * _day.inMilliseconds;
      await env.db.into(env.db.trashRows).insertOnConflictUpdate(
            TrashRowsCompanion.insert(
              entryId: created.snapshot.id,
              payload: Uint8List.fromList(utf8.encode('stale')),
              deletedAt: expireAt - 30 * _day.inMilliseconds,
              expireAt: expireAt,
            ),
          );

      final report = await env.port.purgeExpiredTrash(
        nowMs: expireAt + 1000,
      );

      expect(report.purged, isEmpty);
      expect(report.skipped[created.snapshot.id], contains('已恢复'));
      expect(await env.count('entry'), 1);
    });
  });

  group('墓碑 90 天 TTL 与本地 30 天分离判定', () {
    test('31 天的本地回收站可清理，但同时间点的云端墓碑必须保留', () async {
      final deletedAt = _now - 31 * _day.inMilliseconds;
      final nowMs = _now;
      final expireAt = deletedAt + 30 * _day.inMilliseconds;

      final localVerdict = evaluateTrashPurge(
        nowMs: nowMs,
        expireAt: expireAt,
        entryStillDeleted: true,
        tombstoneConfirmed: true,
        hasPendingOps: false,
        hasUnconfirmedDelete: false,
      );
      final plan = planTombstoneRetention(
        tombstones: <TombstoneRecord>[
          TombstoneRecord(path: '/vault/tombstones/a.enc', deletedAt: deletedAt),
          TombstoneRecord(
            path: '/vault/tombstones/b.enc',
            deletedAt: _now - 91 * _day.inMilliseconds,
          ),
        ],
        nowMs: nowMs,
      );

      expect(localVerdict.canPurge, isTrue);
      expect(plan.retainedPaths, <String>['/vault/tombstones/a.enc']);
      expect(plan.expiredPaths, <String>['/vault/tombstones/b.enc']);
    });

    test('云端墓碑 90 天到期清理不影响 sync_state 里的本地回收站判定',
        () async {
      const String tombPath = '/vault/tombstones/dddddddddddddddddddddddddddddddd.enc';
      final state = <String, String?>{tombPath: 'tomb-e1'};
      final plan = planTombstoneRetention(
        tombstones: <TombstoneRecord>[
          TombstoneRecord(
            path: tombPath,
            deletedAt: _now - 91 * _day.inMilliseconds,
          ),
        ],
        nowMs: _now,
      );

      expect(plan.expiredPaths, <String>[tombPath]);
      expect(isTombstoneConfirmed(state, tombPath), isTrue,
          reason: '删云端墓碑文件不等于抹掉本地已确认记录');
    });
  });
}
