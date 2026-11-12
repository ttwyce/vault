/// 云端 `meta.schema` 与本地 schema 不一致时的处理（docs/03 §9）。
///
/// 不读写 `meta.enc`、不发请求：只按 schema 高低与设备版本集合给出
/// 「拒绝 / 允许 / 同步后写回」计划。
library;

enum SchemaSyncAction { rejectTooNew, allow, allowThenUpgrade }

class SchemaUpgradePlan {
  const SchemaUpgradePlan({
    required this.action,
    required this.reason,
    required this.writeBackSchema,
  });

  final SchemaSyncAction action;
  final String reason;
  final int? writeBackSchema;
}

/// [deviceVersions] 的 key 是 `device_ids`，value 是该设备自报的
/// 支持的最大 schema；缺失视为「未升级」。
SchemaUpgradePlan planSchemaUpgrade({
  required int localSchema,
  required int remoteSchema,
  required Map<String, int> deviceVersions,
  required Iterable<String> deviceIds,
}) {
  if (remoteSchema > localSchema) {
    return const SchemaUpgradePlan(
      action: SchemaSyncAction.rejectTooNew,
      reason: '云端 schema 高于本地，拒绝同步并提示升级 App，'
          '防止低版本破坏高版本数据',
      writeBackSchema: null,
    );
  }
  if (remoteSchema == localSchema) {
    return const SchemaUpgradePlan(
      action: SchemaSyncAction.allow,
      reason: 'schema 一致，正常同步',
      writeBackSchema: null,
    );
  }
  // 云端 schema 低于本地：只有当所有已知设备都已升级才写回。
  final outdated = <String>[
    for (final id in deviceIds)
      if ((deviceVersions[id] ?? 0) < localSchema) id,
  ];
  if (outdated.isNotEmpty) {
    return SchemaUpgradePlan(
      action: SchemaSyncAction.allow,
      reason: '允许同步但不写回新 schema：设备 ${outdated.join('、')} '
          '尚未升级，写回会把它们锁在门外',
      writeBackSchema: null,
    );
  }
  return SchemaUpgradePlan(
    action: SchemaSyncAction.allowThenUpgrade,
    reason: '所有设备已升级，本轮同步完成后把 meta.schema 写回 $localSchema',
    writeBackSchema: localSchema,
  );
}
