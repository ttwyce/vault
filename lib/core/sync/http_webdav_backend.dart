/// 基于 Dart SDK `dart:io` 的真实 WebDAV 后端（不新增第三方依赖）。
///
/// 这一层把 [WebDavBackend] 抽象落到真实 HTTP：OPTIONS / PROPFIND /
/// REPORT / GET / PUT / DELETE / MKCOL。XML 只解析同步需要的
/// `href` / `getetag` / `resourcetype` / `sync-token`，用极小的正则提取，
/// 不引入 xml 解析包 —— 各家服务器的前缀（`d:` / `D:` / 无前缀）差异很大，
/// 用标签局部名匹配反而比严格 DOM 更 tolerant。
///
/// **工程红线**：无条件 PUT 在接口层就无法表达；这里把条件原样转成
/// `If-Match` / `If-None-Match: *`，4xx/5xx 一律映射成 [WebDavException]，
/// 由 `SyncEngine` 的状态机决定 FAILED / BACKOFF / 412 重试。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'webdav_backend.dart';

/// 连接配置。[rootUrl] 以 `https://dav.example.com/remote.php/dav/files/u/`
/// 为例，`CloudLayout` 的 `/vault/...` 路径会拼在它后面。
class HttpWebDavConfig {
  const HttpWebDavConfig({
    required this.rootUrl,
    this.username,
    this.password,
    this.connectTimeout = const Duration(seconds: 15),
    this.userAgent = 'vault/0.1',
  });

  final String rootUrl;
  final String? username;
  final String? password;
  final Duration connectTimeout;
  final String userAgent;
}

class HttpClientWebDavBackend implements WebDavBackend {
  HttpClientWebDavBackend(this.config, {HttpClient? client})
      : _client = client ?? HttpClient();

  final HttpWebDavConfig config;
  final HttpClient _client;

  void close({bool force = true}) => _client.close(force: force);

  Uri _uri(String path) {
    final base = config.rootUrl.endsWith('/')
        ? config.rootUrl.substring(0, config.rootUrl.length - 1)
        : config.rootUrl;
    final relative = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$base/$relative');
  }

  Map<String, String> _headers([Map<String, String>? extra]) =>
      <String, String>{
        HttpHeaders.userAgentHeader: config.userAgent,
        if (config.username != null)
          HttpHeaders.authorizationHeader:
              'Basic ${base64.encode(utf8.encode('${config.username}:${config.password ?? ''}'))}',
        ...?extra,
      };

  Future<HttpClientResponse> _send(
    String method,
    String path, {
    Map<String, String>? headers,
    List<int>? body,
  }) async {
    try {
      final request = await _client
          .openUrl(method, _uri(path))
          .timeout(config.connectTimeout);
      _headers(headers).forEach((String key, String value) {
        request.headers.set(key, value);
      });
      if (body != null) request.add(body);
      final response = await request.close().timeout(config.connectTimeout);
      if (response.statusCode >= 400) {
        await response.drain<void>();
        throw WebDavException(
          statusCode: response.statusCode,
          method: method,
          path: path,
        );
      }
      return response;
    } on WebDavException {
      rethrow;
    } on SocketException catch (e) {
      throw WebDavException(
        statusCode: 503,
        method: method,
        path: path,
        message: e.message,
      );
    } on HttpException catch (e) {
      throw WebDavException(
        statusCode: 503,
        method: method,
        path: path,
        message: e.message,
      );
    }
  }

  Future<Uint8List> _bytes(HttpClientResponse response) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  String? _header(HttpClientResponse response, String name) =>
      response.headers.value(name.toLowerCase());

  @override
  Future<Map<String, String>> options(String path) async {
    final response = await _send('OPTIONS', path);
    await response.drain<void>();
    final out = <String, String>{};
    response.headers.forEach((String name, List<String> values) {
      if (values.isNotEmpty) out[name] = values.join(', ');
    });
    return out;
  }

  @override
  Future<List<WebDavListing>> propfind(String path, {int depth = 1}) async {
    const String body = '<?xml version="1.0"?>'
        '<d:propfind xmlns:d="DAV:"><d:prop>'
        '<d:getetag/><d:getcontentlength/><d:resourcetype/>'
        '</d:prop></d:propfind>';
    final response = await _send(
      'PROPFIND',
      path,
      headers: <String, String>{
        'Depth': depth.toString(),
        HttpHeaders.contentTypeHeader: 'application/xml; charset=utf-8',
      },
      body: utf8.encode(body),
    );
    final xml = utf8.decode(await _bytes(response), allowMalformed: true);
    return _parseMultiStatus(xml, path);
  }

  /// 解析 207 Multi-Status。只取 `<response>` 块里的 href / getetag /
  /// resourcetype；`collection` 用于把目录本身从 diff 里排除。
  static List<WebDavListing> parseMultiStatus(String xml, String basePath) =>
      _parseMultiStatus(xml, basePath);

