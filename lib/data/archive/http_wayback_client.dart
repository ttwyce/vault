/// Wayback availability 的**真实 HTTP 客户端**（docs/05 §6.1）。
///
/// 用 Dart SDK `dart:io` GET `archive.org/wayback/available?url=...`，
/// 响应交给 [parseWaybackAvailability] 解析。不新增依赖；真机 / 外网
/// 验收可跳过，用本地 HttpServer 注入 [baseUrl] 即可完整验证。
/// 网络失败绝不假装「有存档」。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'wayback_client.dart';

class HttpWaybackClient {
  HttpWaybackClient({
    HttpClient? client,
    this.baseUrl = 'https://archive.org',
    this.connectTimeout = const Duration(seconds: 5),
    this.maxResponseBytes = 256 * 1024,
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final String baseUrl;
  final Duration connectTimeout;
  final int maxResponseBytes;

  void close({bool force = true}) => _client.close(force: force);

  Uri _availabilityUri(String targetUrl) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: '/wayback/available',
      queryParameters: <String, String>{'url': targetUrl},
    );
  }

  Future<WaybackResult> findSnapshot(String targetUrl) async {
    final uri = _availabilityUri(targetUrl);
    try {
      final request = await _client.getUrl(uri).timeout(connectTimeout);
      final response = await request.close().timeout(connectTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        return WaybackResult(
          available: false,
          archiveUrl: null,
          hint: 'archive.org 返回 HTTP ${response.statusCode}，建议手动提交',
        );
      }
      final bytes = await response
          .fold<List<int>>(<int>[], (List<int> acc, List<int> chunk) {
        acc.addAll(chunk);
        if (acc.length > maxResponseBytes) {
          throw const HttpException('Wayback 响应过大');
        }
        return acc;
      }).timeout(connectTimeout);
      return parseWaybackAvailability(utf8.decode(bytes), targetUrl);
    } on TimeoutException {
      return const WaybackResult(
        available: false,
        archiveUrl: null,
        hint: '查询 archive.org 超时，建议稍后重试或手动提交',
      );
    } on SocketException {
      return const WaybackResult(
        available: false,
        archiveUrl: null,
        hint: '网络不可达，建议手动提交到 archive.org',
      );
    } on HttpException {
      return const WaybackResult(
        available: false,
        archiveUrl: null,
        hint: 'Wayback 响应异常，建议手动提交到 archive.org',
      );
    } on Object {
      return const WaybackResult(
        available: false,
        archiveUrl: null,
        hint: 'Wayback 响应无法解析，建议手动提交到 archive.org',
      );
    }
  }
}
