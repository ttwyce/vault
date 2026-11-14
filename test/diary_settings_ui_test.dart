import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/features/diary/diary_page.dart';
import 'package:vault/features/settings/settings_hub_page.dart';

import 'support/test_harness.dart';

/// 日记页窄屏菜单与设置中心分组。
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
      child: MaterialApp(
        theme: SketchTheme.light,
        home: Scaffold(backgroundColor: SketchTheme.light.scaffoldBackgroundColor, body: page),
      ),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('日记页顶部只保留补写与更多菜单，不挤爆横向宽度',
      (WidgetTester tester) async {
    await pumpPage(tester, DiaryPage(initialMonth: DateTime(2026, 11)));
    expect(find.text('补写'), findsOneWidget);
    expect(find.byTooltip('更多日记操作'), findsOneWidget);
    expect(find.text('年度回顾'), findsNothing);
    expect(find.text('生成 AI 日记'), findsNothing);
    await tester.tap(find.byTooltip('更多日记操作'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('年度回顾'), findsOneWidget);
    expect(find.text('模板：自由记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置中心按类别分组显示标题与入口', (WidgetTester tester) async {
    await pumpPage(tester, const SettingsHubPage());
    for (final section in <String>[
      '外观与内容',
      '检索与 AI',
      '数据与备份',
      '安全与系统',
    ]) {
      expect(find.text(section), findsOneWidget);
    }
    expect(find.text('安全设置'), findsOneWidget);
    expect(find.text('模型下载源'), findsOneWidget);
    expect(find.text('关于与隐私'), findsOneWidget);
  });
}
