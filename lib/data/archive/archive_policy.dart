/// 归档策略引擎、死链判定、内容变更判定、按需下载与配额守卫。
///
/// 全部是**纯 Dart 判定层**：不碰 WebView、不碰网络、不碰数据库，
/// 于是「模式选择 / 超配额降级 / 死链分类 / simhash 变更 / 缓存清理」
/// 这些最容易在真机上偶发的逻辑都能确定性单测。
/// 真实抓取、PDF 生成、HTTP HEAD 由 M4 接入层按这里的判定结果执行。
library;

import 'archive_meta.dart';

/// 归档模式（docs/05 §5.1）。
enum ArchivePolicy {
  /// 仅 URL + 标题 + 元数据，~1 KB。
  link('link'),

  /// + L1 正文 Markdown（默认、自动、不可关）。
  text('text'),

  /// + L2 PDF 快照 + L3 原始 HTML。
  full('full');

  const ArchivePolicy(this.wire);

  final String wire;
}

/// 一次归档的上下文：决定该存哪几层。
class ArchiveRequest {
  const ArchiveRequest({
    required this.requested,
    required this.quota,
    this.estimatedSnapshotBytes = 0,
    this.blocked = false,
    this.paywalled = false,
    this.dead = false,
    this.timeout = false,
  });

  final ArchivePolicy requested;
  final ArchiveQuota quota;
  final int estimatedSnapshotBytes;

  /// 反爬 / 付费墙 / 死链 / 抓取超时：由抓取层给出，策略层只做降级判定。
  final bool blocked;
  final bool paywalled;
  final bool dead;
  final bool timeout;
}

class ArchiveQuota {
  const ArchiveQuota({
    required this.usedBytes,
    required this.limitBytes,
    this.guardRatio = 0.8,
  });

  final int usedBytes;
  final int limitBytes;

  /// docs/05 §5.2：默认云端剩余空间 × 80%。
  final double guardRatio;

  bool get isOverGuard => usedBytes >= limitBytes * guardRatio;
}

/// 归档策略决策。
class ArchiveDecision {
  const ArchiveDecision({
    required this.status,
    required this.reasons,
    required this.saveText,
    required this.saveSnapshot,
    required this.degraded,
  });

  /// 决策后应写入 `entry.meta.archive_status` 的值。
  final ArchiveStatus status;

  final List<String> reasons;
  final bool saveText;
  final bool saveSnapshot;

  /// 是否因为配额 / 抓取失败而比用户请求的层级更低。
  final bool degraded;
}

/// 决定一次归档实际保存哪几层（docs/05 §5）。
///
/// 硬规则：**L1 正文层必须无条件保存**（除非连正文都没抓到），
/// 它是检索与 AI 的唯一输入源；省掉它「找回」功能直接废掉。
ArchiveDecision decideArchivePolicy(ArchiveRequest request) {
  final reasons = <String>[];
  var policy = request.requested;

  if (request.dead) {
    return const ArchiveDecision(
      status: ArchiveStatus.dead,
      reasons: <String>['原站已失效：只保留已有正文 / 快照，不新建'],
      saveText: false,
      saveSnapshot: false,
      degraded: true,
    );
  }
  if (request.blocked) {
    return const ArchiveDecision(
      status: ArchiveStatus.blocked,
      reasons: <String>['检测到反爬：只存元数据与已提取正文'],
      saveText: true,
      saveSnapshot: false,
      degraded: true,
    );
  }
  if (request.paywalled) {
    return const ArchiveDecision(
      status: ArchiveStatus.paywalled,
      reasons: <String>['检测到付费墙：不生成完整快照'],
      saveText: true,
      saveSnapshot: false,
      degraded: true,
    );
  }
  if (request.timeout) {
    return const ArchiveDecision(
      status: ArchiveStatus.metadata,
      reasons: <String>['单页超时 20s：降级为仅元数据 + 原始 HTML（不渲染）'],
      saveText: true,
      saveSnapshot: false,
      degraded: true,
    );
  }

  // docs/05 §5.4：超配额时把最老的 full 降级为 text；本次只存 L1。
  if (request.quota.isOverGuard &&
      request.quota.usedBytes + request.estimatedSnapshotBytes >
          request.quota.limitBytes * request.quota.guardRatio) {
    if (policy == ArchivePolicy.full) {
      policy = ArchivePolicy.text;
      reasons.add('云端用量超过 80% 配额：本次只存正文层');
    }
  }

  final status = switch (policy) {
    ArchivePolicy.link => ArchiveStatus.metadata,
    ArchivePolicy.text => ArchiveStatus.text,
    ArchivePolicy.full => ArchiveStatus.full,
  };
  return ArchiveDecision(
    status: status,
    reasons: reasons,
    saveText: true,
    saveSnapshot: policy == ArchivePolicy.full,
    degraded: policy != request.requested,
  );
}

