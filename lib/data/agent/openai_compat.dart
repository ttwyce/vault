/// OpenAI 兼容客户端的**纯判定层**（docs/07 §7）。
///
/// 不联网、不存 Key、不加依赖：只构造 `/chat/completions` 请求体、
/// 解析 SSE 增量、裁剪上下文、估算 token 成本、生成脱敏日志。
/// 真实 HTTP / 流式 transport 与 secure_storage 由 M7 平台层接。
library;

import 'dart:convert';

/// 可切换的服务商配置（不含 Key）。
class LlmEndpoint {
  const LlmEndpoint({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.model,
    this.temperature = 0.3,
    this.maxTokens = 2048,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;

  String get chatCompletionsPath => '/chat/completions';

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'base_url': baseUrl,
        'model': model,
        'temperature': temperature,
        'max_tokens': maxTokens,
      };
}

const List<LlmEndpoint> kDefaultEndpoints = <LlmEndpoint>[
  LlmEndpoint(
    id: 'deepseek',
    label: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    model: 'deepseek-chat',
  ),
  LlmEndpoint(
    id: 'qwen',
    label: '通义千问',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    model: 'qwen-plus',
  ),
  LlmEndpoint(
    id: 'kimi',
    label: 'Kimi',
    baseUrl: 'https://api.moonshot.cn/v1',
    model: 'moonshot-v1-8k',
  ),
  LlmEndpoint(
    id: 'openrouter',
    label: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    model: 'openai/gpt-4o-mini',
  ),
];

/// 一条对话消息。
class LlmMessage {
  const LlmMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': role,
        'content': content,
      };
}

/// 构造请求体：tools 来自注册表 schema，temperature/最大输出来自 endpoint。
/// **绝不把 API Key 放进 body**（Key 只能出现在请求头）。
Map<String, Object?> buildChatRequest({
  required LlmEndpoint endpoint,
  required List<LlmMessage> messages,
  required List<Map<String, Object?>> tools,
  bool stream = true,
}) =>
    <String, Object?>{
      'model': endpoint.model,
      'messages': <Object?>[for (final m in messages) m.toJson()],
      'temperature': endpoint.temperature,
      'max_tokens': endpoint.maxTokens,
      'stream': stream,
      if (tools.isNotEmpty)
        'tools': <Object?>[
          for (final tool in tools)
            <String, Object?>{
              'type': 'function',
              'function': tool,
            },
        ],
    };

/// 上下文裁剪：只保留最近 6 轮 + 工具结果截断 2000 字。
List<LlmMessage> trimContext(
  List<LlmMessage> messages, {
  int maxTurns = 6,
  int maxResultChars = 2000,
}) {
  final recent = messages.length > maxTurns * 2
      ? messages.sublist(messages.length - maxTurns * 2)
      : messages;
  return <LlmMessage>[
    for (final message in recent)
      LlmMessage(
        role: message.role,
        content: message.content.length <= maxResultChars
            ? message.content
            : '${message.content.substring(0, maxResultChars)}…（已截断）',
      ),
  ];
}

/// SSE 增量解析：只取 `data:` 行里的 `choices[0].delta.content`。
/// `[DONE]` 返回 null；坏 JSON 跳过而不是整条流崩。
String? parseSseDelta(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('data:')) return null;
  final payload = trimmed.substring(5).trim();
  if (payload.isEmpty || payload == '[DONE]') return null;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final delta = first['delta'];
    if (delta is! Map) return null;
    final content = delta['content'];
    return content is String ? content : null;
  } on Object {
    return null;
  }
}

/// 粗粒度 token 估算（中文按 1 字≈1 token，英文按 4 字符≈1 token）。
int estimateTokens(String text) {
  if (text.isEmpty) return 0;
  final cjk = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
  final rest = text.length - cjk;
  return cjk + (rest / 4).ceil();
}

class CostEstimate {
  const CostEstimate({
    required this.promptTokens,
    required this.completionTokens,
    required this.dailyUsedTokens,
    this.dailyBudgetTokens = 200000,
  });

  final int promptTokens;
  final int completionTokens;
  final int dailyUsedTokens;
  final int dailyBudgetTokens;

  int get totalTokens => promptTokens + completionTokens;

  bool get overBudget =>
      dailyUsedTokens + totalTokens > dailyBudgetTokens;

  String get hint => overBudget
      ? '预计超出每日 token 预算，建议缩短上下文或明天再试'
      : '预计消耗 $totalTokens token，预算内';
}

CostEstimate estimateCost({
  required List<LlmMessage> messages,
  required String draftCompletion,
  required int dailyUsedTokens,
  int dailyBudgetTokens = 200000,
}) =>
    CostEstimate(
      promptTokens:
          messages.fold<int>(0, (int n, LlmMessage m) => n + estimateTokens(m.content)),
      completionTokens: estimateTokens(draftCompletion),
      dailyUsedTokens: dailyUsedTokens,
      dailyBudgetTokens: dailyBudgetTokens,
    );

/// 脱敏日志：只记 URL + 状态码 + token 数，**不记 body / Key**。
Map<String, Object?> redactedRequestLog({
  required LlmEndpoint endpoint,
  required int statusCode,
  required int totalTokens,
}) =>
    <String, Object?>{
      'url': '${endpoint.baseUrl}${endpoint.chatCompletionsPath}',
      'status': statusCode,
      'tokens': totalTokens,
      'model': endpoint.model,
    };

/// 检索结果 5 分钟缓存键（相同 query 复用，避免重复烧 token）。
String cacheKeyFor(String query, {int nowMs = 0}) {
  final bucket = nowMs ~/ const Duration(minutes: 5).inMilliseconds;
  return '${query.trim().toLowerCase()}@$bucket';
}
