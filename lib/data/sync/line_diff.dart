/// 行级三方合并的底层算子（docs/04 §5.2）。
///
/// 只处理字符串数组，不认识 `EntrySnapshot`、不碰数据库，
/// 所以「不同段落自动合并 / 同一段落冲突」能直接单测。
library;

import 'dart:math' as math;

/// LCS 的 DP 是 O(n·m)。正文上限 1MB，行数可能上万，
/// 超过这个阈值就交给上层降级成 LWW，不能让一次合并吃几百 MB。
const int kMaxDiffLines = 1200;

class LineDiffTooLarge implements Exception {
  const LineDiffTooLarge(this.baseLines, this.changedLines);

  final int baseLines;
  final int changedLines;

  @override
  String toString() => '行数超过 $kMaxDiffLines（base=$baseLines, '
      'changed=$changedLines），应降级为 LWW';
}

/// base 的 `[baseStart, baseEnd)` 被替换成 [replacement]。
/// `baseStart == baseEnd` 表示纯插入。
class TextHunk {
  const TextHunk(this.baseStart, this.baseEnd, this.replacement);

  final int baseStart;
  final int baseEnd;
  final List<String> replacement;
}

class LineMergeResult {
  const LineMergeResult({required this.lines, required this.hasConflict});

  final List<String> lines;
  final bool hasConflict;

  String get text => lines.join('\n');
}

/// 计算 `base → changed` 的编辑块。
///
/// 用 LCS 找「没变的行」当锚点，锚点之间整段视为一个 hunk。
/// 比逐行 diff 更贴近用户直觉：改一句话就只产生一个块，
/// 不会因为行号整体平移把所有行都标成修改。
List<TextHunk> diffHunks(List<String> base, List<String> changed) {
  if (base.length > kMaxDiffLines || changed.length > kMaxDiffLines) {
    throw LineDiffTooLarge(base.length, changed.length);
  }

  final n = base.length;
  final m = changed.length;
  // dp[i][j] = base[i..n) 与 changed[j..m) 的 LCS 长度
  final dp = List<List<int>>.generate(
    n + 1,
    (_) => List<int>.filled(m + 1, 0),
  );
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = base[i] == changed[j]
          ? dp[i + 1][j + 1] + 1
          : math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }

  final anchors = <List<int>>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (base[i] == changed[j]) {
      anchors.add(<int>[i, j]);
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  final hunks = <TextHunk>[];
  var cursorBase = 0;
  var cursorChanged = 0;
  for (final anchor in anchors) {
    final bi = anchor[0];
    final cj = anchor[1];
    if (bi > cursorBase || cj > cursorChanged) {
      hunks.add(TextHunk(
        cursorBase,
        bi,
        changed.sublist(cursorChanged, cj),
      ));
    }
    cursorBase = bi + 1;
    cursorChanged = cj + 1;
  }
  if (cursorBase < n || cursorChanged < m) {
    hunks.add(TextHunk(
      cursorBase,
      n,
      changed.sublist(cursorChanged, m),
    ));
  }
  return hunks;
}

/// 合并两侧的编辑块。
///
/// 把每个 hunk 映射成 base 行坐标上的影响区间后做扫描线分组：
/// 组里同时出现两端的 hunk ⇒ 重叠 ⇒ 输出冲突标记（两边内容都留）；
/// 只有一端的 hunk ⇒ 正常应用。这样同一篇里「不同段落」能自动合并，
/// 「同一段落」才升级成冲突，不会一有冲突就把整篇都标乱。
LineMergeResult mergeLineHunks({
  required List<String> base,
  required List<TextHunk> local,
  required List<TextHunk> remote,
  required String localLabel,
  required String remoteLabel,
}) {
  final tagged = <_TaggedHunk>[
    for (final h in local) _TaggedHunk(h, true),
    for (final h in remote) _TaggedHunk(h, false),
  ]..sort((_TaggedHunk a, _TaggedHunk b) =>
      a.hunk.baseStart.compareTo(b.hunk.baseStart));

  final groups = <_Group>[];
  for (final item in tagged) {
    final lo = item.hunk.baseStart;
    final hi = _hi(item.hunk);
    if (groups.isEmpty || lo >= groups.last.hi) {
      groups.add(_Group(lo, hi, <_TaggedHunk>[item]));
    } else {
      final group = groups.last;
      group.hi = math.max(group.hi, hi);
      group.items.add(item);
    }
  }

  final out = <String>[];
  var cursor = 0;
  var hasConflict = false;

  for (final group in groups) {
    final lo = _clamp(group.lo, cursor, base.length);
    final hi = _clamp(group.hi, lo, base.length);
    if (lo < cursor) continue;
    if (lo > cursor) out.addAll(base.sublist(cursor, lo));

    final slice = base.sublist(lo, hi);
    final localHunks = <TextHunk>[];
    final remoteHunks = <TextHunk>[];
    for (final item in group.items) {
      final shifted = TextHunk(
        item.hunk.baseStart - lo,
        item.hunk.baseEnd - lo,
        item.hunk.replacement,
      );
      (item.isLocal ? localHunks : remoteHunks).add(shifted);
    }

    if (localHunks.isNotEmpty && remoteHunks.isNotEmpty) {
      hasConflict = true;
      out.add('<<<<<<< 本地（$localLabel）');
      out.addAll(_applyHunks(slice, localHunks));
      out.add('=======');
      out.addAll(_applyHunks(slice, remoteHunks));
      out.add('>>>>>>> 云端（$remoteLabel）');
    } else {
      out.addAll(_applyHunks(
        slice,
        <TextHunk>[...localHunks, ...remoteHunks],
      ));
    }
    cursor = hi;
  }

  out.addAll(base.sublist(cursor));
  return LineMergeResult(lines: out, hasConflict: hasConflict);
}

/// 插入点 `[p, p)` 扩展成 `[p, p+1)` 才能和覆盖该位置的删除块判重叠。
int _hi(TextHunk h) =>
    h.baseEnd > h.baseStart ? h.baseEnd : h.baseStart + 1;

int _clamp(int value, int lo, int hi) =>
    value < lo ? lo : (value > hi ? hi : value);

List<String> _applyHunks(List<String> lines, List<TextHunk> hunks) {
  final sorted = List<TextHunk>.from(hunks)
    ..sort((TextHunk a, TextHunk b) {
      final byStart = a.baseStart.compareTo(b.baseStart);
      return byStart != 0 ? byStart : a.baseEnd.compareTo(b.baseEnd);
    });

  final out = <String>[];
  var cursor = 0;
  for (final h in sorted) {
    final start = _clamp(h.baseStart, 0, lines.length);
    final end = _clamp(h.baseEnd, start, lines.length);
    if (start < cursor) {
      // 与前一个块交叠：不重复复制 base，只把替换内容接在后面
      out.addAll(h.replacement);
      cursor = math.max(cursor, end);
      continue;
    }
    out.addAll(lines.sublist(cursor, start));
    out.addAll(h.replacement);
    cursor = end;
  }
  out.addAll(lines.sublist(cursor));
  return out;
}

class _TaggedHunk {
  const _TaggedHunk(this.hunk, this.isLocal);
  final TextHunk hunk;
  final bool isLocal;
}

class _Group {
  _Group(this.lo, this.hi, this.items);
  final int lo;
  int hi;
  final List<_TaggedHunk> items;
}
