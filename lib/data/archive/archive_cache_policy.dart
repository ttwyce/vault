/// 按需下载与本地 blob 缓存策略（docs/05 §7）。
///
/// 不联网、不写库：只定义默认 500MB 上限、打开阅读时的下载请求、
/// 以及 LRU 清理动作（**只置 local=0，不删云端**）。
library;

import 'archive_policy.dart'
    show BlobCachePlan, CachedBlob, planBlobCacheEviction;

/// 默认本地缓存上限 500MB。
const int kDefaultBlobCacheMaxBytes = 500 * 1024 * 1024;

enum OnDemandLayer { text, pdf }

class DownloadRequest {
  const DownloadRequest({
    required this.entryId,
    required this.blobHash,
    required this.layer,
    required this.showSkeleton,
    required this.hint,
    required this.requiresUserTap,
  });

  final String entryId;
  final String blobHash;
  final OnDemandLayer layer;
  final bool showSkeleton;
  final String hint;
  final bool requiresUserTap;

  Map<String, Object?> toJson() => <String, Object?>{
        'entry_id': entryId,
        'blob_hash': blobHash,
        'layer': layer.name,
        'show_skeleton': showSkeleton,
        'hint': hint,
        'requires_user_tap': requiresUserTap,
      };
}

/// 打开阅读时的下载请求：
/// - L1 正文 local=0 → 自动下载 + 骨架屏
/// - L2 PDF → 必须用户点「查看原貌」，带进度条
/// - 已本地 → 不发请求
DownloadRequest? planOnDemandRequest({
  required String entryId,
  required String blobHash,
  required OnDemandLayer layer,
  required bool local,
}) {
  if (local) return null;
  return DownloadRequest(
    entryId: entryId,
    blobHash: blobHash,
    layer: layer,
    showSkeleton: layer == OnDemandLayer.text,
    requiresUserTap: layer == OnDemandLayer.pdf,
    hint: layer == OnDemandLayer.text
        ? '正文仅存云端，显示骨架屏并自动下载（通常 <100KB）'
        : '用户点「查看原貌」才下载 PDF，带进度条',
  );
}

class BlobCacheCleanupPlan {
  const BlobCacheCleanupPlan({
    required this.evictedHashes,
    required this.freedBytes,
    required this.actions,
  });

  final List<String> evictedHashes;
  final int freedBytes;

  /// 与 evictedHashes 一一对应的本地表动作。
  final List<String> actions;

  bool get isEmpty => evictedHashes.isEmpty;
}

/// 超出 500MB 按 LRU 清理；动作明确只置 `local=0`，不删云端 blob。
BlobCacheCleanupPlan planBlobCacheCleanup({
  required Iterable<CachedBlob> blobs,
  required int currentBytes,
  int maxBytes = kDefaultBlobCacheMaxBytes,
}) {
  final BlobCachePlan base = planBlobCacheEviction(
    blobs: blobs,
    maxBytes: maxBytes,
    currentBytes: currentBytes,
  );
  return BlobCacheCleanupPlan(
    evictedHashes: base.evicted,
    freedBytes: base.freedBytes,
    actions: <String>[
      for (final hash in base.evicted)
        'UPDATE blob_ref SET local = 0 WHERE blob_hash = $hash '
            '（只清本地标记，云端不动）',
    ],
  );
}
