/// 同步状态机（docs/04 §4）。
///
/// 这是**纯函数**，不碰网络、不碰数据库、不持有锁。
/// 状态转移表单独抽出来的原因和 `resolveGateScreen` 一样：
/// 同步出错时最容易怀疑的是「状态机是不是走错了一步」，
/// 能单测的状态表把这一整类问题从排障清单里划掉。
///
/// 非法事件直接抛 [StateError] 而不是悄悄忽略：
/// 事件与状态不匹配说明调用方有 bug，静默吞掉会让同步卡在一个
/// 永远没人知道的状态里。
library;

/// 13 个状态（docs/04 §4.1）。
enum SyncPhase {
  idle,
  acquireLock,
  probe,
  discover,
  pullTombstones,
  pullMeta,
  pullEntries,
  merge,
  push,
  verify,
  publish,
  backoff,
  failed,
}

/// 触发状态转移的事件。
///
/// 事件名写的是**判据的结果**而不是 HTTP 响应，
/// 这样状态机不需要知道 412 / 429 / 507 这些数字。
enum SyncEvent {
  trigger,
  lockBusy,
  lockAcquired,
  /// 无变化，且 oplog 无待发。
  probeQuiet,
  /// 无变化，但本地有待推送的 oplog。
  probePendingOnly,
  /// 远端水位前进了，或出现了未知设备。
  probeChanged,
  discoverDone,
  /// DISCOVER 阶段请求超预算：先推本地，剩余下次续跑。
  discoverBudgetExceeded,
  tombstonesDone,
  metaVaultMismatch,
  metaSchemaTooNew,
  metaOk,
  pullDone,
  mergeDone,
  /// 合并产生了冲突副本（已落库），仍继续 PUSH。
  mergeDoneWithConflicts,
  pushDone,
  /// If-Match 412：重新拉取该条并再合并。
  pushPreconditionFailed,
  /// 412 超过 3 轮：生成冲突副本后继续校验。
  pushPreconditionExhausted,
  networkError,
  rateLimited,
  verifyOk,
  verifyHashMismatch,
  publishDone,
  backoffElapsed,
  retriesExceeded,
  /// E_AUTH / E_QUOTA / E_CORRUPT 等不可重试的致命错误。
  fatalError,
}

/// 错误码。写入 `sync_log.error_code` 与 UI 提示都从这里取，
/// 避免三处各写一份字符串。
enum SyncErrorCode {
  auth,
  net,
  rate,
  quota,
  conflict,
  corrupt,
  vaultMismatch,
  schemaTooNew,
  mergeBug,
  path,
}

extension SyncErrorCodeWire on SyncErrorCode {
  String get wire => switch (this) {
        SyncErrorCode.auth => 'E_AUTH',
        SyncErrorCode.net => 'E_NET',
        SyncErrorCode.rate => 'E_RATE',
        SyncErrorCode.quota => 'E_QUOTA',
        SyncErrorCode.conflict => 'E_CONFLICT',
        SyncErrorCode.corrupt => 'E_CORRUPT',
        SyncErrorCode.vaultMismatch => 'E_VAULT_MISMATCH',
        SyncErrorCode.schemaTooNew => 'E_SCHEMA_TOO_NEW',
        SyncErrorCode.mergeBug => 'E_MERGE_BUG',
        SyncErrorCode.path => 'E_PATH',
      };
}

class SyncState {
  const SyncState(this.phase, {this.error});

  final SyncPhase phase;
  final SyncErrorCode? error;

  bool get isTerminal => phase == SyncPhase.failed;
  bool get isIdle => phase == SyncPhase.idle;

  @override
  String toString() => error == null
      ? 'SyncState(${phase.name})'
      : 'SyncState(${phase.name}, ${error!.wire})';
}

/// 按 docs/04 §4.2 的转移表推进一格。
///
/// [error] 只在 [SyncEvent.fatalError] 时必须提供；
/// 其它导致 FAILED 的事件有固定错误码。
SyncState syncTransition(
  SyncState state,
  SyncEvent event, {
  SyncErrorCode? error,
}) {
  final next = _nextPhase(state.phase, event);
  return SyncState(
    next,
    error: next == SyncPhase.failed
        ? (error ?? _failureCode(event))
        : null,
  );
}