/// 死链检测分类（docs/05 §6.1）。
///
/// 403/451 ≠ 死链：那更可能是反爬或地区限制，不能把条目标成 dead
/// 后让用户以为原站关停了。超时/DNS 失败重试 2 次后才判 unreachable。
LinkCheckResult classifyHttpStatus(int? statusCode, {int retries = 2}) {
  if (statusCode == null) {
    return retries >= 2 ? LinkCheckResult.unreachable : LinkCheckResult.ok;
  }
  if (statusCode == 404 || statusCode == 410) return LinkCheckResult.dead;
  if (statusCode == 403 || statusCode == 451) {
    return LinkCheckResult.restricted;
  }
  if (statusCode >= 200 && statusCode < 400) return LinkCheckResult.ok;
  if (statusCode >= 500) {
    return retries >= 2 ? LinkCheckResult.unreachable : LinkCheckResult.ok;
  }
  return LinkCheckResult.restricted;
}

/// 死链结果要不要回退 Wayback（docs/11 §3.4）。
bool shouldTryWayback(LinkCheckResult result) =>
    result == LinkCheckResult.dead || result == LinkCheckResult.unreachable;

/// simhash 变更判定（docs/05 §6.2）。
///
/// 64 位指纹的汉明距离 ≤ 3 视为「没实质变化」。用 XOR 后数位，
/// 避免把「改了一个广告位」也提示成内容变更。
bool hasContentChanged(String? previousSimhash, String? currentSimhash,
    {int threshold = 3}) {
  if (previousSimhash == null || currentSimhash == null) return false;
  final previous = int.tryParse(previousSimhash, radix: 16);
  final current = int.tryParse(currentSimhash, radix: 16);
  if (previous == null || current == null) return false;
  final bits = previous ^ current;
  return _popCount(bits) > threshold;
}

int _popCount(int value) {
  var v = value;
  var count = 0;
  while (v != 0) {
    v &= v - 1;
    count++;
  }
  return count;
}

/// 按需下载状态机（docs/05 §7）。
enum BlobAvailability { cloudOnly, downloading, local }

/// 缓存清理只把 `local` 置回 0（仅云端），**不删云端 blob**。
class BlobCachePlan {
  const BlobCachePlan({
    required this.evicted,
    required this.kept,
    required this.freedBytes,
  });

  final List<String> evicted;
  final List<String> kept;
  final int freedBytes;
}

class CachedBlob {
  const CachedBlob({
    required this.blobHash,
    required this.bytes,
    required this.lastAccessAt,
  });

  final String blobHash;
  final int bytes;
  final int lastAccessAt;
}

/// LRU 清理：按 lastAccessAt 升序淘汰，直到本地缓存 ≤ [maxBytes]。
BlobCachePlan planBlobCacheEviction({
  required Iterable<CachedBlob> blobs,
  required int maxBytes,
  required int currentBytes,
}) {
  final sorted = blobs.toList()
    ..sort((CachedBlob a, CachedBlob b) {
      final byTime = a.lastAccessAt.compareTo(b.lastAccessAt);
      return byTime != 0 ? byTime : a.blobHash.compareTo(b.blobHash);
    });
  var remaining = currentBytes;
  final evicted = <String>[];
  final kept = <String>[];
  var freed = 0;
  for (final blob in sorted) {
    if (remaining <= maxBytes) {
      kept.add(blob.blobHash);
      continue;
    }
    evicted.add(blob.blobHash);
    remaining -= blob.bytes;
    freed += blob.bytes;
  }
  return BlobCachePlan(
    evicted: List<String>.unmodifiable(evicted),
    kept: List<String>.unmodifiable(kept),
    freedBytes: freed,
  );
}

