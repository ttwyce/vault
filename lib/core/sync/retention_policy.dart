/// 回收站 / 墓碑保留策略（docs/04 §6、docs/20 §5）。
///
/// 两条 TTL 必须分开判定，绝不互相删除对方的依据：
///
/// - **本地回收站 30 天**（[kTrashRetention]）：到期后物理删除本地行，
///   但只在「云端墓碑已确认」时才允许；否则另一台设备会把这条内容推回来。
/// - **云端墓碑 90 天**（[kTombstoneTtl]）：只用于清理云端 `/vault/tombstones/`
///   文件。它比 30 天长得多，是留给慢上线设备的最后一道通知。
///
/// 这一层只做**判定**，不碰数据库、不发网络请求。落库由
/// `WriteGateway.purgeTrashEntry()` 执行，云端删除由接入层按
/// [TombstoneRetentionPlan.expiredPaths] 执行。判定与执行分离，
/// 所以「不该删」的每一种情况都能写成确定性单测。
library;

import 'conflict_matrix.dart' show isTombstoneExpired, isTrashExpired;

/// 一条回收站记录的清理判定。
enum TrashPurgeDecision {
  /// 可以物理删除本地行。
  purge,

  /// 未到期、或条目已恢复、或还有未推送的 oplog。
  keep,

  /// 到期但云端墓碑未确认：必须等下一次同步把墓碑写上去。
  waitForTombstone,
}

class TrashPurgeVerdict {
  const TrashPurgeVerdict(this.decision, this.reason);

  final TrashPurgeDecision decision;
  final String reason;

  bool get canPurge => decision == TrashPurgeDecision.purge;
}

/// 判断一条回收站记录现在能不能物理清空。
///
/// 闸门顺序不能改：**先确认墓碑，再确认本地状态**。
/// 只看 `expireAt` 就删本地行是 M2 遗留里最危险的一条数据一致性坑：
/// 云端没有墓碑时，其它设备会把这条「已被清理」的内容重新同步回来。
TrashPurgeVerdict evaluateTrashPurge({
  required int nowMs,
  required int expireAt,
  required bool entryStillDeleted,
  required bool tombstoneConfirmed,
  required bool hasPendingOps,
  required bool hasUnconfirmedDelete,
}) {
  if (!isTrashExpired(_deletedAtOf(expireAt), nowMs)) {
    return const TrashPurgeVerdict(
      TrashPurgeDecision.keep,
      '回收站未到 30 天保留期',
    );
  }
  if (!entryStillDeleted) {
    return const TrashPurgeVerdict(
      TrashPurgeDecision.keep,
      '条目已恢复，不允许清空',
    );
  }
  if (hasUnconfirmedDelete || hasPendingOps) {
    return const TrashPurgeVerdict(
      TrashPurgeDecision.waitForTombstone,
      '还有未推送 / 未确认的变更，先完成同步',
    );
  }
  if (!tombstoneConfirmed) {
    return const TrashPurgeVerdict(
      TrashPurgeDecision.waitForTombstone,
      '云端墓碑未确认：物理删除会让其它设备把内容推回来',
    );
  }
  return const TrashPurgeVerdict(
    TrashPurgeDecision.purge,
    '墓碑已确认且本地无待推送变更，可以物理清空',
  );
}

/// 云端墓碑是否被 `sync_state` 确认。
///
/// 判据不是「文件曾经存在」，而是 `/vault/tombstones/<hmac>.enc` 这一路径
/// 在上一轮成功的同步里拿到了服务端 ETag。ETag 为空说明写上去但没确认，
/// 不能当作闸门。
bool isTombstoneConfirmed(
  Map<String, String?> syncState,
  String tombstonePath,
) {
  final etag = syncState[tombstonePath];
  return etag != null && etag.isNotEmpty;
}

/// 一条云端墓碑文件的状态。
class TombstoneRecord {
  const TombstoneRecord({
    required this.path,
    required this.deletedAt,
  });

  final String path;
  final int deletedAt;
}

/// 90 天 TTL 的清理计划。**只影响云端墓碑文件，不动本地回收站。**
class TombstoneRetentionPlan {
  const TombstoneRetentionPlan({
    required this.expiredPaths,
    required this.retainedPaths,
  });

  final List<String> expiredPaths;
  final List<String> retainedPaths;
}

TombstoneRetentionPlan planTombstoneRetention({
  required Iterable<TombstoneRecord> tombstones,
  required int nowMs,
}) {
  final expired = <String>[];
  final retained = <String>[];
  for (final tombstone in tombstones) {
    if (isTombstoneExpired(tombstone.deletedAt, nowMs)) {
      expired.add(tombstone.path);
    } else {
      retained.add(tombstone.path);
    }
  }
  return TombstoneRetentionPlan(
    expiredPaths: List<String>.unmodifiable(expired),
    retainedPaths: List<String>.unmodifiable(retained),
  );
}

/// 从 `expireAt` 反推 `deletedAt`。
///
/// `trash.expire_at` 在 `WriteGateway._commit()` 里恒为
/// `deletedAt + Duration(days: 30)`；这里用同一个常量，避免两处各写一份。
int _deletedAtOf(int expireAt) =>
    expireAt - const Duration(days: 30).inMilliseconds;