SyncPhase _nextPhase(SyncPhase phase, SyncEvent event) {
  final key = (phase, event);
  return switch (key) {
    // IDLE
    (SyncPhase.idle, SyncEvent.trigger) => SyncPhase.acquireLock,

    // ACQUIRE_LOCK：锁被占用就跳过本次，不排队堆积
    (SyncPhase.acquireLock, SyncEvent.lockBusy) => SyncPhase.idle,
    (SyncPhase.acquireLock, SyncEvent.lockAcquired) => SyncPhase.probe,

    // PROBE
    (SyncPhase.probe, SyncEvent.probeQuiet) => SyncPhase.publish,
    (SyncPhase.probe, SyncEvent.probePendingOnly) => SyncPhase.push,
    (SyncPhase.probe, SyncEvent.probeChanged) => SyncPhase.discover,

    // DISCOVER
    (SyncPhase.discover, SyncEvent.discoverDone) =>
      SyncPhase.pullTombstones,
    (SyncPhase.discover, SyncEvent.discoverBudgetExceeded) =>
      SyncPhase.push,

    // PULL：墓碑必须在条目之前
    (SyncPhase.pullTombstones, SyncEvent.tombstonesDone) =>
      SyncPhase.pullMeta,
    (SyncPhase.pullMeta, SyncEvent.metaVaultMismatch) => SyncPhase.failed,
    (SyncPhase.pullMeta, SyncEvent.metaSchemaTooNew) => SyncPhase.failed,
    (SyncPhase.pullMeta, SyncEvent.metaOk) => SyncPhase.pullEntries,
    (SyncPhase.pullEntries, SyncEvent.pullDone) => SyncPhase.merge,

    // MERGE
    (SyncPhase.merge, SyncEvent.mergeDone) => SyncPhase.push,
    (SyncPhase.merge, SyncEvent.mergeDoneWithConflicts) => SyncPhase.push,

    // PUSH
    (SyncPhase.push, SyncEvent.pushDone) => SyncPhase.verify,
    (SyncPhase.push, SyncEvent.pushPreconditionFailed) =>
      SyncPhase.pullEntries,
    (SyncPhase.push, SyncEvent.pushPreconditionExhausted) =>
      SyncPhase.verify,
    (SyncPhase.push, SyncEvent.networkError) => SyncPhase.backoff,
    (SyncPhase.push, SyncEvent.rateLimited) => SyncPhase.backoff,

    // VERIFY
    (SyncPhase.verify, SyncEvent.verifyOk) => SyncPhase.publish,
    (SyncPhase.verify, SyncEvent.verifyHashMismatch) => SyncPhase.failed,

    // PUBLISH
    (SyncPhase.publish, SyncEvent.publishDone) => SyncPhase.idle,

    // BACKOFF
    (SyncPhase.backoff, SyncEvent.backoffElapsed) => SyncPhase.probe,
    (SyncPhase.backoff, SyncEvent.retriesExceeded) => SyncPhase.failed,

    // 任何阶段都可能撞上不可重试的错误（401 / 507 / 解密失败）
    (_, SyncEvent.fatalError) => SyncPhase.failed,

    _ => throw StateError(
        '非法同步事件：${phase.name} + ${event.name}。'
        '检查调用方，或补齐 docs/04 §4.2 的转移表'),
  };
}

SyncErrorCode? _failureCode(SyncEvent event) => switch (event) {
      SyncEvent.metaVaultMismatch => SyncErrorCode.vaultMismatch,
      SyncEvent.metaSchemaTooNew => SyncErrorCode.schemaTooNew,
      SyncEvent.verifyHashMismatch => SyncErrorCode.mergeBug,
      SyncEvent.retriesExceeded => SyncErrorCode.net,
      SyncEvent.fatalError => SyncErrorCode.corrupt,
      _ => null,
    };