/// 归档总览页的状态筛选（docs/11 §3.2）。
enum ArchiveFilter { all, alive, dead, pendingRecheck, metadataOnly, site }

/// 聚合后的站点分组项。
class ArchiveSiteGroup {
  const ArchiveSiteGroup(this.site, this.count);

  final String site;
  final int count;
}

List<ArchiveSiteGroup> groupBySite(Iterable<ArchiveMeta> metas) {
  final counts = <String, int>{};
  for (final meta in metas) {
    counts[meta.site] = (counts[meta.site] ?? 0) + 1;
  }
  final groups = <ArchiveSiteGroup>[
    for (final entry in counts.entries)
      ArchiveSiteGroup(entry.key, entry.value),
  ];
  groups.sort((ArchiveSiteGroup a, ArchiveSiteGroup b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : a.site.compareTo(b.site);
  });
  return List<ArchiveSiteGroup>.unmodifiable(groups);
}

/// 筛选：全部 / 存活 / 失效 / 待重抓 / 仅元数据 / 指定站点。
List<ArchiveMeta> filterArchives(
  Iterable<ArchiveMeta> metas, {
  required ArchiveFilter filter,
  required int nowMs,
  String? site,
}) {
  return List<ArchiveMeta>.unmodifiable(
    metas.where((ArchiveMeta meta) {
      return switch (filter) {
        ArchiveFilter.all => true,
        ArchiveFilter.alive => !meta.isDeadLink &&
            meta.status != ArchiveStatus.blocked &&
            meta.status != ArchiveStatus.paywalled,
        ArchiveFilter.dead => meta.isDeadLink,
        ArchiveFilter.pendingRecheck =>
          meta.nextCheckAt() != null && meta.nextCheckAt()! <= nowMs,
        ArchiveFilter.metadataOnly => meta.status == ArchiveStatus.metadata,
        ArchiveFilter.site => site != null && meta.site == site,
      };
    }),
  );
}

/// 存储占用汇总（docs/11 §3.2 底部面板）。
class ArchiveStorageSummary {
  const ArchiveStorageSummary({
    required this.textBytes,
    required this.snapshotBytes,
    required this.imageBytes,
    required this.totalBytes,
  });

  final int textBytes;
  final int snapshotBytes;
  final int imageBytes;
  final int totalBytes;
}

ArchiveStorageSummary summarizeStorage(
  Iterable<ArchiveMeta> metas, {
  int textBytesPerEntry = 200 * 1024,
  int imageBytesPerEntry = 20 * 1024,
}) {
  var text = 0;
  var snapshot = 0;
  var images = 0;
  for (final meta in metas) {
    if (meta.hasText) text += textBytesPerEntry;
    if (meta.hasSnapshot) {
      snapshot += meta.snapshotBytes;
      images += imageBytesPerEntry;
    }
  }
  return ArchiveStorageSummary(
    textBytes: text,
    snapshotBytes: snapshot,
    imageBytes: images,
    totalBytes: text + snapshot + images,
  );
}

/// 按 LRU 把最老的 full 降级为 text（docs/11 §3.4「清理」）。
/// 只返回需要降级的条目 id，落库/删 blob 由接入层执行。
List<String> planSnapshotDowngrade({
  required Iterable<({String entryId, ArchiveMeta meta})> entries,
  required int quotaLimitBytes,
  required int currentBytes,
}) {
  final candidates = entries
      .where((entry) => entry.meta.hasSnapshot)
      .toList(growable: true)
    ..sort((a, b) {
      final ta = a.meta.lastCheckedAt ?? 0;
      final tb = b.meta.lastCheckedAt ?? 0;
      return ta.compareTo(tb);
    });
  var remaining = currentBytes;
  final target = (quotaLimitBytes * 0.8).floor();
  final downgraded = <String>[];
  for (final entry in candidates) {
    if (remaining <= target) break;
    downgraded.add(entry.entryId);
    remaining -= entry.meta.snapshotBytes;
  }
  return List<String>.unmodifiable(downgraded);
}
