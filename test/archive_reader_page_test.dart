import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/archive/archive_reader_page.dart';

import 'support/test_harness.dart';

/// docs/05 §9 阅读器三模式判定接线测试。
void main() {
  ArchiveMeta meta({
    ArchiveStatus status = ArchiveStatus.full,
    bool changed = false,
  }) =>
      ArchiveMeta(
        url: 'https://example.com/p',
        site: 'example.com',
        status: status,
        changed: changed,
      );

  Future<void> pumpReader(
    WidgetTester tester, {
    required ArchiveMeta archiveMeta,
    bool pdfLocal = true,
    bool hasPrevious = true,
    String? body = '归档正文内容',
    String? previousBody,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ArchiveReaderPage(
          title: '测试归档',
          meta: archiveMeta,
          archivedAtMs: 1731052800000,
          pdfLocal: pdfLocal,
          hasPreviousTextVersion: hasPrevious,
          body: body,
          previousBody: previousBody,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('full + 本地 PDF + 旧版：三个模式可点，纯净默认渲染正文',
      (WidgetTester tester) async {
    await pumpReader(
      tester,
      archiveMeta: meta(changed: true),
      previousBody: '归档旧版内容\n第二段',
    );
    expect(find.text('归档正文内容'), findsOneWidget);
    expect(find.textContaining('归档于'), findsOneWidget);
    expect(find.textContaining('原站存活'), findsOneWidget);

    await tester.tap(find.text('原貌'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('L2 PDF'), findsOneWidget);

    await tester.tap(find.text('对比'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('新旧正文差异'), findsOneWidget);
    expect(find.textContaining('+'), findsWidgets);
    expect(find.textContaining('-'), findsWidgets);
  });

  testWidgets('PDF 仅云端时原貌/对比不可点，给出按需下载提示',
      (WidgetTester tester) async {
    await pumpReader(
      tester,
      archiveMeta: meta(status: ArchiveStatus.text),
      pdfLocal: false,
      hasPrevious: false,
    );
    expect(find.textContaining('归档正文内容'), findsOneWidget);
    expect(find.textContaining('没有 PDF 快照'), findsOneWidget);
  });

  testWidgets('死链状态条明确显示原站已失效',
      (WidgetTester tester) async {
    await pumpReader(
      tester,
      archiveMeta: meta(status: ArchiveStatus.dead),
      pdfLocal: false,
      hasPrevious: false,
      body: null,
    );
    expect(find.textContaining('原站已失效'), findsWidgets);
    expect(find.textContaining('Wayback'), findsWidgets);
  });

  testWidgets('问 AI 选区判定与高亮合并计数接线', (WidgetTester tester) async {
    await pumpReader(tester, archiveMeta: meta(changed: true));
    expect(find.textContaining('高亮合并'), findsOneWidget);
    expect(find.text('问 AI'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'x');
    await tester.tap(find.text('问 AI'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('选区太短'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '这段正文足够长');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('问 AI'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('选区长度合规'), findsOneWidget);
  });

  testWidgets('标注高亮按钮把选区写回真实 kind=5 meta',
      (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    final archiveMeta = meta();
    final created = await app.gateway.writeEntry(EntryWrite.create(
      id: 'reader-a1',
      kind: EntryKind.bookmark,
      title: '测试归档',
      body: '归档正文内容',
      meta: archiveMeta.toJsonString(),
    ));
    final id = created.snapshot.id;
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(
        home: Scaffold(
          body: ArchiveReaderPage(
            entryId: id,
            title: '测试归档',
            meta: archiveMeta,
            archivedAtMs: 1731052800000,
            pdfLocal: true,
            hasPreviousTextVersion: false,
            body: '归档正文内容',
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('标注高亮'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '重点段落');
    await tester.tap(find.text('标注高亮'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('高亮已写回 meta'), findsOneWidget);

    final row = await app.repo.getRow(id);
    final stored = jsonDecode(row!.meta!) as Map<String, Object?>;
    final highlights = stored['highlights'] as List<Object?>;
    expect(highlights, hasLength(1));
  });

  testWidgets('对比模式缺上一版正文时明确说明，不假装能 diff',
      (WidgetTester tester) async {
    await pumpReader(tester, archiveMeta: meta(changed: true));
    await tester.tap(find.text('对比'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('旧版需由历史版本解密后传入'), findsOneWidget);
    expect(find.textContaining('新旧正文差异'), findsNothing);
  });
}
