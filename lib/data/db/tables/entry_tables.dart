import 'package:drift/drift.dart';

/// 统一条目表。笔记 / 想法 / 日记 / AI 日记 / 书签 / 密码都是它。
///
/// 为什么不给不同 kind 建不同表：三视图（笔记 / 想法 / 日记）共享同一套
/// 编辑、搜索、同步、历史、回收站逻辑。拆表等于把五套逻辑复制三遍。
/// 只有 `credential` 因为字段结构完全不同才单独一张一对一扩展表。
///
/// 主键是 UUIDv7（时间有序），见 `lib/core/identity/uuid_v7.dart`。
/// `hlc` 与 `rev` 是同步合并的依据，`content_hash` 用于校验合并结果。
@DataClassName('EntryRow')
@TableIndex(name: 'idx_entry_kind_time', columns: {#kind, #deleted, #updatedAt})
@TableIndex(name: 'idx_entry_hlc', columns: {#hlc})
class Entries extends Table {
  @override
  String get tableName => 'entry';

  TextColumn get id => text()();

  /// 1 笔记 / 2 想法 / 3 日记 / 4 AI 日记 / 5 书签 / 6 密码
  IntColumn get kind => integer()();

  TextColumn get title => text().nullable()();

  /// Markdown 正文
  TextColumn get body => text().nullable()();

  /// 按 kind 区分的扩展字段 JSON（见 docs/13 §3）。
  /// **扩展字段一律进 meta，不给本表加列** —— 加列就要迁移，而 meta 是 JSON。
  TextColumn get meta => text().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  /// 混合逻辑时钟，格式 `0000018F2A3B4C5D:0003:devA`
  TextColumn get hlc => text()();

  IntColumn get rev => integer().withDefault(const Constant(1))();

  /// sha256(canonical)，合并后必须校验一致
  TextColumn get contentHash => text()();

  IntColumn get deleted => integer().withDefault(const Constant(0))();

  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// 条目类型。用 int 存库，用 enum 写代码 —— 和 `ActivityKind` 同一套做法。
///
/// `credential` 在这里出现，但它**另有一张一对一扩展表** `credential`。
/// 本表的 `kind=6` 只是让密码条目也能出现在统一列表、统一搜索、统一同步里。
enum EntryKind {
  note(1),
  thought(2),
  diary(3),
  aiDiary(4),
  bookmark(5),
  credential(6);

  const EntryKind(this.code);

  final int code;

  static EntryKind? fromCode(int code) {
    for (final kind in EntryKind.values) {
      if (kind.code == code) return kind;
    }
    return null;
  }

  /// 是否属于"用户自己写的正文类条目"。AI 日记不算 ——
  /// 默认搜索不返回它，否则用户搜自己的东西先看到一堆二手总结。
  bool get isUserAuthored => this != EntryKind.aiDiary;
}

/// 历史版本。**三方合并的 base 就存在这里** —— 没有 base 就只能生成冲突副本。
///
/// 每条 entry 保留最近 5 个版本（更老的由 `job_queue` 里的清理任务删）。
/// payload 是加密快照，不是明文 JSON。
@DataClassName('EntryHistoryRow')
class EntryHistory extends Table {
  @override
  String get tableName => 'entry_history';

  TextColumn get entryId => text()();

  IntColumn get rev => integer()();

  BlobColumn get payload => blob()();

  TextColumn get hlc => text()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entryId, rev};
}

/// 回收站。删除先进这里，保留 30 天，可一键恢复。
///
/// 和 `deleted` 标记的分工：`entry.deleted=1` 表示"用户删了，但墓碑还没同步出去"，
/// `trash` 表示"内容还在，30 天内能救回来"。
@DataClassName('TrashRow')
class TrashRows extends Table {
  @override
  String get tableName => 'trash';

  TextColumn get entryId => text()();

  BlobColumn get payload => blob()();

  IntColumn get deletedAt => integer()();

  /// 默认 deletedAt + 30 天
  IntColumn get expireAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entryId};
}
