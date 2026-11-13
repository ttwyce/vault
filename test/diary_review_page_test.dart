import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/data/diary/diary_meta.dart';
import 'package:vault/data/diary/diary_review.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/diary/diary_page.dart';
import 'package:vault/features/diary/diary_year_review_page.dart';

import 'support/test_harness.dart';

/// 日记模板预填与年度回顾入口（docs/11 §1.5）。
void main() {
  late TestApp app;
  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(theme: SketchTheme.light, home: page),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('选择复盘模板后补写日记预填正文', (WidgetTester tester) async {
    final month = DateTime(2026, 11);
    await pumpPage(tester, DiaryPage(initialMonth: month));
    expect(find.textContaining('模板：'), findsOneWidget);
    await tester.tap(find.textContaining('模板：'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('复盘'), findsWidgets);
    await tester.tap(find.text('复盘').last);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.textContaining('模板：复盘'), findsOneWidget);

    await tester.tap(find.text('补写'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('明天改什么'), findsOneWidget);
  });

  testWidgets('年度回顾页读取真实日记 meta 并显示汇总',
      (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'diary-review-1',
      kind: EntryKind.diary,
      title: '一月一日',
      body: '正文',
      meta: buildDiaryMeta(
        date: '2026-01-01',
        body: '正文',
        createdAtMs: DateTime(2026, 1, 1).millisecondsSinceEpoch,
        mood: '好',
      ).toJsonString(),
    ));
    await pumpPage(tester, const DiaryYearReviewPage(year: 2026));
    expect(find.textContaining('2026 年共 1 篇'), findsOneWidget);
    expect(find.textContaining('01 月 · 1 篇'), findsOneWidget);
    expect(find.text('好 · 1 次'), findsOneWidget);
    expect(find.textContaining('最长连续 1 天'), findsWidgets);
    expect(diaryTemplateById('free').body, isEmpty);
    expect(kDiaryTemplates.length, greaterThan(1));
  });
}
