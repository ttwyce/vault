/// 聊天上下文预算与自动压缩（docs/07 §7.3）。
///
/// 不联网、不写库：把会话历史按角色转成 LlmMessage，估算 token，
/// 超预算时把较早的对话压成一条「历史摘要」而不是静默丢掉。
/// 摘要本身也计入预算，必要时逐字裁剪，保证输出不超过预算。
library;

import 'openai_compat.dart';

/// 默认留给回答的 token；输入预算 = maxTokens - reserve。
const int kDefaultCompletionReserveTokens = 768;

class LlmContextPlan {
  const LlmContextPlan({
    required this.messages,
    required this.originalTokens,
    required this.packedTokens,
    required this.compressedTurns,
    required this.budgetTokens,
  });

  final List<LlmMessage> messages;
  final int originalTokens;
  final int packedTokens;
  final int compressedTurns;
  final int budgetTokens;

  bool get compressed => compressedTurns > 0;

  String get hint => compressed
      ? '上下文 $originalTokens → $packedTokens token'
          '（已压缩 $compressedTurns 轮历史）'
      : '上下文 $packedTokens / $budgetTokens token';
}

/// 把会话历史打包进预算。
///
/// [systemPrompt] 与 [currentQuestion] 永不压缩；历史按时间从旧到新，
/// 超预算时把最早的若干轮合成一条 system 摘要。
LlmContextPlan packLlmContext({
  required String systemPrompt,
  required List<LlmMessage> history,
  required String currentQuestion,
  required int maxTokens,
  int completionReserveTokens = kDefaultCompletionReserveTokens,
}) {
  final budget = maxTokens > completionReserveTokens
      ? maxTokens - completionReserveTokens
      : maxTokens ~/ 2;
  final fixedTokens =
      estimateTokens(systemPrompt) + estimateTokens(currentQuestion);
  final originalTokens = fixedTokens +
      history.fold<int>(
          0, (int sum, LlmMessage m) => sum + estimateTokens(m.content));

  // 需要压缩时先给摘要预留一个上限，否则保留了再多历史也会被摘要挤爆。
  final skippedHint = history.isNotEmpty ? 24 : 0;
  final availableForHistory = budget - fixedTokens - skippedHint;
  final kept = <LlmMessage>[];
  var keptTokens = 0;
  if (availableForHistory > 0) {
    for (var i = history.length - 1; i >= 0; i--) {
      final cost = estimateTokens(history[i].content);
      if (keptTokens + cost > availableForHistory) break;
      kept.insert(0, history[i]);
      keptTokens += cost;
    }
  }
  final skipped = history.length - kept.length;
  final summary = skipped > 0
      ? LlmMessage(
          role: 'system',
          content: _summarize(
            history.sublist(0, skipped),
            maxTokens: budget - fixedTokens - keptTokens,
          ),
        )
      : null;
  final messages = <LlmMessage>[
    LlmMessage(role: 'system', content: systemPrompt),
    ?summary,
    ...kept,
    LlmMessage(role: 'user', content: currentQuestion),
  ];
  final packedTokens = messages.fold<int>(
      0, (int sum, LlmMessage m) => sum + estimateTokens(m.content));

  return LlmContextPlan(
    messages: messages,
    originalTokens: originalTokens,
    packedTokens: packedTokens,
    compressedTurns: skipped,
    budgetTokens: budget,
  );
}

String _summarize(List<LlmMessage> removed, {required int maxTokens}) {
  final prefix = '前 ${removed.length} 轮历史摘要：';
  final prefixCost = estimateTokens(prefix);
  final room = maxTokens - prefixCost - 2;
  if (room <= 0) return prefix;
  final text = removed.map((LlmMessage m) => m.content).join(' ');
  // 中文约 1 字 1 token，留 1 token 给省略号；按字符裁剪即可保守达标。
  final limit = room < text.length ? room : text.length;
  return '$prefix${text.substring(0, limit)}…';
}
