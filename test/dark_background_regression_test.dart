import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_palette.dart';
import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/features/archive/archive_reader_page.dart';
import 'package:vault/features/settings/about_page.dart';
import 'package:vault/features/settings/diagnostics_page.dart';
import 'package:vault/features/settings/export_backup_page.dart';

import 'support/test_harness.dart';

/// 裸 PageScaffold 页在暗主题下必须自带背景，不能露出黑底。
void main() {
  late TestApp app;
  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(theme: SketchTheme.dark, home: page),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  void expectDarkBackground(WidgetTester tester) {
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, SketchPalette.dark.bg);
  }

  testWidgets('关于与隐私页暗色背景', (WidgetTester tester) async {
    await pumpPage(tester, const AboutPage());
    expectDarkBackground(tester);
  });

  testWidgets('诊断与备份页暗色背景', (WidgetTester tester) async {
    await pumpPage(tester, const DiagnosticsPage());
    expectDarkBackground(tester);
  });

  testWidgets('导出与备份页暗色背景', (WidgetTester tester) async {
    await pumpPage(tester, const ExportBackupPage());
    expectDarkBackground(tester);
  });

  testWidgets('归档阅读页暗色背景', (WidgetTester tester) async {
    await pumpPage(
      tester,
      ArchiveReaderPage(
        entryId: 'a',
        title: '归档',
        meta: ArchiveMeta(
          url: 'https://example.com',
          site: 'example.com',
          status: ArchiveStatus.text,
        ),
        archivedAtMs: 0,
        pdfLocal: false,
        hasPreviousTextVersion: false,
        body: '正文',
      ),
    );
    expectDarkBackground(tester);
  });
}
