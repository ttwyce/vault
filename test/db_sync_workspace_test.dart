import 'dart:math';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/vault_keys.dart';
import 'package:vault/core/identity/uuid_v7.dart';
import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/device_watermark.dart';
import 'package:vault/core/sync/encrypted_sync_codec.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/core/sync/sync_engine.dart';
import 'package:vault/core/sync/sync_state_machine.dart';
import 'package:vault/core/sync/sync_payloads.dart';
import 'package:vault/core/sync/webdav_backend.dart';
import 'package:vault/core/sync/change_diff.dart';
import 'package:vault/data/db/database_key.dart';
import 'package:vault/data/db/database_opener.dart';
import 'package:vault/data/db/tables/log_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/search/cjk_segmenter.dart';
import 'package:vault/data/sync/sync_workspace_store.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/write/entry_snapshot.dart';
import 'package:vault/data/write/write_gateway.dart';

/// #14 专用数据库集成测试。
///
/// 前面的 `sync_engine_test.dart` 只证明「内存编排顺序与零丢失规则」；
/// 这里验证的是**真实 drift 库**：`DbSyncWorkspaceStore.load()` 能不能把
/// `sync_state` / `device_watermark` / `oplog` 装成工作区，`run()` 能不能把
/// 一次同步的实体 / oplog / 同步状态 / 日志 / 水位一起落库，以及任何一步
/// 失败时整次事务是否真的不留半写状态。
///
/// 载荷用真实 `EncryptedSyncPayloadCodec`：DB 里的 oplog payload 就是
/// `ItemEnvelope` 加密字节，workspace 必须与它用同一把密钥、同一套文件名，
/// 否则测出来的「能跑」与生产路径不是一回事。
const String _vaultId = 'vault-db-test';
const String _self = 'devA';
const String _other = 'devB';

class _File {
  const _File(this.bytes, this.etag);

  final List<int> bytes;
  final String etag;
}

/// 内存 WebDAV。只实现 `SyncEngine` 会用到的那几个动作，条件写语义与
/// `sync_engine_test.dart` 的 fake 一致：无条件 PUT 在接口层无法表达。
class _FakeBackend implements WebDavBackend {
  _FakeBackend({
    required this.files,
    required this.listings,
    required this.delta,
  });

  final Map<String, _File> files;
  final Map<String, List<WebDavListing>> listings;
  final SyncCollectionDelta delta;

  final List<String> calls = <String>[];
  int _etagCounter = 500;

  @override
  Future<Map<String, String>> options(String path) async {
    calls.add('OPTIONS $path');
    return <String, String>{
      'DAV': '1, 3, sync-collection',
      'Allow': 'OPTIONS, PROPFIND, REPORT, GET, PUT, DELETE',
      'ETag': '"vault-root"',
    };
  }

  @override
  Future<List<WebDavListing>> propfind(String path, {int depth = 1}) async {
    calls.add('PROPFIND $path');
    return listings[path] ?? const <WebDavListing>[];
  }

  @override
  Future<SyncCollectionDelta> reportSyncCollection(
    String path, {
    String? syncToken,
  }) async {
    calls.add('REPORT $path');
    return delta;
  }

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
    calls.add('PUT $path ${condition.headerName}: ${condition.headerValue}');
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
    return WebDavPutResult(
      etag: etag,
      statusCode: current == null ? 201 : 204,
    );
  }

  @override
  Future<void> delete(String path, {required String ifMatch}) async {
    calls.add('DELETE $path');
    final current = files[path];
    if (current == null) {
      throw WebDavException(statusCode: 404, method: 'DELETE', path: path);
    }
    if (ifMatch != '*' && current.etag != ifMatch) {
      throw WebDavPreconditionFailed(method: 'DELETE', path: path);
    }
    files.remove(path);
  }

  @override
  Future<void> mkcol(String path) async {
    calls.add('MKCOL $path');
  }
}

/// 可变假时钟：让 gateway / clock / store / codec 全读同一份毫秒数。
class _FakeClock {
  _FakeClock(this.millis);

  int millis;

  int call() => millis;
}

