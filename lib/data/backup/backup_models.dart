/// 导出 / 备份的纯判定层（docs/03 §10）。
///
/// 不写 zip、不碰文件系统、不联网：只定义「加密备份包里该有什么、
/// /backup/ 与 /vault/ 怎么隔离、7 天自动备份什么时候该跑、
/// 明文导出必须过哪几道确认」。真实打包用平台层按这里的结构执行。
library;

/// 备份包内容清单（加密 zip 里的 manifest）。
class BackupManifest {
  const BackupManifest({
    required this.schema,
    required this.vaultId,
    required this.createdAt,
    required this.entries,
    required this.blobs,
    required this.models,
  });

  final int schema;
  final String vaultId;
  final int createdAt;

  /// entry id → content_hash（用于导入时无冲突合并）。
  final Map<String, String> entries;

  /// blob sha256 → bytes。
  final Map<String, int> blobs;
  final List<String> models;

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': schema,
        'vault_id': vaultId,
        'created_at': createdAt,
        'entries': entries,
        'blobs': blobs,
        'models': models,
      };

  factory BackupManifest.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('备份 manifest 不是 JSON 对象');
    }
    final map = Map<String, Object?>.from(raw);
    final schema = map['schema'];
    final vaultId = map['vault_id'];
    final createdAt = map['created_at'];
    if (schema is! int || schema < 1 ||
        vaultId is! String || vaultId.isEmpty ||
        createdAt is! int) {
      throw const FormatException('备份 manifest 头部不合法');
    }
    final entries = map['entries'];
    final blobs = map['blobs'];
    final models = map['models'];
    if (entries is! Map || blobs is! Map || models is! List) {
      throw const FormatException('备份 manifest 清单不合法');
    }
    return BackupManifest(
      schema: schema,
      vaultId: vaultId,
      createdAt: createdAt,
      entries: <String, String>{
        for (final item in entries.entries)
          item.key.toString(): item.value.toString(),
      },
      blobs: <String, int>{
        for (final item in blobs.entries)
          item.key.toString(): (item.value as num).toInt(),
      },
      models: models.map((Object? v) => v.toString()).toList(),
    );
  }
}

/// docs/03 §10：`/backup/` 必须与 `/vault/` 分离，否则自动备份会被
/// 同步引擎的 L2 扫描当成普通条目文件。
const String kBackupRoot = '/backup';
const String kVaultRoot = '/vault';

String backupPath(String fileName) {
  if (fileName.isEmpty || fileName.contains('/') || fileName.contains('..')) {
    throw const FormatException('备份文件名不合法');
  }
  return '$kBackupRoot/$fileName';
}

bool isBackupPath(String path) => path.startsWith('$kBackupRoot/');

/// 每 7 天自动备份（docs/03 §10）。首次启用时立即排一次。
int nextBackupAt(int? lastBackupAt, int nowMs) {
  if (lastBackupAt == null) return nowMs;
  return lastBackupAt + const Duration(days: 7).inMilliseconds;
}

/// 明文导出状态机（docs/03 §10：二次确认 + 危险提示）。
enum PlaintextExportStage { idle, warned, confirmed, done }

PlaintextExportStage advancePlaintextExport(
  PlaintextExportStage stage, {
  required bool acknowledgedDanger,
  required bool secondConfirmation,
}) {
  return switch (stage) {
    PlaintextExportStage.idle => acknowledgedDanger
        ? PlaintextExportStage.warned
        : PlaintextExportStage.idle,
    PlaintextExportStage.warned => secondConfirmation
        ? PlaintextExportStage.confirmed
        : PlaintextExportStage.warned,
    PlaintextExportStage.confirmed => PlaintextExportStage.done,
    PlaintextExportStage.done => PlaintextExportStage.done,
  };
}

/// 导入时的「无冲突合并」判定：本地已有同 id 且 hash 相同 → 跳过；
/// 本地已有但 hash 不同 → 冲突副本，绝不覆盖。
enum ImportAction { insert, skip, conflictCopy }

ImportAction decideImport(String contentHash, String? localHash) {
  if (localHash == null) return ImportAction.insert;
  return localHash == contentHash
      ? ImportAction.skip
      : ImportAction.conflictCopy;
}
