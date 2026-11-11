import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/change_diff.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/core/sync/retry_scheduler.dart';
import 'package:vault/core/sync/sync_engine.dart';
import 'package:vault/core/sync/sync_runtime.dart';
import 'package:vault/core/sync/sync_state_machine.dart';
import 'package:vault/data/write/entry_snapshot.dart';

/// `RetryScheduler` 的确定性测试：不真的 sleep、不接网络。
/// 验证 BACKOFF 才重试、错误码驱动退避时长、超过上限停止、其它状态立即停。
const int _now = 1731052800000;

SyncRunResult _result({
  required SyncPhase phase,
  SyncErrorCode? retryCode,
  bool skipped = false,
}) {
  return SyncRunResult(
    skipped: skipped,
    state: SyncState(phase),
    phases: <SyncPhase>[phase],
    requestLog: const <String>[],
    pullOrder: const <String>[],
    requestCount: 0,
    conflicts: 0,
    budgetExceeded: false,
    watermarkPublished: false,
    entries: const <String, EntrySnapshot>{},
    syncState: const <String, String?>{},
    deletedEntries: const <String>{},
    quarantined: const <String>{},
    quarantinePayloads: const <String, List<int>>{},
    nextHlc: Hlc(millis: _now, counter: 0, node: 'devA').encode(),
    pushedPaths: const <String>[],
    conflictCopyIds: const <String>{},
    appliedOps: const <String>{},
    cloudAppliedEntryIds: const <String>{},
    tombstonesWritten: const <String>{},
    preconditionAttempts: const <String, int>{},
    reason: phase.name,
    diff: SyncDiff.empty,
    retryCode: retryCode,
  );
}

Future<RetryRunResult> _drive({
  required List<SyncRunResult> outcomes,
  int maxRetries = 5,
  List<Duration>? slept,
}) async {
  var index = 0;
  final delays = slept ?? <Duration>[];
  return await RetryScheduler(
    policy: BackoffPolicy(maxRetries: maxRetries),
    sleep: (Duration delay) async {
      delays.add(delay);
    },
  ).run(() async {
    final result = outcomes[index.clamp(0, outcomes.length - 1)];
    index++;
    return result;
  });
}

void main() {
  test('T09：E_NET 退避后成功，延迟 1s→2s→4s 且不重复放大', () async {
    final slept = <Duration>[];
    final report = await _drive(
      slept: slept,
      outcomes: <SyncRunResult>[
        _result(phase: SyncPhase.backoff, retryCode: SyncErrorCode.net),
        _result(phase: SyncPhase.backoff, retryCode: SyncErrorCode.net),
        _result(phase: SyncPhase.backoff, retryCode: SyncErrorCode.net),
        _result(phase: SyncPhase.idle),
      ],
    );

    expect(report.attempts, 4);
    expect(report.succeeded, isTrue);
    expect(report.delays, <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    ]);
    expect(slept, report.delays);
    expect(report.stoppedBecause, contains('同步完成'));
  });

  test('T14：E_RATE 是 30s 起步且封顶 10min，不按 E_NET 的 1s 退避', () async {
    final report = await _drive(
      maxRetries: 6,
      outcomes: <SyncRunResult>[
        for (var i = 0; i < 6; i++)
          _result(phase: SyncPhase.backoff, retryCode: SyncErrorCode.rate),
      ],
    );

    expect(report.delays, <Duration>[
      const Duration(seconds: 30),
      const Duration(minutes: 1),
      const Duration(minutes: 2),
      const Duration(minutes: 4),
      const Duration(minutes: 8),
    ]);
    expect(report.attempts, 6);
    expect(report.stoppedBecause, contains('超过最大重试次数'));
    expect(report.finalResult.isBackoff, isTrue);
  });

  test('超过 maxRetries 后停止，不再调用 attempt', () async {
    var calls = 0;
    final report = await RetryScheduler(
      policy: const BackoffPolicy(maxRetries: 2),
      sleep: (Duration _) async {},
    ).run(() async {
      calls++;
      return _result(
        phase: SyncPhase.backoff,
        retryCode: SyncErrorCode.net,
      );
    });

    expect(report.attempts, 2);
    expect(calls, 2);
    expect(report.delays, <Duration>[const Duration(seconds: 1)]);
    expect(report.stoppedBecause, contains('超过最大重试次数'));
  });

  test('FAILED / IDLE / 跳过都不重试，也不 sleep', () async {
    final slept = <Duration>[];
    for (final phase in <SyncPhase>[
      SyncPhase.failed,
      SyncPhase.idle,
      SyncPhase.verify,
    ]) {
      final report = await _drive(
        slept: slept,
        outcomes: <SyncRunResult>[_result(phase: phase)],
      );
      expect(report.attempts, 1);
      expect(report.delays, isEmpty);
    }
    final skipped = await _drive(
      slept: slept,
      outcomes: <SyncRunResult>[
        _result(phase: SyncPhase.idle, skipped: true),
      ],
    );
    expect(skipped.attempts, 1);
    expect(skipped.stoppedBecause, contains('单飞锁'));
    expect(slept, isEmpty);
  });

  test('不可重试错误即使进了 BACKOFF 也不会无限循环', () async {
    final report = await _drive(
      maxRetries: 3,
      outcomes: <SyncRunResult>[
        _result(phase: SyncPhase.backoff, retryCode: SyncErrorCode.auth),
        _result(phase: SyncPhase.backoff, retryCode: SyncErrorCode.auth),
        _result(phase: SyncPhase.idle),
      ],
    );

    // auth 不可退避，但调度器按保守 E_NET 处理；仍受 maxRetries 限制。
    expect(report.attempts, lessThanOrEqualTo(3));
    expect(report.succeeded, isTrue);
  });
}
