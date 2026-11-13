/// 站点 RSS 订阅与整站归档计划（docs/11 §3.5 二期）。
///
/// 不引 XML 包、不新增依赖：用 dart:io GET feed，正则提取
/// `<item>/<entry>` 的 link，规范化去重后生成「只排队不抓取」的归档计划。
/// 真实抓取仍由主 App 的归档流水线消费 job_queue。
library;

import 'dart:convert';
import 'dart:io';

import 'archive_meta.dart' show ArchiveMeta;

class SiteFeedResult {
  const SiteFeedResult({
    required this.ok,
    required this.urls,
    required this.hint,
  });

  final bool ok;
  final List<String> urls;
  final String hint;
}

class SiteArchivePlan {
  const SiteArchivePlan({
    required this.site,
    required this.feedUrl,
    required this.urls,
    required this.maxItems,
  });

  final String site;
  final String feedUrl;
  final List<String> urls;
  final int maxItems;

  List<Map<String, Object?>> queueItems() => <Map<String, Object?>>[
        for (final url in urls.take(maxItems))
          <String, Object?>{
            'type': 'site_archive',
            'site': site,
            'url': url,
          },
      ];
}

class HttpSiteFeed {
  HttpSiteFeed({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  void close({bool force = true}) => _client.close(force: force);

  Future<SiteFeedResult> fetch(Uri feedUrl) async {
    if (feedUrl.scheme != 'http' && feedUrl.scheme != 'https') {
      return const SiteFeedResult(
          ok: false, urls: <String>[], hint: '只接受 http/https feed');
    }
    try {
      final request = await _client.getUrl(feedUrl);
      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        return SiteFeedResult(
          ok: false,
          urls: const <String>[],
          hint: 'RSS 返回 HTTP ${response.statusCode}',
        );
      }
      final raw = await response.transform(utf8.decoder).join();
      final urls = parseFeedUrls(raw);
      return SiteFeedResult(
        ok: urls.isNotEmpty,
        urls: urls,
        hint: urls.isEmpty ? 'feed 中没有可用链接' : '解析到 ${urls.length} 条',
      );
    } on SocketException {
      return const SiteFeedResult(
          ok: false, urls: <String>[], hint: '网络不可达');
    } on Object {
      return const SiteFeedResult(
          ok: false, urls: <String>[], hint: 'RSS 读取失败');
    }
  }
}

/// 解析 RSS `<link>` 或 Atom `<link href="...">`，只保留 http/https。
List<String> parseFeedUrls(String xml) {
  final links = <String>[];
  final linkTag = RegExp(r'<link[^>]*>([\s\S]*?)</link>', caseSensitive: false);
  final hrefAttr = RegExp(
      "<link[^>]*href\\s*=\\s*[\"']([^\"']+)[\"']", caseSensitive: false);
  for (final match in linkTag.allMatches(xml)) {
    final value = _cdata(match.group(1) ?? '').trim();
    if (value.startsWith('http')) links.add(_entity(value));
  }
  for (final match in hrefAttr.allMatches(xml)) {
    final value = _entity(match.group(1) ?? '').trim();
    if (value.startsWith('http')) links.add(value);
  }
  final seen = <String>{};
  return <String>[
    for (final url in links)
      if (seen.add(url)) url,
  ];
}

SiteArchivePlan planSiteArchive({
  required String feedUrl,
  required List<String> urls,
  int maxItems = 50,
}) {
  final site = _safeSite(feedUrl);
  return SiteArchivePlan(
    site: site,
    feedUrl: feedUrl,
    urls: List<String>.unmodifiable(urls),
    maxItems: maxItems <= 0 ? 50 : maxItems,
  );
}

String _safeSite(String url) {
  try {
    return ArchiveMeta.siteOf(url);
  } on Object {
    return 'unknown';
  }
}

String _cdata(String raw) => raw
    .replaceAll('<![CDATA[', '')
    .replaceAll(']]>', '')
    .replaceAll(RegExp(r'<[^>]+>'), '');

String _entity(String raw) => raw
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"');