  static List<WebDavListing> _parseMultiStatus(String xml, String basePath) {
    final responses = RegExp(
      r'<(?:[A-Za-z0-9_]+:)?response\b[^>]*>([\s\S]*?)</(?:[A-Za-z0-9_]+:)?response>',
      caseSensitive: false,
    ).allMatches(xml);
    final out = <WebDavListing>[];
    for (final match in responses) {
      final block = match.group(1) ?? '';
      final href = _tag(block, 'href');
      if (href == null) continue;
      final decoded = Uri.decodeComponent(href);
      final path = _normalizeHref(decoded, basePath);
      // RFC 6578：被删除的条目用 <status>HTTP/1.1 404</status> 表示，
      // 且没有 getetag。统一收敛成 etag=null，让调用方只需一个判据。
      final status404 = RegExp(
        r'<(?:[A-Za-z0-9_]+:)?status\b[^>]*>[\s\S]*?404',
        caseSensitive: false,
      ).hasMatch(block);
      final etag = status404 ? null : _tag(block, 'getetag');
      final isCollection = block.contains('<d:collection') ||
          RegExp(r'<(?:[A-Za-z0-9_]+:)?collection\b', caseSensitive: false)
              .hasMatch(block);
      out.add(WebDavListing(
        path: path,
        etag: etag,
        isCollection: isCollection,
      ));
    }
    return out;
  }

  static String? _tag(String block, String localName) {
    final match = RegExp(
      '<(?:[A-Za-z0-9_]+:)?$localName\\b[^>]*>([\\s\\S]*?)</(?:[A-Za-z0-9_]+:)?$localName>',
      caseSensitive: false,
    ).firstMatch(block);
    return match?.group(1)?.trim();
  }

  /// href 可能是完整 URL、绝对路径，也可能只是文件名；统一成
  /// `/vault/...` 形式，保证与 `CloudLayout` 生成的路径可比较。
  static String _normalizeHref(String href, String basePath) {
    var path = href;
    final uri = Uri.tryParse(href);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      path = uri.path;
    }
    if (!path.startsWith('/')) {
      final prefix = basePath.endsWith('/') ? basePath : '$basePath/';
      path = path.contains('/') ? '/$path' : '$prefix$path';
    }
    // 去掉 URL 编码后的目录尾斜杠差异。
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  @override
  Future<SyncCollectionDelta> reportSyncCollection(
    String path, {
    String? syncToken,
  }) async {
    final token = syncToken == null
        ? ''
        : '<d:sync-token>${_xmlEscape(syncToken)}</d:sync-token>';
    final body = '<?xml version="1.0"?>'
        '<d:sync-collection xmlns:d="DAV:">'
        '<d:sync-level>1</d:sync-level><d:prop>'
        '<d:getetag/><d:resourcetype/>'
        '</d:prop>$token</d:sync-collection>';
    final response = await _send(
      'REPORT',
      path,
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'application/xml; charset=utf-8',
      },
      body: utf8.encode(body),
    );
    final xml = utf8.decode(await _bytes(response), allowMalformed: true);
    final listings = _parseMultiStatus(xml, path);
    final changed = <String, String?>{};
    final deleted = <String>{};
    for (final listing in listings) {
      if (listing.isCollection) continue;
      // 解析阶段已把 status=404 的条目收敛成 etag=null。
      if (listing.etag == null) {
        deleted.add(listing.path);
      } else {
        changed[listing.path] = listing.etag;
      }
    }
    return SyncCollectionDelta(
      changed: changed,
      deleted: deleted,
      syncToken: _tag(xml, 'sync-token') ?? '',
    );
  }

  @override
  Future<WebDavGetResult> get(String path) async {
    final response = await _send('GET', path);
    return WebDavGetResult(
      bytes: await _bytes(response),
      etag: _header(response, 'etag') ?? '',
    );
  }

  @override
  Future<WebDavPutResult> put(
    String path,
    List<int> bytes, {
    required WebDavCondition condition,
  }) async {
    if (!condition.isValid) {
      throw ArgumentError.value(condition, 'condition', '条件写不能同时为空');
    }
    final response = await _send(
      'PUT',
      path,
      headers: <String, String>{
        condition.headerName: condition.headerValue,
        HttpHeaders.contentTypeHeader: 'application/octet-stream',
      },
      body: bytes,
    );
    await response.drain<void>();
    return WebDavPutResult(
      etag: _header(response, 'etag') ?? '',
      statusCode: response.statusCode,
    );
  }

  @override
  Future<void> delete(String path, {required String ifMatch}) async {
    if (ifMatch.isEmpty) {
      throw ArgumentError.value(ifMatch, 'ifMatch', '条件删除必须带 ETag');
    }
    final response = await _send(
      'DELETE',
      path,
      headers: <String, String>{'If-Match': ifMatch},
    );
    await response.drain<void>();
  }

  @override
  Future<void> mkcol(String path) async {
    final response = await _send('MKCOL', path);
    await response.drain<void>();
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
