import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/widgets/sketch_controls.dart' show SketchTone;
import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/archive/archive_status_badge.dart';

/// docs/06 §8.1 检索结果卡归档状态徽章测试。
void main() {
  ArchiveMeta meta(ArchiveStatus status, {int snapshotBytes = 0}) =>
      ArchiveMeta(
        url: 'https://example.com/p',
        site: 'example.com',
        status: status,
        snapshotBytes: snapshotBytes,
      );

  test('dead 用红底且优先于快照', () {
    final badge = planArchiveStatusBadge(
      meta(ArchiveStatus.dead, snapshotBytes: 1000),
    );
    expect(badge.label, '原站已失效');
    expect(badge.tone, SketchTone.primary);
  });

  test('有快照 / 原站存活 / 仅元数据', () {
    expect(
      planArchiveStatusBadge(
        meta(ArchiveStatus.full, snapshotBytes: 1000),
      ).label,
      '有快照',
    );
    expect(
      planArchiveStatusBadge(meta(ArchiveStatus.text)).label,
      '原站存活',
    );
    expect(
      planArchiveStatusBadge(meta(ArchiveStatus.metadata)).label,
      '仅元数据',
    );
  });

  test('反爬 / 付费墙用蓝色调', () {
    for (final status in <ArchiveStatus>[
      ArchiveStatus.blocked,
      ArchiveStatus.paywalled,
    ]) {
      final badge = planArchiveStatusBadge(meta(status));
      expect(badge.tone, SketchTone.blue);
      expect(badge.label, isNot('原站存活'));
    }
  });
}
