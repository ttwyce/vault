import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/model_downloader.dart';

/// docs/06 §5 / §6 模型下载器与索引重建判定层测试。
void main() {
  const total = 1000;
  const sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  DownloadStatus idle() => const DownloadStatus(
        state: ModelState.idle,
        sourceIndex: 0,
        attempt: 1,
        receivedBytes: 0,
        totalBytes: total,
      );

  DownloadStatus step(DownloadStatus s, DownloadEvent e,
          {String actual = sha}) =>
      advanceDownload(
        s,
        e,
        totalBytes: total,
        expectedSha256: sha,
        actualSha256: actual,
      );

  test('正常流程 idle → checking → downloading → verifying → ready',
      () {
    var s = step(idle(), DownloadEvent.start);
    expect(s.state, ModelState.checking);
    s = step(s, DownloadEvent.diskOk);
    expect(s.state, ModelState.downloading);
    s = step(s, DownloadEvent.completed);
    expect(s.state, ModelState.verifying);
    s = step(s, DownloadEvent.verified);
    expect(s.state, ModelState.ready);
    expect(s.sha256Ok, isTrue);
  });

  test('sha256 不符直接损坏，不静默重试', () {
    var s = step(idle(), DownloadEvent.start);
    s = step(s, DownloadEvent.diskOk);
    s = step(s, DownloadEvent.completed);
    s = step(s, DownloadEvent.verified, actual: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
    expect(s.state, ModelState.corrupt);
    expect(s.sha256Ok, isFalse);
  });

  test('同源 3 次保留断点，换源作废 .part，全源失败才 corrupt', () {
    var s = const DownloadStatus(
      state: ModelState.downloading,
      sourceIndex: 0,
      attempt: 1,
      receivedBytes: 300,
      totalBytes: total,
    );
    s = step(s, DownloadEvent.failed);
    expect(s.attempt, 2);
    expect(s.sourceIndex, 0);
    expect(s.receivedBytes, 300, reason: '同源重试保留断点');
    s = step(s, DownloadEvent.failed);
    s = step(s, DownloadEvent.failed);
    expect(s.sourceIndex, 1, reason: '第 4 次失败换下一个源');
    expect(s.receivedBytes, 0, reason: '换源后 .part 作废');

    // 一路失败到最后一个源的 3 次。
    for (var i = 0; i < 3 * (kDefaultSourceOrder.length - 1); i++) {
      s = step(s, DownloadEvent.failed);
    }
    expect(s.state, ModelState.corrupt);
  });

  test('磁盘检查需 1.5 倍；断点 offset 越界归零', () {
    expect(hasEnoughDisk(freeBytes: 1500, modelBytes: 1000), isTrue);
    expect(hasEnoughDisk(freeBytes: 1499, modelBytes: 1000), isFalse);
    expect(resumeOffset(400, total), 400);
    expect(resumeOffset(-1, total), 0);
    expect(resumeOffset(total + 1, total), 0);
  });

  test('索引重建：切换模型删旧向量、全量分批 20 条 + cursor 可续', () {
    final plan = planReembed(
      trigger: ReembedTrigger.modelSwitch,
      activeModelId: 'bge-small',
      newModelId: 'qwen3',
      totalEntries: 55,
    );
    expect(plan.scope, ReembedScope.all);
    expect(plan.deleteOtherModelVectors, isTrue);
    expect(plan.modelId, 'qwen3');
    expect(plan.nextBatch(), (0, 20));

    var next = plan.advance(20);
    expect(next.cursor, 20);
    expect(next.nextBatch(), (20, 40));
    next = next.advance(20);
    expect(next.nextBatch(), (40, 55));
    next = next.advance(15);
    expect(next.nextBatch(), isNull);
    expect(next.progress, 1.0);
  });

  test('单条写入不删向量、不排全量任务；下载中降级纯 FTS', () {
    final plan = planReembed(
      trigger: ReembedTrigger.entryWrite,
      activeModelId: 'bge-small',
      totalEntries: 5000,
    );
    expect(plan.scope, ReembedScope.single);
    expect(plan.totalEntries, 1);
    expect(plan.deleteOtherModelVectors, isFalse);
    expect(plan.nextBatch(), (0, 1));

    expect(useVectorSearch(ModelState.ready), isTrue);
    expect(useVectorSearch(ModelState.downloading), isFalse);
    expect(useVectorSearch(ModelState.verifying), isFalse);
  });

  test('备份排除必须三端四标记全配置', () {
    const good = BackupExclusion(
      androidDataExtraction: true,
      androidFullBackup: true,
      iosIsExcludedFromBackup: true,
      windowsOutsideOneDrive: true,
    );
    expect(good.allConfigured, isTrue);
    const bad = BackupExclusion(
      androidDataExtraction: true,
      androidFullBackup: false,
      iosIsExcludedFromBackup: true,
      windowsOutsideOneDrive: true,
    );
    expect(bad.allConfigured, isFalse);
  });
}
