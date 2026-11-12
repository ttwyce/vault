/// 向量同步开关（docs/06 §7）。
///
/// 不联网、不写库：只定义开关状态、关掉后的代价、以及切换时
/// 「不删云端向量、不清本地向量」的保守规则，避免用户误以为
/// 开关会立刻抹掉数据。
library;

enum VectorSyncMode { enabled, disabled }

class VectorSyncSetting {
  const VectorSyncSetting({this.mode = VectorSyncMode.disabled});

  /// 默认关闭（docs/06 §7：关闭则换设备需全量重算）。
  final VectorSyncMode mode;

  bool get enabled => mode == VectorSyncMode.enabled;

  Map<String, Object?> toJson() => <String, Object?>{'enabled': enabled};

  factory VectorSyncSetting.fromJson(Object? raw) {
    if (raw is! Map) return const VectorSyncSetting();
    return VectorSyncSetting(
      mode: raw['enabled'] == true
          ? VectorSyncMode.enabled
          : VectorSyncMode.disabled,
    );
  }
}

class VectorSyncTogglePlan {
  const VectorSyncTogglePlan({
    required this.next,
    required this.hint,
    required this.actions,
    required this.needsSecondConfirm,
  });

  final VectorSyncSetting next;
  final String hint;
  final List<String> actions;
  final bool needsSecondConfirm;
}

VectorSyncTogglePlan planVectorSyncToggle(VectorSyncSetting current) {
  if (current.enabled) {
    // 关闭是保守操作：既不删云端向量，也不清本地向量。
    return const VectorSyncTogglePlan(
      next: VectorSyncSetting(mode: VectorSyncMode.disabled),
      hint: '关闭后新设备需全量重算向量（本地已有的向量仍然可用）；'
          '云端已加密的向量不会被删除',
      actions: <String>[
        '停止后续向量上传',
        '保留云端 /vault/vec/ 既有封包',
        '保留本地 entry_vec',
      ],
      needsSecondConfirm: true,
    );
  }
  return const VectorSyncTogglePlan(
    next: VectorSyncSetting(mode: VectorSyncMode.enabled),
    hint: '开启后向量以加密封包同步；model_id / dim 不匹配一律丢弃重算',
    actions: <String>[
      '按当前活跃模型校验 model_id / dim',
      '仅上传校验通过的加密向量',
      '新设备拉取后写入本地 entry_vec',
    ],
    needsSecondConfirm: false,
  );
}
