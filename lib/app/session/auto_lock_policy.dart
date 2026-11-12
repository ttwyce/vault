/// 自动锁定（docs/18 §9）。
///
/// 不碰会话、不读安全存储：只按「进入后台时刻 / 回到前台时刻 /
/// 阈值」判定是否该 lock，以及剩余宽限。
library;

/// 默认后台 5 分钟自动锁定。
const int kDefaultAutoLockMs = 5 * 60 * 1000;

class AutoLockDecision {
  const AutoLockDecision({
    required this.shouldLock,
    required this.backgroundMs,
    required this.remainingMs,
    required this.reason,
  });

  final bool shouldLock;
  final int backgroundMs;
  final int remainingMs;
  final String reason;
}

AutoLockDecision decideAutoLock({
  required int backgroundAtMs,
  required int resumedAtMs,
  int thresholdMs = kDefaultAutoLockMs,
}) {
  final elapsed = resumedAtMs - backgroundAtMs;
  if (elapsed < 0) {
    return const AutoLockDecision(
      shouldLock: false,
      backgroundMs: 0,
      remainingMs: 0,
      reason: '时间戳倒退，保守不锁定',
    );
  }
  final shouldLock = elapsed >= thresholdMs;
  return AutoLockDecision(
    shouldLock: shouldLock,
    backgroundMs: elapsed,
    remainingMs: shouldLock ? 0 : thresholdMs - elapsed,
    reason: shouldLock
        ? '后台超过 ${thresholdMs ~/ 60000} 分钟，回到前台自动锁定'
        : '后台时间未达阈值，不锁定',
  );
}
