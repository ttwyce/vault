/// 归档抓取 / 按需下载任务状态机（docs/05 §4 / §7）。
///
/// 不加载 WebView、不联网、不写 blob：只把「九步流水线怎么推进、
/// 同 URL 怎么去重、失败怎么降级、按需下载并发与进度怎么算」写成
/// 确定性逻辑。平台层按 [ArchiveJob.next] 执行真实动作。
library;

import 'archive_policy.dart';

/// 抓取流水线阶段（docs/05 §4）。
enum ArchiveStage {
  dedupe,
  metadata,
  loadPage,
  readability,
  markdown,
  pdf,
  rawHtml,
  writeBlob,
  enqueueVector,
  done,
  failed,
}

const List<ArchiveStage> kArchivePipeline = <ArchiveStage>[
  ArchiveStage.dedupe,
  ArchiveStage.metadata,
  ArchiveStage.loadPage,
  ArchiveStage.readability,
  ArchiveStage.markdown,
  ArchiveStage.pdf,
  ArchiveStage.rawHtml,
  ArchiveStage.writeBlob,
  ArchiveStage.enqueueVector,
];

class ArchiveJob {
  const ArchiveJob({
    required this.entryId,
    required this.url,
    required this.stage,
    required this.requestedPolicy,
    required this.decision,
    this.attempt = 1,
    this.skipped = const <ArchiveStage>[],
    this.error,
  });

  final String entryId;
  final String url;
  final ArchiveStage stage;
  final ArchivePolicy requestedPolicy;
  final ArchiveDecision decision;
  final int attempt;

  /// 因策略降级而跳过的阶段（pdf / rawHtml）。
  final List<ArchiveStage> skipped;
  final String? error;

  /// 当前阶段之后下一步该执行的动作；done/failed 返回 null。
  ArchiveStage? get next {
    if (stage == ArchiveStage.done || stage == ArchiveStage.failed) {
      return null;
    }
    var index = kArchivePipeline.indexOf(stage) + 1;
    while (index < kArchivePipeline.length &&
        skipped.contains(kArchivePipeline[index])) {
      index++;
    }
    return index >= kArchivePipeline.length
        ? ArchiveStage.done
        : kArchivePipeline[index];
  }

  double get progress {
    final total = kArchivePipeline.length;
    final current = kArchivePipeline.indexOf(stage);
    if (stage == ArchiveStage.done) return 1.0;
    if (stage == ArchiveStage.failed) return current / total;
    return current / total;
  }
}

/// 同 URL 去重：已有条目时不自动覆盖，要求显式确认更新快照。
ArchiveJob startArchiveJob({
  required String entryId,
  required String url,
  required ArchiveRequest request,
  required bool duplicateUrlExists,
  required bool userConfirmedUpdate,
}) {
  final decision = decideArchivePolicy(request);
  if (duplicateUrlExists && !userConfirmedUpdate) {
    return ArchiveJob(
      entryId: entryId,
      url: url,
      stage: ArchiveStage.failed,
      requestedPolicy: request.requested,
      decision: decision,
      error: '已归档过，需用户确认是否更新快照',
    );
  }
  final skipped = <ArchiveStage>[
    if (!decision.saveSnapshot) ...<ArchiveStage>[
      ArchiveStage.pdf,
      ArchiveStage.rawHtml,
    ],
  ];
  return ArchiveJob(
    entryId: entryId,
    url: url,
    stage: ArchiveStage.dedupe,
    requestedPolicy: request.requested,
    decision: decision,
    skipped: skipped,
  );
}

/// 推进阶段。失败按 docs/05 §8 降级：PDF 失败只保留 L1+L3，
/// 其余阶段失败重试，超过 3 次标 failed。
ArchiveJob advanceArchiveJob(ArchiveJob job, {bool ok = true}) {
  if (job.next == null) return job;
  if (!ok) {
    if (job.stage == ArchiveStage.pdf) {
      // PDF 失败不是整体失败：标记降级后继续下一步。
      return ArchiveJob(
        entryId: job.entryId,
        url: job.url,
        stage: job.next!,
        requestedPolicy: job.requestedPolicy,
        decision: job.decision,
        attempt: job.attempt,
        skipped: <ArchiveStage>[...job.skipped, ArchiveStage.pdf],
        error: 'PDF 生成失败，降级为仅 L1+L3',
      );
    }
    final attempts = job.attempt + 1;
    return ArchiveJob(
      entryId: job.entryId,
      url: job.url,
      stage: attempts > 3 ? ArchiveStage.failed : job.stage,
      requestedPolicy: job.requestedPolicy,
      decision: job.decision,
      attempt: attempts,
      skipped: job.skipped,
      error: attempts > 3 ? '重试 3 次仍失败' : '阶段失败，等待重试',
    );
  }
  final next = job.next!;
  return ArchiveJob(
    entryId: job.entryId,
    url: job.url,
    stage: next,
    requestedPolicy: job.requestedPolicy,
    decision: job.decision,
    attempt: 1,
    skipped: job.skipped,
  );
}

// ---------------------------------------------------------------------------
// 按需下载（docs/05 §7）
// ---------------------------------------------------------------------------

class DownloadRequest {
  const DownloadRequest({
    required this.blobHash,
    required this.bytes,
    required this.needPdf,
  });

  final String blobHash;
  final int bytes;

  /// 是否 L2 PDF（用户点「查看原貌」才需要）。
  final bool needPdf;
}

/// 默认并发 2；L1 正文优先于 L2 PDF，避免大文件阻塞秒开。
List<DownloadRequest> planOnDemandDownloads(
  Iterable<DownloadRequest> requests, {
  int maxConcurrent = 2,
}) {
  final sorted = requests.toList()
    ..sort((DownloadRequest a, DownloadRequest b) {
      final byPdf = (a.needPdf ? 1 : 0).compareTo(b.needPdf ? 1 : 0);
      return byPdf != 0 ? byPdf : a.blobHash.compareTo(b.blobHash);
    });
  return List<DownloadRequest>.unmodifiable(sorted.take(maxConcurrent));
}

/// 下载进度：只按已完成字节算，绝不把未完成的 .part 当成可用。
double downloadProgress(int receivedBytes, int totalBytes) =>
    totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);

/// 下载完成后写回本地缓存标记；仅置 local，不删云端。
BlobAvailability onDownloadComplete(bool ok) =>
    ok ? BlobAvailability.local : BlobAvailability.cloudOnly;
