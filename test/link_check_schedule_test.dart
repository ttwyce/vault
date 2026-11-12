import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/archive/link_check_schedule.dart';
import 'package:vault/data/platform/platform_capabilities.dart';

/// docs/05 §6.1 死链平台默认排期测试。
void main() {
  const day = 86400000;
  const now = 1731052800000;

  test('Windows 默认 weekly、移动端默认 monthly', () {
    expect(defaultRecheckPolicy(PlatformKind.windows), RecheckPolicy.weekly);
    expect(defaultRecheckPolicy(PlatformKind.android), RecheckPolicy.monthly);
    expect(defaultRecheckPolicy(PlatformKind.ios), RecheckPolicy.monthly);
  });

  test('批量规模：Windows 25 / 移动端 10', () {
    expect(recheckBatchSize(PlatformKind.windows), 25);
    expect(recheckBatchSize(PlatformKind.android), 10);
    expect(recheckBatchSize(PlatformKind.ios), 10);
  });

  test('显式策略优先于平台默认；never 无到期时刻', () {
    final explicit = planLinkCheckSchedule(
      platform: PlatformKind.windows,
      lastCheckedAtMs: now,
      explicitPolicy: RecheckPolicy.never,
    );
    expect(explicit.policy, RecheckPolicy.never);
    expect(explicit.nextCheckAtMs, isNull);
    expect(explicit.isDue(now + 365 * day), isFalse);
    expect(explicit.reason, contains('优先于平台默认'));
  });

  test('Windows 7 天到期、移动端 30 天到期', () {
    final windows = planLinkCheckSchedule(
      platform: PlatformKind.windows,
      lastCheckedAtMs: now,
    );
    expect(windows.nextCheckAtMs, now + 7 * day);
    expect(windows.isDue(now + 6 * day), isFalse);
    expect(windows.isDue(now + 7 * day), isTrue);

    final mobile = planLinkCheckSchedule(
      platform: PlatformKind.ios,
      lastCheckedAtMs: now,
    );
    expect(mobile.nextCheckAtMs, now + 30 * day);
    expect(mobile.isDue(now + 7 * day), isFalse);
    expect(mobile.reason, contains('ios'));
  });

  test('从未检查过（lastCheckedAt=null）立即到期', () {
    final plan = planLinkCheckSchedule(
      platform: PlatformKind.android,
      lastCheckedAtMs: null,
    );
    expect(plan.nextCheckAtMs, 30 * day);
    expect(plan.isDue(now), isTrue);
  });
}
