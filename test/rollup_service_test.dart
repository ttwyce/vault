import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/daily_summary.dart';
import 'package:vault/data/agent/rollup_service.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// docs/07 §5.3 滚动摘要测试。
void main() {
  late TestApp app;
  late RollupService service;

  setUp(() async {
    app = await TestApp.create(now: () => 1731052800000);
    service = RollupService(db: app.db, gateway: app.gateway);
  });
  tearDown(() async => app.dispose());

  Future<void> addSummary(
    String date,
    SummaryGranularity g, {
    List<String> citations = const <String>[],
  }) async {
    final summary = DailySummary(
      headline: '$date 做了同步',
      timeline: const <TimelineItem>[],
      openThreads: const <String>[],
      citations: citations,
      date: date,
      granularity: g,
    );
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.aiDiary,
      title: '摘要 $date',
      meta: jsonEncode(summary.toJson()),
      body: summary.headline,
    ));
  }

  test('周读 7 日日摘要，聚合后落 kind=4 周摘要', () async {
    for (var day = 1; day <= 7; day++) {
      await addSummary('2026-11-0$day', SummaryGranularity.day);
    }
    final week = await service.rollup(
      target: SummaryGranularity.week,
      periodKey: '2026-W45',
      from: '2026-11-01',
      to: '2026-11-07',
    );
    expect(week, isNotNull);
    expect(week!.headline, contains('7/7 条'));
    expect(week.timeline, hasLength(7));
    expect(week.granularity, SummaryGranularity.week);
    expect(childCountFor(SummaryGranularity.week), 7);
  });

  test('月读 4 周、年读 12 月，各自只读对应层级不串层', () async {
    for (var w = 1; w <= 4; w++) {
      await addSummary('2026-W4$w', SummaryGranularity.week);
    }
    await addSummary('2026-11-01', SummaryGranularity.day,
        citations: const <String>['ignored']);
    final month = await service.rollup(
      target: SummaryGranularity.month,
      periodKey: '2026-11',
      from: '2026-W41',
      to: '2026-W44',
    );
    expect(month!.timeline, hasLength(4), reason: '日摘要不能被月层误读');

    for (var m = 1; m <= 12; m++) {
      final key = '2026-${m.toString().padLeft(2, '0')}';
      await addSummary(key, SummaryGranularity.month);
    }
    final year = await service.rollup(
      target: SummaryGranularity.year,
      periodKey: '2026',
      from: '2026-01',
      to: '2026-12',
    );
    expect(year!.timeline, hasLength(13),
        reason: '含刚才生成的 2026-11 月摘要，共 13 条月层');
    expect(childCountFor(SummaryGranularity.year), 12);
  });

  test('坏 meta 与已删除条目跳过；引用只保留真实存在的 id', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'real',
      kind: EntryKind.note,
      title: '原文',
    ));
    await addSummary('2026-11-01', SummaryGranularity.day,
        citations: const <String>['real', 'missing']);
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.aiDiary,
      title: '坏摘要',
      meta: '{"headline": "坏摘要", "granularity": "unknown"}',
      body: 'x',
    ));
    final week = await service.rollup(
      target: SummaryGranularity.week,
      periodKey: '2026-W45',
      from: '2026-11-01',
      to: '2026-11-07',
    );
    expect(week!.timeline, hasLength(1));
    expect(week.citations, <String>['real']);
  });

  test('没有下层摘要时不写空条目；日不能作为滚动目标', () async {
    expect(
      await service.rollup(
        target: SummaryGranularity.week,
        periodKey: '2026-W45',
        from: '2026-11-01',
        to: '2026-11-07',
      ),
      isNull,
    );
    expect(
      () => service.rollup(
        target: SummaryGranularity.day,
        periodKey: 'x',
        from: 'a',
        to: 'b',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
