/// OpenAI-compatible 的**真实 SSE 流式客户端**（docs/07 §7）。
///
/// 用 Dart SDK `dart:io` POST `/chat/completions`（stream=true），
/// 逐行读 `data:` 事件并交给 [parseSseDelta]；`[DONE]` 结束。
/// 不新增依赖；真机 / 真实云 Key 可跳过，用本地 HttpServer 注入
/// [LlmEndpoint.baseUrl] 即可完整验证。
/// Key 只放在 Authorization 头，日志走 [redactedRequestLog] 不含 Key / body。
library;

import 'dart:convert';
import 'dart:io';

import '../network_failure.dart';
import 'openai_compat.dart';

class LlmStreamResult {
  const LlmStreamResult({
    required this.deltas,
    required this.statusCode,
    required this.log,
    required this.error,
  });

  final List<String> deltas;
  final int? statusCode;
  final Map<String, Object?> log;
  final String? error;

  String get text => deltas.join();
  bool get ok => error == null;
}

class HttpLlmClient {
  HttpLlmClient({
    HttpClient? client,
    this.connectTimeout = const Duration(seconds: 15),
    this.readTimeout = const Duration(seconds: 60),
    this.maxResponseBytes = 2 * 1024 * 1024,
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Duration connectTimeout;
  final Duration readTimeout;
  final int maxResponseBytes;

  void close({bool force = true}) => _client.close(force: force);

  Uri _uri(LlmEndpoint endpoint) {
    final base = Uri.parse(endpoint.baseUrl);
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$prefix${endpoint.chatCompletionsPath}');
  }

  /// 一次性收集流式返回（便于测试与调用方）；同时返回脱敏日志。
  Future<LlmStreamResult> streamChat({
    required LlmEndpoint endpoint,
    required List<LlmMessage> messages,
    required String apiKey,
    List<Map<String, Object?>> tools = const <Map<String, Object?>>[],
  }) async {
    final body = jsonEncode(buildChatRequest(
      endpoint: endpoint,
      messages: messages,
      tools: tools,
      stream: true,
    ));
    final deltas = <String>[];
    int? statusCode;
    try {
      final request = await _client
          .postUrl(_uri(endpoint))
          .timeout(connectTimeout);
      final encoded = utf8.encode(body);
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
        ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
        ..set(HttpHeaders.acceptHeader, 'text/event-stream');
      // 显式 Content-Length：某些代理 / 桩服务按长度读完请求体，
      // 不依赖 chunked 结束标记，避免双向流互等。
      request.contentLength = encoded.length;
      request.add(encoded);
      final response = await request.close().timeout(connectTimeout);
      statusCode = response.statusCode;
      if (statusCode != 200) {
        await response.drain<void>();
        return LlmStreamResult(
          deltas: deltas,
          statusCode: statusCode,
          log: redactedRequestLog(
            endpoint: endpoint,
            statusCode: statusCode,
            totalTokens: 0,
          ),
          error: 'LLM 返回 HTTP $statusCode',
        );
      }
      var total = 0;
      var buffer = '';
      await for (final chunk
          in response.transform(utf8.decoder).timeout(readTimeout)) {
        total += chunk.length;
        if (total > maxResponseBytes) {
          throw const HttpException('LLM 流式响应过大');
        }
        buffer += chunk;
        // 按完整行解析；最后一个不完整片段留到下一 chunk，
        // 避免一个 data: 事件被 TCP 拆成两半时丢内容。
        final lines = buffer.split(RegExp(r'\r?\n'));
        buffer = lines.removeLast();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed == 'data: [DONE]' || trimmed == '[DONE]') {
            return _done(endpoint, statusCode, deltas);
          }
          final delta = parseSseDelta(line);
          if (delta != null) deltas.add(delta);
        }
      }
      if (buffer.trim().isNotEmpty) {
        final delta = parseSseDelta(buffer);
        if (delta != null) deltas.add(delta);
      }
      return _done(endpoint, statusCode, deltas);
    } on Object catch (error) {
      final failure = classifyNetworkFailure(error);
      return switch (failure.kind) {
        NetworkFailureKind.timeout =>
          _error(endpoint, statusCode, deltas, 'LLM 流式读取超时'),
        NetworkFailureKind.unreachable =>
          _error(endpoint, statusCode, deltas, '网络不可达'),
        NetworkFailureKind.protocol => _error(
            endpoint, statusCode, deltas, 'LLM 响应异常：${failure.detail}'),
        NetworkFailureKind.other =>
          _error(endpoint, statusCode, deltas, 'LLM 请求失败'),
      };
    }
  }

  LlmStreamResult _done(
    LlmEndpoint endpoint,
    int? statusCode,
    List<String> deltas,
  ) =>
      LlmStreamResult(
        deltas: List<String>.unmodifiable(deltas),
        statusCode: statusCode,
        log: redactedRequestLog(
          endpoint: endpoint,
          statusCode: statusCode ?? 0,
          totalTokens: estimateTokens(deltas.join()),
        ),
        error: null,
      );

  LlmStreamResult _error(
    LlmEndpoint endpoint,
    int? statusCode,
    List<String> deltas,
    String message,
  ) =>
      LlmStreamResult(
        deltas: List<String>.unmodifiable(deltas),
        statusCode: statusCode,
        log: redactedRequestLog(
          endpoint: endpoint,
          statusCode: statusCode ?? 0,
          totalTokens: estimateTokens(deltas.join()),
        ),
        error: message,
      );
}
