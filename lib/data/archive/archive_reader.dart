/// 归档阅读器的纯判定层（docs/05 §9）。
///
/// 不渲染 Markdown / PDF、不碰平台通道：只决定「这个条目现在该用哪种模式、
/// 哪些模式不可点、高亮怎么合并、划词能不能问 AI」。
/// 接入层按这里的判定去加载 L1 正文 / L2 PDF / 并排 diff。
library;

import 'archive_meta.dart';

/// 阅读器三模式。
enum ReaderMode { clean, original, compare }

class ReaderAvailability {
  const ReaderAvailability({
    required this.modes,
    required this.reasons,
  });

  final List<ReaderMode> modes;
  final List<String> reasons;

  bool can(ReaderMode mode) => modes.contains(mode);
}

/// 根据归档状态与本地 blob 可用性判定可用模式。
///
/// - 纯净模式（L1 正文）只要有正文层就可用，永远排第一
/// - 原貌模式要求 L2 PDF 快照已本地下载（`local=1`）
/// - 对比模式要求「内容确实变更过」且有新旧两版正文
ReaderAvailability resolveReaderModes({
  required ArchiveMeta meta,
  required bool pdfLocal,
  required bool hasPreviousTextVersion,
}) {
  final modes = <ReaderMode>[];
  final reasons = <String>[];
  if (meta.hasText || meta.status == ArchiveStatus.dead) {
    modes.add(ReaderMode.clean);
  } else {
    reasons.add('还没有 L1 正文层：只能看元数据');
  }
  if (pdfLocal && meta.hasSnapshot) {
    modes.add(ReaderMode.original);
  } else if (meta.hasSnapshot) {
    reasons.add('PDF 快照仅在云端：点「原貌」需先按需下载');
  } else {
    reasons.add('本条目没有 PDF 快照');
  }
  if (meta.changed && hasPreviousTextVersion) {
    modes.add(ReaderMode.compare);
  } else if (meta.changed) {
    reasons.add('检测到内容变更，但本地没有上一版正文可对比');
  }
  if (meta.isDeadLink) {
    reasons.add('原站已失效：建议回退快照 / Wayback');
  }
  return ReaderAvailability(
    modes: List<ReaderMode>.unmodifiable(modes),
    reasons: List<String>.unmodifiable(reasons),
  );
}

/// 用户点了不可用的模式时，退到哪个模式（永不空白页）。
///
/// 一个模式都没有时仍返回 `clean`：接入层会渲染「仅元数据」空状态，
/// 而不是落到一个同样不可用的 compare 模式上。
ReaderMode fallbackReaderMode(ReaderAvailability availability) =>
    availability.can(ReaderMode.clean)
        ? ReaderMode.clean
        : (availability.can(ReaderMode.original)
            ? ReaderMode.original
            : ReaderMode.clean);

/// 底部状态条文案。
String readerStatusLine({
  required ArchiveMeta meta,
  required int archivedAtMs,
  required String Function(int millis) formatDate,
}) {
  final status = meta.isDeadLink
      ? '原站已失效'
      : meta.status == ArchiveStatus.blocked ||
              meta.status == ArchiveStatus.paywalled
          ? '访问受限'
          : '原站存活';
  return '归档于 ${formatDate(archivedAtMs)} · 原站状态：$status';
}

/// 高亮区间合并：重叠 / 相邻的两段合成一段，避免同一句话存多条。
/// offsets 按升序输出，text 取最早那段的文本（保留用户原文）。
List<ArchiveHighlight> mergeHighlights(Iterable<ArchiveHighlight> highlights) {
  final sorted = highlights.toList()
    ..sort((ArchiveHighlight a, ArchiveHighlight b) {
      final byOffset = a.offset.compareTo(b.offset);
      return byOffset != 0 ? byOffset : a.text.compareTo(b.text);
    });
  final out = <ArchiveHighlight>[];
  for (final highlight in sorted) {
    if (highlight.offset < 0 || highlight.text.isEmpty) continue;
    if (out.isEmpty) {
      out.add(highlight);
      continue;
    }
    final last = out.last;
    final lastEnd = last.offset + last.text.length;
    final end = highlight.offset + highlight.text.length;
    if (highlight.offset <= lastEnd) {
      // 重叠 / 相邻：保留最早 offset，长度取两段覆盖到的最远位置。
      // text 只是 UI 预览用的片段，不做脆弱的字符级拼接。
      final mergedLength = (end > lastEnd ? end : lastEnd) - last.offset;
      out[out.length - 1] = ArchiveHighlight(
        text: last.text.length >= mergedLength
            ? last.text
            : '${last.text}…',
        offset: last.offset,
        note: last.note ?? highlight.note,
      );
    } else {
      out.add(highlight);
    }
  }
  return List<ArchiveHighlight>.unmodifiable(out);
}

/// 划词能否「问 AI」：太短 / 太长 / 落在密码类条目上一律拒绝。
bool canAskAiAboutSelection(String selection, {int maxChars = 2000}) {
  final trimmed = selection.trim();
  return trimmed.length >= 2 && trimmed.length <= maxChars;
}
