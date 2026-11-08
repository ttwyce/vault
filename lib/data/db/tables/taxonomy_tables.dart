import 'package:drift/drift.dart';

/// 分类树（两级，禁止三级）。
///
/// 分类与标签分工（docs/11 §2）：分类管归属（最多 1 个，两级树），
/// 标签管横切（可多个，扁平）。这条规则一放开，用户就会陷入整理瘫痪，
/// AI 也失去"这条该放哪"的判断依据。
@DataClassName('CategoryRow')
@TableIndex(name: 'idx_cat_kind', columns: {#kind, #parentId, #sortOrder})
class Categories extends Table {
  @override
  String get tableName => 'category';

  TextColumn get id => text()();

  /// 归属类型，与 entry.kind 对齐
  IntColumn get kind => integer()();

  /// null = 一级；非空 = 二级
  TextColumn get parentId => text().nullable()();

  TextColumn get name => text()();

  TextColumn get color => text().nullable()();

  TextColumn get icon => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 冗余计数，异步更新（为了列表页不用 count(*) 扫全表）
  IntColumn get entryCount => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer().nullable()();

  IntColumn get updatedAt => integer().nullable()();

  TextColumn get hlc => text()();

  IntColumn get deleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// 全局标签。扁平、无层级、可多个。
@DataClassName('TagRow')
@TableIndex(name: 'idx_tag_name', columns: {#name})
class Tags extends Table {
  @override
  String get tableName => 'tag';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get color => text().nullable()();

  IntColumn get usageCount => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer().nullable()();

  IntColumn get updatedAt => integer().nullable()();

  TextColumn get hlc => text()();

  IntColumn get deleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// 条目 ↔ 分类。业务上一条最多 1 个分类，但用多对多表是为了
/// 同步时能独立合并（同名分类合并要改指关联，见 docs/11 §2.5）。
@DataClassName('EntryCategoryRow')
class EntryCategories extends Table {
  @override
  String get tableName => 'entry_category';

  TextColumn get entryId => text()();

  TextColumn get categoryId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entryId, categoryId};
}

/// 条目 ↔ 标签（一条最多 8 个）。
@DataClassName('EntryTagRow')
class EntryTags extends Table {
  @override
  String get tableName => 'entry_tag';

  TextColumn get entryId => text()();

  TextColumn get tagId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entryId, tagId};
}

/// 分组内的字段模板（账号专用）。
///
/// 这是"分组"真正的价值所在：在「工作 › 开发」下新建账号，
/// 自动带上「恢复码（私密）/ 团队名 / 部署环境」，不用每次手动加。
@DataClassName('CategoryFieldTemplateRow')
@TableIndex(name: 'idx_template_cat', columns: {#categoryId, #sortOrder})
class CategoryFieldTemplates extends Table {
  @override
  String get tableName => 'category_field_template';

  TextColumn get id => text()();

  TextColumn get categoryId => text()();

  TextColumn get label => text()();

  /// text / url / number / secret
  TextColumn get type => text().withDefault(const Constant('text'))();

  /// 模板本身不带值，只带"建号时要加这个字段"
  IntColumn get secret => integer().withDefault(const Constant(0))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get hlc => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
