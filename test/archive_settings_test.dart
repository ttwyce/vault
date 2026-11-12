import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_settings.dart';

/// docs/05 §5.2 / §5.4 归档全局配置与配额守卫测试。
void main() {
  test('默认值：L1 常开、完整快照关、1 年保留、按需下载、80% 配额', () {
    const settings = ArchiveSettings();
    expect(settings.autoTextArchive, isTrue);
    expect(settings.schedule, SnapshotSchedule.off);
    expect(settings.retention.days, 365);
    expect(settings.syncMode, SnapshotSyncMode.onDemand);
    expect(settings.quotaRatio, 0.8);
  });

  test('JSON 往返；L1 不允许被配置关掉；坏值回默认', () {
    final settings = ArchiveSettings(
      schedule: SnapshotSchedule.weekly,
      retention: SnapshotRetention.forever,
      syncMode: SnapshotSyncMode.allDevices,
      quotaRatio: 0.5,
    );
    final back = ArchiveSettings.fromJson(settings.toJson());
    expect(back.schedule, SnapshotSchedule.weekly);
    expect(back.retention.days, isNull);
    expect(back.syncMode, SnapshotSyncMode.allDevices);
    expect(back.quotaRatio, 0.5);
    expect(back.autoTextArchive, isTrue);

    final forcedOff = ArchiveSettings.fromJson(<String, Object?>{
      'auto_text_archive': false,
      'quota_ratio': 9,
    });
    expect(forcedOff.autoTextArchive, isTrue);
    expect(forcedOff.quotaRatio, 0.8);
    expect(ArchiveSettings.fromJson('坏数据').schedule,
        SnapshotSchedule.off);
  });

  test('平台文案不承诺后台自动', () {
    const settings = ArchiveSettings();
    expect(settings.platformHint('iOS'), contains('前台补偿'));
    expect(settings.platformHint('Android'), contains('App 运行时'));
    expect(settings.platformHint('Windows'), contains('托盘常驻'));
    expect(settings.platformHint('unknown'), contains('启动时检查积压'));
  });

  test('配额守卫：降级后仍超则只存 L1；充足则允许 L2/L3', () {
    final exceeded = planQuotaGuard(
      freeBytes: 1000,
      usedBytes: 700,
      incomingBytes: 200,
      downgradedBytes: 50,
    );
    expect(exceeded.quotaBytes, 800);
    expect(exceeded.wouldExceed, isTrue);
    expect(exceeded.allowL2L3, isFalse);
    expect(exceeded.hint, contains('只存 L1'));

    final afterDowngrade = planQuotaGuard(
      freeBytes: 1000,
      usedBytes: 700,
      incomingBytes: 200,
      downgradedBytes: 200,
    );
    expect(afterDowngrade.allowL2L3, isTrue);
    expect(afterDowngrade.hint, contains('LRU'));

    final plenty = planQuotaGuard(
      freeBytes: 10000,
      usedBytes: 100,
      incomingBytes: 200,
      downgradedBytes: 0,
    );
    expect(plenty.wouldExceed, isFalse);
  });
}
