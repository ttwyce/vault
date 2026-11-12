/// 内容变更检测的成本控制（docs/05 §6.2）。
///
/// 不抓取、不写库：只判定「哪些条目值得每月重抓 L1」、
/// 相似度是否触发变更提示、以及旧版是否保留为 history。
library;

import 'archive_policy.dart' show hasContentChanged;

/// 30 天内访问过（docs/05 §6.2 成本控制）。
const int kRecentlyVisitedMs = 30 * 86400000;

class ChangeCheckCandidate {
  const ChangeCheckCandidate({
    required this.entryId,
    required this.watchChanges,
    required this.lastVisitedAtMs,
    this.previousSimhash,
  });

  final String entryId;
  final bool watchChanges;
  final int? lastVisitedAtMs;
  final String? previousSimhash;
}

/// 「用户手动标记」或「30 天内访问过」才排进重抓队列。
List<String> planChangeCheckBatch(
  Iterable<ChangeCheckCandidate> candidates, {
  required int nowMs,
}) =>
    List<String>.unmodifiable(<String>[
      for (final candidate in candidates)
        if (candidate.watchChanges ||
            (candidate.lastVisitedAtMs != null &&
                nowMs - candidate.lastVisitedAtMs! <= kRecentlyVisitedMs))
          candidate.entryId,
    ]);

enum ContentChangeAction { unchanged, promptChange, firstSnapshot }

class ContentChangePlan {
  const ContentChangePlan({
    required this.action,
    required this.keepPreviousAsHistory,
    required this.hint,
  });

  final ContentChangeAction action;
  final bool keepPreviousAsHistory;
  final String hint;
}

/// 新抓到 simhash 后判定：首次快照不提示变更；汉明距离 > 3 才提示，
/// 且保留旧正文为 history（docs/05 §6.2）。
ContentChangePlan planContentChange({
  required String? previousSimhash,
  required String newSimhash,
  int threshold = 3,
}) {
  if (previousSimhash == null || previousSimhash.isEmpty) {
    return const ContentChangePlan(
      action: ContentChangeAction.firstSnapshot,
      keepPreviousAsHistory: false,
      hint: '首次生成内容指纹，不提示变更',
    );
  }
  final changed = hasContentChanged(
    previousSimhash,
    newSimhash,
    threshold: threshold,
  );
  return ContentChangePlan(
    action: changed
        ? ContentChangeAction.promptChange
        : ContentChangeAction.unchanged,
    keepPreviousAsHistory: changed,
    hint: changed ? '这页内容有变化，已保留旧版可对比' : '内容无实质变化',
  );
}
