/// 「清除所有 AI 数据」计划（docs/07 §7.3）。
///
/// 不删库、不碰安全存储：只列出要清的本地数据域、执行顺序、
/// 二次确认与不可逆提示；真实删除由平台层按计划逐项执行。
library;

enum AiDataDomain {
  conversations('对话消息', 'message / conversation 记录'),
  aiDiaries('AI 日记', 'kind=4 生成条目'),
  searchCache('检索缓存', '内存 5 分钟结果缓存'),
  activityQueries('搜索活动记录', 'activity.query 字段'),
  apiKey('云端 API Key', 'flutter_secure_storage 中的凭据');

  const AiDataDomain(this.label, this.detail);

  final String label;
  final String detail;
}

class AiDataClearancePlan {
  const AiDataClearancePlan({
    required this.allowed,
    required this.domains,
    required this.steps,
    required this.hint,
  });

  final bool allowed;
  final List<AiDataDomain> domains;
  final List<String> steps;
  final String hint;

  Map<String, Object?> toJson() => <String, Object?>{
        'allowed': allowed,
        'domains': <String>[for (final d in domains) d.name],
        'steps': steps,
        'hint': hint,
      };
}

/// 必须逐次二次确认；未确认只给清单，不允许执行。
/// [keepUserNotes] 永远为真：用户手写笔记/日记绝不因 AI 清理被删。
AiDataClearancePlan planAiDataClearance({
  required bool userConfirmed,
  bool keepUserNotes = true,
}) {
  final domains = AiDataDomain.values.toList();
  final steps = <String>[
    '停掉进行中的 AI 任务与工具调用',
    '清空检索缓存（内存）',
    '删除 message / conversation 记录',
    '删除 kind=4 的 AI 日记条目（用户日记不动）',
    '清空 activity.query 搜索词',
    '删除安全存储中的云端 API Key',
    '重置本地 AI 偏好为默认（AI 日记搜索开关关闭）',
  ];
  return AiDataClearancePlan(
    allowed: userConfirmed && keepUserNotes,
    domains: List<AiDataDomain>.unmodifiable(domains),
    steps: List<String>.unmodifiable(steps),
    hint: userConfirmed
        ? '将不可逆删除上述 AI 数据；用户手写笔记 / 日记不在此列'
        : '此操作不可逆，请先二次确认；用户手写内容永远不会被删除',
  );
}
