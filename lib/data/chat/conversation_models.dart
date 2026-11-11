/// 会话抽屉与草稿态的纯判定层（docs/12 §3 / §5）。
///
/// 不碰数据库、不碰 UI、不碰模型：只决定「会话该归到哪个分组、
/// 点新对话时是否落库、消息按什么顺序追加、标题怎么兜底」。
library;

/// 会话分组。用户自定义分组优先于日期分组（docs/12 §5 ④）。
enum ConversationSection { today, yesterday, thisWeek, earlier }

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.groupId,
    this.groupName,
    this.messageCount = 0,
  });

  final String id;
  final String? title;
  final int updatedAt;
  final String? groupId;
  final String? groupName;
  final int messageCount;
}

class ConversationGroup {
  const ConversationGroup({
    required this.key,
    required this.label,
    required this.conversations,
  });

  /// 用户分组用 `group:<id>`，日期分组用 `date:<section>`。
  final String key;
  final String label;
  final List<ConversationSummary> conversations;
}

/// 日期分组边界按本地日历日计算（nowMs 由调用方传入，便于测试）。
ConversationSection sectionFor(int updatedAtMs, int nowMs) {
  if (updatedAtMs > nowMs) return ConversationSection.today;
  final diff = nowMs - updatedAtMs;
  if (diff < Duration(days: 1).inMilliseconds) {
    return ConversationSection.today;
  }
  if (diff < Duration(days: 2).inMilliseconds) {
    return ConversationSection.yesterday;
  }
  if (diff < Duration(days: 7).inMilliseconds) {
    return ConversationSection.thisWeek;
  }
  return ConversationSection.earlier;
}

const Map<ConversationSection, String> _dateLabels =
    <ConversationSection, String>{
  ConversationSection.today: '今天',
  ConversationSection.yesterday: '昨天',
  ConversationSection.thisWeek: '本周',
  ConversationSection.earlier: '更早',
};

/// 按 docs/12 §5 ④ 分组：用户分组单独成组且不再出现在日期分组里；
/// 组内按 updatedAt 倒序；组之间「用户分组 → 今天 → 昨天 → 本周 → 更早」。
List<ConversationGroup> groupConversations(
  Iterable<ConversationSummary> conversations, {
  required int nowMs,
}) {
  final userGroups = <String, List<ConversationSummary>>{};
  final userNames = <String, String>{};
  final dateGroups = <ConversationSection, List<ConversationSummary>>{
    for (final section in ConversationSection.values)
      section: <ConversationSummary>[],
  };
  for (final conversation in conversations) {
    final groupId = conversation.groupId;
    if (groupId != null && groupId.isNotEmpty) {
      userGroups.putIfAbsent(groupId, () => <ConversationSummary>[])
          .add(conversation);
      if (conversation.groupName != null) {
        userNames[groupId] = conversation.groupName!;
      }
    } else {
      dateGroups[sectionFor(conversation.updatedAt, nowMs)]!.add(conversation);
    }
  }

  List<ConversationSummary> sorted(List<ConversationSummary> list) {
    final copy = List<ConversationSummary>.from(list)
      ..sort((ConversationSummary a, ConversationSummary b) {
        final byTime = b.updatedAt.compareTo(a.updatedAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return copy;
  }

  final out = <ConversationGroup>[];
  final userKeys = userGroups.keys.toList()..sort();
  for (final key in userKeys) {
    out.add(ConversationGroup(
      key: 'group:$key',
      label: userNames[key] ?? '未命名分组',
      conversations: List<ConversationSummary>.unmodifiable(
        sorted(userGroups[key]!),
      ),
    ));
  }
  for (final section in ConversationSection.values) {
    final items = dateGroups[section]!;
    if (items.isEmpty) continue;
    out.add(ConversationGroup(
      key: 'date:${section.name}',
      label: _dateLabels[section]!,
      conversations: List<ConversationSummary>.unmodifiable(sorted(items)),
    ));
  }
  return List<ConversationGroup>.unmodifiable(out);
}

/// 草稿态状态机（docs/12 §5 ②）：T26 不产生空会话记录。
class ConversationDraftState {
  const ConversationDraftState({
    required this.hasDraft,
    required this.currentId,
    required this.persisted,
  });

  /// 是否处于「新对话草稿」（还没发第一条消息）。
  final bool hasDraft;

  final String? currentId;

  /// 是否已经落库。
  final bool persisted;

  static const ConversationDraftState initial = ConversationDraftState(
    hasDraft: false,
    currentId: null,
    persisted: false,
  );

  ConversationDraftState startDraft() => const ConversationDraftState(
        hasDraft: true,
        currentId: null,
        persisted: false,
      );

  /// 只有「处于草稿态且发出第一条消息」才落库；重复调用幂等。
  ConversationDraftState commitFirstMessage(String newId) {
    if (!hasDraft) return this;
    return ConversationDraftState(
      hasDraft: false,
      currentId: newId,
      persisted: true,
    );
  }

  /// 草稿态下切走：直接丢弃，不落库。
  ConversationDraftState discardDraft() => const ConversationDraftState(
        hasDraft: false,
        currentId: null,
        persisted: false,
      );

  ConversationDraftState selectExisting(String id) => ConversationDraftState(
        hasDraft: false,
        currentId: id,
        persisted: true,
      );
}

/// 消息 append-only（docs/12 §6 / T25）：只按 (createdAt, hlc, id) 稳定排序，
/// 绝不改写已存在的消息。
class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.createdAt,
    required this.hlc,
  });

  final String id;
  final int createdAt;
  final String hlc;
}

List<ConversationMessage> orderMessages(
  Iterable<ConversationMessage> messages,
) {
  final out = messages.toList()
    ..sort((ConversationMessage a, ConversationMessage b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      if (byTime != 0) return byTime;
      final byHlc = a.hlc.compareTo(b.hlc);
      return byHlc != 0 ? byHlc : a.id.compareTo(b.id);
    });
  return List<ConversationMessage>.unmodifiable(out);
}

/// 标题兜底：默认取首条消息前 20 字（docs/12 §4.3）。
String deriveConversationTitle(String? title, String? firstMessage) {
  final trimmed = title?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  final first = (firstMessage ?? '').trim();
  if (first.isEmpty) return '新对话';
  return first.length <= 20 ? first : '${first.substring(0, 20)}…';
}
