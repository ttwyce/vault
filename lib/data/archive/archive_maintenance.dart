/// 归档维护计划器（docs/05 §6 / §7 / §11 §3.4）。
///
/// 把已有的纯判定函数收成一份**可执行动作清单**：哪些条目该重检查、
/// 哪些死链该回退 Wayback、哪些本地缓存该清、哪些快照该降级。
/// 不联网、不碰 WebView、不写库；平台层按清单逐条执行。
library;

import 'archive_meta.dart';
import 'archive_policy.dart';

class ArchiveMaintenanceItem {
  const ArchiveMaintenanceItem({
    required this.entryId,
    required this.meta,
    this.lastCheckResult,
  });

  final String entryId;
  final ArchiveMeta meta;

  /// 最近一次 HTTP 判定结果（若已有）。
  final LinkCheckResult? lastCheckResult;
}

enum MaintenanceAction {
  recheck,
  wayback,
  evictBlob,
  downgradeSnapshot,
}

class MaintenanceTask {
  const MaintenanceTask({
    required this.action,
    required this.target,
    required this.reason,
  });

  final MaintenanceAction action;
  final String target;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'action': action.name,
        'target': target,
        'reason': reason,
      };
}

class ArchiveMaintenancePlan {
  const ArchiveMaintenancePlan(this.tasks);

  final List<MaintenanceTask> tasks;

  int countOf(MaintenanceAction action) =>
      tasks.where((MaintenanceTask t) => t.action == action).length;

  List<Map<String, Object?>> toJson() => <Map<String, Object?>>[
        for (final task in tasks) task.toJson(),
      ];
}

/// 生成维护计划。
ArchiveMaintenancePlan planArchiveMaintenance({
  required Iterable<ArchiveMaintenanceItem> entries,
  required int nowMs,
  required int cacheMaxBytes,
  required int cacheCurrentBytes,
  required Iterable<CachedBlob> cachedBlobs,
  required int quotaLimitBytes,
  required int quotaCurrentBytes,
}) {
  final tasks = <MaintenanceTask>[];
  final items = entries.toList();

  // ① 重检查排期：按 RecheckPolicy 算出的下次时间已到。
  for (final item in items) {
    final next = item.meta.nextCheckAt();
    if (next != null && next <= nowMs) {
      tasks.add(MaintenanceTask(
        action: MaintenanceAction.recheck,
        target: item.entryId,
        reason: '重检查到期（${item.meta.policy.wire}）',
      ));
    }
  }

  // ② 死链 / 不可达 → Wayback 回退；restricted / paywalled 不回退。
  for (final item in items) {
    final result = item.lastCheckResult;
    if (result != null && shouldTryWayback(result)) {
      tasks.add(MaintenanceTask(
        action: MaintenanceAction.wayback,
        target: item.entryId,
        reason: '${result.name} → 建议回退 Wayback 快照',
      ));
    }
  }

  // ③ 本地 blob 缓存清理：只清本地，不删云端。
  final eviction = planBlobCacheEviction(
    blobs: cachedBlobs,
    maxBytes: cacheMaxBytes,
    currentBytes: cacheCurrentBytes,
  );
  for (final hash in eviction.evicted) {
    tasks.add(MaintenanceTask(
      action: MaintenanceAction.evictBlob,
      target: hash,
      reason: '本地缓存超预算，释放 ${eviction.freedBytes} B',
    ));
  }

  // ④ 云端配额守卫：最旧的带快照条目优先降级为仅元数据。
  final downgrade = planSnapshotDowngrade(
    entries: <({String entryId, ArchiveMeta meta})>[
      for (final item in items)
        (entryId: item.entryId, meta: item.meta),
    ],
    quotaLimitBytes: quotaLimitBytes,
    currentBytes: quotaCurrentBytes,
  );
  for (final id in downgrade) {
    tasks.add(MaintenanceTask(
      action: MaintenanceAction.downgradeSnapshot,
      target: id,
      reason: '配额守卫 80%：L2/L3 降级为 L1',
    ));
  }

  return ArchiveMaintenancePlan(List<MaintenanceTask>.unmodifiable(tasks));
}
