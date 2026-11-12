/// HIBP k-anonymity 的**真实 HTTPS 客户端**（docs/09 §8 / docs/11 §4.4）。
///
/// 用 Dart SDK `dart:io` GET `/range/<prefix>`。**只把 SHA1 前 5 位放进
/// URL，完整哈希与密码明文永远不出设备**。不新增依赖；真机 / 外网验收
/// 可跳过，用本地 HttpServer 注入 [baseUrl] 即可完整验证。
/// 网络失败返回 null，绝不把「未知」当成「安全」。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'hibp_client.dart' show HibpRequest;

class HibpFetchResult {
  const HibpFetchResult({required this.body, required this.hint});

  /// null 表示未能取回（网络失败 / 非 200 / 响应异常）。
  final String? body;
  final String hint;
}

class HttpHibpClient {
  HttpHibpClient({
    HttpClient? client,
    this.baseUrl = 'https://api.pwnedpasswords.com',
    this.connectTimeout = const Duration(seconds: 5),
    this.maxResponseBytes = 512 * 1024,
    this.userAgent = 'vault/0.1',
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final String baseUrl;
  final Duration connectTimeout;
  final int maxResponseBytes;
  final String userAgent;

  void close({bool force = true}) => _client.close(force: force);

  Uri _rangeUri(String prefix) {
    final base = Uri.parse(baseUrl);
    return base.replace(path: '/range/$prefix');
  }

  /// [request] 只有 prefix 会被用来拼 URL；suffix 绝不参与。
  Future<HibpFetchResult> fetchRange(HibpRequest request) async {
    final prefix = request.prefix.toUpperCase();
    if (!RegExp(r'^[0-9A-F]{5}$').hasMatch(prefix)) {
      return const HibpFetchResult(body: null, hint: '前缀非法，拒绝发请求');
    }
    try {
      final httpRequest = await _client
          .getUrl(_rangeUri(prefix))
          .timeout(connectTimeout);
      httpRequest.headers.set(HttpHeaders.userAgentHeader, userAgent);
      final response = await httpRequest.close().timeout(connectTimeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        return HibpFetchResult(
          body: null,
          hint: 'HIBP 返回 HTTP ${response.statusCode}，结果未知',
        );
      }
      final bytes = await response
          .fold<List<int>>(<int>[], (List<int> acc, List<int> chunk) {
        acc.addAll(chunk);
        if (acc.length > maxResponseBytes) {
          throw const HttpException('HIBP 响应过大');
        }
        return acc;
      }).timeout(connectTimeout);
      return HibpFetchResult(body: utf8.decode(bytes), hint: '已取回前缀 $prefix');
    } on TimeoutException {
      return const HibpFetchResult(body: null, hint: '查询 HIBP 超时，结果未知');
    } on SocketException {
      return const HibpFetchResult(body: null, hint: '网络不可达，结果未知');
    } on HttpException {
      return const HibpFetchResult(body: null, hint: 'HIBP 响应异常，结果未知');
    } on Object {
      return const HibpFetchResult(body: null, hint: 'HIBP 请求失败，结果未知');
    }
  }
}
