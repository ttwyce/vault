import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/archive/archive_policy.dart';

/// docs/05 §5 / §6 / §7、docs/11 §3 的纯判定层测试。
const String _url = 'https://example.com/post/123';
const int _now = 1731052800000;

ArchiveMeta _meta({
  String url = _url,
  ArchiveStatus status = ArchiveStatus.text,
  int? lastCheckedAt = _now - 1000,
  int snapshotBytes = 0,
  RecheckPolicy policy = RecheckPolicy.monthly,
}) =>
    ArchiveMeta(
      url: url,
      site: ArchiveMeta.siteOf(url),
      status: status,
      lastCheckedAt: lastCheckedAt,
      snapshotBytes: snapshotBytes,
      policy: policy,
    );

void main() {
  group('归档策略引擎（docs/05 §5）', () {
    test('默认 text：L1 正文必须保存、不生成快照', () {
      final decision = decideArchivePolicy(ArchiveRequest(
        requested: ArchivePolicy.text,
        quota: const ArchiveQuota(usedBytes: 0, limitBytes: 1000000),
      ));
      expect(decision.status, ArchiveStatus.text);
      expect(decision.saveText, isTrue);
      expect(decision.saveSnapshot, isFalse);
      expect(decision.degraded, isFalse);
    });

    test('full 且配额充足：保存正文 + 快照', () {
      final decision = decideArchivePolicy(ArchiveRequest(
        requested: ArchivePolicy.full,
        quota: const ArchiveQuota(usedBytes: 100, limitBytes: 1000000),
        estimatedSnapshotBytes: 1000,
      ));
      expect(decision.status, ArchiveStatus.full);
      expect(decision.saveSnapshot, isTrue);
    });

    test('用量超 80% 配额时 full 自动降级为 text，不删条目', () {
      final decision = decideArchivePolicy(ArchiveRequest(
        requested: ArchivePolicy.full,
        quota: const ArchiveQuota(usedBytes: 850000, limitBytes: 1000000),
        estimatedSnapshotBytes: 5000,
      ));
      expect(decision.status, ArchiveStatus.text);
      expect(decision.saveText, isTrue, reason: 'L1 正文永远不能被省掉');
      expect(decision.saveSnapshot, isFalse);
      expect(decision.degraded, isTrue);
      expect(decision.reasons.single, contains('80%'));
    });

    test('反爬 / 付费墙 / 死链 / 超时各自给出明确状态', () {
      ArchiveDecision run({
        bool blocked = false,
        bool paywalled = false,
        bool dead = false,
        bool timeout = false,
      }) =>
          decideArchivePolicy(ArchiveRequest(
            requested: ArchivePolicy.full,
            quota: const ArchiveQuota(usedBytes: 0, limitBytes: 1000000),
            blocked: blocked,
            paywalled: paywalled,
            dead: dead,
            timeout: timeout,
          ));

      expect(run(blocked: true).status, ArchiveStatus.blocked);
      expect(run(paywalled: true).status, ArchiveStatus.paywalled);
      expect(run(timeout: true).status, ArchiveStatus.metadata);
      final dead = run(dead: true);
      expect(dead.status, ArchiveStatus.dead);
      expect(dead.saveText, isFalse, reason: '死链没有新正文可存');
      expect(dead.degraded, isTrue);
    });
  });

  group('死链与内容变更判定（docs/05 §6）', () {
    test('404/410 死链；403/451 restricted；2xx/3xx 存活', () {
      expect(classifyHttpStatus(404), LinkCheckResult.dead);
      expect(classifyHttpStatus(410), LinkCheckResult.dead);
      expect(classifyHttpStatus(403), LinkCheckResult.restricted);
      expect(classifyHttpStatus(451), LinkCheckResult.restricted);
      expect(classifyHttpStatus(200), LinkCheckResult.ok);
      expect(classifyHttpStatus(301), LinkCheckResult.ok);
    });

    test('超时/DNS 失败重试 2 次后才判 unreachable', () {
      expect(classifyHttpStatus(null, retries: 1), LinkCheckResult.ok);
      expect(classifyHttpStatus(null, retries: 2),
          LinkCheckResult.unreachable);
      expect(classifyHttpStatus(503, retries: 1), LinkCheckResult.ok);
      expect(classifyHttpStatus(503, retries: 2),
          LinkCheckResult.unreachable);
    });

    test('只有 dead / unreachable 才提示 Wayback', () {
      expect(shouldTryWayback(LinkCheckResult.dead), isTrue);
      expect(shouldTryWayback(LinkCheckResult.unreachable), isTrue);
      expect(shouldTryWayback(LinkCheckResult.restricted), isFalse);
      expect(shouldTryWayback(LinkCheckResult.changed), isFalse);
    });

    test('simhash 汉明距离 ≤3 不算实质变更，非法值保守返回 false', () {
      expect(hasContentChanged('0', '0'), isFalse);
      expect(hasContentChanged('0', '7'), isFalse, reason: '3 bit 变化');
      expect(hasContentChanged('0', 'f'), isTrue, reason: '4 bit 变化');
      expect(hasContentChanged(null, 'f'), isFalse);
      expect(hasContentChanged('not-hex', 'f'), isFalse);
    });
  });

  group('按需下载与 LRU 缓存（docs/05 §7）', () {
    test('按最久未访问顺序淘汰，只释放本地空间', () {
      final plan = planBlobCacheEviction(
        blobs: <CachedBlob>[
          const CachedBlob(blobHash: 'old', bytes: 300, lastAccessAt: 1),
          const CachedBlob(blobHash: 'new', bytes: 300, lastAccessAt: 100),
          const CachedBlob(blobHash: 'mid', bytes: 200, lastAccessAt: 50),
        ],
        maxBytes: 400,
        currentBytes: 800,
      );
      expect(plan.evicted, <String>['old', 'mid']);
      expect(plan.kept, <String>['new']);
      expect(plan.freedBytes, 500);
    });

    test('缓存本就没超限时一条都不淘汰', () {
      final plan = planBlobCacheEviction(
        blobs: <CachedBlob>[
          const CachedBlob(blobHash: 'a', bytes: 100, lastAccessAt: 1),
        ],
        maxBytes: 500,
        currentBytes: 100,
      );
      expect(plan.evicted, isEmpty);
      expect(plan.freedBytes, 0);
    });
  });

  group('归档总览筛选与聚合（docs/11 §3.2）', () {
    final metas = <ArchiveMeta>[
      _meta(status: ArchiveStatus.full, snapshotBytes: 400000),
      _meta(url: 'https://example.com/other', status: ArchiveStatus.dead),
      _meta(
          url: 'https://github.com/a',
          status: ArchiveStatus.metadata,
          policy: RecheckPolicy.weekly),
      _meta(
          url: 'https://blog.example.org/x',
          status: ArchiveStatus.blocked),
    ];

    test('站点聚合按数量降序，example.com 两条合并', () {
      final groups = groupBySite(metas);
      expect(groups.first.site, 'example.com');
      expect(groups.first.count, 2);
    });

    test('状态筛选：全部 / 存活 / 失效 / 仅元数据 / 指定站点', () {
      List<ArchiveMeta> filtered(ArchiveFilter filter, {String? site}) =>
          filterArchives(metas, filter: filter, nowMs: _now, site: site);

      expect(filtered(ArchiveFilter.all), hasLength(4));
      expect(filtered(ArchiveFilter.alive), hasLength(2),
          reason: 'blocked 不算存活');
      expect(filtered(ArchiveFilter.dead), hasLength(1));
      expect(filtered(ArchiveFilter.metadataOnly), hasLength(1));
      expect(filtered(ArchiveFilter.site, site: 'github.com'), hasLength(1));
    });

    test('待重抓：nextCheckAt 已到期且 policy 不是 never', () {
      final due = _meta(
        lastCheckedAt: _now - const Duration(days: 31).inMilliseconds,
      );
      final fresh = _meta(lastCheckedAt: _now);
      final never = _meta(policy: RecheckPolicy.never);
      final result = filterArchives(<ArchiveMeta>[due, fresh, never],
          filter: ArchiveFilter.pendingRecheck, nowMs: _now);
      expect(result, <ArchiveMeta>[due]);
    });

    test('存储面板汇总正文 / 快照 / 图片占用', () {
      final summary = summarizeStorage(metas);
      expect(summary.textBytes, greaterThan(0));
      expect(summary.snapshotBytes, 400000);
      expect(summary.totalBytes,
          summary.textBytes + summary.snapshotBytes + summary.imageBytes);
    });

    test('超配额清理只把最老的 full 降级为 text，不删条目', () {
      final fullOld = (
        entryId: 'e1',
        meta: _meta(status: ArchiveStatus.full, snapshotBytes: 400000,
            lastCheckedAt: 1),
      );
      final fullNew = (
        entryId: 'e2',
        meta: _meta(url: 'https://github.com/b', status: ArchiveStatus.full,
            snapshotBytes: 300000, lastCheckedAt: 100),
      );
      final textOnly = (entryId: 'e3', meta: _meta());
      final plan = planSnapshotDowngrade(
        entries: <({String entryId, ArchiveMeta meta})>[
          fullOld,
          fullNew,
          textOnly,
        ],
        quotaLimitBytes: 1000000,
        currentBytes: 850000,
      );
      expect(plan, <String>['e1'],
          reason: '降到 80% 配额线以下就停，不多删一份快照');
      expect(plan, isNot(contains('e3')), reason: 'text 条目没有快照可降级');

      // 需要降更多时才会继续按 LRU 处理下一条。
      final deeper = planSnapshotDowngrade(
        entries: <({String entryId, ArchiveMeta meta})>[
          fullOld,
          fullNew,
          textOnly,
        ],
        quotaLimitBytes: 500000,
        currentBytes: 850000,
      );
      expect(deeper, <String>['e1', 'e2']);
    });
  });
}
