/// 同步错误后的下一轮请求预算（docs/04 §7 E_RATE / §10）。
///
/// 不联网、不改 SyncEngine：只按上一轮错误码与退避轮次算出下一轮
/// `budgetLimit`，供协调器/重试调度器注入。
library;

import 'sync_state_machine.dart' show SyncErrorCode;

/// 默认预算 200（docs/04 §10）。
const int kDefaultSyncBudget = 200;

/// E_RATE 每次减半，下限 1；其它可重试错误保持；致命错误返回 0。
int nextSyncBudget({
  required SyncErrorCode? lastError,
  required int previousBudget,
  int baseBudget = kDefaultSyncBudget,
  int consecutiveRateLimits = 1,
}) {
  if (previousBudget <= 0 || baseBudget <= 0) return 0;
  return switch (lastError) {
    SyncErrorCode.auth ||
    SyncErrorCode.quota ||
    SyncErrorCode.vaultMismatch ||
    SyncErrorCode.schemaTooNew ||
    SyncErrorCode.corrupt ||
    SyncErrorCode.mergeBug ||
    SyncErrorCode.path =>
      0,
    SyncErrorCode.rate => _halve(previousBudget, consecutiveRateLimits),
    SyncErrorCode.net ||
    SyncErrorCode.conflict ||
    null =>
      previousBudget > baseBudget ? baseBudget : previousBudget,
  };
}

int _halve(int previous, int rounds) {
  var value = previous;
  for (var i = 0; i < rounds.clamp(1, 8); i++) {
    value = value ~/ 2;
    if (value <= 1) return 1;
  }
  return value;
}

/// 恢复：连续成功 N 轮后把预算放回基线（避免永久半速）。
int recoverSyncBudget({
  required int currentBudget,
  required int consecutiveSuccesses,
  int baseBudget = kDefaultSyncBudget,
  int recoveryRounds = 2,
}) =>
    consecutiveSuccesses >= recoveryRounds ? baseBudget : currentBudget;
