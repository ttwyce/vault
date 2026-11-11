import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/sync_state_machine.dart';
import 'package:vault/core/sync/sync_status_ui.dart';

/// docs/04 §11 同步状态 → UI 映射测试。
void main() {
  test('IDLE 无提示；PROBE/PULL 细进度条；PUSH 显示上传项数', () {
    expect(resolveSyncBanner(phase: SyncPhase.idle).visible, isFalse);
    for (final phase in <SyncPhase>[
      SyncPhase.probe,
      SyncPhase.discover,
      SyncPhase.pullTombstones,
      SyncPhase.pullMeta,
      SyncPhase.pullEntries,
    ]) {
      final banner = resolveSyncBanner(phase: phase);
      expect(banner.text, '同步中…');
      expect(banner.showProgress, isTrue);
    }
    final push = resolveSyncBanner(phase: SyncPhase.push, pushingCount: 3);
    expect(push.text, '正在上传 3 项…');
    expect(push.showProgress, isTrue);
  });

  test('失败分支：认证 / 配额 / 误连 / schema / 数据损坏', () {
    final cases = <SyncErrorCode, String>{
      SyncErrorCode.auth: 'WebDAV 认证失败',
      SyncErrorCode.quota: '云端空间不足',
      SyncErrorCode.vaultMismatch: '误连了另一个 vault',
      SyncErrorCode.schemaTooNew: '云端 schema 高于本地',
      SyncErrorCode.corrupt: '已隔离可疑文件',
    };
    for (final entry in cases.entries) {
      final banner = resolveSyncBanner(
        phase: SyncPhase.failed,
        errorCode: entry.key,
      );
      expect(banner.text, contains(entry.value));
      expect(banner.visible, isTrue);
    }
    expect(
      resolveSyncBanner(
        phase: SyncPhase.failed,
        errorCode: SyncErrorCode.auth,
      ).action,
      SyncBannerAction.openSettings,
    );
  });

  test('冲突横幅优先于进行中；BACKOFF 静默；离线提示', () {
    final conflict = resolveSyncBanner(
      phase: SyncPhase.push,
      conflicts: 1,
    );
    expect(conflict.text, contains('1 个冲突待处理'));
    expect(conflict.action, SyncBannerAction.openMerge);
    expect(
      resolveSyncBanner(phase: SyncPhase.backoff).visible,
      isFalse,
      reason: 'BACKOFF 顶部静默',
    );
    expect(
      resolveSyncBanner(phase: SyncPhase.idle, offline: true).text,
      contains('离线'),
    );
  });

  test('设置页诊断：隔离文件红点 + 下次重试时间', () {
    final note = resolveSyncDiagnostics(
      quarantineCount: 2,
      nextRetryAtMs: 1731052830000,
      nowMs: 1731052800000,
    );
    expect(note.hasRedDot, isTrue);
    expect(note.nextRetryText, contains('30 秒'));
    expect(note.toJson()['red_dot'], isTrue);
    expect(
      resolveSyncDiagnostics(quarantineCount: 0).hasRedDot,
      isFalse,
    );
    expect(
      resolveSyncDiagnostics(
        quarantineCount: 0,
        nextRetryAtMs: 1731052800000,
        nowMs: 1731052800000,
      ).nextRetryText,
      '即将重试',
    );
  });

  test('冲突队列入口只在有冲突时出现', () {
    expect(conflictQueueAction(0), isNull);
    expect(conflictQueueAction(2), SyncBannerAction.openConflictQueue);
  });
}
