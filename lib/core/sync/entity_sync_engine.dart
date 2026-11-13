/// taxonomy 独立同步通道（docs/20 §5 / docs/11 §2.4）。
///
/// category / tag / entry_taxonomy 不进 `/vault/items/`：正文同步器会把它们
/// 误当成 `EntrySnapshot` 去跑 merge3。这里只做三件事：
///
/// 1. 把 `oplog` 里 `applied=0` 的 taxonomy 记录按 seq 顺序条件推送到
///    `CloudLayout.entityItemPath()`，成功后交给 [WriteGateway] 标记已推；
/// 2. 列举 16 个 `/vault/entities/<shard>/` 分片，用 ETag diff 找到新增 /
///    修改文件，解密后整体交给 [WriteGateway] 在一个事务里落库；
/// 3. 损坏载荷写进同一个隔离区，绝不覆盖本地。
///
/// **不跑 merge3**：taxonomy 是 LWW 实体，`WriteGateway` 里用 rev 判定先后，
/// 同 rev 或更旧的远端直接跳过。所有 PUT/DELETE 都必须带条件写，接口层
/// 不存在无条件 PUT 的调用形态。
library;

import '../../data/db/tables/log_tables.dart';
import '../../data/write/write_gateway.dart';
import 'change_diff.dart';
import 'cloud_layout.dart';
import 'sync_payloads.dart';
import 'sync_runtime.dart';
import 'sync_state_machine.dart';
import 'webdav_backend.dart';

/// 白名单：只有这四类实体允许走 `/vault/entities/`。
const Set<String> kSyncEntityTaxonomy = <String>{
  SyncEntity.category,
  SyncEntity.tag,
  SyncEntity.entryTaxonomy,
  SyncEntity.categoryFieldTemplate,
};

bool isSyncEntityTaxonomy(String entity) =>
    kSyncEntityTaxonomy.contains(entity);

/// 一轮独立通道的结果。requestCount 用于诊断与请求预算对账。
class EntitySyncRunResult {
  const EntitySyncRunResult({
    required this.skipped,
    required this.pushedPaths,
    required this.pulledPaths,
    required this.quarantinedPaths,
    required this.quarantinePayloads,
    required this.requestCount,
    required this.requestLog,
    required this.errorCode,
    required this.reason,
    required this.syncState,
    required this.budgetExceeded,
  });

  factory EntitySyncRunResult.skipped() => const EntitySyncRunResult(
        skipped: true,
        pushedPaths: <String>[],
        pulledPaths: <String>[],
        quarantinedPaths: <String>{},
        quarantinePayloads: <String, List<int>>{},
        requestCount: 0,
        requestLog: <String>[],
        errorCode: null,
        reason: '单飞锁被占用：本次跳过，不排队',
        syncState: <String, String?>{},
        budgetExceeded: false,
      );

  final bool skipped;
  final List<String> pushedPaths;
  final List<String> pulledPaths;
  final Set<String> quarantinedPaths;
  final Map<String, List<int>> quarantinePayloads;
  final int requestCount;
  final List<String> requestLog;
  final SyncErrorCode? errorCode;
  final String reason;
  final Map<String, String?> syncState;

  /// 本轮有请求因预算不足没发出去。调度器据此保守跳过清理阶段。
  final bool budgetExceeded;

  bool get isFailed => errorCode != null;
  bool get isComplete =>
      !skipped && !isFailed && !budgetExceeded;
}

/// 本地 outbox 里的一条 taxonomy 操作：oplog 信封字节原样 PUT。
class EntityPendingOp {
  const EntityPendingOp({
    required this.seq,
    required this.entity,
    required this.entityId,
    required this.payload,
  });

  final int seq;
  final String entity;
  final String entityId;
  final List<int> payload;
}

/// 独立通道与本地库之间的边界。真实实现是 [DbEntitySyncPort]。
abstract interface class EntitySyncPort {
  /// 单轮待推上限，与正文通道的 50 条分批保持一致。
  static const int pendingBatchSize = 50;

  Future<List<EntityPendingOp>> pending({
    int limit = pendingBatchSize,
  });

  /// path → 上次见到的 ETag。
  Future<Map<String, String?>> syncState();

  /// 推送成功后：写 oplog applied=1、记录 path → etag、写 sync_log。
  Future<void> commitPushes(Iterable<SyncedOplogPush> pushes);

