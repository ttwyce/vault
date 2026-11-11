import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/archive/archive_recheck_actions.dart';

/// docs/11 §3.4 归档交互动作判定测试。
void main() {
  const now = 1731052800000;

  ArchiveMeta meta({
    String url = 'https://example.com/p',
    ArchiveStatus status = ArchiveStatus.text,
    int? lastCheckedAt,
    int snapshotBytes = 0,
    String? waybackUrl,
    RecheckPolicy policy = RecheckPolicy.monthly,
  }) =>
      ArchiveMeta(
        url: url,
        site: 'example.com',
        status: status,
        lastCheckedAt: lastCheckedAt,
        snapshotBytes: snapshotBytes,
        waybackUrl: waybackUrl,
        policy: policy,
      );

  test('单条重抓：有快照保留旧版本，无快照只补正文', () {
    final withSnapshot = planSingleRecheck(
      entryId: 'a1',
      meta: meta(status: ArchiveStatus.full),
    );
    expect(withSnapshot.keepOldSnapshot, isTrue);
    expect(withSnapshot.reason, contains('历史版本'));

    final noSnapshot = planSingleRecheck(
      entryId: 'a2',
      meta: meta(status: ArchiveStatus.metadata),
    );
    expect(noSnapshot.keepOldSnapshot, isFalse);
    expect(noSnapshot.toJson()['url'], 'https://example.com/p');
  });

  test('Wayback 徽章：死链且有存档 URL 才显示年份', () {
    expect(
      planWaybackBadge(meta(status: ArchiveStatus.dead)).visible,
      isFalse,
    );
    expect(
      planWaybackBadge(meta(
        status: ArchiveStatus.text,
        waybackUrl: 'https://web.archive.org/web/2019/https://x',
      )).visible,
      isFalse,
      reason: '原站存活不显示存档徽章',
    );
    final badge = planWaybackBadge(meta(
      status: ArchiveStatus.dead,
      waybackUrl: 'https://web.archive.org/web/2019/https://x/p',
    ));
    expect(badge.visible, isTrue);
    expect(badge.label, '查看 2019 存档');
  });

  test('批量检查按到期分批，never 策略不排', () {
    final batches = planBatchRecheck(
      metasById: <String, ArchiveMeta>{
        'a': meta(url: 'https://x/a', lastCheckedAt: now - 40 * 86400000),
        'b': meta(url: 'https://x/b', lastCheckedAt: now - 40 * 86400000),
        'c': meta(url: 'https://x/c', lastCheckedAt: now - 86400000),
        'd': meta(
          url: 'https://x/d',
          lastCheckedAt: now - 200 * 86400000,
          policy: RecheckPolicy.never,
        ),
      },
      nowMs: now,
      batchSize: 1,
    );
    expect(batches, hasLength(2));
    expect(batches.expand((List<String> b) => b).toList(), <String>['a', 'b']);
  });

  test('配额清理复用最旧带快照优先规则，输出将降级的条目', () {
    final cleaned = planQuotaCleanup(
      metasById: <String, ArchiveMeta>{
        'old': meta(
          url: 'https://x/old',
          status: ArchiveStatus.full,
          lastCheckedAt: 1,
          snapshotBytes: 500,
        ),
        'text': meta(
          url: 'https://x/text',
          status: ArchiveStatus.text,
          lastCheckedAt: 2,
        ),
      },
      quotaLimitBytes: 1000,
      currentBytes: 950,
    );
    expect(cleaned, <String>['old']);
  });
}
