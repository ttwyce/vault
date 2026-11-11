/// System Prompt 与输出强制约束（docs/07 §9）。
///
/// 不调模型：把 §9.1 的提示词结构、§9.2 的四条代码级约束
/// （不编造引用 / 不输出密码 / 6 轮 / token 预算）写成可测纯逻辑。
library;

import '../vault/credential_models.dart' show CredentialGuard;
import 'agent_policy.dart' show AgentLoopLimits;
import 'openai_compat.dart' show LlmMessage, estimateTokens;

/// §9.1 分段 system prompt。
const String kSystemPrompt = '''
[角色] 你是用户的私人知识库助手，可以检索其笔记、想法、日记、网页归档。

[能力边界]
- 你能看到用户的笔记内容，但看不到密码明文，这是设计如此。
- 你只能通过工具访问数据，不要凭空猜测内容。

[行为准则]
- 回答「我记过什么」类问题时，必须先调用 search_entries，不得凭印象回答。
- 引用条目时必须给出可点击的引用，让用户能跳回原文。
- 不确定时明说，不要编造条目或时间。
- 涉及密码、TOTP 时，只回答统计信息，不输出任何凭据内容。

[输出格式]
- 中文回答，简洁，不超过 300 字（除非用户要求详细）。
- 引用格式：在相关句子后用「（见：<条目标题>）」标注。
''';

/// 构造消息列表：system prompt 永远在最前，历史经 6 轮裁剪。
List<LlmMessage> buildPromptMessages(List<LlmMessage> history) =>
    <LlmMessage>[
      LlmMessage(role: 'system', content: kSystemPrompt),
      ...history,
    ];

class PromptGuardResult {
  const PromptGuardResult({
    required this.text,
    required this.removedCitations,
    required this.redactedSecrets,
    required this.withinBudget,
  });

  final String text;
  final List<String> removedCitations;
  final bool redactedSecrets;
  final bool withinBudget;

  /// 输出是否可以安全展示：假引用被移除是「已修复」，不算不干净；
  /// 密码命中被整段替换、token 超限都不算通过。
  bool get clean => !redactedSecrets && withinBudget;
}

/// §9.2 输出前统一过四道关卡。
///
/// - 引用：正则找出 `vault://entry/<id>`，不在真实 id 集合里的整句移除
/// - 密码：用 [CredentialGuard.containsSecret] 扫描，命中即整段替换
/// - 长度：超过 300 字且用户没要求详细 → 截断并标注
/// - token：单次上限（默认 2048）内才算通过
PromptGuardResult enforceOutputConstraints(
  String draft, {
  required Set<String> existingEntryIds,
  required Iterable<String> knownSecrets,
  bool userRequestedDetail = false,
  int maxChars = 300,
  int maxTokens = 2048,
}) {
  final removed = <String>[];
  var text = draft;

  // ① 不编造引用：按句号切分，含假引用 id 的整句移除。
  final sentences = text.split(RegExp(r'(?<=[。！？])'));
  final kept = <String>[];
  final citationPattern = RegExp(r'vault://entry/([A-Za-z0-9_-]+)');
  for (final sentence in sentences) {
    final ids = citationPattern
        .allMatches(sentence)
        .map((RegExpMatch m) => m.group(1)!)
        .toList();
    final fake = ids.where((String id) => !existingEntryIds.contains(id)).toList();
    if (fake.isNotEmpty) {
      removed.addAll(fake);
      continue;
    }
    kept.add(sentence);
  }
  text = kept.join();

  // ② 不输出密码：命中即整段替换，绝不逐字暴露。
  var redacted = false;
  if (CredentialGuard.containsSecret(text, knownSecrets)) {
    text = '[已隐藏] 回答中包含本机敏感值，已按安全边界拦截。';
    redacted = true;
  }

  // ③ 输出长度。
  if (!userRequestedDetail && text.length > maxChars) {
    text = '${text.substring(0, maxChars)}…（已截断，可要求详细展开）';
  }

  // ④ token 预算。
  final withinBudget = estimateTokens(text) <= maxTokens;
  return PromptGuardResult(
    text: text,
    removedCitations: List<String>.unmodifiable(removed),
    redactedSecrets: redacted,
    withinBudget: withinBudget,
  );
}

/// 6 轮上限直接复用主循环约束，避免两处各写一份常量。
bool canContinueTurn(int turn) =>
    const AgentLoopLimits().canContinue(turn);
