/// 归档正文派生 meta（docs/05 §10）。
///
/// 不读 blob、不联网：从 L1 Markdown 正文算出「前 200 字摘要」与
/// 预估阅读时长，让列表页不用读 blob 也能渲染摘要。
library;

const int kArchiveExcerptChars = 200;

/// 中文按 300 字/分、英文按 200 词/分估算，正文为空返回 0。
const int kCjkCharsPerMinute = 300;
const int kEnglishWordsPerMinute = 200;

class ArchiveBodyMeta {
  const ArchiveBodyMeta({
    required this.excerpt,
    required this.readingTimeMin,
  });

  final String excerpt;
  final int readingTimeMin;
}

String _stripMarkdown(String body) => body
    .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
    .replaceAllMapped(
      RegExp(r'!?\[([^\]]*)\]\([^)]*\)'),
      (Match m) => m.group(1) ?? '',
    )
    .replaceAll(RegExp(r'[#*_>`~|]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

ArchiveBodyMeta planArchiveBodyMeta(String body) {
  final text = _stripMarkdown(body);
  if (text.isEmpty) {
    return const ArchiveBodyMeta(excerpt: '', readingTimeMin: 0);
  }
  final cjk = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
  final words = RegExp(r'[A-Za-z0-9]+').allMatches(text).length;
  final minutes = ((cjk / kCjkCharsPerMinute) +
          (words / kEnglishWordsPerMinute))
      .ceil();
  return ArchiveBodyMeta(
    excerpt: text.length > kArchiveExcerptChars
        ? text.substring(0, kArchiveExcerptChars)
        : text,
    readingTimeMin: minutes < 1 ? 1 : minutes,
  );
}
