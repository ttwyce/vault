/// 归档全局配置（docs/05 §5.2 / §5.4）。
///
/// 不写库、不联网：只定义自动完整快照排期、保留期、配额上限、快照同步
/// 模式与前台补偿文案；配额守卫给出「降级哪些 / 是否只存 L1」的计划。
library;

enum SnapshotSchedule { off, perClip, daily, weekly }

extension SnapshotScheduleWire on SnapshotSchedule {
  String get wire => switch (this) {
        SnapshotSchedule.off => 'off',
        SnapshotSchedule.perClip => 'per_clip',
        SnapshotSchedule.daily => 'daily_0200',
        SnapshotSchedule.weekly => 'weekly_0200',
      };

  String get label => switch (this) {
        SnapshotSchedule.off => '关闭（默认）',
        SnapshotSchedule.perClip => '每次剪藏',
        SnapshotSchedule.daily => '每日 02:00',
        SnapshotSchedule.weekly => '每周日 02:00',
      };
}

enum SnapshotRetention { days30, year1, forever }

extension SnapshotRetentionWire on SnapshotRetention {
  int? get days => switch (this) {
        SnapshotRetention.days30 => 30,
        SnapshotRetention.year1 => 365,
        SnapshotRetention.forever => null,
      };

  String get label => switch (this) {
        SnapshotRetention.days30 => '30 天',
        SnapshotRetention.year1 => '1 年（默认）',
        SnapshotRetention.forever => '永久',
      };
}

enum SnapshotSyncMode { allDevices, onDemand }

class ArchiveSettings {
  const ArchiveSettings({
    this.schedule = SnapshotSchedule.off,
    this.retention = SnapshotRetention.year1,
    this.syncMode = SnapshotSyncMode.onDemand,
    this.quotaRatio = 0.8,
    this.autoTextArchive = true,
  });

  /// L1 正文归档始终开，不可关（docs/05 §5.2）。
  final bool autoTextArchive;
  final SnapshotSchedule schedule;
  final SnapshotRetention retention;
  final SnapshotSyncMode syncMode;

  /// 云端配额上限 = WebDAV 剩余空间 × ratio。
  final double quotaRatio;

  /// 平台文案：绝不承诺后台自动（docs/05 §5.3）。
  String platformHint(String platform) => switch (platform.toLowerCase()) {
        'windows' => '每天 02:00 自动归档（托盘常驻）',
        'android' => 'App 运行时自动归档（受 Doze 影响）',
        'ios' => '下次打开 App 时归档（前台补偿）',
        _ => '前台补偿：启动时检查积压任务',
      };

  Map<String, Object?> toJson() => <String, Object?>{
        'auto_text_archive': autoTextArchive,
        'schedule': schedule.wire,
        'retention': retention.name,
        'sync_mode': syncMode.name,
        'quota_ratio': quotaRatio,
      };

  factory ArchiveSettings.fromJson(Object? raw) {
    if (raw is! Map) return const ArchiveSettings();
    final ratio = raw['quota_ratio'];
    return ArchiveSettings(
      // autoTextArchive 只读：配置里试图关掉也强制回到 true。
      autoTextArchive: true,
      schedule: SnapshotSchedule.values
          .where((SnapshotSchedule s) => s.wire == raw['schedule'])
          .firstOrNull ?? SnapshotSchedule.off,
      retention: SnapshotRetention.values
          .where((SnapshotRetention r) => r.name == raw['retention'])
          .firstOrNull ?? SnapshotRetention.year1,
      syncMode: SnapshotSyncMode.values
          .where((SnapshotSyncMode m) => m.name == raw['sync_mode'])
          .firstOrNull ?? SnapshotSyncMode.onDemand,
      quotaRatio: ratio is num && ratio > 0 && ratio <= 1
          ? ratio.toDouble()
          : 0.8,
    );
  }
}

class QuotaGuardPlan {
  const QuotaGuardPlan({
    required this.quotaBytes,
    required this.wouldExceed,
    required this.allowL2L3,
    required this.hint,
  });

  final int quotaBytes;
  final bool wouldExceed;
  final bool allowL2L3;
  final String hint;
}

/// 配额守卫（docs/05 §5.4）：每次 L2/L3 前判定。
/// [downgradedBytes] 是「按 LRU 降级最老 full 后」能释放的量，
/// 由已有 `planSnapshotDowngrade` 的执行结果回填。
QuotaGuardPlan planQuotaGuard({
  required int freeBytes,
  required int usedBytes,
  required int incomingBytes,
  required int downgradedBytes,
  double quotaRatio = 0.8,
}) {
  final quota = (freeBytes * quotaRatio).floor();
  final projected = usedBytes + incomingBytes - downgradedBytes;
  final exceed = projected > quota;
  return QuotaGuardPlan(
    quotaBytes: quota,
    wouldExceed: exceed,
    allowL2L3: !exceed,
    hint: exceed
        ? '降级最老快照后仍超配额：只存 L1 正文，并提示用户'
        : downgradedBytes > 0
            ? '已按 LRU 降级最老快照，本次 L2/L3 可存'
            : '配额充足，本次 L2/L3 可存',
  );
}
