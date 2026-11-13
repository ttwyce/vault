import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/shell/app_shell.dart';
import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/features/settings/settings_hub_page.dart';

import 'support/test_harness.dart';

/// 单一设置入口：外壳有齿轮，五个 tab 页不再各自挂齿轮。
void main() {
  late TestApp app;
  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(theme: SketchTheme.light, home: page),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('外壳有且只有一个设置齿轮，tab 页不再重复显示',
      (WidgetTester tester) async {
    await pumpPage(tester, const AppShell());
    // 移动底栏末尾的齿轮；桌面 rail 的同款按钮不在当前断点渲染。
    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.byTooltip('设置 · 字体'), findsNothing);
  });

  testWidgets('设置中心包含安全设置与云端模型入口',
      (WidgetTester tester) async {
    await pumpPage(tester, const SettingsHubPage());
    expect(find.text('安全设置'), findsOneWidget);
    expect(find.text('云端模型'), findsOneWidget);
    // 设置页本身不再显示旧的「设置 · 字体」齿轮。
    expect(find.byTooltip('设置 · 字体'), findsNothing);
  });
}
