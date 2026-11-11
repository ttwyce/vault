import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_job_queue.dart';
import 'package:vault/data/archive/archive_policy.dart';

/// docs/05 §4 / §7 抓取与按需下载状态机测试。
void main() {
  ArchiveRequest request({
    ArchivePolicy policy = ArchivePolicy.full,
    bool blocked = false,
    bool dead = false,
  }) =>
      ArchiveRequest(
        requested: policy,
        quota: const ArchiveQuota(usedBytes: 0, limitBytes: 10000000),
        estimatedSnapshotBytes: 1000,
        blocked: blocked,
        dead: dead,
      );

  test('九步流水线按顺序推进，progress 单调到 1.0', () {
    var job = startArchiveJob(
      entryId: 'e1',
      url: 'https://example.com/p',
      request: request(),
      duplicateUrlExists: false,
      userConfirmedUpdate: false,
    );
    expect(job.stage, ArchiveStage.dedupe);
    expect(kArchivePipeline, hasLength(9));
    final seen = <ArchiveStage>[job.stage];
    while (job.next != null) {
      final next = job.next!;
      job = advanceArchiveJob(job);
      expect(job.stage, next);
      seen.add(job.stage);
    }
    expect(job.stage, ArchiveStage.done);
    expect(job.progress, 1.0);
    expect(seen.first, ArchiveStage.dedupe);
    expect(seen.last, ArchiveStage.done);
  });

  test('同 URL 已存在且未确认更新 → 直接失败，不覆盖快照', () {
    final job = startArchiveJob(
      entryId: 'e1',
      url: 'https://example.com/p',
      request: request(),
      duplicateUrlExists: true,
      userConfirmedUpdate: false,
    );
    expect(job.stage, ArchiveStage.failed);
    expect(job.error, contains('确认'));
    expect(job.next, isNull);
  });

  test('blocked 策略只存 L1：pdf/rawHtml 被跳过', () {
    final job = startArchiveJob(
      entryId: 'e1',
      url: 'https://example.com/p',
      request: request(blocked: true),
      duplicateUrlExists: false,
      userConfirmedUpdate: false,
    );
    expect(job.decision.saveSnapshot, isFalse);
    expect(job.skipped, contains(ArchiveStage.pdf));
    expect(job.skipped, contains(ArchiveStage.rawHtml));
  });

  test('PDF 失败只降级不整体失败；其它阶段失败 3 次后 failed', () {
    var job = startArchiveJob(
      entryId: 'e1',
      url: 'https://example.com/p',
      request: request(),
      duplicateUrlExists: false,
      userConfirmedUpdate: false,
    );
    // 走到 pdf 阶段
    while (job.stage != ArchiveStage.pdf) {
      job = advanceArchiveJob(job);
    }
    final degraded = advanceArchiveJob(job, ok: false);
    expect(degraded.stage, isNot(ArchiveStage.failed));
    expect(degraded.skipped, contains(ArchiveStage.pdf));
    expect(degraded.error, contains('降级'));

    var retry = startArchiveJob(
      entryId: 'e2',
      url: 'https://example.com/q',
      request: request(),
      duplicateUrlExists: false,
      userConfirmedUpdate: false,
    );
    for (var i = 0; i < 4; i++) {
      retry = advanceArchiveJob(retry, ok: false);
    }
    expect(retry.stage, ArchiveStage.failed);
    expect(retry.error, contains('3 次'));
  });

  test('按需下载：L1 优先于 L2 PDF，并发上限 2，失败保持仅云端', () {
    final plan = planOnDemandDownloads(
      <DownloadRequest>[
        const DownloadRequest(blobHash: 'pdf', bytes: 5000, needPdf: true),
        const DownloadRequest(blobHash: 'text-b', bytes: 100, needPdf: false),
        const DownloadRequest(blobHash: 'text-a', bytes: 80, needPdf: false),
      ],
      maxConcurrent: 2,
    );
    expect(plan.map((DownloadRequest r) => r.blobHash).toList(),
        <String>['text-a', 'text-b']);
    expect(downloadProgress(50, 100), 0.5);
    expect(downloadProgress(0, 0), 0.0);
    expect(onDownloadComplete(true), BlobAvailability.local);
    expect(onDownloadComplete(false), BlobAvailability.cloudOnly);
  });
}
