/// 一次同步的顶层调度：正文 → taxonomy → 本地清理 → 云端墓碑清理。
///
/// 前一批把三条链路各自做完了，但它们还只是三个互不感知的入口。这里把
/// 顺序钉死，并守住一条保守原则：**任一前置链路不完整，就不做清理**。
/// 清理是不可逆的（本地行物理删除、云端墓碑 DELETE），绝不能在正文同步
/// 失败 / 退避 / 预算不足、或 taxonomy 通道半途中断时执行。
///
/// 仍然不依赖真实 HTTP 客户端：`WebDavBackend` 是抽象，测试用内存 fake；
/// 所有 DELETE 都带 `If-Match`，接口层不存在无条件删除的调用形态。
library;

import 'entity_sync_engine.dart';
import 'retention_policy.dart';
import 'sync_engine.dart';
import 'sync_payloads.dart';
import 'sync_runtime.dart';
import 'sync_state_machine.dart';
import 'webdav_backend.dart';

/// 一轮调度里「本地清理」阶段的执行边界。
abstract interface class TrashPurgeRunner {
  /// 返回真正被物理清空的 entry id。
  Future<List<String>> purgedEntryIds({required int nowMs});
}

/// 90 天墓碑 TTL：列出云端墓碑文件及其 `deleted_at`。
abstract interface class TombstoneLister {
  Future<List<TombstoneRecord>> tombstones();
}

/// 清理阶段的结果。
class RetentionRunResult {
  const RetentionRunResult({
    required this.executed,
    required this.reason,
    required this.purgedEntryIds,
    required this.expiredTombstonePaths,
    required this.deletedTombstonePaths,
    required this.quarantinedPaths,
    required this.quarantinePayloads,
    required this.requestLog,
  });

  factory RetentionRunResult.skipped(String reason) => RetentionRunResult(
        executed: false,
        reason: reason,
        purgedEntryIds: const <String>[],
        expiredTombstonePaths: const <String>[],
        deletedTombstonePaths: const <String>[],
        quarantinedPaths: const <String>{},
        quarantinePayloads: const <String, List<int>>{},
        requestLog: const <String>[],
      );

  final bool executed;
  final String reason;
  final List<String> purgedEntryIds;
  final List<String> expiredTombstonePaths;
  final List<String> deletedTombstonePaths;
  final Set<String> quarantinedPaths;
  final Map<String, List<int>> quarantinePayloads;
  final List<String> requestLog;
}

/// 一轮顶层同步的完整结果。
class SyncRunReport {
  const SyncRunReport({
    required this.entry,
    required this.entity,
    required this.retention,
    required this.reason,
  });

  final SyncRunResult entry;
  final EntitySyncRunResult entity;
  final RetentionRunResult retention;
  final String reason;

  bool get completed =>
      !entry.skipped &&
      !entry.isFailed &&
      !entry.isBackoff &&
      !entry.budgetExceeded &&
      entity.isComplete &&
      retention.executed;
}

/// 顶层调度器。三个子阶段各有自己的单飞锁；本调度器用一把总锁保证
/// 「同一时刻只有一轮顶层同步」，锁忙直接跳过，不排队（D24）。
class SyncCoordinator {
  SyncCoordinator({
    required this.entryEngine,
    required this.entityEngine,
    required this.purgeRunner,
    required this.tombstoneLister,
    required this.backend,
    required this.workspaceLoader,
    required this.commitEntryRun,
    required this.commitQuarantine,
    required this.syncState,
    required this.now,
    SingleFlightLock? lock,
    this.retentionBudgetLimit = 32,
  }) : _lock = lock ?? SingleFlightLock();

  /// 正文同步引擎。
  final SyncEngine entryEngine;

  /// taxonomy 独立通道。
  final EntitySyncEngine entityEngine;

  final TrashPurgeRunner purgeRunner;
  final TombstoneLister tombstoneLister;
  final WebDavBackend backend;

  /// 从本地库装配正文工作区（通常就是 `DbSyncWorkspaceStore.load`）。
  final Future<SyncWorkspace> Function() workspaceLoader;

  /// 把正文同步结果原子落库（`DbSyncWorkspaceStore.commit`）。
  final Future<void> Function(SyncRunResult result) commitEntryRun;

  /// 把清理阶段发现的坏载荷写进同一个隔离区。
  final Future<void> Function(Map<String, List<int>> payloads)
      commitQuarantine;

  /// path → 已确认 ETag。云端 DELETE 必须用它做 If-Match。
  final Future<Map<String, String?>> Function() syncState;

  final int Function() now;
  final int retentionBudgetLimit;
  final SingleFlightLock _lock;

