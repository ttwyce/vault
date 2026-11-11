import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/openai_compat.dart';

/// docs/07 §7 OpenAI 兼容层纯判定测试。
void main() {
  final endpoint = kDefaultEndpoints.first;

  test('请求体含 tools / 低温 / 流式，且绝不带 API Key', () {
    final body = buildChatRequest(
      endpoint: endpoint,
      messages: const <LlmMessage>[
        LlmMessage(role: 'system', content: '你是助手'),
        LlmMessage(role: 'user', content: '找同步笔记'),
      ],
      tools: const <Map<String, Object?>>[
        <String, Object?>{'name': 'search_entries'},
      ],
    );
    expect(body['model'], 'deepseek-chat');
    expect(body['temperature'], 0.3);
    expect(body['stream'], isTrue);
    final tools = body['tools']! as List<Object?>;
    expect(tools, hasLength(1));
    expect((tools.first! as Map)['type'], 'function');
    expect(body.containsKey('api_key'), isFalse);
    expect(body.containsKey('authorization'), isFalse);
  });

  test('SSE 增量解析：坏 JSON / 非 data 行 / DONE 都安全跳过', () {
    expect(
      parseSseDelta('data: {"choices":[{"delta":{"content":"同步"}}]}'),
      '同步',
    );
    expect(parseSseDelta('data: [DONE]'), isNull);
    expect(parseSseDelta('event: ping'), isNull);
    expect(parseSseDelta('data: {坏 JSON'), isNull);
    expect(
      parseSseDelta('data: {"choices":[{"delta":{"tool_calls":[]}}]}'),
      isNull,
    );
  });

  test('上下文只保留最近 6 轮并截断超长工具结果', () {
    final messages = List<LlmMessage>.generate(
      20,
      (int i) => LlmMessage(role: 'user', content: '消息$i'),
    );
    final trimmed = trimContext(messages);
    expect(trimmed, hasLength(12));
    expect(trimmed.first.content, '消息8');

    final long = LlmMessage(role: 'tool', content: 'x' * 3000);
    expect(trimContext(<LlmMessage>[long]).single.content,
        contains('已截断'));
  });

  test('token 估算 / 每日预算 / 脱敏日志 / 缓存键', () {
    expect(estimateTokens('同步'), 2);
    final cost = estimateCost(
      messages: const <LlmMessage>[
        LlmMessage(role: 'user', content: '同步'),
      ],
      draftCompletion: '增量同步',
      dailyUsedTokens: 199998,
    );
    expect(cost.overBudget, isTrue);
    expect(cost.hint, contains('超出'));
    expect(estimateCost(
      messages: const <LlmMessage>[],
      draftCompletion: '',
      dailyUsedTokens: 0,
    ).overBudget, isFalse);

    final log = redactedRequestLog(
      endpoint: endpoint,
      statusCode: 200,
      totalTokens: 42,
    );
    expect(log['url'], contains('/chat/completions'));
    expect(log['status'], 200);
    expect(log['tokens'], 42);
    expect(log.containsKey('body'), isFalse);
    expect(log.containsKey('api_key'), isFalse);

    expect(cacheKeyFor(' 同步 ', nowMs: 0),
        cacheKeyFor('同步', nowMs: 60000));
    expect(cacheKeyFor('同步', nowMs: 0),
        isNot(cacheKeyFor('同步', nowMs: 300001)));
  });
}
