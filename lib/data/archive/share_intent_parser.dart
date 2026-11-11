/// 剪藏分享意图的**纯判定层**（docs/08 §4 / docs/05 §3）。
///
/// 不接平台 channel、不抓页面：只把「分享来的 text/plain」解析成
/// 可归档的 URL 列表 / 纯文本速记，处理多 URL、去重、坏 scheme、
/// 标题与 URL 混排。真实 Intent / Share Extension 由平台层接。
library;

import 'archive_meta.dart' show ArchiveMeta;

enum ShareIntentKind { archiveUrls, quickNote, empty }

class ShareIntentPlan {
  const ShareIntentPlan({
    required this.kind,
    required this.urls,
    required this.text,
    required this.reason,
  });

  final ShareIntentKind kind;
  final List<String> urls;
  final String text;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind.name,
        'urls': urls,
        'text': text,
        'reason': reason,
      };
}

/// URL 提取：只接受 http/https，去掉常见尾随标点，按出现顺序去重。
/// 只接受 RFC 3986 的 ASCII URL 字符集；汉字与中文标点自然终止匹配。
final RegExp _urlPattern = RegExp(r"https?://[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+");

List<String> extractShareUrls(String raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final match in _urlPattern.allMatches(raw)) {
    var url = match.group(0)!;
    // 中文句子后面常跟的标点不属于 URL。
    url = url.replaceAll(RegExp(r'[，。！？；：、,;!?)\]]+$'), '');
    if (seen.add(url)) out.add(url);
  }
  return List<String>.unmodifiable(out);
}

/// 判断分享文本该走哪条路径：
/// - 有 URL → 归档（可多条，不做抓取，只排队）
/// - 无 URL 但有非空文本 → 一句话速记 / 想法
/// - 空白 → 忽略
ShareIntentPlan planShareIntent(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return const ShareIntentPlan(
      kind: ShareIntentKind.empty,
      urls: <String>[],
      text: '',
      reason: '分享内容为空',
    );
  }
  final urls = extractShareUrls(text);
  if (urls.isNotEmpty) {
    return ShareIntentPlan(
      kind: ShareIntentKind.archiveUrls,
      urls: urls,
      text: text,
      reason: '识别到 ${urls.length} 个 URL，只接收不抓取（Extension 30s 限制）',
    );
  }
  return ShareIntentPlan(
    kind: ShareIntentKind.quickNote,
    urls: const <String>[],
    text: text,
    reason: '纯文本无 URL，落为一条想法',
  );
}

/// 生成待处理队列项（真实队列落库由主 App 启动时消费）。
List<Map<String, Object?>> shareQueueItems(ShareIntentPlan plan) => switch (plan.kind) {
      ShareIntentKind.archiveUrls => <Map<String, Object?>>[
          for (final url in plan.urls)
            <String, Object?>{
              'type': 'archive',
              'url': url,
              // 站点键复用 ArchiveMeta.siteOf 的口径，坏 URL 在平台层拦。
              'site': _safeSite(url),
              'text': plan.text,
            },
        ],
      ShareIntentKind.quickNote => <Map<String, Object?>>[
          <String, Object?>{
            'type': 'quick_note',
            'text': plan.text,
          },
        ],
      ShareIntentKind.empty => const <Map<String, Object?>>[],
    };

String _safeSite(String url) {
  try {
    return ArchiveMeta.siteOf(url);
  } on Object {
    return 'unknown';
  }
}
