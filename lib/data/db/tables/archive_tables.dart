import 'package:drift/drift.dart';

/// 归档 blob 引用。
///
/// `local` 默认 0（仅云端）：快照按需下载。**这条如果漏了同步会直接崩** ——
/// 1000 条完整归档 = 3GB，每次全量同步不可能。
@DataClassName('BlobRefRow')
@TableIndex(name: 'idx_blob_local', columns: {#local, #bytes})
class BlobRefs extends Table {
  @override
  String get tableName => 'blob_ref';

  TextColumn get entryId => text()();

  /// sha256，内容寻址
  TextColumn get blobHash => text()();

  /// 1 text / 2 pdf / 3 html / 4 image / 5 favicon
  IntColumn get kind => integer()();

  IntColumn get bytes => integer()();

  /// 0 仅云端 / 1 本地已有
  IntColumn get local => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entryId, blobHash};
}

/// 死链与内容变更检查历史。
///
/// `simhash` 是内容指纹：只比它就知道"页面改过了"，
/// 不用下载全文对比。这是归档子系统里最省流量的一个设计。
@DataClassName('LinkCheckRow')
class LinkChecks extends Table {
  @override
  String get tableName => 'link_check';

  TextColumn get entryId => text()();

  IntColumn get checkedAt => integer()();

  IntColumn get httpStatus => integer().nullable()();

  /// ok / dead / restricted / unreachable / changed
  TextColumn get result => text()();

  TextColumn get finalUrl => text().nullable()();

  TextColumn get simhash => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entryId, checkedAt};
}

/// 后台任务队列。定时归档、重建向量、死链检测都排这里。
///
/// 三端可靠性差异极大（Windows 常驻、Android 受 Doze 影响、iOS 额度极少），
/// 所以队列必须**可中断、可续跑**，并且靠"下次打开 App 补跑"兜底。
@DataClassName('JobQueueRow')
@TableIndex(name: 'idx_job_ready', columns: {#state, #nextRunAt})
class JobQueues extends Table {
  @override
  String get tableName => 'job_queue';

  IntColumn get id => integer().autoIncrement()();

  /// embed / archive / reembed_all / deadlink / compact_oplog / purge_trash
  TextColumn get type => text()();

  TextColumn get payload => text().nullable()();

  /// 0 pending / 1 running / 2 done / 3 failed
  IntColumn get state => integer().withDefault(const Constant(0))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  IntColumn get nextRunAt => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer()();
}
