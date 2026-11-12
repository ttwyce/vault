/// 本地 blob 缓存 LRU 清理的**执行器**（docs/05 §7）。
///
/// 只置 `local=0`，不删云端副本、不删条目。判定复用
/// `planBlobCacheCleanup`，这里负责把计划落到真实表。
library;

import '../db/vault_database.dart';
import '../write/write_gateway.dart';
import 'archive_cache_policy.dart';
import 'archive_policy.dart' show CachedBlob;

class BlobEvictionResult {
  const BlobEvictionResult({
    required this.evictedHashes,
    required this.freedBytes,
  });

  final List<String> evictedHashes;
  final int freedBytes;
}

class BlobCacheEvictor {
  const BlobCacheEvictor({
    required this.db,
    required this.gateway,
  });

  final VaultDatabase db;
  final WriteGateway gateway;

  Future<BlobEvictionResult> run({
    int maxBytes = kDefaultBlobCacheMaxBytes,
  }) async {
    final rows = await db.select(db.blobRefs).get();
    final localRows = rows.where((BlobRefRow r) => r.local == 1).toList();
    final currentBytes = localRows.fold<int>(
      0,
      (int sum, BlobRefRow r) => sum + r.bytes,
    );
    final blobs = <CachedBlob>[
      for (final row in localRows)
        CachedBlob(
          blobHash: row.blobHash,
          bytes: row.bytes,
          lastAccessAt: row.createdAt,
        ),
    ];
    final plan = planBlobCacheCleanup(
      blobs: blobs,
      currentBytes: currentBytes,
      maxBytes: maxBytes,
    );
    final byHash = <String, BlobRefRow>{
      for (final row in localRows) row.blobHash: row,
    };
    for (final hash in plan.evictedHashes) {
      final row = byHash[hash];
      if (row == null) continue;
      await gateway.unmarkArchiveBlobLocal(
        entryId: row.entryId,
        blobHash: row.blobHash,
      );
    }
    return BlobEvictionResult(
      evictedHashes: plan.evictedHashes,
      freedBytes: plan.freedBytes,
    );
  }
}
