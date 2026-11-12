import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/llm_chat_service.dart';
import 'package:vault/data/agent/http_llm_client.dart';
import 'package:vault/data/agent/openai_compat.dart';
import 'package:vault/data/chat/conversation_models.dart';

import 'support/test_harness.dart';

/// docs/07 §7/§9：真实 SSE → 安全约束 → append-only 落会话。
class _SseServer {
  _SseServer(this.server, this.content);
  final HttpServer server;
  final String content;
  String get baseUrl => 'http://127.0.0.1:${server.port}/v1';

  static Future<_SseServer> start(String content) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _SseServer(server, content);
    server.listen((HttpRequest request) async {
      await utf8.decoder.bind(request).drain<void>();
      request.response.headers.set('Content-Type', 'text/event-stream; charset=utf-8');
      final event = 'data: ${jsonEncode(<String, Object?>{'choices': <Object?>[<String, Object?>{'delta': <String, Object?>{'content': site.content}}]})}\n\n';
      request.response.add(utf8.encode(event));
      request.response.add(utf8.encode('data: [DONE]\n\n'));
      await request.response.close();
    });
    return site;
  }

  void close() => server.close(force: true);
}

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<LlmChatReply> run(String content, {Iterable<String> secrets = const <String>[]}) async {
    final site = await _SseServer.start(content);
    final client = HttpLlmClient(connectTimeout: const Duration(seconds: 2));
    final service = LlmChatService(
      db: app.db,
      writer: buildConversationWriter(app.db),
      client: client,
    );
    final reply = await service.generateAndAppend(
      endpoint: LlmEndpoint(
        id: 'local',
        label: '本地桩',
        baseUrl: site.baseUrl,
        model: 'test-model',
      ),
      apiKey: 'k',
      messages: const <LlmMessage>[LlmMessage(role: 'user', content: '问题')],
      draft: ConversationDraftState.initial,
      knownSecrets: secrets,
    );
    client.close();
    site.close();
    return reply;
  }

  test('真实 SSE 回答经安全约束后落成 assistant 消息', () async {
    final reply = await run('这是模型给出的回答。');
    expect(reply.ok, isTrue);
    expect(reply.text, '这是模型给出的回答。');
    expect(reply.draft.currentId, isNotNull);
    final messages = await app.db.select(app.db.messages).get();
    expect(messages, hasLength(1));
    expect(messages.single.role, 2);
    expect(messages.single.content, '这是模型给出的回答。');
    expect(reply.log.toString(), isNot(contains('Bearer')));
  });

  test('模型夹带本机密码 → 整段拦截，不落库', () async {
    final reply = await run(
      '你的密码是 Hunter2Secret',
      secrets: const <String>['Hunter2Secret'],
    );
    expect(reply.redactedSecrets, isTrue);
    expect(reply.text, contains('已按安全边界拦截'));
    final messages = await app.db.select(app.db.messages).get();
    expect(messages.single.content, isNot(contains('Hunter2Secret')));
  });
}