class _Env {
  _Env({
    required this.opener,
    required this.db,
    required this.keys,
    required this.fakeClock,
    required this.codec,
  }) : clock = HlcClock(node: _self, now: fakeClock.call),
       uuid = UuidV7(random: Random(23), now: fakeClock.call) {
    gateway = WriteGateway(
      db: db,
      keys: keys,
      clock: clock,
      deviceId: _self,
      now: fakeClock.call,
      uuid: uuid,
    );
  }

  final VaultDatabaseOpener opener;
  final VaultDatabase db;
  final VaultKeys keys;
  final _FakeClock fakeClock;
  final HlcClock clock;
  final UuidV7 uuid;
  final EncryptedSyncPayloadCodec codec;

  /// 单一网关实例，与 store / 测试断言共享同一把 clock 与 uuid。
  late final WriteGateway gateway;

  int get nowMillis => fakeClock.millis;

  DbSyncWorkspaceStore store() => DbSyncWorkspaceStore(
        db: db,
        gateway: gateway,
        codec: codec,
        clock: clock,
        uuid: uuid,
        deviceId: _self,
        vaultId: _vaultId,
        schema: 1,
        now: fakeClock.call,
      );

  /// 换一个「索引写入一定失败」的网关，用来在事务中段制造真实失败。
  /// 与正常网关共享同一个 db / keys / clock，失败点落在 oplog 与实体
  /// 都已写入之后 —— 这是验证事务边界最有说服力的位置。
  WriteGateway get brokenGateway => WriteGateway(
        db: db,
        keys: keys,
        clock: clock,
        deviceId: _self,
        now: fakeClock.call,
        uuid: uuid,
        segmenter: (String _) => throw StateError('索引写入故意失败'),
      );

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT count(*) AS c FROM $table;')
        .getSingle();
    return row.read<int>('c');
  }
}

Future<_Env> _createEnv() async {
  final opener = VaultDatabaseOpener(
    key: DatabaseKey.random(Random(19)),
    inMemory: true,
  );
  final db = await opener.open();
  final keys = VaultKeys.generate();
  return _Env(
    opener: opener,
    db: db,
    keys: keys,
    fakeClock: _FakeClock(1731052800000),
    codec: EncryptedSyncPayloadCodec(keys, random: Random(29)),
  );
}

/// 合法快照。hash 由计算得出，不能被手工写死。
EntrySnapshot _snapshot({
  required String id,
  String title = '远端条目',
  String body = '这是从另一台设备同步过来的正文',
  int rev = 1,
  bool deleted = false,
}) {
  const int kind = 1;
  return EntrySnapshot(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: 1731052800000,
    updatedAt: 1731052800000,
    hlc: Hlc(millis: 1731052800000, counter: 0, node: _other).encode(),
    rev: rev,
    contentHash: EntrySnapshot.computeContentHash(
      kind: kind,
      title: title,
      body: body,
    ),
    deleted: deleted,
  );
}

/// 直接构造一次同步结果，用于把「坏 content_hash」与隔离载荷喂给
/// `applySyncRun()`，而不必先跑一遍网络编排。
SyncRunResult _result({
  required SyncWorkspace workspace,
  Map<String, EntrySnapshot>? entries,
  Map<String, String?>? syncState,
  Map<String, List<int>>? quarantinePayloads,
  Set<String>? appliedOps,
  Set<String>? cloudAppliedEntryIds,
  bool watermarkPublished = false,
  String? nextHlc,
  String outcomeReason = '测试构造的同步结果',
}) {
  return SyncRunResult(
    skipped: false,
    state: const SyncState(SyncPhase.idle),
    phases: const <SyncPhase>[SyncPhase.idle],
    requestLog: const <String>[],
    pullOrder: const <String>[],
    requestCount: 0,
    conflicts: 0,
    budgetExceeded: false,
    watermarkPublished: watermarkPublished,
    entries: entries ?? <String, EntrySnapshot>{},
    syncState: syncState ?? <String, String?>{},
    deletedEntries: const <String>{},
    quarantined: const <String>{},
    quarantinePayloads: quarantinePayloads ?? const <String, List<int>>{},
    nextHlc: nextHlc ?? workspace.nextHlc,
    pushedPaths: const <String>[],
    conflictCopyIds: const <String>{},
    appliedOps: appliedOps ?? const <String>{},
    cloudAppliedEntryIds: cloudAppliedEntryIds ?? const <String>{},
    tombstonesWritten: const <String>{},
    preconditionAttempts: const <String, int>{},
    reason: outcomeReason,
    diff: SyncDiff.empty,
  );
}

