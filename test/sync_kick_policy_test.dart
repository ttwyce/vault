import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/sync_kick_policy.dart';

/// docs/04 §12 写入后 debounce 8s 触发同步测试。
void main() {
  test('无写入不触发；写入后未到 8s 给剩余等待', () {
    expect(
      decideSyncKick(
        lastWriteAtMs: null,
        nowMs: 1000,
        unlocked: true,
        syncRunning: false,
        appInForeground: true,
      ).action,
      SyncKickAction.wait,
    );
    final waiting = decideSyncKick(
      lastWriteAtMs: 1000,
      nowMs: 4000,
      unlocked: true,
      syncRunning: false,
      appInForeground: true,
    );
    expect(waiting.action, SyncKickAction.wait);
    expect(waiting.remainingMs, 5000);
    expect(kSyncKickDebounceMs, 8000);
  });

  test('静默满 8s 触发；边界当天有效', () {
    final kick = decideSyncKick(
      lastWriteAtMs: 0,
      nowMs: kSyncKickDebounceMs,
      unlocked: true,
      syncRunning: false,
      appInForeground: true,
    );
    expect(kick.action, SyncKickAction.kick);
    expect(kick.reason, contains('8 秒'));
  });

  test('未解锁 / 后台 / 同步中一律推迟；时间戳倒退保守等待', () {
    for (final flags in <(bool, bool, bool)>[
      (false, false, true),
      (true, false, false),
      (true, true, true),
    ]) {
      final d = decideSyncKick(
        lastWriteAtMs: 0,
        nowMs: 99999,
        unlocked: flags.$1,
        appInForeground: flags.$2,
        syncRunning: flags.$3,
      );
      expect(d.action, SyncKickAction.defer, reason: flags.toString());
    }
    expect(
      decideSyncKick(
        lastWriteAtMs: 500,
        nowMs: 100,
        unlocked: true,
        syncRunning: false,
        appInForeground: true,
      ).action,
      SyncKickAction.wait,
    );
  });
}
