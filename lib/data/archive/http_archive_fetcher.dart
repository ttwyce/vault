/// 网页 L1 正文的**真实抓取**（docs/05 §5 / §9）。
///
/// 用 Dart SDK `dart:io` GET HTML，纯 Dart 抽取 `<title>` 与
/// `<article>/<main>/<body>` 里的可见文本，转成简化 Markdown。
/// 不引 readability.js / 不新增依赖；真机 / 外网验收可跳过，
/// 用本地 HttpServer 即可完整验证。抓取失败绝不写空正文。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ArchiveFetchResult {
  const ArchiveFetchResult({
    required this.ok,
    required this.title,
    required this.body,
    required this.hint,
    required this.statusCode,
  });

  final bool ok;
  final String? title;
  final String? body;
  final String hint;
  final int? statusCode;
}

class HttpArchiveFetcher {
  HttpArchiveFetcher({
    HttpClient? client,
    this.connectTimeout = const Duration(seconds: 10),
    this.maxResponseBytes = 1024 * 1024,
    this.userAgent = 'vault/0.1',
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Duration connectTimeout;
  final int maxResponseBytes;
  final String userAgent;

  void close({bool force = true}) => _client.close(force: force);

  Future<ArchiveFetchResult> fetch(Uri url) async {
    if (url.scheme != 'http' && url.scheme != 'https') {
      return const ArchiveFetchResult(
        ok: false,
        title: null,
        body: null,
        hint: 'URL 非法（只接受 http/https）',
        statusCode: null,
      );
    }
    try {
      final request = await _client.getUrl(url).timeout(connectTimeout);
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      final response = await request.close().timeout(connectTimeout);
      final code = response.statusCode;
      if (code < 200 || code >= 300) {
        await response.drain<void>();
        return ArchiveFetchResult(
          ok: false,
          title: null,
          body: null,
          hint: '页面返回 HTTP $code，未写入正文',
          statusCode: code,
        );
      }
      final bytes = await response
          .fold<List<int>>(<int>[], (List<int> acc, List<int> chunk) {
        acc.addAll(chunk);
        if (acc.length > maxResponseBytes) {
          throw const HttpException('页面超过 1MB，拒绝抓取');
        }
        return acc;
      }).timeout(connectTimeout);
      final html = utf8.decode(bytes, allowMalformed: true);
      final title = _extractTitle(html);
      final body = _extractBody(html);
      if (body.trim().isEmpty) {
        return ArchiveFetchResult(
          ok: false,
          title: title,
          body: null,
          hint: '页面没有可抽取的正文，未写入空正文',
          statusCode: code,
        );
      }
      return ArchiveFetchResult(
        ok: true,
        title: title,
        body: body,
        hint: '已抓取 L1 正文（${body.length} 字）',
        statusCode: code,
      );
    } on TimeoutException {
      return const ArchiveFetchResult(
        ok: false,
        title: null,
        body: null,
        hint: '页面抓取超时，未写入正文',
        statusCode: null,
      );
    } on SocketException {
      return const ArchiveFetchResult(
        ok: false,
        title: null,
        body: null,
        hint: '网络不可达，未写入正文',
        statusCode: null,
      );
    } on HttpException catch (e) {
      return ArchiveFetchResult(
        ok: false,
        title: null,
        body: null,
        hint: '页面抓取异常：${e.message}',
        statusCode: null,
      );
    } on Object {
      return const ArchiveFetchResult(
        ok: false,
        title: null,
        body: null,
        hint: '页面抓取失败，未写入正文',
        statusCode: null,
      );
    }
  }

  static String? _extractTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;
    final text = _plain(match.group(1) ?? '');
    return text.isEmpty ? null : text;
  }

  /// 优先 article / main，否则退化到 body；去脚本/样式/标签/注释，
  /// 保留段落与标题的换行，输出极简 Markdown。
  static String _extractBody(String html) {
    var source = html
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ')
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<noscript[\s\S]*?</noscript>', caseSensitive: false), ' ');
    for (final tag in <String>['article', 'main']) {
      final match = RegExp('<$tag[^>]*>([\\s\\S]*?)</$tag>',
              caseSensitive: false)
          .firstMatch(source);
      if (match != null) {
        source = match.group(1) ?? source;
        break;
      }
    }
    source = source
        .replaceAll(RegExp(r'<h([1-6])[^>]*>', caseSensitive: false), '\n\n## ')
        .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|section|li)>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    final lines = <String>[];
    for (final line in source.split('\n')) {
      final plain = _plain(line);
      if (plain.isNotEmpty) lines.add(plain);
    }
    return lines.join('\n\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static String _plain(String raw) => raw
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
