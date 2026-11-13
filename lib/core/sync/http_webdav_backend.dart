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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'collection_request.dart';
import 'mkcol_with_parents.dart';
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
    this.maxConcurrentRequests = 3,
    this.maxResponseBytes = 1024 * 1024,
  })  : assert(maxConcurrentRequests > 0),
        assert(maxResponseBytes > 0);

  final String rootUrl;
  final String? username;
  final String? password;
  final Duration connectTimeout;
  final String userAgent;

  /// docs/04 §10：全局最多 3 个在途 HTTP 请求。
  final int maxConcurrentRequests;

  /// 单条目正文上限（docs/README 关键预算：1 MB）。
  /// blob 按需下载时可显式调大；超限绝不静默截断。
  final int maxResponseBytes;
}

class HttpClientWebDavBackend implements WebDavBackend {
  HttpClientWebDavBackend(this.config, {HttpClient? client})
      : _client = client ?? HttpClient() {
    // docs/04 §10：全局最多 3 个在途 HTTP 请求。HttpClient 的连接池上限
    // 覆盖「发请求 + 读响应体」整个生命周期，比只包住 _send 的手写信号量
    // 更可靠；超出的请求在 SDK 层排队，不会瞬时打满服务商限流。
    _client.maxConnectionsPerHost = config.maxConcurrentRequests;
  }

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
      // 条件写被 3xx 重定向到登录页时，自动跟随会把 If-Match 丢掉却
      // 返回 200 —— 用户以为写成功，实际什么都没发生。原样交给状态机。
      request.followRedirects = false;
      _headers(headers).forEach((String key, String value) {
        request.headers.set(key, value);
      });
      if (body != null) request.add(body);
      final response = await request.close().timeout(config.connectTimeout);
      if (response.statusCode >= 300) {
        await response.drain<void>();
        // 3xx 常见于「会话过期 → 302 登录页」。不能当成成功：
        // 条件写被重定向后 If-Match 已丢失，返回 200 会静默丢数据。
        throw WebDavException(
          statusCode: response.statusCode >= 400
              ? response.statusCode
              : 401,
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
    } on TimeoutException catch (e) {
      // 超时必须映射成 E_NET（可退避），否则会被 SyncEngine 的顶层
      // catch 当成 E_CORRUPT 直接 FAILED，用户看到「文件损坏」而不是
      // 「网络不可用，稍后重试」。
      throw WebDavException(
        statusCode: 504,
        method: method,
        path: path,
        message: e.message ?? 'connect timeout',
      );
    }
  }

  Future<Uint8List> _bytes(
    HttpClientResponse response, {
    required String method,
    required String path,
  }) async {
    final declared = response.contentLength;
    if (declared > 0 && declared > config.maxResponseBytes) {
      // 不调用 drain()：HttpClientResponse 是单订阅流，drain 之后再
      // await for 会抛「Stream has already been listened to」，把真正的
      // E_QUOTA 掩盖掉。超限直接抛，连接由 SDK 自行回收。
      throw WebDavException(
        statusCode: 507,
        method: method,
        path: path,
        message: '响应体 ${declared}B 超过上限 ${config.maxResponseBytes}B',
      );
    }
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in response) {
      total += chunk.length;
      if (total > config.maxResponseBytes) {
        // chunked 响应没有 Content-Length，必须边读边挡；
        // 超限不返回半个载荷（半个载荷会被当成损坏条目去解密）。
        throw WebDavException(
          statusCode: 507,
          method: method,
          path: path,
          message: '响应体超过上限 ${config.maxResponseBytes}B',
        );
      }
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
    return collectionRequest(this, path, () => _propfind(path, depth: depth));
  }

  /// 单次 PROPFIND；集合 404/409 由 [collectionRequest] 补齐父目录后重试。
  Future<List<WebDavListing>> _propfind(String path,
      {int depth = 1}) async {
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
    final xml = utf8.decode(
      await _bytes(response, method: 'PROPFIND', path: path),
      allowMalformed: true,
    );
    return _relativizeListings(_parseMultiStatus(xml, path));
  }

  /// PROPFIND / REPORT 的 href 可能是服务器绝对路径。
  static List<WebDavListing> parseMultiStatus(String xml, String basePath) =>
      _parseMultiStatus(xml, basePath);

  /// Nextcloud 的 PROPFIND/REPORT href 是服务器绝对路径：
  /// `/remote.php/dav/files/<user>/<root>/vault/items/...`。
  /// 剥掉 config.rootUrl 的 path 前缀，还原成 CloudLayout 的 `/vault/...`；
  /// 否则另一台设备拿 href 再拼一次 base 会得到重复前缀而 404。
  List<WebDavListing> _relativizeListings(List<WebDavListing> listings) {
    final base = Uri.parse(config.rootUrl).path.replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return listings;
    return <WebDavListing>[
      for (final item in listings)
        WebDavListing(
          path: item.path.startsWith('$base/')
              ? item.path.substring(base.length)
              : item.path,
          etag: item.etag,
          isCollection: item.isCollection,
        ),
    ];
  }

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
    final xml = utf8.decode(
      await _bytes(response, method: 'REPORT', path: path),
      allowMalformed: true,
    );
    final listings = _relativizeListings(_parseMultiStatus(xml, path));
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
    var etag = _header(response, 'etag') ?? '';
    final bytes = await _bytes(response, method: 'GET', path: path);
    if (etag.isEmpty) {
      // 与 PUT 对称：GET 无 ETag 时 HEAD 回读，绝不把空条件写进 syncState。
      try {
        final head = await _send('HEAD', path);
        await head.drain<void>();
        etag = _header(head, 'etag') ?? '';
      } on WebDavException {
        // HEAD 不被支持时留空，由调用方隔离该载荷。
      }
    }
    return WebDavGetResult(bytes: bytes, etag: etag);
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
    if (condition.isCreateOnly) {
      // 坚果云忽略 `If-None-Match: *`：重复 createOnly PUT 会静默覆盖。
      // 先在后端层做一次 GET 存在性预检，保持「永不覆盖」语义；
      // 只有明确 404 才继续 PUT，其它错误原样抛。
      try {
        await get(path);
        throw WebDavPreconditionFailed(method: 'PUT', path: path);
      } on WebDavException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
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
    var etag = _header(response, 'etag') ?? '';
    if (etag.isEmpty) {
      // 坚果云成功 PUT 不返回 ETag，HEAD 也不带；必须用 GET 回读真实
      // ETag（GET 响应头有），否则 syncState 会被写成空、下一轮 412 死循环。
      try {
        final readBack = await get(path);
        etag = readBack.etag;
      } on WebDavException {
        // 仍拿不到就抛 E_PATH，交由调用方下一轮重新发现，绝不静默返回空。
      }
    }
    if (etag.isEmpty) {
      throw WebDavException(
        statusCode: 409,
        method: 'PUT',
        path: path,
        message: 'PUT 成功但 GET/HEAD 均未提供 ETag',
      );
    }
    return WebDavPutResult(
      etag: etag,
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
    // 真实 Nextcloud：MKCOL /vault/items/f 在父级 /vault/items 不存在时
    // 返回 409。逐段补齐父集合后重试；已存在的 405/409 视为幂等成功。
    try {
      final response = await _send('MKCOL', path);
      await response.drain<void>();
    } on WebDavException catch (e) {
      if (e.statusCode == 405) return;
      if (e.statusCode != 409) rethrow;
      await mkcolWithParents(this, path);
    }
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
