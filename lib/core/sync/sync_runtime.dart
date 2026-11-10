/// 同步的三条运行时约束（docs/04 §10）：
/// 单飞锁、请求预算、退避。全是纯 Dart，方便把「超时/限流/并发触发」
/// 这些最容易在真机上偶发的问题变成确定性单测。
library;

import 'sync_state_machine.dart';

/// 全局 mutex。**锁被占用时直接跳过，不排队**。
///
/// 排队看起来更"不丢触发"，但前台、编辑 debounce、定时器会同时触发，
/// 一排队就会堆积出几十次同步，反而把请求预算和限流打爆。
class SingleFlightLock {
  bool _held = false;

  bool get isHeld => _held;

  bool tryAcquire() {
    if (_held) return false;
    _held = true;
    return true;
  }

  void release() {
    _held = false;
  }

  /// 持锁执行。拿不到锁直接返回 [skipped]，不等待。
  ///
  /// `finally` 里释放是硬要求：MERGE 抛异常却没解锁的话，
  /// 这台设备此后永远不会再同步，而且现象只是"同步不动了"。
  Future<T> run<T>(Future<T> Function() body, {required T skipped}) async {
    if (!tryAcquire()) return skipped;
    try {
      return await body();
    } finally {
      release();
    }
  }
}

/// 单次同步的请求预算。默认 200（docs/04 §10）。
///
/// 超预算不抛异常，而是返回 false 让调用方保存游标、下次续跑 ——
/// 抛异常会走 BACKOFF，但这里根本没有网络错误可退避。
class RequestBudget {
  RequestBudget({this.limit = 200}) {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', '预算必须为正');
    }
  }

  final int limit;
  int _used = 0;

  int get used => _used;
  int get remaining => limit - _used;
  bool get exhausted => _used >= limit;

  /// 预留 [count] 个请求。预算不足时返回 false 且**不消耗**。
  bool tryConsume([int count = 1]) {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', '每次至少消耗 1 个请求');
    }
    if (_used + count > limit) return false;
    _used += count;
    return true;
  }

  void reset() => _used = 0;
}

/// 指数退避（docs/04 §10）。
///
/// | 错误 | 首次 | 倍率 | 上限 |
/// |---|---|---|---|
/// | E_NET | 1s | ×2 | 5min |
/// | E_RATE | 30s | ×2 | 10min |
///
/// E_AUTH / E_QUOTA 等**不允许退避**：文档明确要求停止同步并禁用自动重试，
/// 这里直接抛错，避免调用方拿它们去 `Timer` 上死循环。
class BackoffPolicy {
  const BackoffPolicy({this.maxRetries = 5});

  final int maxRetries;

  static const Duration _netBase = Duration(seconds: 1);
  static const Duration _netCap = Duration(minutes: 5);
  static const Duration _rateBase = Duration(seconds: 30);
  static const Duration _rateCap = Duration(minutes: 10);

  bool canRetry(SyncErrorCode code) =>
      code == SyncErrorCode.net || code == SyncErrorCode.rate;

  /// [attempt] 从 1 开始（第一次重试）。
  Duration delayFor(SyncErrorCode code, int attempt) {
    if (!canRetry(code)) {
      throw ArgumentError.value(code, 'code', '只有 E_NET / E_RATE 可以退避');
    }
    if (attempt < 1) {
      throw ArgumentError.value(attempt, 'attempt', 'attempt 从 1 开始');
    }

    final base = code == SyncErrorCode.net ? _netBase : _rateBase;
    final cap = code == SyncErrorCode.net ? _netCap : _rateCap;
    var micros = base.inMicroseconds;
    for (var i = 1; i < attempt; i++) {
      if (micros >= cap.inMicroseconds) break;
      micros *= 2;
    }
    return Duration(
      microseconds: micros > cap.inMicroseconds ? cap.inMicroseconds : micros,
    );
  }

  bool shouldRetry(SyncErrorCode code, int attempt) =>
      canRetry(code) && attempt <= maxRetries;
}
