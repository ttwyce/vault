import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_cache_policy.dart';
import 'package:vault/data/archive/archive_policy.dart' show CachedBlob;

/// docs/05 §7 按需下载与本地 blob 缓存策略测试。
void main() {
  test('默认上限 500MB', () {
    expect(kDefaultBlobCacheMaxBytes, 500 * 1024 * 1024);
  });

  test('L1 自动下载带骨架屏；L2 必须点原貌；已本地不请求', () {
    final text = planOnDemandRequest(
      entryId: 'a',
      blobHash: 'h1',
      layer: OnDemandLayer.text,
      local: false,
    )!;
    expect(text.showSkeleton, isTrue);
    expect(text.requiresUserTap, isFalse);
    expect(text.hint, contains('<100KB'));
    expect(text.toJson()['layer'], 'text');

    final pdf = planOnDemandRequest(
      entryId: 'a',
      blobHash: 'h2',
      layer: OnDemandLayer.pdf,
      local: false,
    )!;
    expect(pdf.requiresUserTap, isTrue);
    expect(pdf.showSkeleton, isFalse);
    expect(
      planOnDemandRequest(
        entryId: 'a',
        blobHash: 'h1',
        layer: OnDemandLayer.text,
        local: true,
      ),
      isNull,
    );
  });

  test('超上限按 LRU 清理，动作只置 local=0 不删云端', () {
    final blobs = <CachedBlob>[
      const CachedBlob(blobHash: 'old', bytes: 300, lastAccessAt: 1),
      const CachedBlob(blobHash: 'new', bytes: 300, lastAccessAt: 2),
    ];
    final plan = planBlobCacheCleanup(
      blobs: blobs,
      currentBytes: 600,
      maxBytes: 400,
    );
    expect(plan.evictedHashes, <String>['old']);
    expect(plan.freedBytes, 300);
    expect(plan.isEmpty, isFalse);
    expect(plan.actions, hasLength(1));
    expect(plan.actions.single, contains('local = 0'));
    expect(plan.actions.single, contains('云端不动'));

    final ok = planBlobCacheCleanup(
      blobs: blobs,
      currentBytes: 600,
      maxBytes: 600,
    );
    expect(ok.isEmpty, isTrue);
    expect(ok.actions, isEmpty);
  });
}
