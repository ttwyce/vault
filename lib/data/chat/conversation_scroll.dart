/// 会话切换后的滚动目标（docs/12 §5 ③ / R15 分页）。
///
/// 文档写的是 `jumpTo(maxExtent)`（定位到最新消息）；分页后一页最多 50 条
/// 且按 append-only 正序渲染，最新消息在底部。这里把「目标位置」写成
/// 可测判定，UI 在消息 Future 完成后按结果执行，避免两处口径漂移。
library;

enum ConversationScrollTarget { top, latestBottom }

class ConversationScrollPlan {
  const ConversationScrollPlan({
    required this.target,
    required this.reason,
  });

  final ConversationScrollTarget target;
  final String reason;

  bool get goToBottom => target == ConversationScrollTarget.latestBottom;
}

/// - 草稿 / 无会话 → 顶部
/// - 选中已有会话且 [messageCount] > 0 → 底部（最新消息）
/// - 空会话 → 顶部
ConversationScrollPlan planConversationScroll({
  required String? conversationId,
  required int messageCount,
  bool isDraft = false,
}) {
  if (isDraft || conversationId == null || messageCount == 0) {
    return const ConversationScrollPlan(
      target: ConversationScrollTarget.top,
      reason: '草稿 / 空会话，回顶部',
    );
  }
  return const ConversationScrollPlan(
    target: ConversationScrollTarget.latestBottom,
    reason: '定位到最新消息（append-only 正序渲染，最新在底部）',
  );
}

/// 把目标换算成实际 offset。切换瞬间先回顶部，加载完成后再到底部：
/// [hasMessages] 为 false 时统一返回 0，避免旧 offset 被沿用。
double scrollOffsetFor(
  ConversationScrollPlan plan, {
  required double maxExtent,
  required bool hasMessages,
}) =>
    hasMessages && plan.goToBottom && maxExtent > 0 ? maxExtent : 0.0;
