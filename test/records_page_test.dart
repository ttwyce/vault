import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/records/records_page.dart';

import 'support/test_harness.dart';

/// 记录页测试。
void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
  });

  tearDown(() async {
    await app.dispose();
  });

  Future<void> pumpRecords(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(
        // RecordsPage 是 AppShell 里的 tab，生产环境由 AppShell 的 Scaffold
        // 提供 Material 祖先；测试里单独 pump 要自己补一个。
        home: Scaffold(body: RecordsPage()),
      ),
    ));
    // 不用 pumpAndSettle：加载圈 + 手绘控件动画会一直触发重绘。
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('列表渲染出新建的笔记', (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.note,
      title: '第一篇笔记',
      body: '正文内容',
    ));

    await pumpRecords(tester);

    expect(find.text('第一篇笔记'), findsOneWidget);
  });

  testWidgets('「笔记/想法」分段切换', (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.note,
      title: '一条笔记',
    ));
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.thought,
      title: '一个想法',
    ));

    await pumpRecords(tester);

    // 默认「笔记」分段：想法不显示
    expect(find.text('一条笔记'), findsOneWidget);
    expect(find.text('一个想法'), findsNothing);

    // 切到「想法」：笔记消失、想法出现
    await tester.tap(find.text('想法'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('一个想法'), findsOneWidget);
    expect(find.text('一条笔记'), findsNothing);
  });

  testWidgets('搜索框过滤（带防抖）', (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.note,
      title: '增量同步',
      body: 'webdav',
    ));
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.note,
      title: '完全无关',
      body: '别的内容',
    ));

    await pumpRecords(tester);

    await tester.enterText(find.byType(TextField).first, '同步');
    // 防抖 300ms + FutureBuilder 完成
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('增量同步'), findsOneWidget);
    expect(find.text('完全无关'), findsNothing);
  });

  testWidgets('没有内容时显示空状态', (WidgetTester tester) async {
    await pumpRecords(tester);

    expect(find.text('还没有内容，点右上角新建'), findsOneWidget);
  });

  testWidgets('搜索结果默认排除 AI 日记（M5 判定层接进 UI）',
      (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.note,
      title: '同步笔记',
      body: '普通笔记也提到同步',
    ));
    await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.aiDiary,
      title: '同步 AI 日记',
      body: '生成文本也提到同步',
    ));
    await pumpRecords(tester);

    await tester.enterText(find.byType(TextField).first, '同步');
    // 搜索框有防抖。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('同步笔记'), findsOneWidget);
    expect(find.text('同步 AI 日记'), findsNothing);
  });
}
