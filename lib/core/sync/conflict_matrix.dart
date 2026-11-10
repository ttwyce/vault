/// 冲突规则矩阵与墓碑语义（docs/04 §5.1 / §6）。
///
/// **第 8、9 条「编辑胜」是零丢失的核心**：删除永远不能吞掉
/// 未同步的编辑。这一层只做判定、不碰数据库，判定结果交给
/// SyncEngine 去落库 —— 便于把 12 条矩阵逐条钉在测试里。
library;

/// 一侧的状态。`created` 与 `modified` 分开，是为了把
/// 「本地新建未推」和「两边都改过」区分开（前者不该走三方合并）。
enum SyncSide { absent, created, unchanged, modified, deleted, corrupt }

enum ConflictAction {
  /// 1：远端新条目，直接插入本地。
  insertRemote,
  /// 2：本地有、远端无，保持本地并等待推送。
  keepLocal,
  /// 3：只有本地改了，直接 PUT（If-Match=base）。
  pushLocal,
  /// 4：只有远端改了，覆盖本地是安全的。
  overwriteLocal,
  /// 5：两边都改了，走三方合并（失败则冲突副本）。
  merge3,
  /// 6：只有本地删了，写墓碑再 DELETE 文件。
  writeTombstone,
  /// 7：只有远端删了，本地软删进回收站（保留 30 天）。
  softDeleteLocal,
  /// 8：本地编辑 vs 远端删除 —— 编辑胜，复活条目并写新版本。
  resurrectLocalEdit,
  /// 9：本地删除 vs 远端编辑 —— 编辑胜，取消本地删除、接受远端。
  resurrectRemoteEdit,
  /// 10：两边都删了，幂等清理。
  noop,
  /// 12：解密失败 / hash 不匹配，隔离，绝不覆盖本地。
  quarantine,
}

class ConflictDecision {
  const ConflictDecision(this.action, this.rule, this.reason);

  final ConflictAction action;

  /// docs/04 §5.1 的规则编号 1~12；0 表示「文档未列出的异常组合」。
  final int rule;
  final String reason;
}

/// 判定一条条目的同步动作。
///
/// 文档没列出的组合（例如同一 id 两边都"新建"）不猜、不覆盖，
/// 一律隔离并报警。UUIDv7 保证这种事物理上不该发生（规则 11），
/// 真发生了说明有人篡改了云端文件或本地库损坏。
ConflictDecision resolveConflict({
  required SyncSide local,
  required SyncSide remote,
}) {
  // 规则 12 优先级最高：坏数据先隔离，不参与任何合并。
  if (local == SyncSide.corrupt || remote == SyncSide.corrupt) {
    return const ConflictDecision(
      ConflictAction.quarantine,
      12,
      '解密失败或 hash 不匹配：隔离到 quarantine/，不覆盖本地',
    );
  }

  // 规则 10：双方都删 / 双方都不存在
  if (local == SyncSide.deleted && remote == SyncSide.deleted) {
    return const ConflictDecision(
      ConflictAction.noop,
      10,
      '双方都已删除，幂等清理',
    );
  }
  if (local == SyncSide.absent && remote == SyncSide.absent) {
    return const ConflictDecision(ConflictAction.noop, 10, '双方都不存在');
  }
  if (local == SyncSide.unchanged && remote == SyncSide.unchanged) {
    return const ConflictDecision(ConflictAction.noop, 10, '双方都未变');
  }

  // 规则 1：远端有、本地无
  if (local == SyncSide.absent &&
      (remote == SyncSide.created ||
          remote == SyncSide.unchanged ||
          remote == SyncSide.modified)) {
    return const ConflictDecision(
      ConflictAction.insertRemote,
      1,
      '远端新条目，直接插入本地',
    );
  }

  // 规则 2：本地有、远端无（等待推送）
  if (remote == SyncSide.absent &&
      (local == SyncSide.created ||
          local == SyncSide.unchanged ||
          local == SyncSide.modified)) {
    return const ConflictDecision(
      ConflictAction.keepLocal,
      2,
      '本地有、远端无：保持本地并等待推送',
    );
  }
  if (remote == SyncSide.absent && local == SyncSide.deleted) {
    return const ConflictDecision(
      ConflictAction.noop,
      10,
      '本地已删除且远端本就没有文件：仅清理',
    );
  }

  // 规则 3 / 4：只有一侧改了
  if (local == SyncSide.modified && remote == SyncSide.unchanged) {
    return const ConflictDecision(
      ConflictAction.pushLocal,
      3,
      '只有本地改动：If-Match=base 直接 PUT',
    );
  }
  if (local == SyncSide.unchanged && remote == SyncSide.modified) {
    return const ConflictDecision(
      ConflictAction.overwriteLocal,
      4,
      '本地未变，远端改动可安全覆盖',
    );
  }

  // 规则 5：两边都改了
  if (local == SyncSide.modified && remote == SyncSide.modified) {
    return const ConflictDecision(
      ConflictAction.merge3,
      5,
      '三方合并；行级重叠则生成冲突副本',
    );
  }

  // 规则 6 / 7：单方删除
  if (local == SyncSide.deleted && remote == SyncSide.unchanged) {
    return const ConflictDecision(
      ConflictAction.writeTombstone,
      6,
      '只有本地删除：先写墓碑，再 DELETE 条目文件',
    );
  }
  if (local == SyncSide.unchanged && remote == SyncSide.deleted) {
    return const ConflictDecision(
      ConflictAction.softDeleteLocal,
      7,
      '只有远端删除：本地软删进回收站，保留 30 天',
    );
  }

  // 规则 8 / 9：编辑胜 —— 零丢失的核心
  if (local == SyncSide.modified && remote == SyncSide.deleted) {
    return const ConflictDecision(
      ConflictAction.resurrectLocalEdit,
      8,
      '本地编辑 vs 远端删除：复活条目，内容为本地版本并写新 rev',
    );
  }
  if (local == SyncSide.deleted && remote == SyncSide.modified) {
    return const ConflictDecision(
      ConflictAction.resurrectRemoteEdit,
      9,
      '本地删除 vs 远端编辑：取消本地删除，接受远端版本',
    );
  }
  if (local == SyncSide.deleted && remote == SyncSide.created) {
    return const ConflictDecision(
      ConflictAction.resurrectRemoteEdit,
      9,
      '删除期间远端出现同 id 新条目：编辑胜，保留远端',
    );
  }
  if (local == SyncSide.created && remote == SyncSide.deleted) {
    return const ConflictDecision(
      ConflictAction.resurrectLocalEdit,
      8,
      '远端墓碑但本地有未推的新建：保留本地',
    );
  }

  // 规则 11 的防御：同一 id 两边各自新建（UUIDv7 不该发生）。
  return const ConflictDecision(
    ConflictAction.quarantine,
    11,
    '同一 id 出现文档未定义的组合（疑似撞 id 或被篡改）：隔离而不是猜测',
  );
}

