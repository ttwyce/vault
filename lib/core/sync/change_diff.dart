/// L2：远端目录 listings 与本地 `sync_state` 的 diff（docs/04 §3.2）。
///
/// 判据是 **ETag，不是 mtime**：各端时钟不一致，mtime 只能当提示。
library;

class SyncDiff {
  const SyncDiff({
    required this.added,
    required this.modified,
    required this.deleted,
  });

  /// 需要 GET 的路径（远端有、本地没见过）。
  final Set<String> added;

  /// ETag 变化、需要重新 GET 的路径。
  final Set<String> modified;

  /// 本地有、远端没有的路径。
  final Set<String> deleted;

  bool get isEmpty =>
      added.isEmpty && modified.isEmpty && deleted.isEmpty;

  /// 需要拉取的路径总数。请求预算按这个数预留。
  int get pullCount => added.length + modified.length;

  static const SyncDiff empty = SyncDiff(
    added: <String>{},
    modified: <String>{},
    deleted: <String>{},
  );
}

/// 比对 `path → etag` 两份映射。
///
/// [includeDeletes] 默认 true，对应「16 个分片全部 PROPFIND 完」的情形。
/// **只查了部分分片时必须传 false** —— 没查到的分片里文件"看起来不见了"
/// 并不是删除，把它们算进 deleted 会直接删掉本地数据。
/// 支持 RFC 6578 的服务器由 `REPORT sync-collection` 直接给删除列表，
/// 用 [withServerDeletes] 合入，不从目录缺失里推断。
SyncDiff diffListings({
  required Map<String, String?> remote,
  required Map<String, String?> local,
  bool includeDeletes = true,
}) {
  final added = <String>{};
  final modified = <String>{};

  for (final entry in remote.entries) {
    if (!local.containsKey(entry.key)) {
      added.add(entry.key);
    } else if (local[entry.key] != entry.value) {
      modified.add(entry.key);
    }
  }

  final deleted = <String>{};
  if (includeDeletes) {
    for (final path in local.keys) {
      if (!remote.containsKey(path)) deleted.add(path);
    }
  }

  return SyncDiff(added: added, modified: modified, deleted: deleted);
}

/// 合入 `sync-collection` 返回的删除列表。
///
/// 服务器给的删除优先级高于目录 diff：它明确知道文件被删了，
/// 而目录列表可能因为分页 / 限流不完整。
SyncDiff withServerDeletes(SyncDiff diff, Iterable<String> serverDeletes) {
  return SyncDiff(
    added: diff.added,
    modified: diff.modified,
    deleted: <String>{...diff.deleted, ...serverDeletes},
  );
}
