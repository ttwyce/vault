import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/sync_checkpoint.dart';
import 'package:vault/core/sync/sync_state_machine.dart' show SyncPhase;

/// docs/04 §10 分片游标测试。
void main() {
  test('预算未耗尽 / 无剩余路径时不生成游标', () {
    expect(
      createCheckpoint(
        phase: SyncPhase.push,
        remainingPaths: const <String>['a'],
        completedPaths: const <String>[],
        watermark: 'w1',
        nowMs: 1000,
        budgetExceeded: false,
      ),
      isNull,
    );
    expect(
      createCheckpoint(
        phase: SyncPhase.push,
        remainingPaths: const <String>[],
        completedPaths: const <String>['a'],
        watermark: 'w1',
        nowMs: 1000,
        budgetExceeded: true,
      ),
      isNull,
    );
  });

  test('预算耗尽生成游标：已完成不重复、待处理保持顺序、JSON 往返', () {
    final checkpoint = createCheckpoint(
      phase: SyncPhase.push,
      remainingPaths: const <String>['a', 'b', 'c'],
      completedPaths: const <String>['a'],
      watermark: 'w1',
      nowMs: 1000,
      budgetExceeded: true,
    )!;
    expect(checkpoint.pendingPaths, <String>['b', 'c']);
    expect(checkpoint.completedPaths, <String>['a']);
    final back = SyncCheckpoint.fromJson(checkpoint.toJson());
    expect(back.phase, SyncPhase.push);
    expect(back.pendingPaths, <String>['b', 'c']);
    expect(back.watermark, 'w1');
    expect(() => SyncCheckpoint.fromJson('bad'),
        throwsA(isA<FormatException>()));
  });

  test('恢复：水位一致且未过期才续跑', () {
    final checkpoint = createCheckpoint(
      phase: SyncPhase.pullEntries,
      remainingPaths: const <String>['x', 'y'],
      completedPaths: const <String>[],
      watermark: 'w1',
      nowMs: 1000,
      budgetExceeded: true,
    )!;
    final resume = planCheckpointResume(
      checkpoint,
      currentWatermark: 'w1',
      nowMs: 2000,
    );
    expect(resume.shouldResume, isTrue);
    expect(resume.paths, <String>['x', 'y']);

    expect(
      planCheckpointResume(
        checkpoint,
        currentWatermark: 'w2',
        nowMs: 2000,
      ).action,
      CheckpointResume.restart,
      reason: '水位前进后旧游标作废',
    );
    expect(
      planCheckpointResume(
        checkpoint,
        currentWatermark: 'w1',
        nowMs: 1000 + 604800001,
      ).reason,
      contains('7 天'),
    );
    expect(
      planCheckpointResume(
        null,
        currentWatermark: 'w1',
        nowMs: 2000,
      ).action,
      CheckpointResume.restart,
    );
  });
}
