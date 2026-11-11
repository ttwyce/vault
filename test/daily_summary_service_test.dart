import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/activity/activity_logger.dart';
import 'package:vault/data/agent/daily_summary.dart' show AiDiaryRules;
import 'package:vault/data/agent/daily_summary_service.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// docs/07 §5 / §6 日总结流水线接真实 ActivityLogger 测试。
void main() {
  late TestApp app;
  const int base = 1731052800000; // 2026-11-08 10:00 附近

  setUp(() async => app = await TestApp.create(now: () => base));
  tearDown(() async => app.dispose());

  ActivityLogger logger() => ActivityLogger(
        db: app.db,
        deviceId: 'devA',
        now: () => base,
      );

  test('空的一天不写 kind=4 条目', () async {
    final service = DailySummaryService(
      logger: logger(),
      gateway: app.gateway,
      db: app.db,
    );
    final result = await service.buildAndStore(
      DateTime.fromMillisecondsSinceEpoch(base),
    );
    expect(result, isNull);
    expect(await app.db.select(app.db.entries).get(), isEmpty);
  });

  test('真实活动 → 事实 headline + 时间线 + kind=4 落库，引用校验生效',
      () async {
    final log = logger();
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'entry-1',
      kind: EntryKind.note,
      title: 'RFC 6578',
    ));
    await log.recordCreate('entry-1');
    await log.view('entry-1', dwell: const Duration(minutes: 12));
    await log.recordSearch('增量同步');

    final service = DailySummaryService(
      logger: log,
      gateway: app.gateway,
      db: app.db,
    );
    final day = DateTime.fromMillisecondsSinceEpoch(base);
    final summary = await service.buildAndStore(day);
    expect(summary, isNotNull);
    expect(summary!.headline, contains('新建 1 条'));
    expect(summary.timeline, isNotEmpty);
    expect(summary.citations, <String>['entry-1']);

    final rows = await (app.db.select(app.db.entries)
          ..where((t) => t.kind.equals(EntryKind.aiDiary.code)))
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.title, contains('日总结'));
    expect(AiDiaryRules.shouldVectorize(rows.single.kind), isFalse);
    expect(AiDiaryRules.includeInSearch(userOptedIn: false), isFalse);
  });

  test('引用到已删除的条目被剔除，绝不展示假引用', () async {
    final log = logger();
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'gone',
      kind: EntryKind.note,
      title: '已删',
    ));
    await app.gateway.writeEntry(EntryWrite.delete(id: 'gone'));
    await log.view('gone');

    final service = DailySummaryService(
      logger: log,
      gateway: app.gateway,
      db: app.db,
    );
    final summary = await service.buildAndStore(
      DateTime.fromMillisecondsSinceEpoch(base),
    );
    expect(summary, isNotNull);
    expect(summary!.citations, isEmpty);
  });
}
