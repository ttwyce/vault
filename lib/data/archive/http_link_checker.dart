/// 真实死链 HTTP 检查（docs/05 §6.1）。
///
/// 用 Dart SDK `dart:io` 发 HEAD：200/301/302 → 存活并记录最终 URL，
/// 404/410 → dead，403/451 → restricted，超时 / DNS 失败重试 2 次后
/// → unreachable。不新增依赖；真机 / 外网验收可跳过，用本地 HttpServer
/// 即可完整验证。不写库，落库交给 [LinkCheckService]。
library;

import 'dart:io';

import '../network_failure.dart';

class LinkCheckObservation {
  const LinkCheckObservation({
    required this.httpStatus,
    required this.retries,
    required this.finalUrl,
    required this.reason,
  });

  /// null 表示网络不可达（DNS / 超时 / 连接失败）。
  final int? httpStatus;
  final int retries;
  final String? finalUrl;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'http_status': httpStatus,
        'retries': retries,
        'final_url': finalUrl,
        'reason': reason,
      };
}

class HttpLinkChecker {
  HttpLinkChecker({
    HttpClient? client,
    this.connectTimeout = const Duration(seconds: 5),
    this.maxRedirects = 3,
    this.maxRetries = 2,
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Duration connectTimeout;
  final int maxRedirects;
  final int maxRetries;

  void close({bool force = true}) => _client.close(force: force);

  Future<LinkCheckObservation> check(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return const LinkCheckObservation(
        httpStatus: null,
        retries: 0,
        finalUrl: null,
        reason: 'URL 非法（只接受 http/https）',
      );
    }

    var current = uri;
    var retries = 0;
    var redirects = 0;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      retries = attempt;
      try {
        final request = await _client
            .openUrl('HEAD', current)
            .timeout(connectTimeout);
        request.followRedirects = false;
        final response = await request.close().timeout(connectTimeout);
        await response.drain<void>();
        final code = response.statusCode;
        // 3xx：手工跟随 Location，最多 maxRedirects 次，并记录最终 URL。
        if (code >= 300 && code < 400 && redirects < maxRedirects) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location != null) {
            final next = Uri.tryParse(location);
            if (next != null) {
              current = next.hasScheme ? next : current.resolve(location);
              redirects++;
              // 跳转不算失败，也不消耗重试次数：再发一次 HEAD。
              attempt--;
              continue;
            }
          }
        }
        return LinkCheckObservation(
          httpStatus: code,
          retries: retries,
          finalUrl: current.toString() == url ? null : current.toString(),
          reason: 'HTTP $code',
        );
      } on Object catch (error) {
        final failure = classifyNetworkFailure(error);
        // DNS / 超时要重试，协议错误立刻返回：这是本客户端独有的策略，
        // 统一分类只负责识别错误，不替它决定重试。
        if (failure.kind == NetworkFailureKind.timeout) {
          if (attempt == maxRetries) {
            return const LinkCheckObservation(
              httpStatus: null,
              retries: 2,
              finalUrl: null,
              reason: '请求超时',
            );
          }
          continue;
        }
        if (failure.kind == NetworkFailureKind.unreachable) {
          if (attempt == maxRetries) {
            return LinkCheckObservation(
              httpStatus: null,
              retries: retries,
              finalUrl: null,
              reason: '网络不可达：${failure.detail}',
            );
          }
          continue;
        }
        if (failure.kind == NetworkFailureKind.protocol) {
          return LinkCheckObservation(
            httpStatus: null,
            retries: retries,
            finalUrl: null,
            reason: 'HTTP 协议错误：${failure.detail}',
          );
        }
        // 其它异常原先不在任何 on 分支里，会冒出 check()；
        // 这里保持「重试耗尽」的结果，不吞掉成 unreachable。
        return const LinkCheckObservation(
          httpStatus: null,
          retries: 2,
          finalUrl: null,
          reason: '重试耗尽',
        );
      }
    }
    return const LinkCheckObservation(
      httpStatus: null,
      retries: 2,
      finalUrl: null,
      reason: '重试耗尽',
    );
  }
}
