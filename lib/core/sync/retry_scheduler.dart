/// 退避重试驱动（docs/04 §7 / §10）。
///
/// `SyncEngine` 只负责把一次 E_NET / E_RATE 推进到 [SyncPhase.backoff]，
/// 此前没有任何东西真正「等一会儿再跑一次」。这一层把重试循环做成
/// **可注入时钟的纯 Dart 调度器**：生产接 `Future.delayed`，测试接假时钟，
/// 于是 T09 / T14 的「退避后成功、无数据损坏」能确定性验证，不依赖真实
/// 定时器或网络。
library;

import 'sync_engine.dart';
import 'sync_runtime.dart';
import 'sync_state_machine.dart';

/// 一次重试循环的结果。
class RetryRunResult {
  const RetryRunResult({
    required this.attempts,
    required this.delays,
    required this.results,
    required this.finalResult,
    required this.stoppedBecause,
  });

  final int attempts;
  final List<Duration> delays;
  final List<SyncRunResult> results;
  final SyncRunResult finalResult;
  final String stoppedBecause;

  bool get succeeded => finalResult.isIdle && !finalResult.skipped;
}

/// 把一次 `SyncEngine.run` 包装成可重试的同步轮次。
///
/// - 只有 [SyncPhase.backoff] 会重试；FAILED / IDLE / 跳过都立即停
/// - 每次等待时长由 [BackoffPolicy.delayFor] 给出，可重试错误码从结果里取
/// - 超过 `maxRetries` 后返回最后一轮结果，不再无休止重试
/// - 单飞锁跳过不算失败，也不消耗重试次数
class RetryScheduler {
  const RetryScheduler({
    this.policy = const BackoffPolicy(),
    this.sleep = _defaultSleep,
  });

  final BackoffPolicy policy;

  /// 可注入的等待函数。测试里可以只累积时长、不真的睡着。
  final Future<void> Function(Duration delay) sleep;

  static Future<void> _defaultSleep(Duration delay) =>
      Future<void>.delayed(delay);

  Future<RetryRunResult> run(
    Future<SyncRunResult> Function() attempt,
  ) async {
    final results = <SyncRunResult>[];
    final delays = <Duration>[];

    // maxRetries 是**总尝试次数**上限：第 maxRetries 次仍 BACKOFF 就停，
    // 不再 sleep 也不再调用 attempt，避免「最多 5 次重试却跑 6 轮」的歧义。
    for (var attemptNumber = 1;
        attemptNumber <= policy.maxRetries;
        attemptNumber++) {
      final result = await attempt();
      results.add(result);

      if (!result.isBackoff) {
        return RetryRunResult(
          attempts: attemptNumber,
          delays: List<Duration>.unmodifiable(delays),
          results: List<SyncRunResult>.unmodifiable(results),
          finalResult: result,
          stoppedBecause: _stopReason(result),
        );
      }
      if (attemptNumber >= policy.maxRetries) {
        return RetryRunResult(
          attempts: attemptNumber,
          delays: List<Duration>.unmodifiable(delays),
          results: List<SyncRunResult>.unmodifiable(results),
          finalResult: result,
          stoppedBecause: '超过最大重试次数 ${policy.maxRetries}',
        );
      }

      final delay = policy.delayFor(_backoffCode(result), attemptNumber);
      delays.add(delay);
      await sleep(delay);
    }
    // 循环内第 maxRetries 次必定返回；这里只是满足分析器的兜底。
    return RetryRunResult(
      attempts: results.length,
      delays: List<Duration>.unmodifiable(delays),
      results: List<SyncRunResult>.unmodifiable(results),
      finalResult: results.last,
      stoppedBecause: '超过最大重试次数 ${policy.maxRetries}',
    );
  }

  SyncErrorCode _backoffCode(SyncRunResult result) {
    final code = result.retryCode;
    if (code == null || !policy.canRetry(code)) {
      // 没有显式错误码或不可重试错误都不该进 BACKOFF；保守按 E_NET 处理，
      // 但 shouldRetry 会在下一轮把这种异常组合收敛掉。
      return SyncErrorCode.net;
    }
    return code;
  }

  String _stopReason(SyncRunResult result) {
    if (result.skipped) return '单飞锁跳过：本轮不重试';
    if (result.isFailed) return '不可重试的致命错误';
    if (result.isIdle) return '同步完成';
    return '进入 ${result.state.phase.name}，不重试';
  }
}
