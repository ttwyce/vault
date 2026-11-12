/// Agent 失败 / 超时的降级提示（docs/07 §11 C6）。
///
/// 不发请求、不调模型：只把停止原因翻译成用户可见文案，
/// 并明确「检索仍可用 / AI 回答不可用」的边界。
library;

import 'agent_loop.dart' show LoopStop;

enum AgentFailureKind { none, timeout, network, modelError, quota }

class AgentFallbackHint {
  const AgentFallbackHint({
    required this.title,
    required this.detail,
    required this.retryable,
    required this.searchStillUsable,
  });

  final String title;
  final String detail;
  final bool retryable;
  final bool searchStillUsable;
}

AgentFallbackHint planAgentFallback({
  required LoopStop stoppedBy,
  AgentFailureKind failure = AgentFailureKind.none,
  bool hasFtsResults = false,
}) {
  if (failure == AgentFailureKind.timeout) {
    return const AgentFallbackHint(
      title: 'AI 回答超时',
      detail: '已停止本轮工具调用；关键词检索仍然可用，可稍后重试',
      retryable: true,
      searchStillUsable: true,
    );
  }
  if (failure == AgentFailureKind.network) {
    return const AgentFallbackHint(
      title: '网络不可用',
      detail: '端侧功能与关键词检索不受影响；恢复网络后可重试 AI 回答',
      retryable: true,
      searchStillUsable: true,
    );
  }
  if (failure == AgentFailureKind.modelError) {
    return const AgentFallbackHint(
      title: '模型返回异常',
      detail: '本轮回答未生成，原始条目未改动；可重试或改用关键词检索',
      retryable: true,
      searchStillUsable: true,
    );
  }
  if (failure == AgentFailureKind.quota) {
    return const AgentFallbackHint(
      title: '已达今日 AI 预算',
      detail: '不再发起云端调用；关键词检索与本地功能继续可用',
      retryable: false,
      searchStillUsable: true,
    );
  }
  return switch (stoppedBy) {
    LoopStop.maxTurns => AgentFallbackHint(
        title: '工具调用已达 6 轮上限',
        detail: '已停止循环防止无限烧 token；'
            '${hasFtsResults ? "检索结果可直接查看" : "可换个说法重试"}',
        retryable: true,
        searchStillUsable: true,
      ),
    LoopStop.denied => const AgentFallbackHint(
        title: '已按安全边界拒绝',
        detail: '该操作涉及禁止数据，本轮不继续；其它功能不受影响',
        retryable: false,
        searchStillUsable: true,
      ),
    LoopStop.needsConfirm => const AgentFallbackHint(
        title: '等待你确认',
        detail: '确认卡已展示完整预览，取消即可停止本轮',
        retryable: false,
        searchStillUsable: true,
      ),
    LoopStop.planExhausted => const AgentFallbackHint(
        title: '本轮完成',
        detail: '无失败与降级',
        retryable: false,
        searchStillUsable: true,
      ),
  };
}
