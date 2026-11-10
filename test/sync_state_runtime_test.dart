import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/sync/sync_runtime.dart';
import 'package:vault/core/sync/sync_state_machine.dart';

void main() {
  void expectTransition(
    SyncPhase phase,
    SyncEvent event,
    SyncPhase expected, [
    SyncErrorCode? expectedError,
  ]) {
    final result = syncTransition(SyncState(phase), event);
    expect(result.phase, expected, reason: '${phase.name} + ${event.name}');
    expect(
      result.error,
      expectedError,
      reason: '${phase.name} + ${event.name} 的错误码',
    );
  }

  group('同步状态机（docs/04 §4.2）', () {
    test('完整合法转移表', () {
      expectTransition(
        SyncPhase.idle,
        SyncEvent.trigger,
        SyncPhase.acquireLock,
      );
      expectTransition(
        SyncPhase.acquireLock,
        SyncEvent.lockBusy,
        SyncPhase.idle,
      );
      expectTransition(
        SyncPhase.acquireLock,
        SyncEvent.lockAcquired,
        SyncPhase.probe,
      );

      expectTransition(
        SyncPhase.probe,
        SyncEvent.probeQuiet,
        SyncPhase.publish,
      );
      expectTransition(
        SyncPhase.probe,
        SyncEvent.probePendingOnly,
        SyncPhase.push,
      );
      expectTransition(
        SyncPhase.probe,
        SyncEvent.probeChanged,
        SyncPhase.discover,
      );

      expectTransition(
        SyncPhase.discover,
        SyncEvent.discoverDone,
        SyncPhase.pullTombstones,
      );
      expectTransition(
        SyncPhase.discover,
        SyncEvent.discoverBudgetExceeded,
        SyncPhase.push,
      );

      expectTransition(
        SyncPhase.pullTombstones,
        SyncEvent.tombstonesDone,
        SyncPhase.pullMeta,
      );
      expectTransition(
        SyncPhase.pullMeta,
        SyncEvent.metaOk,
        SyncPhase.pullEntries,
      );
      expectTransition(
        SyncPhase.pullEntries,
        SyncEvent.pullDone,
        SyncPhase.merge,
      );

      expectTransition(
        SyncPhase.merge,
        SyncEvent.mergeDone,
        SyncPhase.push,
      );
      expectTransition(
        SyncPhase.merge,
        SyncEvent.mergeDoneWithConflicts,
        SyncPhase.push,
      );

      expectTransition(
        SyncPhase.push,
        SyncEvent.pushDone,
        SyncPhase.verify,
      );
      expectTransition(
        SyncPhase.push,
        SyncEvent.pushPreconditionFailed,
        SyncPhase.pullEntries,
      );
      expectTransition(
        SyncPhase.push,
        SyncEvent.pushPreconditionExhausted,
        SyncPhase.verify,
      );
      expectTransition(
        SyncPhase.push,
        SyncEvent.networkError,
        SyncPhase.backoff,
      );
      expectTransition(
        SyncPhase.push,
        SyncEvent.rateLimited,
        SyncPhase.backoff,
      );

      expectTransition(
        SyncPhase.verify,
        SyncEvent.verifyOk,
        SyncPhase.publish,
      );
      expectTransition(
        SyncPhase.publish,
        SyncEvent.publishDone,
        SyncPhase.idle,
      );
      expectTransition(
        SyncPhase.backoff,
        SyncEvent.backoffElapsed,
        SyncPhase.probe,
      );
    });

    test('失败路径携带文档规定的错误码', () {
      expectTransition(
        SyncPhase.pullMeta,
        SyncEvent.metaVaultMismatch,
        SyncPhase.failed,
        SyncErrorCode.vaultMismatch,
      );
      expectTransition(
        SyncPhase.pullMeta,
        SyncEvent.metaSchemaTooNew,
        SyncPhase.failed,
        SyncErrorCode.schemaTooNew,
      );
      expectTransition(
        SyncPhase.verify,
        SyncEvent.verifyHashMismatch,
        SyncPhase.failed,
        SyncErrorCode.mergeBug,
      );
      expectTransition(
        SyncPhase.backoff,
        SyncEvent.retriesExceeded,
        SyncPhase.failed,
        SyncErrorCode.net,
      );
    });

    test('任何阶段的致命错误都进入 FAILED 并保留显式错误码', () {
      for (final phase in SyncPhase.values) {
        final result = syncTransition(
          SyncState(phase),
          SyncEvent.fatalError,
          error: SyncErrorCode.auth,
        );
        expect(result.phase, SyncPhase.failed, reason: phase.name);
        expect(result.isTerminal, isTrue, reason: phase.name);
        expect(result.error, SyncErrorCode.auth, reason: phase.name);
      }
    });

    test('致命错误未指定错误码时默认 E_CORRUPT', () {
      final result = syncTransition(
        const SyncState(SyncPhase.probe),
        SyncEvent.fatalError,
      );
      expect(result.phase, SyncPhase.failed);
      expect(result.error, SyncErrorCode.corrupt);
      expect(result.toString(), contains('E_CORRUPT'));
    });

    test('非法事件直接抛 StateError，而不是静默卡住', () {
      expect(
        () => syncTransition(
          const SyncState(SyncPhase.idle),
          SyncEvent.publishDone,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => syncTransition(
          const SyncState(SyncPhase.publish),
          SyncEvent.probeChanged,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('错误码线格式与 docs/04 §7 一致', () {
      const expected = <SyncErrorCode, String>{
        SyncErrorCode.auth: 'E_AUTH',
        SyncErrorCode.net: 'E_NET',
        SyncErrorCode.rate: 'E_RATE',
        SyncErrorCode.quota: 'E_QUOTA',
        SyncErrorCode.conflict: 'E_CONFLICT',
        SyncErrorCode.corrupt: 'E_CORRUPT',
        SyncErrorCode.vaultMismatch: 'E_VAULT_MISMATCH',
        SyncErrorCode.schemaTooNew: 'E_SCHEMA_TOO_NEW',
        SyncErrorCode.mergeBug: 'E_MERGE_BUG',
        SyncErrorCode.path: 'E_PATH',
      };
      for (final entry in expected.entries) {
        expect(entry.key.wire, entry.value);
      }
      expect(const SyncState(SyncPhase.idle).isIdle, isTrue);
    });
  });

  group('SingleFlightLock', () {
    test('锁占用时直接跳过，不排队堆积', () async {
      final lock = SingleFlightLock();
      final gate = Completer<void>();
      var bodyStarted = false;

      final first = lock.run<String>(() async {
        bodyStarted = true;
        await gate.future;
        return 'first';
      }, skipped: 'skipped');
      await Future<void>.delayed(Duration.zero);

      expect(bodyStarted, isTrue);
      expect(lock.isHeld, isTrue);

      var skippedBodyStarted = false;
      final second = await lock.run<String>(() async {
        skippedBodyStarted = true;
        return 'should-not-run';
      }, skipped: 'skipped');

      expect(second, 'skipped');
      expect(skippedBodyStarted, isFalse);
      expect(lock.isHeld, isTrue, reason: '被跳过的触发不能释放别人的锁');

      gate.complete();
      expect(await first, 'first');
      expect(lock.isHeld, isFalse);

      final third = await lock.run(() async => 'third', skipped: 'skipped');
      expect(third, 'third');
      expect(lock.isHeld, isFalse);
    });

    test('合并抛异常也一定释放锁，否则同步会永久停滞', () async {
      final lock = SingleFlightLock();
      await expectLater(
        lock.run<String>(() async {
          throw StateError('merge bug');
        }, skipped: 'skipped'),
        throwsA(isA<StateError>()),
      );
      expect(lock.isHeld, isFalse);
      expect(
        await lock.run(() async => 'ok', skipped: 'skipped'),
        'ok',
      );
    });
  });

  group('RequestBudget', () {
    test('预算不足时返回 false 且不消耗本次预留', () {
      final budget = RequestBudget(limit: 3);
      expect(budget.remaining, 3);
      expect(budget.tryConsume(2), isTrue);
      expect(budget.used, 2);
      expect(budget.tryConsume(2), isFalse);
      expect(budget.used, 2, reason: '失败的多请求预留不能扣掉一部分');
      expect(budget.tryConsume(), isTrue);
      expect(budget.exhausted, isTrue);
      expect(budget.tryConsume(), isFalse);
      expect(budget.used, 3);
    });

    test('reset 后可以续跑；非法参数显式拒绝', () {
      final budget = RequestBudget();
      expect(budget.limit, 200);
      budget.tryConsume(200);
      expect(budget.exhausted, isTrue);
      budget.reset();
      expect(budget.remaining, 200);
      expect(budget.tryConsume(), isTrue);

      expect(
        () => RequestBudget(limit: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => budget.tryConsume(0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('BackoffPolicy（docs/04 §10 / T14）', () {
    const policy = BackoffPolicy();

    test('E_NET 从 1s 指数增长并封顶 5min', () {
      expect(policy.delayFor(SyncErrorCode.net, 1), const Duration(seconds: 1));
      expect(policy.delayFor(SyncErrorCode.net, 2), const Duration(seconds: 2));
      expect(policy.delayFor(SyncErrorCode.net, 3), const Duration(seconds: 4));
      expect(policy.delayFor(SyncErrorCode.net, 9), const Duration(seconds: 256));
      expect(policy.delayFor(SyncErrorCode.net, 10), const Duration(minutes: 5));
      expect(policy.delayFor(SyncErrorCode.net, 99), const Duration(minutes: 5));
    });

    test('E_RATE 从 30s 长退避并封顶 10min', () {
      expect(policy.delayFor(SyncErrorCode.rate, 1), const Duration(seconds: 30));
      expect(policy.delayFor(SyncErrorCode.rate, 2), const Duration(minutes: 1));
      expect(policy.delayFor(SyncErrorCode.rate, 3), const Duration(minutes: 2));
      expect(policy.delayFor(SyncErrorCode.rate, 4), const Duration(minutes: 4));
      expect(policy.delayFor(SyncErrorCode.rate, 5), const Duration(minutes: 8));
      expect(policy.delayFor(SyncErrorCode.rate, 6), const Duration(minutes: 10));
      expect(policy.delayFor(SyncErrorCode.rate, 99), const Duration(minutes: 10));
    });

    test('不可重试错误绝不进入 Timer 死循环', () {
      expect(policy.canRetry(SyncErrorCode.net), isTrue);
      expect(policy.canRetry(SyncErrorCode.rate), isTrue);
      for (final code in SyncErrorCode.values) {
        if (code == SyncErrorCode.net || code == SyncErrorCode.rate) continue;
        expect(policy.canRetry(code), isFalse, reason: code.name);
        expect(policy.shouldRetry(code, 1), isFalse, reason: code.name);
        expect(
          () => policy.delayFor(code, 1),
          throwsA(isA<ArgumentError>()),
          reason: code.name,
        );
      }
      expect(
        () => policy.delayFor(SyncErrorCode.net, 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('最大重试次数由调用方配置', () {
      const custom = BackoffPolicy(maxRetries: 2);
      expect(custom.shouldRetry(SyncErrorCode.net, 1), isTrue);
      expect(custom.shouldRetry(SyncErrorCode.net, 2), isTrue);
      expect(custom.shouldRetry(SyncErrorCode.net, 3), isFalse);
      expect(custom.shouldRetry(SyncErrorCode.quota, 1), isFalse);
    });
  });
}
