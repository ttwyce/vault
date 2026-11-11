import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/archive/link_check_service.dart';

import 'support/test_harness.dart';

/// docs/05 §6 / docs/11 §3.4 重检查编排测试。
void main() {
  late TestApp app;
  late LinkCheckService service;

  setUp(() async {
    app = await TestApp.create(now: () => 1731052800000);
    service = LinkCheckService(db: app.db, gateway: app.gateway);
  });
  tearDown(() async => app.dispose());

  test('404 / 网络不可达 → dead/unreachable 且回退 Wayback', () {
    final dead = decideLinkCheck(
      httpStatus: 404,
      retries: 0,
      previousSimhash: null,
      currentSimhash: null,
    );
    expect(dead.result, LinkCheckResult.dead);
    expect(dead.tryWayback, isTrue);
    expect(dead.reasons.join(), contains('Wayback'));

    final unreachable = decideLinkCheck(
      httpStatus: null,
      retries: 2,
      previousSimhash: null,
      currentSimhash: null,
    );
    expect(unreachable.result, LinkCheckResult.unreachable);
    expect(unreachable.tryWayback, isTrue);
  });

  test('restricted / paywalled 不回退；simhash 变化改为 changed', () {
    final restricted = decideLinkCheck(
      httpStatus: 403,
      retries: 0,
      previousSimhash: null,
      currentSimhash: null,
    );
    expect(restricted.result, LinkCheckResult.restricted);
    expect(restricted.tryWayback, isFalse);

    final changed = decideLinkCheck(
      httpStatus: 200,
      retries: 0,
      // 汉明距离远大于 3（低 8 位全翻转）。
      previousSimhash: '0000000000000000',
      currentSimhash: '00000000000000ff',
    );
    expect(changed.result, LinkCheckResult.changed);
    expect(changed.changed, isTrue);
    expect(changed.tryWayback, isFalse);
  });

  test('距上次检查未过 30 天不重复落证据', () {
    final outcome = decideLinkCheck(
      httpStatus: 200,
      retries: 0,
      previousSimhash: null,
      currentSimhash: null,
      nowMs: 1731052800000,
      previousCheckedAt: 1731052800000 - 86400000,
    );
    expect(outcome.shouldRecord, isFalse);
    expect(outcome.reasons.join(), contains('跳过'));
  });

  test('run 经 WriteGateway 落 link_check，第二次用上次 simhash 比对',
      () async {
    final first = await service.run(
      entryId: 'arch-1',
      httpStatus: 200,
      retries: 0,
      previousSimhash: null,
      currentSimhash: '0000000000000000',
      finalUrl: 'https://example.com/final',
      nowMs: 1731052800000,
    );
    expect(first.result, LinkCheckResult.ok);
    var rows = await app.db.select(app.db.linkChecks).get();
    expect(rows, hasLength(1));
    expect(rows.single.simhash, '0000000000000000');
    expect(rows.single.finalUrl, 'https://example.com/final');

    // 30 天后内容变了：应判 changed 并落第二条证据。
    final second = await service.run(
      entryId: 'arch-1',
      httpStatus: 200,
      retries: 0,
      previousSimhash: null,
      currentSimhash: '00000000000000ff',
      nowMs: 1731052800000 + kRecheckIntervalMs + 1,
    );
    expect(second.result, LinkCheckResult.changed);
    rows = await app.db.select(app.db.linkChecks).get();
    expect(rows, hasLength(2));
  });
}
