/// 两个历史版本的行级对比展示（docs/10 第 23 屏）。
///
/// 不碰数据库：把 `line_diff.dart` 的 hunks 翻译成可读的 +/- 行，
/// 供「版本对比」弹窗渲染。超过行数上限时明确降级，不假装可对比。
library;

import 'line_diff.dart';

enum DiffLineKind { context, added, removed }

class DiffLine {
  const DiffLine({
    required this.kind,
    required this.text,
    required this.oldNumber,
    required this.newNumber,
  });

  final DiffLineKind kind;
  final String text;
  final int? oldNumber;
  final int? newNumber;

  String get marker => switch (kind) {
        DiffLineKind.context => ' ',
        DiffLineKind.added => '+',
        DiffLineKind.removed => '-',
      };
}

class VersionDiffView {
  const VersionDiffView({
    required this.lines,
    required this.addedCount,
    required this.removedCount,
    required this.degraded,
  });

  final List<DiffLine> lines;
  final int addedCount;
  final int removedCount;
  final bool degraded;

  String get summary => degraded
      ? '版本过大，已降级为统计视图'
      : '+$addedCount / -$removedCount';
}

/// 从旧版本 [before] 到新版本 [after] 的展示行。
/// 行数超过阈值时只返回统计（不跑 O(n·m) DP）。
VersionDiffView buildVersionDiff(
  String before,
  String after, {
  int maxLines = kMaxDiffLines,
}) {
  final oldLines = before.split('\n');
  final newLines = after.split('\n');
  if (oldLines.length > maxLines || newLines.length > maxLines) {
    return const VersionDiffView(
      lines: <DiffLine>[],
      addedCount: 0,
      removedCount: 0,
      degraded: true,
    );
  }
  final hunks = diffHunks(oldLines, newLines);
  final out = <DiffLine>[];
  var oldCursor = 0;
  var newCursor = 0;
  var added = 0;
  var removed = 0;
  for (final hunk in hunks) {
    // 变化的上下文行。
    final contextStart = oldCursor;
    for (var i = oldCursor; i < hunk.baseStart; i++) {
      out.add(DiffLine(
        kind: DiffLineKind.context,
        text: oldLines[i],
        oldNumber: i + 1,
        newNumber: newCursor + (i - contextStart) + 1,
      ));
    }
    newCursor += hunk.baseStart - oldCursor;
    // 删除行。
    for (var i = hunk.baseStart; i < hunk.baseEnd; i++) {
      out.add(DiffLine(
        kind: DiffLineKind.removed,
        text: oldLines[i],
        oldNumber: i + 1,
        newNumber: null,
      ));
      removed++;
    }
    // 新增行。
    for (final line in hunk.replacement) {
      out.add(DiffLine(
        kind: DiffLineKind.added,
        text: line,
        oldNumber: null,
        newNumber: newCursor + 1,
      ));
      newCursor++;
      added++;
    }
    oldCursor = hunk.baseEnd;
  }
  for (var i = oldCursor; i < oldLines.length; i++) {
    out.add(DiffLine(
      kind: DiffLineKind.context,
      text: oldLines[i],
      oldNumber: i + 1,
      newNumber: newCursor + (i - oldCursor) + 1,
    ));
  }
  return VersionDiffView(
    lines: List<DiffLine>.unmodifiable(out),
    addedCount: added,
    removedCount: removed,
    degraded: false,
  );
}
