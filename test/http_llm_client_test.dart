import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/http_llm_client.dart';
import 'package:vault/data/agent/openai_compat.dart';

/// docs/07 §7：真实 SSE 流式用本地 HttpServer 验证，跳过真机 / 云 Key。
class _SseServer {
  _SseServer(this.server);
  final HttpServer server;
  int status = 200;
  bool sendDone = true;
  bool splitDelta = false;
  bool splitMidEvent = false;
  String? lastAuthorization;
  Map<String, Object?>? lastBody;

  static Future<_SseServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _SseServer(server);
    server.listen((HttpRequest request) async {
      site.lastAuthorization =
          request.headers.value(HttpHeaders.authorizationHeader);
      final raw = await utf8.decoder.bind(request).join();
      site.lastBody = jsonDecode(raw) as Map<String, Object?>;
      request.response.statusCode = site.status;
      request.response.headers.set('Content-Type', 'text/event-stream; charset=utf-8');
      if (site.status != 200) {
        await request.response.close();
        return;
      }
      String sseChunk(String content) =>
          'data: ${jsonEncode(<String, Object?>{'choices': <Object?>[<String, Object?>{'delta': <String, Object?>{'content': content}}]})}\n\n';
      void writeSse(String text) =>
          request.response.add(utf8.encode(text));
      if (site.splitMidEvent) {
        // 把一个 data: 事件硬拆成两个 TCP 写入，中间强制 flush，
        // 验证客户端按完整行缓冲解析而不是逐块 split。
        final event = sseChunk('拆开的正文');
        final half = event.length ~/ 2;
        request.response.add(utf8.encode(event.substring(0, half)));
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        request.response.add(utf8.encode(event.substring(half)));
      } else {
        writeSse(sseChunk('你好'));
        writeSse(sseChunk('，世界'));
      }
      if (site.splitDelta) {
        writeSse(sseChunk('！'));
      }
      if (site.sendDone) writeSse('data: [DONE]\n\n');
      await request.response.close();
    });
    return site;
  }

  String get baseUrl => 'http://127.0.0.1:${server.port}/v1';
  void close() => server.close(force: true);
}

LlmEndpoint _endpoint(String base) => LlmEndpoint(
      id: 'local',
      label: '本地桩',
      baseUrl: base,
      model: 'test-model',
    );

void main() {
  late _SseServer site;
  late HttpLlmClient client;

  setUp(() async {
    site = await _SseServer.start();
    client = HttpLlmClient(
      connectTimeout: const Duration(seconds: 2),
      readTimeout: const Duration(seconds: 2),
    );
  });
  tearDown(() {
    client.close();
    site.close();
  });

  test('SSE 多个 delta 拼接、[DONE] 结束、Key 只进 Authorization 头',
      () async {
    final result = await client.streamChat(
      endpoint: _endpoint(site.baseUrl),
      messages: const <LlmMessage>[LlmMessage(role: 'user', content: '讲个笑话')],
      apiKey: 'sk-test-123',
    );
    expect(result.ok, isTrue);
    expect(result.text, '你好，世界');
    expect(result.statusCode, 200);
    expect(site.lastAuthorization, 'Bearer sk-test-123');
    expect(site.lastBody?['stream'], isTrue);
    expect(site.lastBody?['model'], 'test-model');
    // 脱敏日志不含 Key / body。
    expect(result.log.toString(), isNot(contains('sk-test-123')));
    expect(result.log['status'], 200);
  });

  test('非 200 / 断连都给出错误，不伪装已生成', () async {
    site.status = 429;
    final limited = await client.streamChat(
      endpoint: _endpoint(site.baseUrl),
      messages: const <LlmMessage>[LlmMessage(role: 'user', content: 'hi')],
      apiKey: 'k',
    );
    expect(limited.ok, isFalse);
    expect(limited.error, contains('429'));

    final base = site.baseUrl;
    site.close();
    final down = await client.streamChat(
      endpoint: _endpoint(base),
      messages: const <LlmMessage>[LlmMessage(role: 'user', content: 'hi')],
      apiKey: 'k',
    );
    expect(down.ok, isFalse);
    expect(down.error, isNotNull);
  });

  test('单个 data 事件被 TCP 拆成两半仍能完整解析', () async {
    site.splitMidEvent = true;
    final result = await client.streamChat(
      endpoint: _endpoint(site.baseUrl),
      messages: const <LlmMessage>[LlmMessage(role: 'user', content: 'hi')],
      apiKey: 'k',
    );
    expect(result.ok, isTrue);
    expect(result.text, '拆开的正文');
  });
}
