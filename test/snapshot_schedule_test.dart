import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_settings.dart';
import 'package:vault/data/archive/snapshot_schedule.dart';

/// docs/05 §5.2 自动完整快照排期测试。
void main() {
  // 2026-11-15 是周日。
  final sunday0300 = DateTime(2026, 11, 15, 3, 0);

  test('off / perClip 不参与定时', () {
    for (final s in <SnapshotSchedule>[
      SnapshotSchedule.off,
      SnapshotSchedule.perClip,
    ]) {
      expect(
        decideSnapshotSchedule(schedule: s, now: sunday0300).shouldRun,
        isFalse,
      );
    }
  });

  test('daily：02:00 后触发、02:00 前不触发、当天已跑不重复', () {
    expect(
      decideSnapshotSchedule(
        schedule: SnapshotSchedule.daily,
        now: DateTime(2026, 11, 12, 2, 0),
      ).shouldRun,
      isTrue,
    );
    expect(
      decideSnapshotSchedule(
        schedule: SnapshotSchedule.daily,
        now: DateTime(2026, 11, 12, 1, 59),
      ).reason,
      contains('未到'),
    );
    final already = decideSnapshotSchedule(
      schedule: SnapshotSchedule.daily,
      now: sunday0300,
      lastRunAt: DateTime(2026, 11, 15, 2, 5),
    );
    expect(already.shouldRun, isFalse);
    expect(already.reason, contains('不重复'));
    expect(
      decideSnapshotSchedule(
        schedule: SnapshotSchedule.daily,
        now: sunday0300,
        lastRunAt: DateTime(2026, 11, 14, 2, 5),
      ).shouldRun,
      isTrue,
    );
  });

  test('weekly：仅周日触发', () {
    expect(
      decideSnapshotSchedule(
        schedule: SnapshotSchedule.weekly,
        now: sunday0300,
      ).shouldRun,
      isTrue,
    );
    final monday = decideSnapshotSchedule(
      schedule: SnapshotSchedule.weekly,
      now: DateTime(2026, 11, 16, 3, 0),
    );
    expect(monday.shouldRun, isFalse);
    expect(monday.reason, contains('周日'));
  });
}
