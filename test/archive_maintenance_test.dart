import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_maintenance.dart';
import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/archive/archive_policy.dart';

/// docs/05 §6 / §7 归档维护计划器测试。
void main() {
  const now = 1731052800000;
  const day = 86400000;

  ArchiveMeta meta({
    ArchiveStatus status = ArchiveStatus.text,
    RecheckPolicy policy = RecheckPolicy.monthly,
    int? lastCheckedAt,
    int snapshotBytes = 0,
  }) =>
      ArchiveMeta(
        url: 'https://example.com/p',
        site: 'example.com',
        status: status,
        policy: policy,
        lastCheckedAt: lastCheckedAt,
        snapshotBytes: snapshotBytes,
      );

  test('四类动作都能排出清单，JSON 可导出', () {
    final plan = planArchiveMaintenance(
      entries: <ArchiveMaintenanceItem>[
        ArchiveMaintenanceItem(
          entryId: 'recheck-me',
          meta: meta(lastCheckedAt: now - 40 * day),
          lastCheckResult: LinkCheckResult.dead,
        ),
        ArchiveMaintenanceItem(
          entryId: 'snap-old',
          meta: meta(
            status: ArchiveStatus.full,
            lastCheckedAt: now - 100 * day,
            snapshotBytes: 500,
          ),
        ),
      ],
      nowMs: now,
      cacheMaxBytes: 100,
      cacheCurrentBytes: 200,
      cachedBlobs: const <CachedBlob>[
        CachedBlob(blobHash: 'b1', bytes: 150, lastAccessAt: 1),
      ],
      quotaLimitBytes: 1000,
      quotaCurrentBytes: 950,
    );
    expect(plan.countOf(MaintenanceAction.recheck), 2);
    expect(plan.countOf(MaintenanceAction.wayback), 1);
    expect(plan.countOf(MaintenanceAction.evictBlob), 1);
    expect(plan.countOf(MaintenanceAction.downgradeSnapshot), 1);
    expect(plan.toJson().first['action'], 'recheck');
  });

  test('restricted / paywalled 不回退 Wayback，never 策略不排重检查', () {
    final plan = planArchiveMaintenance(
      entries: <ArchiveMaintenanceItem>[
        ArchiveMaintenanceItem(
          entryId: 'restricted',
          meta: meta(),
          lastCheckResult: LinkCheckResult.restricted,
        ),
        ArchiveMaintenanceItem(
          entryId: 'never',
          meta: meta(policy: RecheckPolicy.never, lastCheckedAt: 1),
        ),
      ],
      nowMs: now,
      cacheMaxBytes: 1000,
      cacheCurrentBytes: 0,
      cachedBlobs: const <CachedBlob>[],
      quotaLimitBytes: 1000,
      quotaCurrentBytes: 0,
    );
    expect(plan.countOf(MaintenanceAction.wayback), 0);
    expect(plan.countOf(MaintenanceAction.recheck), 0);
  });

  test('配额未触线时不降级，缓存未超预算时不清理', () {
    final plan = planArchiveMaintenance(
      entries: <ArchiveMaintenanceItem>[
        ArchiveMaintenanceItem(
          entryId: 'snap',
          meta: meta(status: ArchiveStatus.full, snapshotBytes: 500),
        ),
      ],
      nowMs: now,
      cacheMaxBytes: 1000,
      cacheCurrentBytes: 100,
      cachedBlobs: const <CachedBlob>[
        CachedBlob(blobHash: 'b1', bytes: 100, lastAccessAt: 1),
      ],
      quotaLimitBytes: 1000,
      quotaCurrentBytes: 700,
    );
    expect(plan.countOf(MaintenanceAction.downgradeSnapshot), 0);
    expect(plan.countOf(MaintenanceAction.evictBlob), 0);
    expect(plan.tasks, isEmpty);
  });
}
