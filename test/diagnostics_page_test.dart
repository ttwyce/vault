import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/features/settings/diagnostics_page.dart';
import 'package:vault/features/settings/settings_hub_page.dart';

import 'support/test_harness.dart';

/// 设置中心「诊断与备份」入口与自检页测试。
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(home: Scaffold(body: page)),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('诊断页展示九项自检与加密备份 manifest',
      (WidgetTester tester) async {
    await pumpPage(tester, const DiagnosticsPage());
    expect(find.textContaining('自检有未通过项'), findsWidgets);
    expect(find.text('A1 · 日志 / prompt 明文零泄露'), findsOneWidget);
    expect(find.text('A6 · secret 自定义字段整体脱敏'), findsOneWidget);
    expect(find.textContaining('加密备份包'), findsOneWidget);
    expect(find.textContaining('/backup/'), findsWidgets);
    expect(find.textContaining('vault-local'), findsWidgets);
    expect(find.textContaining('不替代真实服务器集成用例'), findsWidgets);
    expect(find.text('向量模型下载与索引重建'), findsOneWidget);
    expect(find.textContaining('17 个 Agent 工具'), findsWidgets);
    expect(find.text('三端能力缺口（docs/08）'), findsOneWidget);
    expect(find.text('性能基线（5000 条 / 真机）'), findsOneWidget);
    expect(find.text('演示死链重检查判定'), findsOneWidget);
    expect(find.textContaining('A7'), findsWidgets);
    expect(find.textContaining('A9'), findsWidgets);
    expect(find.textContaining('源优先级'), findsOneWidget);
  });

  testWidgets('设置中心有诊断与备份入口并可进入',
      (WidgetTester tester) async {
    await pumpPage(tester, const SettingsHubPage());
    expect(find.text('诊断与备份'), findsOneWidget);
    await tester.tap(find.text('诊断与备份'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('诊断与备份'), findsWidgets);
    expect(find.textContaining('自检有未通过项'), findsWidgets);
  });
}
