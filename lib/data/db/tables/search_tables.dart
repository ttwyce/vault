import 'package:drift/drift.dart';

/// 日记月历索引。**可随时从 entry 重建**，所以不参与同步。
///
/// 为什么需要它：月历一屏要回答"这个月哪几天写了"，直接扫 entry 表
/// 按 created_at 分组会用到不了索引（日期是本地时区概念，不是 created_at）。
@DataClassName('DiaryIndexRow')
class DiaryIndexes extends Table {
  @override
  String get tableName => 'diary_index';

  /// YYYY-MM-DD（本地时区）。**不能用 created_at 推** ——
  /// 补写、跨时区、"凌晨两点写的算前一天"都要求日期是显式字段。
  TextColumn get date => text()();

  /// kind=3
  TextColumn get userEntryId => text().nullable()();

  /// kind=4
  TextColumn get aiEntryId => text().nullable()();

  IntColumn get wordCount => integer().withDefault(const Constant(0))();

  IntColumn get hasMood => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{date};
}

/// 向量缓存。**本地派生数据，不参与同步**（云端同步的是 `vec/<hmac>.enc`）。
///
/// 每条向量必须带 `model_id`：不同模型的向量不可比，
/// 混在一个表里会让"换设备后检索全乱"。
@DataClassName('EntryVecRow')
@TableIndex(name: 'idx_vec_model', columns: {#modelId})
class EntryVecs extends Table {
  @override
  String get tableName => 'entry_vec';

  TextColumn get entryId => text()();

  /// 长文分块序号
  IntColumn get chunkIdx => integer().withDefault(const Constant(0))();

  TextColumn get modelId => text()();

  IntColumn get dim => integer()();

  /// int8 量化。768 维 × 1 字节 = 768B/条
  BlobColumn get vec => blob()();

  IntColumn get computedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entryId, chunkIdx};
}

/// 已安装的嵌入模型。
@DataClassName('EmbeddingModelRow')
class EmbeddingModels extends Table {
  @override
  String get tableName => 'embedding_model';

  TextColumn get id => text()();

  TextColumn get family => text().nullable()();

  IntColumn get dim => integer().nullable()();

  /// 可裁剪维度列表，逗号分隔（MRL）
  TextColumn get mrl => text().nullable()();

  IntColumn get ctx => integer().nullable()();

  TextColumn get quant => text().nullable()();

  TextColumn get sha256 => text().nullable()();

  TextColumn get path => text().nullable()();

  /// 0 未下载 / 1 下载中 / 2 就绪 / 3 损坏
  IntColumn get state => integer().withDefault(const Constant(0))();

  IntColumn get installedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
