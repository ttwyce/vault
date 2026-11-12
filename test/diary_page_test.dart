import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/diary/diary_page.dart';

import 'support/test_harness.dart';

/// 日记页测试。
///
/// 日记日期存在 `meta.date`（YYYY-MM-DD）。`TestApp.create()` 默认时钟是
/// 2026-11-08，所以把页面固定到 2026 年 11 月，数据与标题就能对齐。
void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
  });

  tearDown(() async {
    await app.dispose();
  });

  Future<void> pumpDiary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(
        // 生产环境由 AppShell 的 Scaffold 提供 Material 祖先，测试里补一个。
        home: Scaffold(body: DiaryPage(initialMonth: DateTime(2026, 11))),
      ),
    ));
    // 不用 pumpAndSettle：加载圈与手绘控件动画会一直触发重绘。
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('月历渲染固定月份的标题', (WidgetTester tester) async {
    await pumpDiary(tester);

    expect(find.text('2026年11月'), findsOneWidget);
  });

  testWidgets('有用户日记时下方列表显示标题', (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.diary,
      title: '这一天',
      body: '内容',
      meta: '{"date":"2026-11-08"}',
    ));

    await pumpDiary(tester);

    expect(find.text('这一天'), findsOneWidget);
  });

  testWidgets('AI 日记显示 AI 标签', (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.aiDiary,
      title: 'AI 总结',
      body: '自动生成的内容',
      meta: '{"date":"2026-11-08"}',
    ));

    await pumpDiary(tester);

    expect(find.text('AI'), findsOneWidget);
    expect(find.text('AI 总结'), findsOneWidget);
  });

  testWidgets('空月显示空状态文案', (WidgetTester tester) async {
    await pumpDiary(tester);

    expect(find.text('这个月还没有日记，点右上角补写'), findsOneWidget);
  });

  testWidgets('生成 AI 日记按钮在无活动时不写空条目',
      (WidgetTester tester) async {
    await pumpDiary(tester);
    expect(find.text('生成 AI 日记'), findsOneWidget);
    await tester.tap(find.text('生成 AI 日记'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      await (app.db.select(app.db.entries)
            ..where((t) => t.kind.equals(EntryKind.aiDiary.code)))
          .get(),
      isEmpty,
    );
  });

  testWidgets('底部显示连续天数标签', (WidgetTester tester) async {
    await pumpDiary(tester);
    expect(find.textContaining('连续'), findsOneWidget);
  });
}
