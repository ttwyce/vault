import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/rate_limit_budget.dart';
import 'package:vault/core/sync/sync_state_machine.dart' show SyncErrorCode;

/// docs/04 §7 / §10 限流后预算减半测试。
void main() {
  test('E_RATE 连续减半，下限 1', () {
    expect(
      nextSyncBudget(
        lastError: SyncErrorCode.rate,
        previousBudget: 200,
        consecutiveRateLimits: 1,
      ),
      100,
    );
    expect(
      nextSyncBudget(
        lastError: SyncErrorCode.rate,
        previousBudget: 200,
        consecutiveRateLimits: 3,
      ),
      25,
    );
    expect(
      nextSyncBudget(
        lastError: SyncErrorCode.rate,
        previousBudget: 3,
        consecutiveRateLimits: 8,
      ),
      1,
    );
  });

  test('E_NET / E_CONFLICT / 无错误保持；超基线回落到基线', () {
    for (final code in <SyncErrorCode?>[
      SyncErrorCode.net,
      SyncErrorCode.conflict,
      null,
    ]) {
      expect(
        nextSyncBudget(lastError: code, previousBudget: 200),
        200,
      );
    }
    expect(
      nextSyncBudget(lastError: null, previousBudget: 500),
      kDefaultSyncBudget,
    );
  });

  test('致命错误返回 0，不再发请求', () {
    for (final code in <SyncErrorCode>[
      SyncErrorCode.auth,
      SyncErrorCode.quota,
      SyncErrorCode.vaultMismatch,
      SyncErrorCode.schemaTooNew,
      SyncErrorCode.corrupt,
      SyncErrorCode.mergeBug,
      SyncErrorCode.path,
    ]) {
      expect(
        nextSyncBudget(lastError: code, previousBudget: 200),
        0,
        reason: code.name,
      );
    }
  });

  test('连续成功 2 轮恢复基线；否则保持半速', () {
    expect(
      recoverSyncBudget(currentBudget: 50, consecutiveSuccesses: 2),
      kDefaultSyncBudget,
    );
    expect(
      recoverSyncBudget(currentBudget: 50, consecutiveSuccesses: 1),
      50,
    );
    expect(
      recoverSyncBudget(
        currentBudget: 50,
        consecutiveSuccesses: 3,
        baseBudget: 100,
      ),
      100,
    );
  });
}
