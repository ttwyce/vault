/// U4「一屏红色不超过 3 处」的纯审计（docs/10 §12）。
///
/// 不渲染、不读 context：把一屏里用红的组件按用途列出，
/// 统计并给出降级建议。真实计数由页面按 [RedUsage] 逐项上报。
library;

/// docs/10 §2：红只给「AI 动作 / 当前状态 / 主按钮」；
/// 危险类徽章属于「当前状态」，其它用途一律不该用红。
enum RedUsage { aiAction, currentState, primaryButton, dangerBadge, other }

const int kMaxRedPerScreen = 3;

class RedUsageReport {
  const RedUsageReport({
    required this.count,
    required this.passed,
    required this.suggestions,
  });

  final int count;
  final bool passed;
  final List<String> suggestions;
}

RedUsageReport auditRedUsage(Iterable<RedUsage> usages) {
  final list = usages.toList();
  final invalid = list.where((RedUsage u) => u == RedUsage.other).length;
  final suggestions = <String>[
    if (invalid > 0) '$invalid 处红色用途不在「AI 动作 / 当前状态 / 主按钮」内，改用蓝或 ghost',
    if (list.length > kMaxRedPerScreen)
      '共 ${list.length} 处红色超过上限 $kMaxRedPerScreen，'
          '把次要按钮降级为 ghost，只保留主按钮 / 当前状态',
  ];
  return RedUsageReport(
    count: list.length,
    passed: invalid == 0 && list.length <= kMaxRedPerScreen,
    suggestions: List<String>.unmodifiable(suggestions),
  );
}
