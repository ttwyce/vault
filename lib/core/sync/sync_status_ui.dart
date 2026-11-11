/// 同步状态 → UI 表现的**纯判定层**（docs/04 §11）。
///
/// 不碰网络、不碰数据库：只把 [SyncPhase] / 错误码 / 冲突数 / 隔离数 /
/// 重试时间映射成横幅文案、颜色与点击动作。UI 按结果渲染即可，
/// 避免每个页面各写一份「同步中…」导致状态口径漂移。
library;

import 'sync_state_machine.dart' show SyncErrorCode, SyncPhase;

enum SyncBannerTone { none, info, progress, warning, danger }

/// 点击横幅后的动作（由 UI 路由）。
enum SyncBannerAction { none, openMerge, openSettings, openConflictQueue }

class SyncBanner {
  const SyncBanner({
    required this.tone,
    required this.text,
    required this.action,
    required this.showProgress,
  });

  final SyncBannerTone tone;
  final String text;
  final SyncBannerAction action;
  final bool showProgress;

  bool get visible => text.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'tone': tone.name,
        'text': text,
        'action': action.name,
        'show_progress': showProgress,
      };
}

/// 设置页「同步诊断」里的补充信息（不影响顶部横幅）。
class SyncDiagnosticsNote {
  const SyncDiagnosticsNote({
    required this.quarantineCount,
    required this.nextRetryText,
  });

  final int quarantineCount;
  final String nextRetryText;

  bool get hasRedDot => quarantineCount > 0;

  Map<String, Object?> toJson() => <String, Object?>{
        'quarantine_count': quarantineCount,
        'next_retry': nextRetryText,
        'red_dot': hasRedDot,
      };
}

/// 主判定。优先级：致命错误 > 冲突 > 隔离提示 > 进行中 > 退避 > IDLE。
///
/// [nextRetryAtMs] / [nowMs] 用本地时间戳；退避横幅静默，只在诊断里
/// 显示下次重试时间（docs/04 §11 BACKOFF 行）。
SyncBanner resolveSyncBanner({
  required SyncPhase phase,
  SyncErrorCode? errorCode,
  int conflicts = 0,
  int pushingCount = 0,
  bool offline = false,
}) {
  if (phase == SyncPhase.failed) {
    return switch (errorCode) {
      SyncErrorCode.auth => const SyncBanner(
          tone: SyncBannerTone.danger,
          text: 'WebDAV 认证失败，点击跳设置',
          action: SyncBannerAction.openSettings,
          showProgress: false,
        ),
      SyncErrorCode.quota => const SyncBanner(
          tone: SyncBannerTone.warning,
          text: '云端空间不足',
          action: SyncBannerAction.openSettings,
          showProgress: false,
        ),
      SyncErrorCode.vaultMismatch => const SyncBanner(
          tone: SyncBannerTone.danger,
          text: '误连了另一个 vault 目录，已停止同步',
          action: SyncBannerAction.openSettings,
          showProgress: false,
        ),
      SyncErrorCode.schemaTooNew => const SyncBanner(
          tone: SyncBannerTone.warning,
          text: '云端 schema 高于本地，请升级后再同步',
          action: SyncBannerAction.openSettings,
          showProgress: false,
        ),
      SyncErrorCode.corrupt ||
      SyncErrorCode.mergeBug ||
      SyncErrorCode.path =>
        const SyncBanner(
          tone: SyncBannerTone.danger,
          text: '同步数据异常，已隔离可疑文件',
          action: SyncBannerAction.openSettings,
          showProgress: false,
        ),
      _ => const SyncBanner(
          tone: SyncBannerTone.danger,
          text: '同步失败，点击查看详情',
          action: SyncBannerAction.openSettings,
          showProgress: false,
        ),
    };
  }
  if (conflicts > 0) {
    return SyncBanner(
      tone: SyncBannerTone.warning,
      text: '有 $conflicts 个冲突待处理，点击进入合并',
      action: SyncBannerAction.openMerge,
      showProgress: false,
    );
  }
  if (phase == SyncPhase.backoff) {
    // 静默：顶部不出现横幅，只在设置页显示下次重试时间。
    return const SyncBanner(
      tone: SyncBannerTone.none,
      text: '',
      action: SyncBannerAction.none,
      showProgress: false,
    );
  }
  if (offline) {
    return const SyncBanner(
      tone: SyncBannerTone.info,
      text: '当前离线，恢复网络后继续同步',
      action: SyncBannerAction.none,
      showProgress: false,
    );
  }
  return switch (phase) {
    SyncPhase.idle => const SyncBanner(
        tone: SyncBannerTone.none,
        text: '',
        action: SyncBannerAction.none,
        showProgress: false,
      ),
    SyncPhase.push => SyncBanner(
        tone: SyncBannerTone.progress,
        text: pushingCount > 0 ? '正在上传 $pushingCount 项…' : '正在上传…',
        action: SyncBannerAction.none,
        showProgress: true,
      ),
    SyncPhase.merge => const SyncBanner(
        tone: SyncBannerTone.progress,
        text: '正在合并云端变更…',
        action: SyncBannerAction.none,
        showProgress: true,
      ),
    _ => const SyncBanner(
        tone: SyncBannerTone.progress,
        text: '同步中…',
        action: SyncBannerAction.none,
        showProgress: true,
      ),
  };
}

/// 设置页诊断补充：隔离文件红点 + 下次重试时间。
SyncDiagnosticsNote resolveSyncDiagnostics({
  required int quarantineCount,
  int? nextRetryAtMs,
  int? nowMs,
}) {
  var retryText = '';
  final next = nextRetryAtMs;
  if (next != null && nowMs != null) {
    final remaining = next - nowMs;
    if (remaining > 0) {
      final seconds = (remaining / 1000).ceil();
      retryText = seconds >= 60
          ? '${(seconds / 60).ceil()} 分钟后重试'
          : '$seconds 秒后重试';
    } else {
      retryText = '即将重试';
    }
  }
  return SyncDiagnosticsNote(
    quarantineCount: quarantineCount,
    nextRetryText: retryText,
  );
}

/// 冲突队列入口：只有冲突数 > 0 时才在设置页出现。
SyncBannerAction? conflictQueueAction(int conflicts) =>
    conflicts > 0 ? SyncBannerAction.openConflictQueue : null;