/// 删除顺序（docs/04 §6.1）。
///
/// **先写墓碑，再 DELETE 条目文件**。反了会让其它设备先看到文件消失，
/// 却无法判断这是「删除」还是「同步故障写到一半」，进而误删本地数据。
enum DeleteStep { writeTombstone, deleteItemFile }

class DeletePlan {
  const DeletePlan(this.steps);
  final List<DeleteStep> steps;

  static const DeletePlan standard = DeletePlan(<DeleteStep>[
    DeleteStep.writeTombstone,
    DeleteStep.deleteItemFile,
  ]);
}

/// 墓碑 TTL 与回收站保留期。集中放常量，避免两处各写一个 30/90。
const Duration kTombstoneTtl = Duration(days: 90);
const Duration kTrashRetention = Duration(days: 30);

bool isTombstoneExpired(int deletedAt, int nowMs) =>
    nowMs - deletedAt > kTombstoneTtl.inMilliseconds;

bool isTrashExpired(int deletedAt, int nowMs) =>
    nowMs - deletedAt > kTrashRetention.inMilliseconds;

enum TombstoneAction {
  /// 正常应用墓碑：本地软删进回收站。
  apply,
  /// 编辑胜：忽略墓碑，保留本地并推送新版本。
  ignoreKeepLocal,
  /// 本地已删，幂等清理。
  alreadyDeleted,
}

/// 收到远端墓碑时怎么处置。
///
/// 判据来自 docs/04 §5.1 末尾：本地有未推的编辑（`localRev > baseRev`）
/// 就忽略墓碑。T07「A 编辑、B 删除」必须走这条路，否则 A 的编辑会被吞掉。
TombstoneAction decideTombstone({
  required bool localDeleted,
  required int localRev,
  required int baseRev,
}) {
  if (localDeleted) return TombstoneAction.alreadyDeleted;
  if (localRev > baseRev) return TombstoneAction.ignoreKeepLocal;
  return TombstoneAction.apply;
}

/// 本地已删、远端却出现更新过的条目时是否复活（规则 9 / T06）。
///
/// 三个条件缺一不可：远端 rev 更大、远端内容确实相对 base 变了、
/// 本地确实处于删除态。只看 rev 会把「同步了一次但内容没变」也复活。
bool shouldResurrectAfterDelete({
  required bool localDeleted,
  required int localRev,
  required int remoteRev,
  required bool remoteDiffersFromBase,
}) {
  return localDeleted && remoteRev > localRev && remoteDiffersFromBase;
}

/// 冲突副本标题（docs/04 §5.2）。
/// 时间戳由调用方格式化，保持 core/sync 不依赖 intl。
String conflictCopyTitle(String title, String deviceLabel, String timestamp) =>
    '$title (冲突副本 $deviceLabel $timestamp)';