void main() {
  late _Env env;

  setUp(() async {
    env = await _createEnv();
  });

  tearDown(() async {
    env.keys.destroy();
    await env.opener.close();
  });

  // -------------------------------------------------------------------------
  group('DbSyncWorkspaceStore.load', () {
    test('sync_state 与 device_watermark 装成 syncState / deviceEtags / 水位',
        () async {
      final db = env.db;
      final otherHlc = Hlc(millis: 1731052700000, counter: 0, node: _other);
      final otherPath = CloudLayout.devicePath(_other);
      final itemPath = CloudLayout.itemPath(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.enc',
      );

      await db.into(db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: otherPath,
              etag: const Value<String?>('dev-e1'),
              updatedAt: const Value<int?>(1731052800000),
            ),
          );
      await db.into(db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: itemPath,
              etag: const Value<String?>('item-e1'),
            ),
          );
      await db.into(db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: CloudLayout.metaPath,
              etag: const Value<String?>('meta-e1'),
            ),
          );
      await db.into(db.deviceWatermarks).insert(
            DeviceWatermarksCompanion.insert(
              deviceId: _other,
              maxHlc: Value<String?>(otherHlc.encode()),
              lastSeen: const Value<int?>(1731052700000),
            ),
          );

      final workspace = await env.store().load();

      expect(workspace.selfDeviceId, _self);
      expect(workspace.vaultId, _vaultId);
      expect(workspace.schema, 1);
      expect(workspace.syncState[otherPath], 'dev-e1');
      expect(workspace.syncState[itemPath], 'item-e1');
      expect(workspace.syncState[CloudLayout.metaPath], 'meta-e1');
      expect(workspace.deviceEtags, <String, String>{_other: 'dev-e1'});
      expect(workspace.localWatermarks[_other], otherHlc);
      expect(workspace.syncToken, isNull);
      expect(Hlc.tryParse(workspace.nextHlc), isNotNull);
    });

    test('本地 entry 与待推 oplog 装成 pendingOps，rawPayload 就是信封字节',
        () async {
      final created = await env.gateway.writeEntry(
        EntryWrite.create(id: 'entry-local', title: '本地笔记', body: '正文'),
      );
      final name = await env.codec.hashedName('entry-local');
      final pendingRow = await (env.db.select(env.db.oplogs)
            ..where((t) => t.seq.equals(created.oplogSeq)))
          .getSingle();

      final workspace = await env.store().load();

      expect(workspace.entries.containsKey(name), isTrue);
      expect(workspace.entries[name]!.title, '本地笔记');
      expect(workspace.pendingOps, hasLength(1));
      final op = workspace.pendingOps.single;
      expect(op.id, 'oplog:${created.oplogSeq}');
      expect(op.kind, SyncPendingOpKind.upsert);
      expect(op.entity, SyncEntity.entry);
      expect(op.entryId, 'entry-local');
      expect(op.hashedName, name);
      expect(op.snapshot!.rev, 1);
      expect(op.baseRev, 0);
      expect(
        List<int>.from(op.rawPayload!),
        pendingRow.payload!.toList(),
        reason: 'oplog 信封字节必须原样 PUT，不重新加密',
      );
    });

    test('T01：超过一批的待推 oplog 只装 50 条，剩余按 seq 留到下一轮',
        () async {
      // 60 条本地新建 = 60 条 applied=0 的 oplog。
      for (var i = 0; i < 60; i++) {
        await env.gateway.writeEntry(
          EntryWrite.create(id: 'entry-batch-$i', title: '第 $i 条'),
        );
      }
      final first = await env.store().load();
      expect(first.pendingOps, hasLength(50));
      expect(first.pendingOps.first.entryId, 'entry-batch-0');
      expect(first.pendingOps.last.entryId, 'entry-batch-49');

      // 模拟第一轮推送成功：把这 50 条标为已应用。
      await env.gateway.markApplied(
        first.pendingOps.map(
          (SyncPendingOp op) =>
              int.parse(op.id.substring('oplog:'.length)),
        ),
      );
      final second = await env.store().load();
      expect(second.pendingOps, hasLength(10));
      expect(second.pendingOps.first.entryId, 'entry-batch-50');
      expect(second.pendingOps.last.entryId, 'entry-batch-59');
      expect(
        await env.gateway.pendingCount(),
        10,
        reason: '未推的 oplog 必须保持 applied=0，天然续跑',
      );
    });

    test('已应用 oplog 装成 baseRevs / baseSnapshots，坏 oplog 被跳过',
        () async {
      final created = await env.gateway.writeEntry(
        EntryWrite.create(id: 'entry-base', title: 'v1'),
      );
      await env.gateway.markApplied(<int>[created.oplogSeq]);
      env.fakeClock.millis += 1000;
      await env.gateway.writeEntry(
        EntryWrite.update(id: 'entry-base', title: 'v2', body: '改过正文'),
      );

      // 一条已应用但载荷损坏的 oplog：load() 必须隔离它而不是整轮崩掉。
      await env.db.into(env.db.oplogs).insert(
            OplogsCompanion.insert(
              hlc: Hlc(millis: 1, counter: 0, node: _other).encode(),
              deviceId: _other,
              entity: SyncEntity.entry,
              entityId: 'entry-broken',
              op: OplogOp.create.code,
              payload: Value<Uint8List>(Uint8List.fromList(<int>[1, 2, 3])),
              applied: const Value<int>(1),
              createdAt: 1,
            ),
          );

      final workspace = await env.store().load();

      expect(workspace.baseRevs['entry-base'], 1);
      expect(workspace.baseSnapshots['entry-base']?.rev, 1);
      expect(workspace.baseSnapshots['entry-base']?.title, 'v1');
      expect(workspace.baseRevs.containsKey('entry-broken'), isFalse);
      expect(workspace.pendingOps, hasLength(1));
      expect(workspace.pendingOps.single.baseRev, 1);
      expect(workspace.pendingOps.single.snapshot!.rev, 2);
    });
  });

  // -------------------------------------------------------------------------
  group('DbSyncWorkspaceStore.run（fake WebDAV 端到端）', () {
    Future<_FakeBackend> backend({
      required List<EntrySnapshot> remoteEntries,
      Map<String, List<int>> corruptFiles = const <String, List<int>>{},
      Set<String> deletedPaths = const <String>{},
    }) async {
      final codec = env.codec;
      final delta = SyncCollectionDelta(
        changed: <String, String?>{},
        deleted: deletedPaths,
        syncToken: 'token-2',
      );
      final files = <String, _File>{
        CloudLayout.metaPath: _File(
          await codec.encodeMeta(
            const SyncVaultMeta(vaultId: _vaultId, schema: 1),
          ),
          'meta-e1',
        ),
        CloudLayout.devicePath(_other): _File(
          await codec.encodeWatermark(
            DeviceWatermark(
              deviceId: _other,
              maxHlc: Hlc(millis: 1731052900000, counter: 0, node: _other),
              lastSeen: 1731052900000,
              schema: 1,
            ),
          ),
          'dev-e1',
        ),
      };
      final listings = <String, List<WebDavListing>>{
        CloudLayout.devicesDir: <WebDavListing>[
          WebDavListing(
            path: CloudLayout.devicePath(_other),
            etag: 'dev-e1',
          ),
        ],
        '${CloudLayout.root}/tombstones': const <WebDavListing>[],
        for (var i = 0; i < CloudLayout.shardCount; i++)
          CloudLayout.itemsDir(i.toRadixString(16)): const <WebDavListing>[],
      };

      for (final snapshot in remoteEntries) {
        final name = await codec.hashedName(snapshot.id);
        final path = CloudLayout.itemPath(name);
        files[path] = _File(await codec.encodeEntry(snapshot), 'item-e1');
        delta.changed[path] = 'item-e1';
      }
      for (final entry in corruptFiles.entries) {
        files[entry.key] = _File(List<int>.from(entry.value), 'bad-e1');
        delta.changed[entry.key] = 'bad-e1';
      }

      return _FakeBackend(files: files, listings: listings, delta: delta);
    }

    test('一次同步把 entry / oplog / sync_state / sync_log / 水位一起落库',
        () async {
      final remote = _snapshot(id: 'entry-remote');
      final fake = await backend(remoteEntries: <EntrySnapshot>[remote]);
      final name = await env.codec.hashedName(remote.id);
      final itemPath = CloudLayout.itemPath(name);
      final store = env.store();
      final engine = SyncEngine(backend: fake, codec: env.codec);

      final result = await store.run(engine, trigger: 'integration');

      expect(result.skipped, isFalse);
      expect(result.isIdle, isTrue);
      expect(result.isFailed, isFalse);
      expect(result.watermarkPublished, isTrue);
      expect(result.cloudAppliedEntryIds, contains(remote.id));
      expect(result.pullOrder, <String>['tombstones', 'meta', 'entries']);

      // 实体与索引
      final row = await (env.db.select(env.db.entries)
            ..where((t) => t.id.equals(remote.id)))
          .getSingle();
      expect(row.title, remote.title);
      expect(row.rev, 1);
      expect(row.deleted, 0);
      expect(
        await env.db.searchEntryIds(CjkSegmenter.matchQuery('同步过来')),
        contains(remote.id),
        reason: 'FTS 索引必须与实体在同一个事务里落地',
      );

      // 远端已确认的快照必须直接标 applied=1，否则下次会重复推送
      final ops = await env.db.select(env.db.oplogs).get();
      expect(ops, hasLength(1));
      expect(ops.single.entity, SyncEntity.entry);
      expect(ops.single.entityId, remote.id);
      expect(ops.single.op, OplogOp.create.code);
      expect(ops.single.applied, 1);
      expect(await env.gateway.pendingCount(), 0);

      // 同步状态与日志
      final stateRows = await env.db.select(env.db.syncStates).get();
      final stateByPath = <String, String?>{
        for (final state in stateRows) state.path: state.etag,
      };
      expect(stateByPath[itemPath], 'item-e1');
      expect(stateByPath[CloudLayout.metaPath], 'meta-e1');
      final selfPath = CloudLayout.devicePath(_self);
      expect(stateByPath.containsKey(selfPath), isTrue);
      expect(stateByPath[selfPath], isNotNull);

      final logs = await env.db.select(env.db.syncLogs).get();
      expect(logs, hasLength(1));
      expect(logs.single.trigger, 'integration');
      expect(logs.single.result, 'ok');
      expect(logs.single.pulled, 1);

      // 发布水位后本地 device_watermark 必须持久化（重启后 HLC 不倒退）
      final watermark = await (env.db.select(env.db.deviceWatermarks)
            ..where((t) => t.deviceId.equals(_self)))
          .getSingle();
      expect(watermark.maxHlc, isNotNull);
      expect(Hlc.tryParse(watermark.maxHlc!), isNotNull);
    });

    test('损坏载荷被隔离进 sync_quarantine，原始字节完整且不覆盖本地',
        () async {
      final remote = _snapshot(id: 'entry-good');
      const String badName = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.enc';
      final badPath = CloudLayout.itemPath(badName);
      final badBytes = <int>[0, 1, 2, 3, 255, 7];
      final fake = await backend(
        remoteEntries: <EntrySnapshot>[remote],
        corruptFiles: <String, List<int>>{badPath: badBytes},
      );
      final store = env.store();

      final result = await store.run(
        SyncEngine(backend: fake, codec: env.codec),
      );

      expect(result.quarantined, contains(badPath));
      expect(result.quarantinePayloads[badPath], badBytes);
      final quarantined = await env.gateway.quarantine();
      expect(quarantined, hasLength(1));
      expect(quarantined.single.path, badPath);
      expect(quarantined.single.bytes.toList(), badBytes);
      expect(quarantined.single.reason, contains('E_CORRUPT'));
      expect(quarantined.single.createdAt, env.nowMillis);

      // 好条目照常落库，坏文件没有生成幽灵实体
      final ids = (await env.db.select(env.db.entries).get())
          .map((row) => row.id)
          .toList();
      expect(ids, <String>[remote.id]);
    });

    test('远端 item 文件消失：软删进回收站、FTS 移除、sync_state 清干净',
        () async {
      // 先在本地写一条，再假装它上次同步已被云端确认（applied=1），
      // 这样 load() 会给出 baseRev，编排器判定「本地未变 → 规则 7 软删」。
      final created = await env.gateway.writeEntry(
        EntryWrite.create(id: 'entry-vanished', title: '会被删掉', body: '正文'),
      );
      await env.gateway.markApplied(<int>[created.oplogSeq]);
      final name = await env.codec.hashedName(created.snapshot.id);
      final itemPath = CloudLayout.itemPath(name);
      await env.db.into(env.db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: itemPath,
              etag: const Value<String?>('gone-e1'),
            ),
          );
      final fake = await backend(
        remoteEntries: const <EntrySnapshot>[],
        deletedPaths: <String>{itemPath},
      );

      final result = await env.store().run(
            SyncEngine(backend: fake, codec: env.codec),
            trigger: 'integration',
          );

      expect(result.isFailed, isFalse);
      expect(result.diff.deleted, <String>{itemPath});
      final row = await (env.db.select(env.db.entries)
            ..where((t) => t.id.equals('entry-vanished')))
          .getSingle();
      expect(row.deleted, 1);
      expect(row.deletedAt, isNotNull);
      expect(await env.count('trash'), 1,
          reason: '规则 7 要求软删进回收站，不是物理删除');
      expect(
        await env.db.searchEntryIds(CjkSegmenter.matchQuery('会被删掉')),
        isEmpty,
        reason: '软删后 FTS 索引必须移除',
      );
      expect(
        (await env.db.select(env.db.syncStates).get())
            .map((row) => row.path)
            .contains(itemPath),
        isFalse,
        reason: '陈旧 path → ETag 不能留到下一轮',
      );
      final ops = await (env.db.select(env.db.oplogs)
            ..where((t) => t.entityId.equals('entry-vanished')))
          .get();
      expect(ops.length, 2, reason: '原 create + 同步产生的 delete');
      expect(ops.last.op, OplogOp.delete.code);
      expect(ops.last.applied, 1, reason: '远端已确认的软删不该再被推回去');
    });

    test('单飞锁跳过的结果不写 sync_log，也不动 sync_state', () async {
      final store = env.store();
      final workspace = await store.load();
      final before = await env.count('sync_log');

      await store.commit(
        SyncRunResult.skipped(workspace),
        trigger: 'skipped',
      );

      expect(await env.count('sync_log'), before);
      expect(await env.count('sync_state'), 0);
    });
  });

  // -------------------------------------------------------------------------
  group('applySyncRun 原子性', () {
    /// 预置一份「已经存在的本地状态」，让回滚前后可以逐表比对。
    Future<EntryWriteResult> seed() async {
      final created = await env.gateway.writeEntry(
        EntryWrite.create(id: 'entry-existing', title: '原文', body: '原始正文'),
      );
      await env.db.into(env.db.syncStates).insert(
            SyncStatesCompanion.insert(
              path: '/vault/items/0/old.enc',
              etag: const Value<String?>('old-etag'),
            ),
          );
      await env.db.into(env.db.syncLogs).insert(
            SyncLogsCompanion.insert(
              trigger: const Value<String?>('seed'),
              result: const Value<String?>('ok'),
            ),
          );
      return created;
    }

    test('坏 content_hash 的 SyncRunResult 整次拒绝，预置状态一字节不变',
        () async {
      final created = await seed();
      final workspace = await env.store().load();
      final name = await env.codec.hashedName('entry-existing');
      final broken = created.snapshot.copyWith(body: '篡改后的正文');

      final result = _result(
        workspace: workspace,
        entries: <String, EntrySnapshot>{name: broken},
        syncState: <String, String?>{'/vault/items/1/new.enc': 'new-etag'},
        quarantinePayloads: <String, List<int>>{
          '/vault/items/2/bad.enc': <int>[9, 8, 7],
        },
        appliedOps: <String>{'oplog:${created.oplogSeq}'},
        watermarkPublished: true,
        nextHlc: Hlc(millis: 1731052999999, counter: 0, node: _self).encode(),
      );

      await expectLater(
        env.gateway.applySyncRun(result, trigger: 'bad-hash'),
        throwsA(
          isA<WriteException>().having(
            (WriteException e) => e.code,
            'code',
            'invalid',
          ),
        ),
      );

      final entry = await (env.db.select(env.db.entries)
            ..where((t) => t.id.equals('entry-existing')))
          .getSingle();
      expect(entry.body, '原始正文', reason: '坏快照不能覆盖本地');
      expect(await env.count('entry'), 1);

      final oplog = await (env.db.select(env.db.oplogs)
            ..where((t) => t.seq.equals(created.oplogSeq)))
          .getSingle();
      expect(oplog.applied, 0, reason: 'appliedOps 不能部分生效');
      expect(await env.count('oplog'), 1);

      final stateRows = await env.db.select(env.db.syncStates).get();
      expect(stateRows, hasLength(1));
      expect(stateRows.single.path, '/vault/items/0/old.enc');
      expect(stateRows.single.etag, 'old-etag');
      expect(await env.count('sync_log'), 1);
      expect(await env.gateway.quarantine(), isEmpty);
    });

    test('事务中段失败：oplog / entry / sync_state / sync_log / 隔离区全部回滚',
        () async {
      final created = await seed();
      final workspace = await env.store().load();
      final incoming = _snapshot(id: 'entry-incoming');
      final name = await env.codec.hashedName(incoming.id);
      final watermarkBefore = await (env.db.select(env.db.deviceWatermarks)
            ..where((t) => t.deviceId.equals(_self)))
          .getSingle();

      final result = _result(
        workspace: workspace,
        entries: <String, EntrySnapshot>{name: incoming},
        syncState: <String, String?>{'/vault/items/1/incoming.enc': 'new-etag'},
        quarantinePayloads: <String, List<int>>{
          '/vault/items/2/bad.enc': <int>[4, 5, 6],
        },
        cloudAppliedEntryIds: <String>{incoming.id},
        watermarkPublished: true,
      );

      // brokenGateway 在 oplog 已写、entity 已改之后的索引阶段抛错。
      await expectLater(
        env.brokenGateway.applySyncRun(result, trigger: 'mid-failure'),
        throwsA(isA<StateError>()),
      );

      expect(await env.count('entry'), 1, reason: '实体必须回滚');
      expect(
        (await env.db.select(env.db.entries).get()).single.id,
        'entry-existing',
      );
      expect(await env.count('oplog'), 1, reason: '新 oplog 必须回滚');
      expect(
        (await (env.db.select(env.db.oplogs)
              ..where((t) => t.seq.equals(created.oplogSeq)))
            .getSingle())
            .applied,
        0,
      );
      final stateRows = await env.db.select(env.db.syncStates).get();
      expect(stateRows, hasLength(1));
      expect(stateRows.single.path, '/vault/items/0/old.enc');
      expect(await env.count('sync_log'), 1, reason: '不能把失败记成一次同步');
      expect(await env.gateway.quarantine(), isEmpty);
      final watermarkAfter = await (env.db.select(env.db.deviceWatermarks)
            ..where((t) => t.deviceId.equals(_self)))
          .getSingle();
      expect(watermarkAfter.maxHlc, watermarkBefore.maxHlc);
    });

    test('quarantinePayloads 正常写入隔离区，reason 标明损坏原因', () async {
      await seed();
      final workspace = await env.store().load();
      final badPath = CloudLayout.itemPath(
        'cccccccccccccccccccccccccccccccc.enc',
      );
      final bytes = <int>[10, 20, 30, 40];

      await env.gateway.applySyncRun(
        _result(
          workspace: workspace,
          quarantinePayloads: <String, List<int>>{badPath: bytes},
        ),
        trigger: 'quarantine',
      );

      final quarantined = await env.gateway.quarantine();
      expect(quarantined, hasLength(1));
      expect(quarantined.single.path, badPath);
      expect(quarantined.single.bytes.toList(), bytes);
      expect(quarantined.single.reason, contains('不覆盖本地'));
    });
  });

  // -------------------------------------------------------------------------
  group('#14 预备的 taxonomy 落库入口', () {
    test('recordEntityPushes 把 oplog 标为已推并记录 ETag', () async {
      final created = await env.gateway.writeCategory(
        CategoryWrite.create(name: '工作'),
      );
      const String path = '/vault/entities/3/category.enc';

      await env.gateway.recordEntityPushes(<SyncedOplogPush>[
        SyncedOplogPush(
          oplogSeq: created.oplogSeq,
          path: path,
          etag: 'entity-e1',
        ),
      ]);

      final op = await (env.db.select(env.db.oplogs)
            ..where((t) => t.seq.equals(created.oplogSeq)))
          .getSingle();
      expect(op.applied, 1);
      final state = await (env.db.select(env.db.syncStates)
            ..where((t) => t.path.equals(path)))
          .getSingle();
      expect(state.etag, 'entity-e1');
      final logs = await env.db.select(env.db.syncLogs).get();
      expect(logs.single.trigger, 'entity_push');
      expect(logs.single.result, 'ok');
      expect(logs.single.pushed, 1);
    });

    test('applyRemoteTaxonomySnapshots 落库且远端 oplog 直接 applied=1',
        () async {
      final snapshot = TaxonomySnapshot(
        entity: SyncEntity.category,
        id: 'cat-remote',
        rev: 2,
        hlc: Hlc(millis: 1731052800000, counter: 0, node: _other).encode(),
        updatedAt: 1731052800000,
        deleted: false,
        fields: <String, Object?>{
          'name': '远端分类',
          'kind': 1,
          'parent_id': null,
          'sort_order': 0,
        },
      );
      final path = CloudLayout.entityItemPath(
        await env.codec.hashedEntityName(snapshot.entity, snapshot.id),
      );

      await env.gateway.applyRemoteTaxonomySnapshots(<RemoteTaxonomyFile>[
        RemoteTaxonomyFile(
          path: path,
          etag: 'entity-e1',
          snapshot: snapshot,
        ),
      ]);

      final category = await (env.db.select(env.db.categories)
            ..where((t) => t.id.equals(snapshot.id)))
          .getSingle();
      expect(category.name, '远端分类');
      expect(category.deleted, 0);
      final op = await (env.db.select(env.db.oplogs)
            ..where((t) => t.entityId.equals(snapshot.id)))
          .getSingle();
      expect(op.entity, SyncEntity.category);
      expect(op.applied, 1, reason: '远端已确认，不能再被推回去');
      final state = await (env.db.select(env.db.syncStates)
            ..where((t) => t.path.equals(path)))
          .getSingle();
      expect(state.etag, 'entity-e1');
    });

    test('同 rev 或更旧的远端 taxonomy 不重复写 oplog', () async {
      final snapshot = TaxonomySnapshot(
        entity: SyncEntity.tag,
        id: 'tag-remote',
        rev: 3,
        hlc: Hlc(millis: 1731052800000, counter: 0, node: _other).encode(),
        updatedAt: 1731052800000,
        deleted: false,
        fields: <String, Object?>{'name': '同步'},
      );
      final path = CloudLayout.entityItemPath(
        await env.codec.hashedEntityName(snapshot.entity, snapshot.id),
      );
      final file = RemoteTaxonomyFile(
        path: path,
        etag: 'entity-e1',
        snapshot: snapshot,
      );

      await env.gateway.applyRemoteTaxonomySnapshots(<RemoteTaxonomyFile>[file]);
      final afterFirst = await env.count('oplog');
      await env.gateway.applyRemoteTaxonomySnapshots(<RemoteTaxonomyFile>[file]);
      final afterSecond = await env.count('oplog');

      expect(afterFirst, 1);
      expect(afterSecond, afterFirst, reason: '重复拉取不能生成重复 oplog');
    });
  });
}
