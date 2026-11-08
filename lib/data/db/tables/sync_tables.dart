import 'package:drift/drift.dart';

/// 云端路径 → etag 映射。冲突检测的基础。
///
/// **不用 mtime 判断冲突**：各端时钟不一致，mtime 只能当提示，
/// 唯一可靠的判据是 ETag + `If-Match`。
@DataClassName('SyncStateRow')
class SyncStates extends Table {
  @override
  String get tableName => 'sync_state';

  /// 云端相对路径，如 `items/a/3f9c....enc`
  TextColumn get path => text()();

  TextColumn get etag => text().nullable()();

  IntColumn get size => integer().nullable()();

  /// 本地见到的该文件最大 hlc
  TextColumn get hlc => text().nullable()();

  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{path};
}

/// 各设备水位。**整套同步里性价比最高的一处优化**：
/// 一次 `PROPFIND devices/` 就能判断"有没有变化"，
/// 比全库 PROPFIND 便宜两个数量级。
@DataClassName('DeviceWatermarkRow')
class DeviceWatermarks extends Table {
  @override
  String get tableName => 'device_watermark';

  TextColumn get deviceId => text()();

  TextColumn get maxHlc => text().nullable()();

  IntColumn get lastSeen => integer().nullable()();

  TextColumn get platform => text().nullable()();

  TextColumn get appVersion => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{deviceId};
}

/// 同步历史（诊断用）。用户报"同步不动了"时，这张表是第一现场。
@DataClassName('SyncLogRow')
class SyncLogs extends Table {
  @override
  String get tableName => 'sync_log';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get startedAt => integer().nullable()();

  IntColumn get finishedAt => integer().nullable()();

  /// manual / foreground / debounce / timer / background
  TextColumn get trigger => text().nullable()();

  /// ok / partial / failed / cancelled
  TextColumn get result => text().nullable()();

  IntColumn get pulled => integer().nullable()();

  IntColumn get pushed => integer().nullable()();

  IntColumn get conflicts => integer().nullable()();

  TextColumn get errorCode => text().nullable()();

  TextColumn get errorMsg => text().nullable()();

  IntColumn get requestCount => integer().nullable()();
}
