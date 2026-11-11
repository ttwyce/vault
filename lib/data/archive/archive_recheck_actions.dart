/// 归档交互动作的**纯判定层**（docs/11 §3.4 / docs/05 §6）。
///
/// 不联网、不抓页面、不写库：只定义「单条重抓保留旧快照为历史版本、
/// Wayback 存档什么时候显示、批量检查怎么分批、清理降级顺序」。
library;

import 'archive_meta.dart';
import 'archive_policy.dart'
    show ArchiveFilter, filterArchives, planSnapshotDowngrade;

/// 一次重抓计划。
class RecheckPlan {
  const RecheckPlan({
    required this.entryId,
    required this.url,
    required this.keepOldSnapshot,
    required this.reason,
  });

  final String entryId;
  final String url;

  /// docs/11 §3.4：单条重抓保留旧快照为历史版本。
  final bool keepOldSnapshot;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'entry_id': entryId,
        'url': url,
        'keep_old_snapshot': keepOldSnapshot,
        'reason': reason,
      };
}

/// 单条重抓：有快照就保留为历史版本，无快照则只补正文层。
RecheckPlan planSingleRecheck({
  required String entryId,
  required ArchiveMeta meta,
}) =>
    RecheckPlan(
      entryId: entryId,
      url: meta.url,
      keepOldSnapshot: meta.hasSnapshot,
      reason: meta.hasSnapshot
          ? '保留旧 ${meta.status.wire} 快照为历史版本，再抓新正文'
          : '当前只有元数据 / 正文层，重抓补齐正文',
    );

/// Wayback 展示判定：死链且拿到 availability URL 才显示「查看存档」。
class WaybackBadge {
  const WaybackBadge({
    required this.visible,
    required this.label,
    required this.url,
  });

  final bool visible;
  final String label;
  final String? url;

  Map<String, Object?> toJson() => <String, Object?>{
        'visible': visible,
        'label': label,
        'url': url,
      };
}

WaybackBadge planWaybackBadge(ArchiveMeta meta) {
  final url = meta.waybackUrl;
  if (!meta.isDeadLink || url == null || url.isEmpty) {
    return const WaybackBadge(visible: false, label: '', url: null);
  }
  // 从 Wayback URL 里取年份（/web/2019.../），拿不到就只说「查看存档」。
  final yearMatch = RegExp(r'/web/(\d{4})').firstMatch(url);
  final year = yearMatch?.group(1);
  return WaybackBadge(
    visible: true,
    label: year == null ? '查看存档' : '查看 $year 存档',
    url: url,
  );
}

/// 批量检查：按 recheck_policy 到期分前台批次，不承诺后台执行。
List<List<String>> planBatchRecheck({
  required Map<String, ArchiveMeta> metasById,
  required int nowMs,
  int batchSize = 10,
}) {
  final due = filterArchives(
    metasById.values,
    filter: ArchiveFilter.pendingRecheck,
    nowMs: nowMs,
  ).map((ArchiveMeta m) => m.url).toSet();
  final ids = <String>[
    for (final entry in metasById.entries)
      if (due.contains(entry.value.url)) entry.key,
  ]..sort();
  final out = <List<String>>[];
  for (var i = 0; i < ids.length; i += batchSize) {
    final end = i + batchSize > ids.length ? ids.length : i + batchSize;
    out.add(List<String>.unmodifiable(ids.sublist(i, end)));
  }
  return List<List<String>>.unmodifiable(out);
}

/// 配额守卫降级顺序：直接复用已有的「最旧带快照优先」规则，
/// 但这里输出 entry id 而不是只给 bool，方便 UI 展示将清理哪些条目。
List<String> planQuotaCleanup({
  required Map<String, ArchiveMeta> metasById,
  required int quotaLimitBytes,
  required int currentBytes,
}) =>
    planSnapshotDowngrade(
      entries: <({String entryId, ArchiveMeta meta})>[
        for (final entry in metasById.entries)
          (entryId: entry.key, meta: entry.value),
      ],
      quotaLimitBytes: quotaLimitBytes,
      currentBytes: currentBytes,
    );
