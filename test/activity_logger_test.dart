import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/activity/activity_logger.dart';
import 'package:vault/data/db/database_key.dart';
import 'package:vault/data/db/database_opener.dart';
import 'package:vault/data/db/tables/log_tables.dart';
import 'package:vault/data/db/vault_database.dart';

/// 活动埋点的测试。
///
/// 重点不是"能不能记下来"，而是**合并窗口的语义**：
/// 记太细会让表爆炸且日总结读不动，记太粗会丢掉"读了多久"这个关键维度。
void main() {
  late VaultDatabaseOpener opener;
  late VaultDatabase db;
  late ActivityLogger logger;

  /// 2026-11-08 10:00 本地时间
  late DateTime base;
  late int nowMillis;

  setUp(() async {
    opener = VaultDatabaseOpener(key: DatabaseKey.random(Random(3)), inMemory: true);
    db = await opener.open();
    base = DateTime(2026, 11, 8, 10);
    nowMillis = base.millisecondsSinceEpoch;
    logger = ActivityLogger(db: db, deviceId: 'devA', now: () => nowMillis);
  });

  tearDown(() async {
    await opener.close();
  });

  Future<List<ActivityRow>> all() => db.select(db.activities).get();

  group('浏览合并', () {
    test('同一窗口内多次浏览合并成一次阅读会话，dwell 累加', () async {
      await logger.view('e1', dwell: const Duration(seconds: 30));
      nowMillis += const Duration(minutes: 10).inMilliseconds;
      await logger.view('e1', dwell: const Duration(seconds: 45));

      final rows = await all();
      expect(rows.length, 1, reason: '10 分钟内应合并成一行');
      expect(rows.single.dwellMs, 75000);
      expect(rows.single.ts, nowMillis, reason: 'ts 记的是会话最后一次活动的时刻');
    });

    test('超出窗口后另起一行', () async {
      await logger.view('e1');
      nowMillis += const Duration(minutes: 31).inMilliseconds;
      await logger.view('e1');

      expect((await all()).length, 2);
    });

    test('不同条目不合并', () async {
      await logger.view('e1');
      await logger.view('e2');
      expect((await all()).length, 2);
    });

    test('阅读归档与阅读笔记分开统计', () async {
      await logger.view('e1');
      await logger.archiveView('e1');
      final kinds = (await all()).map((ActivityRow r) => r.kind).toList()..sort();
      expect(kinds, <int>[ActivityKind.view.code, ActivityKind.archiveView.code]..sort());
    });
  });

  group('搜索合并', () {
    test('同一关键词 60 秒内只记一次（防打字机式刷屏）', () async {
      await logger.recordSearch('webdav');
      nowMillis += 10000;
      await logger.recordSearch('webdav');
      nowMillis += 10000;
      await logger.recordSearch('webdav');

      expect((await all()).length, 1);
    });

    test('不同关键词各记一次', () async {
      await logger.recordSearch('webdav');
      await logger.recordSearch('冲突');
      expect((await all()).length, 2);
    });

    test('空查询不记', () async {
      await logger.recordSearch('');
      await logger.recordSearch('   ');
      expect(await all(), isEmpty);
    });

    test('结果数写进 extra', () async {
      await logger.recordSearch('webdav', resultCount: 7);
      final extra = jsonDecode((await all()).single.extra!) as Map<String, Object?>;
      expect(extra['results'], 7);
      expect(extra['device'], 'devA');
    });
  });

  group('创建与编辑', () {
    test('创建不合并（每次都是独立事件）', () async {
      await logger.recordCreate('e1');
      await logger.recordCreate('e1');
      expect((await all()).length, 2);
    });

    test('编辑 5 分钟内合并成一次编辑会话', () async {
      await logger.recordEdit('e1');
      nowMillis += 60000;
      await logger.recordEdit('e1');
      nowMillis += 60000;
      await logger.recordEdit('e1');

      expect((await all()).length, 1, reason: '自动保存不应该产生上百行');
    });

    test('编辑超出窗口另起一行', () async {
      await logger.recordEdit('e1');
      nowMillis += const Duration(minutes: 6).inMilliseconds;
      await logger.recordEdit('e1');
      expect((await all()).length, 2);
    });
  });

  group('日时间线与摘要', () {
    test('只返回当天（按本地时区切分）', () async {
      await logger.view('today');

      // 前一天的 23:59
      final yesterday = base.subtract(const Duration(days: 1));
      nowMillis = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59)
          .millisecondsSinceEpoch;
      await logger.view('yesterday');

      // 次日 00:01
      final tomorrow = base.add(const Duration(days: 1));
      nowMillis = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 1)
          .millisecondsSinceEpoch;
      await logger.view('tomorrow');

      nowMillis = base.millisecondsSinceEpoch;
      final timeline = await logger.timelineForDay(base);
      expect(timeline.map((ActivityRow r) => r.entryId), <String>['today']);
    });

    test('摘要统计各类事件与停留时长', () async {
      await logger.recordCreate('e1');
      await logger.recordCreate('e2');
      await logger.recordEdit('e1');
      await logger.view('e1', dwell: const Duration(minutes: 2));
      await logger.view('e2', dwell: const Duration(minutes: 1));
      await logger.recordSearch('webdav');
      await logger.recordSearch('冲突');
      await logger.recordClip(entryId: 'e3', source: 'share');

      final summary = await logger.summarizeDay(base);
      expect(summary.totalEvents, 8);
      expect(summary.countByKind[ActivityKind.create], 2);
      expect(summary.countByKind[ActivityKind.search], 2);
      expect(summary.countByKind[ActivityKind.clip], 1);
      expect(summary.dwellByKind[ActivityKind.view], 180000);
      expect(summary.touchedEntryIds.toSet(), <String>{'e1', 'e2', 'e3'});
      expect(summary.searchQueries, <String>['webdav', '冲突']);
      expect(summary.isEmpty, isFalse);
    });

    test('headline 是事实描述，不是"洞察"', () async {
      await logger.recordCreate('e1');
      await logger.view('e1');
      await logger.recordSearch('x');

      final summary = await logger.summarizeDay(base);
      expect(summary.headline, contains('新建 1 条'));
      expect(summary.headline, contains('阅读 1 次'));
      expect(summary.headline, contains('搜索 1 次'));
    });

    test('空的一天 headline 明确说明没有记录', () async {
      final summary = await logger.summarizeDay(base);
      expect(summary.isEmpty, isTrue);
      expect(summary.headline, contains('没有记录'));
    });
  });

  group('维护与边界', () {
    test('prune 清掉超过保留期的记录', () async {
      await logger.view('old');
      nowMillis += const Duration(days: 400).inMilliseconds;
      await logger.view('new');

      final removed = await logger.prune();
      expect(removed, 1);
      final left = await all();
      expect(left.length, 1);
      expect(left.single.entryId, 'new');
    });

    test('埋点不产生 oplog（活动是本地数据，不参与同步）', () async {
      await logger.view('e1');
      await logger.recordCreate('e1');
      await logger.recordSearch('x');

      final oplog = await db.select(db.oplogs).get();
      expect(oplog, isEmpty,
          reason: 'activity 不在 SyncEntity 列表里，绝不能被推送出去');
    });
  });

  test('搜索词夹带已知密码明文时不落 activity 表', () async {
    final guarded = ActivityLogger(
      db: db,
      deviceId: 'devA',
      now: () => nowMillis,
      knownSecrets: const <String>{'UniquePass!2026'},
    );
    await guarded.recordSearch('我的密码 UniquePass!2026');
    await guarded.recordSearch('正常的同步笔记');

    final rows = await db.select(db.activities).get();
    final queries = rows
        .where((row) => row.kind == ActivityKind.search.code)
        .map((row) => row.query)
        .whereType<String>()
        .toList();
    expect(queries, <String>['正常的同步笔记']);
    expect(jsonEncode(queries), isNot(contains('UniquePass')));
  });
}
