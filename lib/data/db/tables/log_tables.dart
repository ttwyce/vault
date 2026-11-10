import 'package:drift/drift.dart';

/// 变更日志 = outbox。
///
/// **所有写操作先写 oplog，再改实体，同一事务内。**
/// 任何合并出错、同步中断、甚至数据库损坏，都能从 oplog 重放恢复。
///
/// 永不物理删除（只做周期性 compact 成快照），否则"回滚依据"就没了。
@DataClassName('OplogRow')
@TableIndex(name: 'idx_oplog_pending', columns: {#applied, #seq})
@TableIndex(name: 'idx_oplog_entity', columns: {#entity, #entityId})
class Oplogs extends Table {
  @override
  String get tableName => 'oplog';

  IntColumn get seq => integer().autoIncrement()();

  TextColumn get hlc => text()();

  TextColumn get deviceId => text()();

  /// entry / category / tag / entry_taxonomy / credential /
  /// conversation / message / blob / meta
  TextColumn get entity => text()();

  TextColumn get entityId => text()();

  /// 1 create / 2 update / 3 delete / 4 restore / 5 merge
  IntColumn get op => integer()();

  /// 加密后的完整快照
  BlobColumn get payload => blob().nullable()();

  /// 合并用的基准版本号
  IntColumn get baseRev => integer().nullable()();

  /// 0 = 待推送，1 = 已推送
  IntColumn get applied => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer()();
}

/// 活动埋点。**AI 日总结的唯一燃料，必须第一版就埋，后补就永远缺历史数据。**
///
/// 只记 App 内行为。用户"今天做了什么"如果只靠这个，价值有限
/// （会退化成"你今天写了 3 条笔记"），所以它还要配合全局快速输入
/// 让用户主动留一句话，两者合起来才够。
@DataClassName('ActivityRow')
@TableIndex(name: 'idx_activity_ts', columns: {#ts})
@TableIndex(name: 'idx_activity_kind_ts', columns: {#kind, #ts})
class Activities extends Table {
  @override
  String get tableName => 'activity';

  IntColumn get id => integer().autoIncrement()();

  /// UTC 毫秒
  IntColumn get ts => integer()();

  /// 1 view / 2 create / 3 edit / 4 search / 5 clip / 6 archive_view
  IntColumn get kind => integer()();

  TextColumn get entryId => text().nullable()();

  /// 停留时长，用于区分"扫了一眼"和"读了五分钟"
  IntColumn get dwellMs => integer().nullable()();

  /// 搜索词。**注意这是敏感数据**，日总结只用它做聚类，不外发。
  TextColumn get query => text().nullable()();

  /// 其它维度 JSON（来源入口、设备、是否离线等）
  TextColumn get extra => text().nullable()();
}

/// 活动类型。用 int 存库，用 enum 写代码。
enum ActivityKind {
  view(1),
  create(2),
  edit(3),
  search(4),
  clip(5),
  archiveView(6);

  const ActivityKind(this.code);

  final int code;

  static ActivityKind? fromCode(int code) {
    for (final kind in ActivityKind.values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

/// 操作类型（oplog.op）。
enum OplogOp {
  create(1),
  update(2),
  delete(3),
  restore(4),
  merge(5);

  const OplogOp(this.code);

  final int code;
}

/// 同步实体类型。拼错一个字符串就同步不上，所以收敛成常量。
abstract final class SyncEntity {
  const SyncEntity._();

  static const String entry = 'entry';
  static const String category = 'category';
  static const String tag = 'tag';

  /// 条目 ↔ 分类/标签 的关联。
  ///
  /// 文档 11 只提到 category / tag 两个新实体，但**关联本身也要同步**：
  /// 否则「给笔记打了个标签」在另一台设备上不会生效。不能塞进 `entry` ——
  /// 正文没变、rev 也不该 +1，硬塞会让合并器误判成正文更新，
  /// 甚至覆盖掉对方真正的编辑。
  static const String entryTaxonomy = 'entry_taxonomy';

  static const String credential = 'credential';
  static const String conversation = 'conversation';
  static const String message = 'message';
  static const String blob = 'blob';
  static const String meta = 'meta';
}