  /// 拉取成功后：实体 / oplog / sync_state / sync_log / 隔离区同一事务。
  Future<void> commitPulls(
    Iterable<RemoteTaxonomyFile> files,
    Map<String, String?> entityState,
    Map<String, List<int>> quarantinePayloads,
  );

  /// 没有可落库文件、只有坏载荷时单独写隔离区。
  Future<void> commitQuarantine(Map<String, List<int>> payloads);
}

/// taxonomy 编排器。`SyncEngine`（正文）与它各自持有单飞锁，互不阻塞：
/// 锁忙时直接跳过本轮，不排队（docs/README D24）。
class EntitySyncEngine {
  EntitySyncEngine({
    required this.backend,
    required this.codec,
    required this.port,
    this.budgetLimit = 200,
    SingleFlightLock? lock,
  }) : _lock = lock ?? SingleFlightLock();

  final WebDavBackend backend;
  final SyncEntityPayloadCodec codec;
  final EntitySyncPort port;
  final int budgetLimit;
  final SingleFlightLock _lock;

  Future<EntitySyncRunResult> run() {
    return _lock.run(
      _run,
      skipped: EntitySyncRunResult.skipped(),
    );
  }

  Future<EntitySyncRunResult> _run() async {
    final budget = RequestBudget(limit: budgetLimit);
    final pushedPaths = <String>[];
    final pulledPaths = <String>[];
    final quarantined = <String>{};
    final quarantinePayloads = <String, List<int>>{};
    final requestLog = <String>[];
    final state = <String, String?>{};
    var reason = 'taxonomy 同步完成';
    var budgetExceeded = false;

    Future<T?> request<T>(String label, Future<T> Function() call) async {
      if (!budget.tryConsume()) {
        budgetExceeded = true;
        return null;
      }
      requestLog.add(label);
      return await call();
    }

    EntitySyncRunResult finish({
      SyncErrorCode? errorCode,
      String? failureReason,
    }) =>
        EntitySyncRunResult(
          skipped: false,
          pushedPaths: List<String>.unmodifiable(pushedPaths),
          pulledPaths: List<String>.unmodifiable(pulledPaths),
          quarantinedPaths: Set<String>.unmodifiable(quarantined),
          quarantinePayloads: Map<String, List<int>>.unmodifiable(
            <String, List<int>>{
              for (final entry in quarantinePayloads.entries)
                entry.key: List<int>.unmodifiable(entry.value),
            },
          ),
          requestCount: budget.used,
          requestLog: List<String>.unmodifiable(requestLog),
          errorCode: errorCode,
          reason: failureReason ?? reason,
          syncState: Map<String, String?>.unmodifiable(state),
          budgetExceeded: budgetExceeded,
        );

    // -----------------------------------------------------------------------
    // PUSH：先推本地 outbox，再拉远端。推送与拉取用同一份 sync_state，
    // 避免「刚 PUT 上去又被自己的 ETag diff 当成远端新增」。
    // -----------------------------------------------------------------------
    state.addAll(await port.syncState());
    final pending = await port.pending(limit: EntitySyncPort.pendingBatchSize);
    final pushes = <SyncedOplogPush>[];

    for (final op in pending) {
      final name = await codec.hashedEntityName(op.entity, op.entityId);
      final path = CloudLayout.entityItemPath(name);
      final existing = state[path];
      final condition = existing == null || existing.isEmpty
          ? const WebDavCondition.createOnly()
          : WebDavCondition.ifMatch(existing);

      final WebDavPutResult? put;
      try {
        put = await request<WebDavPutResult>(
          'PUT $path',
          () => backend.put(path, op.payload, condition: condition),
        );
      } on WebDavException catch (e) {
        if (quarantinePayloads.isNotEmpty) {
          await port.commitQuarantine(quarantinePayloads);
        }
        return finish(
          errorCode: e.syncErrorCode,
          failureReason: 'taxonomy 推送失败：${e.toString()}',
        );
      }
      if (put == null) {
        reason = 'taxonomy 推送阶段请求预算不足：剩余下次续跑';
        break;
      }
      state[path] = put.etag;
      pushedPaths.add(path);
      pushes.add(
        SyncedOplogPush(oplogSeq: op.seq, path: path, etag: put.etag),
      );
    }
    if (pushes.isNotEmpty) {
      await port.commitPushes(pushes);
    }

    // -----------------------------------------------------------------------
    // PULL：16 个分片必须全部列举完才推断删除；本通道的删除只从
    // sync_state 里清理记录，绝不动本地实体（taxonomy 删除靠快照 deleted=1）。
    // -----------------------------------------------------------------------
    final listings = <String, List<WebDavListing>>{};
    for (var i = 0; i < CloudLayout.shardCount; i++) {
      final shard = i.toRadixString(16);
      final dir = CloudLayout.entitiesDir(shard);
      final List<WebDavListing>? found;
      try {
        found = await request<List<WebDavListing>>(
          'PROPFIND $dir',
          () => backend.propfind(dir),
        );
      } on WebDavException catch (e) {
        if (quarantinePayloads.isNotEmpty) {
          await port.commitQuarantine(quarantinePayloads);
        }
        return finish(
          errorCode: e.syncErrorCode,
          failureReason: 'taxonomy 分片扫描失败：${e.toString()}',
        );
      }
      if (found == null) {
        reason = 'taxonomy 分片扫描请求预算不足：部分分片不推断删除';
        break;
      }
      listings[shard] = found;
    }

    final pushedSet = <String>{...pushedPaths};
    final remote = <String, String?>{};
    for (final shardListings in listings.values) {
      for (final listing in shardListings) {
        if (!listing.isCollection) remote[listing.path] = listing.etag;
      }
    }
    // 本轮刚 PUT 的文件必须合入 remote：PROPFIND 与 PUT 之间没有
    // 原子性保证，服务器可能还没把新文件列出来。少这一步就会把刚推送的
    // taxonomy 当成远端删除，下一轮又推一遍，甚至清掉本地 sync_state。
    for (final path in pushedSet) {
      remote.putIfAbsent(path, () => state[path]);
    }
    final localEntityState = <String, String?>{
      for (final entry in state.entries)
        if (entry.key.startsWith('${CloudLayout.root}/entities/'))
          entry.key: entry.value,
    };
    final diff = diffListings(
      remote: remote,
      local: localEntityState,
      includeDeletes: listings.length == CloudLayout.shardCount,
    );
    for (final path in diff.deleted) {
      state.remove(path);
    }

    final files = <RemoteTaxonomyFile>[];
    for (final path in <String>{...diff.added, ...diff.modified}) {
      final WebDavGetResult? get;
      try {
        get = await request<WebDavGetResult>(
          'GET $path',
          () => backend.get(path),
        );
      } on WebDavException catch (e) {
        if (quarantinePayloads.isNotEmpty) {
          await port.commitQuarantine(quarantinePayloads);
        }
        return finish(
          errorCode: e.syncErrorCode,
          failureReason: 'taxonomy 拉取失败：${e.toString()}',
        );
      }
      if (get == null) {
        reason = 'taxonomy 拉取阶段请求预算不足：剩余下次续跑';
        break;
      }
      try {
        final snapshot = await codec.decodeTaxonomy(get.bytes);
        if (!isSyncEntityTaxonomy(snapshot.entity)) {
          throw FormatException('实体 ${snapshot.entity} 不在 taxonomy 白名单');
        }
        files.add(
          RemoteTaxonomyFile(
            path: path,
            etag: get.etag,
            snapshot: snapshot,
          ),
        );
        state[path] = get.etag;
        pulledPaths.add(path);
      } catch (_) {
        quarantined.add(path);
        quarantinePayloads[path] = List<int>.from(get.bytes);
      }
    }

    // 拉取落库与隔离区写入必须在同一个事务里，避免「实体落了但坏文件没记录」
    // 或「隔离区写了但 sync_state 没前进」这两种半写状态。
    // commitPushes 已经把 path / etag 写进 sync_state；pull 阶段只更新
    // `/vault/entities/` 命名空间，绝不把正文通道的映射一起带走。
    final entityState = <String, String?>{
      for (final entry in state.entries)
        if (entry.key.startsWith('${CloudLayout.root}/entities/'))
          entry.key: entry.value,
    };
    if (files.isNotEmpty || diff.deleted.isNotEmpty) {
      await port.commitPulls(files, entityState, quarantinePayloads);
    } else if (quarantinePayloads.isNotEmpty) {
      await port.commitQuarantine(quarantinePayloads);
    }

    return finish();
  }
}
