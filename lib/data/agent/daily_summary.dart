/// 日总结流水线的纯判定层（docs/07 §5 / §6）。
///
/// 不调模型、不读数据库：只做「活动怎么按条目聚合、时间线怎么排、
/// 周/月/年摘要怎么分层、引用怎么校验、AI 日记怎么隔离」。
/// 端侧模型只负责生成 headline / 反思文本；**绝不编造未发生的事**
/// 由这里的 citations 校验兜底。
library;

/// 聚合后的单条活动（docs/07 §5.2 输入）。
class ActivityDigest {
  const ActivityDigest({
    required this.entryId,
    required this.title,
    required this.views,
    required this.edits,
    required this.clips,
    required this.searches,
    required this.dwellMs,
  });

  final String entryId;
  final String? title;
  final int views;
  final int edits;
  final int clips;
  final int searches;
  final int dwellMs;

  int get dwellMinutes => dwellMs ~/ 60000;

  /// 参与总结的「分量」：编辑 / 剪藏比单纯浏览更重要。
  int get weight => edits * 5 + clips * 4 + views + dwellMinutes;
}

/// 时间线条目。
class TimelineItem {
  const TimelineItem({
    required this.atMs,
    required this.what,
    this.entryId,
  });

  final int atMs;
  final String what;
  final String? entryId;
}

/// 日总结输出（端侧模型生成，这里只定义结构与校验）。
class DailySummary {
  const DailySummary({
    required this.headline,
    required this.timeline,
    required this.openThreads,
    required this.citations,
    required this.date,
  });

  final String headline;
  final List<TimelineItem> timeline;
  final List<String> openThreads;

  /// 引用到的 entry id（UI 每条结论可点开原文）。
  final List<String> citations;
  final String date;

  Map<String, Object?> toJson() => <String, Object?>{
        'headline': headline,
        'timeline': <Map<String, Object?>>[
          for (final item in timeline)
            <String, Object?>{
              'at_ms': item.atMs,
              'what': item.what,
              'entry_id': item.entryId,
            },
        ],
        'open_threads': openThreads,
        'citations': citations,
        'date': date,
      };
}

/// 按分量倒序挑出「今天主要做了什么」的前 N 个条目，作为 prompt 输入。
/// 只带标题与前 100 字的摘要由上层从 entry 读，这里不碰全文。
List<ActivityDigest> rankActivities(
  Iterable<ActivityDigest> activities, {
  int limit = 10,
}) {
  final sorted = activities
      .where((ActivityDigest a) => a.weight > 0)
      .toList()
    ..sort((ActivityDigest a, ActivityDigest b) {
      final byWeight = b.weight.compareTo(a.weight);
      return byWeight != 0 ? byWeight : a.entryId.compareTo(b.entryId);
    });
  return List<ActivityDigest>.unmodifiable(sorted.take(limit));
}

/// 时间线按时间升序，且不允许同一毫秒出现两条相同描述。
List<TimelineItem> normalizeTimeline(Iterable<TimelineItem> items) {
  final sorted = items.toList()
    ..sort((TimelineItem a, TimelineItem b) {
      final byTime = a.atMs.compareTo(b.atMs);
      return byTime != 0 ? byTime : a.what.compareTo(b.what);
    });
  final out = <TimelineItem>[];
  for (final item in sorted) {
    if (out.isNotEmpty &&
        out.last.atMs == item.atMs &&
        out.last.what == item.what) {
      continue;
    }
    out.add(item);
  }
  return List<TimelineItem>.unmodifiable(out);
}

/// 摘要层级（docs/07 §5.3）：查询「去年主要忙什么」只需读 12 条月摘要。
enum SummaryGranularity { day, week, month, year }

/// 下一层摘要需要读多少条（7 日 / 4 周 / 12 月）。
int childCountFor(SummaryGranularity granularity) => switch (granularity) {
      SummaryGranularity.week => 7,
      SummaryGranularity.month => 4,
      SummaryGranularity.year => 12,
      SummaryGranularity.day => 0,
    };

/// 引用校验（docs/07 §6.2）：citations 里不存在的 id 必须剔除，
/// 不能把假引用展示给用户。返回去重后的有效引用。
List<String> validateCitations(
  Iterable<String> citations,
  Set<String> existingEntryIds,
) {
  final seen = <String>{};
  final out = <String>[];
  for (final id in citations) {
    if (existingEntryIds.contains(id) && seen.add(id)) out.add(id);
  }
  return List<String>.unmodifiable(out);
}

/// AI 日记硬规则（docs/07 §6.3）。
abstract final class AiDiaryRules {
  static const int kind = 4;
  static const int userDiaryKind = 3;
  static const int minChars = 150;
  static const int maxChars = 300;

  /// 物理隔离：kind=4 独立视图。
  static bool isAiDiary(int kind) => kind == AiDiaryRules.kind;

  /// 默认检索排除 kind=4；设置里给开关，但必须由调用方显式打开。
  static bool includeInSearch({
    required bool userOptedIn,
  }) =>
      userOptedIn;

  /// **AI 日记不向量化**：否则语义空间会被大量生成文本占据。
  static bool shouldVectorize(int kind) => !isAiDiary(kind);

  /// 可删除 / 可重新生成，但不可编辑。
  static bool isEditable(int kind) => kind == userDiaryKind;

  /// 长度 150~300 字，超出或不足都不合格。
  static bool isValidLength(String text) =>
      text.trim().length >= minChars && text.trim().length <= maxChars;
}
