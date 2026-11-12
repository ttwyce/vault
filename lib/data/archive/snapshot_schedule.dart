/// 自动完整快照排期判定（docs/05 §5.2）。
///
/// 不启动定时器、不写库：只按 schedule / 上次快照时刻 / 当前本地时间
/// 判定这一刻该不该跑 L2+L3 快照；「每次剪藏」由剪藏流程直接触发，
/// 不参与定时。
library;

import 'archive_settings.dart' show SnapshotSchedule;

/// 定时窗口 02:00（本地时间）。
const int kSnapshotHour = 2;

class SnapshotScheduleDecision {
  const SnapshotScheduleDecision({
    required this.shouldRun,
    required this.reason,
  });

  final bool shouldRun;
  final String reason;
}

/// [now] 本地时间；[lastRunAt] 上次成功跑全量快照的时刻，null 表示从未。
/// 周日 = DateTime.sunday(7)。
SnapshotScheduleDecision decideSnapshotSchedule({
  required SnapshotSchedule schedule,
  required DateTime now,
  DateTime? lastRunAt,
}) {
  if (schedule == SnapshotSchedule.off ||
      schedule == SnapshotSchedule.perClip) {
    return const SnapshotScheduleDecision(
      shouldRun: false,
      reason: '关闭 / 每次剪藏不参与定时任务',
    );
  }
  if (schedule == SnapshotSchedule.weekly && now.weekday != DateTime.sunday) {
    return const SnapshotScheduleDecision(
      shouldRun: false,
      reason: '每周日 02:00 才执行',
    );
  }
  if (now.hour < kSnapshotHour) {
    return const SnapshotScheduleDecision(
      shouldRun: false,
      reason: '未到 02:00 定时窗口',
    );
  }
  if (lastRunAt != null && _sameLocalDay(lastRunAt, now)) {
    return const SnapshotScheduleDecision(
      shouldRun: false,
      reason: '今天已跑过自动完整快照，不重复',
    );
  }
  return SnapshotScheduleDecision(
    shouldRun: true,
    reason: schedule == SnapshotSchedule.daily
        ? '已到每日 02:00 且今日未跑，触发完整快照'
        : '已到周日 02:00 且本周未跑，触发完整快照',
  );
}

bool _sameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
