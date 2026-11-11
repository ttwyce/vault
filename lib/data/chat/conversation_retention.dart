/// 会话表膨胀的**纯判定层**（docs/09 R15）。
///
/// 不写库、不删消息：只定义「一次加载多少条、翻页游标怎么算、
/// 90 天前的会话该不该归档为摘要、摘要保留几条原文」。
/// 真实归档任务与摘要生成由平台层按这里的计划执行。
library;

/// 默认分页大小与 90 天阈值。
const int kMessagePageSize = 50;
const int kConversationArchiveDays = 90;

/// 分页窗口：`beforeMs` 为空表示最新一页，否则取更早的消息。
class MessagePagePlan {
  const MessagePagePlan({
    required this.limit,
    required this.beforeMs,
  });

  final int limit;
  final int? beforeMs;

  static MessagePagePlan latest({int limit = kMessagePageSize}) =>
      MessagePagePlan(limit: _clampLimit(limit), beforeMs: null);

  MessagePagePlan older(int oldestCreatedAt, {int limit = kMessagePageSize}) =>
      MessagePagePlan(
        limit: _clampLimit(limit),
        beforeMs: oldestCreatedAt,
      );

  static int _clampLimit(int limit) =>
      limit <= 0 ? kMessagePageSize : (limit > 200 ? 200 : limit);
}

enum ConversationArchiveAction { keep, archiveToSummary }

class ConversationArchivePlan {
  const ConversationArchivePlan({
    required this.action,
    required this.reason,
    this.keepRecentMessages = 0,
  });

  final ConversationArchiveAction action;
  final String reason;
  final int keepRecentMessages;
}

/// 90 天前、且最近没有更新的会话 → 归档为摘要。
/// 归档时只保留最近 N 条原文（默认 5），其余由摘要覆盖。
ConversationArchivePlan planConversationArchive({
  required int updatedAtMs,
  required int nowMs,
  int messageCount = 0,
  int archiveAfterDays = kConversationArchiveDays,
  int keepRecentMessages = 5,
}) {
  final age = nowMs - updatedAtMs;
  final threshold = archiveAfterDays * 86400000;
  if (age <= threshold || messageCount == 0) {
    return const ConversationArchivePlan(
      action: ConversationArchiveAction.keep,
      reason: '会话仍在保留期内或无消息',
    );
  }
  return ConversationArchivePlan(
    action: ConversationArchiveAction.archiveToSummary,
    reason: '超过 $archiveAfterDays 天未更新，归档为摘要，'
        '仅保留最近 $keepRecentMessages 条原文',
    keepRecentMessages:
        keepRecentMessages < messageCount ? keepRecentMessages : messageCount,
  );
}

/// 批量：返回需要归档的会话 id（按 updatedAt 升序，最老的先处理）。
List<String> planArchiveBatch(
  Map<String, int> updatedAtById, {
  required int nowMs,
  required Map<String, int> messageCountById,
  int archiveAfterDays = kConversationArchiveDays,
}) {
  final candidates = <(String, int)>[
    for (final entry in updatedAtById.entries)
      if (planConversationArchive(
            updatedAtMs: entry.value,
            nowMs: nowMs,
            messageCount: messageCountById[entry.key] ?? 0,
            archiveAfterDays: archiveAfterDays,
          ).action ==
          ConversationArchiveAction.archiveToSummary)
        (entry.key, entry.value),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return <String>[for (final item in candidates) item.$1];
}
