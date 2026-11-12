/// 写入后的同步触发 debounce（docs/04 §12）。
///
/// 不启动定时器、不调 SyncEngine：只按「最后一次写入时刻 / 当前时刻 /
/// 会话状态」判定这一刻该不该 kick，以及还要等多久。
library;

/// 写入后 debounce 8 秒（docs/04 §12）。
const int kSyncKickDebounceMs = 8000;

enum SyncKickAction { kick, wait, defer }

class SyncKickDecision {
  const SyncKickDecision({
    required this.action,
    required this.remainingMs,
    required this.reason,
  });

  final SyncKickAction action;
  final int remainingMs;
  final String reason;
}

SyncKickDecision decideSyncKick({
  required int? lastWriteAtMs,
  required int nowMs,
  required bool unlocked,
  required bool syncRunning,
  required bool appInForeground,
  int debounceMs = kSyncKickDebounceMs,
}) {
  if (lastWriteAtMs == null) {
    return const SyncKickDecision(
      action: SyncKickAction.wait,
      remainingMs: 0,
      reason: '没有待同步写入',
    );
  }
  if (!unlocked || !appInForeground || syncRunning) {
    return const SyncKickDecision(
      action: SyncKickAction.defer,
      remainingMs: 0,
      reason: '未解锁 / 在后台 / 已有同步进行中，推迟到下次前台补偿',
    );
  }
  final elapsed = nowMs - lastWriteAtMs;
  if (elapsed < 0) {
    return const SyncKickDecision(
      action: SyncKickAction.wait,
      remainingMs: 0,
      reason: '时间戳倒退，保守不触发',
    );
  }
  if (elapsed < debounceMs) {
    return SyncKickDecision(
      action: SyncKickAction.wait,
      remainingMs: debounceMs - elapsed,
      reason: '编辑 debounce 未到，继续合并窗口',
    );
  }
  return const SyncKickDecision(
    action: SyncKickAction.kick,
    remainingMs: 0,
    reason: '最后一次写入后已静默 8 秒，触发单飞同步',
  );
}
