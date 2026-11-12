/// 首次绑定已有 vault 的三选一策略（docs/04 §8.1）。
///
/// 不联网、不写库：只判定「本地已有数据 + 云端已有 vault 时，
/// 三个选项各自该做什么、哪个是推荐项、哪个必须二次确认」。
/// 真实 GET meta.enc / 备份 / 覆盖由平台层按计划执行。
library;

enum FirstBindOption { merge, preferCloud, preferLocal }

class FirstBindPlan {
  const FirstBindPlan({
    required this.option,
    required this.allowed,
    required this.recommended,
    required this.needsSecondConfirm,
    required this.backupTarget,
    required this.reason,
  });

  final FirstBindOption option;
  final bool allowed;
  final bool recommended;
  final bool needsSecondConfirm;

  /// `trash` / `quarantine` / `none`。
  final String backupTarget;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'option': option.name,
        'allowed': allowed,
        'recommended': recommended,
        'needs_second_confirm': needsSecondConfirm,
        'backup_target': backupTarget,
        'reason': reason,
      };
}

/// [cloudHasVault] / [localHasData] 决定三选一是否都可选；
/// 云端为空或本地为空时不需要三选一（直接走 §8.2 / 全量下载）。
bool needsFirstBindChoice({
  required bool cloudHasVault,
  required bool localHasData,
}) =>
    cloudHasVault && localHasData;

/// 生成三个选项的计划（顺序固定，UI 直接渲染）。
List<FirstBindPlan> planFirstBind({
  required bool cloudHasVault,
  required bool localHasData,
}) {
  if (!needsFirstBindChoice(
    cloudHasVault: cloudHasVault,
    localHasData: localHasData,
  )) {
    return const <FirstBindPlan>[];
  }
  return const <FirstBindPlan>[
    FirstBindPlan(
      option: FirstBindOption.merge,
      allowed: true,
      recommended: true,
      needsSecondConfirm: false,
      backupTarget: 'none',
      reason: '重复 id 走冲突规则，不同 id 全部保留（推荐）',
    ),
    FirstBindPlan(
      option: FirstBindOption.preferCloud,
      allowed: true,
      recommended: false,
      needsSecondConfirm: false,
      backupTarget: 'trash',
      reason: '本地数据先备份到 trash 再被云端覆盖',
    ),
    FirstBindPlan(
      option: FirstBindOption.preferLocal,
      allowed: true,
      recommended: false,
      needsSecondConfirm: true,
      backupTarget: 'quarantine',
      reason: '云端数据先下载到 quarantine 再覆盖，需二次确认',
    ),
  ];
}

/// 用户确认后给出该选项的执行清单（供平台层逐步执行，任一步失败不丢数据）。
class FirstBindExecution {
  const FirstBindExecution({
    required this.steps,
    required this.rebuildIndexes,
  });

  final List<String> steps;
  final bool rebuildIndexes;

  bool get isEmpty => steps.isEmpty;
}

FirstBindExecution executionFor(FirstBindOption option) => switch (option) {
      FirstBindOption.merge => const FirstBindExecution(
          steps: <String>[
            '下载云端条目',
            '重复 id 走三方合并 / 冲突副本',
            '不同 id 全部本地保留',
            '合并结果作为新 oplog 追加',
          ],
          rebuildIndexes: true,
        ),
      FirstBindOption.preferCloud => const FirstBindExecution(
          steps: <String>[
            '本地数据写入 trash（可恢复）',
            '清空本地冲突集合',
            '全量下载云端条目',
          ],
          rebuildIndexes: true,
        ),
      FirstBindOption.preferLocal => const FirstBindExecution(
          steps: <String>[
            '云端数据下载到 quarantine（只读留证）',
            '二次确认用户仍要以本地为准',
            '按本地 oplog 顺序覆盖云端',
          ],
          rebuildIndexes: true,
        ),
    };
