import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/features/archive/archive_reader_page.dart';

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
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('full + 本地 PDF + 旧版：三个模式可点，纯净默认渲染正文',
      (WidgetTester tester) async {
    await pumpReader(tester, archiveMeta: meta(changed: true));
    expect(find.text('归档正文内容'), findsOneWidget);
    expect(find.textContaining('归档于'), findsOneWidget);
    expect(find.textContaining('原站存活'), findsOneWidget);

    await tester.tap(find.text('原貌'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('L2 PDF'), findsOneWidget);

    await tester.tap(find.text('对比'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('并排差异'), findsOneWidget);
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
}
