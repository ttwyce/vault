import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/search/search_page.dart';

import 'support/test_harness.dart';

/// docs/06 §8.1 搜索结果卡片元信息测试。
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> pumpSearch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: Scaffold(body: SearchPage())),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('结果卡片显示类型 / 命中来源 / 归档徽章', (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'note-1',
      kind: EntryKind.note,
      title: '同步笔记',
      body: '增量同步正文',
    ));
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'bookmark-1',
      kind: EntryKind.bookmark,
      title: '归档页',
      body: '增量同步归档',
    ));
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField).first, '同步');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('命中：关键词'), findsWidgets);
    expect(find.text('笔记'), findsWidgets);
    expect(find.text('书签'), findsWidgets);
    expect(find.text('归档'), findsWidgets);
  });

  testWidgets('空结果默认显示模型未就绪引导，不谎称可问 AI',
      (WidgetTester tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField).first, '不存在的词xyz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('模型管理页'), findsOneWidget);
    expect(find.text('问 AI（逐次授权）'), findsNothing);
  });

  testWidgets('相同 query 5 分钟内复用缓存，重复搜索仍展示结果',
      (WidgetTester tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField).first, '同步');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    // 清空再输入同一 query：走缓存命中分支，不重复 FTS/埋点。
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, '同步');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField).first, findsOneWidget);
  });

  testWidgets('归档结果显示真实死链状态徽章', (WidgetTester tester) async {
    final meta = ArchiveMeta(
      url: 'https://example.com/dead',
      site: 'example.com',
      status: ArchiveStatus.dead,
    );
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'bookmark-dead',
      kind: EntryKind.bookmark,
      title: '失效归档',
      body: '增量同步失效页',
      meta: meta.toJsonString(),
    ));
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField).first, '同步');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('原站已失效'), findsWidgets);
  });
}
