/// 死链重检查的**平台默认排期**（docs/05 §6.1）。
///
/// 每周一次（Windows）/ 每月一次（移动端，Android 与 iOS 一致）。
/// 不发 HEAD、不启动定时器：只把「平台 + 用户显式策略 + 上次检查时刻」
/// 解析成有效策略、到期时刻与批量规模，供真实任务调度层消费。
library;

import '../platform/platform_capabilities.dart' show PlatformKind;
import 'archive_meta.dart' show RecheckPolicy;

/// 各平台的默认重检查策略。用户显式写入 `recheck_policy` 时优先。
RecheckPolicy defaultRecheckPolicy(PlatformKind platform) => switch (platform) {
      PlatformKind.windows => RecheckPolicy.weekly,
      PlatformKind.android || PlatformKind.ios => RecheckPolicy.monthly,
    };

/// 移动端后台任务受限，批量小；Windows 常驻可靠，批量大。
int recheckBatchSize(PlatformKind platform) => switch (platform) {
      PlatformKind.windows => 25,
      PlatformKind.android || PlatformKind.ios => 10,
    };

class LinkCheckSchedule {
  const LinkCheckSchedule({
    required this.policy,
    required this.batchSize,
    required this.nextCheckAtMs,
    required this.reason,
  });

  final RecheckPolicy policy;
  final int batchSize;
  final int? nextCheckAtMs;
  final String reason;

  bool isDue(int nowMs) =>
      nextCheckAtMs != null && nowMs >= nextCheckAtMs!;
}

/// [explicitPolicy] 非 null 表示 meta 里显式写了 `recheck_policy`；
/// 为 null 时按平台默认（不读 meta 的隐式 monthly，避免平台差异被抹平）。
LinkCheckSchedule planLinkCheckSchedule({
  required PlatformKind platform,
  required int? lastCheckedAtMs,
  RecheckPolicy? explicitPolicy,
}) {
  final policy = explicitPolicy ?? defaultRecheckPolicy(platform);
  final reason = explicitPolicy != null
      ? '用户在 meta 显式指定 ${explicitPolicy.wire}，优先于平台默认'
      : '按平台默认 ${policy.wire}（${platform.name}）';
  final interval = policy.interval?.inMilliseconds;
  return LinkCheckSchedule(
    policy: policy,
    batchSize: recheckBatchSize(platform),
    nextCheckAtMs: interval == null
        ? null
        : (lastCheckedAtMs ?? 0) + interval,
    reason: reason,
  );
}