  Future<SyncRunReport?> run({String trigger = 'coordinator'}) {
    return _lock.run(
      () => _run(trigger: trigger),
      skipped: null,
    );
  }

  Future<SyncRunReport> _run({required String trigger}) async {
    // ① 正文：load → run → 原子落库。
    final workspace = await workspaceLoader();
    final entryResult = await entryEngine.run(workspace);
    await commitEntryRun(entryResult);

    if (!_entryComplete(entryResult)) {
      final reason = '正文同步未完成：跳过 taxonomy / 清理阶段'
          '（${entryResult.reason}）';
      return SyncRunReport(
        entry: entryResult,
        entity: EntitySyncRunResult.skipped(),
        retention: RetentionRunResult.skipped(reason),
        reason: reason,
      );
    }

    // ② taxonomy 独立通道。
    final entityResult = await entityEngine.run();
    if (!entityResult.isComplete) {
      final reason = 'taxonomy 通道未完成：跳过清理阶段'
          '（${entityResult.reason}）';
      return SyncRunReport(
        entry: entryResult,
        entity: entityResult,
        retention: RetentionRunResult.skipped(reason),
        reason: reason,
      );
    }

    // ③ 本地 30 天清理 + ④ 云端 90 天墓碑 TTL。
    final retention = await _runRetention();
    return SyncRunReport(
      entry: entryResult,
      entity: entityResult,
      retention: retention,
      reason: retention.reason,
    );
  }

  bool _entryComplete(SyncRunResult result) =>
      !result.skipped &&
      !result.isFailed &&
      !result.isBackoff &&
      !result.budgetExceeded &&
      result.watermarkPublished;

  Future<RetentionRunResult> _runRetention() async {
    final nowMs = now();
    final budget = RequestBudget(limit: retentionBudgetLimit);
    final requestLog = <String>[];
    final quarantined = <String>{};
    final quarantinePayloads = <String, List<int>>{};
    final deletedPaths = <String>[];

    Future<T?> request<T>(String label, Future<T> Function() call) async {
      if (!budget.tryConsume()) return null;
      requestLog.add(label);
      return await call();
    }

    RetentionRunResult finish({
      required List<String> purged,
      required List<String> expired,
      String? reason,
    }) =>
        RetentionRunResult(
          executed: true,
          reason: reason ?? '清理阶段完成',
          purgedEntryIds: List<String>.unmodifiable(purged),
          expiredTombstonePaths: List<String>.unmodifiable(expired),
          deletedTombstonePaths: List<String>.unmodifiable(deletedPaths),
          quarantinedPaths: Set<String>.unmodifiable(quarantined),
          quarantinePayloads: Map<String, List<int>>.unmodifiable(
            <String, List<int>>{
              for (final entry in quarantinePayloads.entries)
                entry.key: List<int>.unmodifiable(entry.value),
            },
          ),
          requestLog: List<String>.unmodifiable(requestLog),
        );

    // 本地清理先跑：它只在「本条墓碑已确认」时才删本地行，
    // 而云端 TTL 删除的是 90 天前的墓碑，两者不会碰同一条记录。
    final purged = await purgeRunner.purgedEntryIds(nowMs: nowMs);

    final tombstones = await tombstoneLister.tombstones();
    final plan = planTombstoneRetention(
      tombstones: tombstones,
      nowMs: nowMs,
    );
    final state = await syncState();

    var incomplete = false;
    var failureCode = SyncErrorCode.path;
    for (final path in plan.expiredPaths) {
      final etag = state[path];
      if (etag == null || etag.isEmpty) {
        // 没有 ETag 就不能构造条件 DELETE；留到下一轮，绝不无条件删。
        incomplete = true;
        continue;
      }
      try {
        final done = await request<bool>(
          'DELETE $path',
          () async {
            await backend.delete(path, ifMatch: etag);
            return true;
          },
        );
        if (done == null) {
          incomplete = true;
          continue;
        }
        deletedPaths.add(path);
      } on WebDavException catch (e) {
        incomplete = true;
        failureCode = e.syncErrorCode;
        if (e.statusCode == 412) {
          // 412 说明墓碑被别人改过：下一轮重新拉 ETag，不重试覆盖。
          continue;
        }
        break;
      }
    }

    if (quarantinePayloads.isNotEmpty) {
      await commitQuarantine(quarantinePayloads);
    }
    final reason = incomplete
        ? '清理阶段部分完成：剩余墓碑下一轮续跑（${failureCode.name}）'
        : '清理阶段完成';
    return finish(
      purged: purged,
      expired: plan.expiredPaths,
      reason: reason,
    );
  }
}
