import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/shell/app_shell.dart';
import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/core/widgets/sketch_controls.dart';
import 'package:vault/features/editor/editor_page.dart';
import 'package:vault/features/settings/settings_hub_page.dart';

import 'support/test_harness.dart';

/// 本轮 UI 修复的回归：状态栏避让 + 底栏 / FAB 不互相遮挡。
void main() {
  late TestApp app;
  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> pumpPage(WidgetTester tester, Widget page,
      {double topPadding = 0}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding(top: topPadding, bottom: 0);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(theme: SketchTheme.light, home: page),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('PageScaffold 顶部避开状态栏：设置页标题下移',
      (WidgetTester tester) async {
    const top = 47.0;
    await pumpPage(tester, const SettingsHubPage(), topPadding: top);
    expect(tester.getTopLeft(find.text('设置')).dy,
        greaterThanOrEqualTo(top));
  });

  testWidgets('PageScaffold 顶部避开状态栏：编辑页标题下移',
      (WidgetTester tester) async {
    const top = 47.0;
    await pumpPage(tester, const EditorPage(), topPadding: top);
    expect(tester.getTopLeft(find.text('新建笔记')).dy,
        greaterThanOrEqualTo(top));
  });

  testWidgets('移动端不再渲染无效快速记录按钮', (WidgetTester tester) async {
    await pumpPage(tester, const AppShell());
    expect(find.widgetWithText(SketchButton, '快速记录'), findsNothing);
    expect(find.text('密码'), findsWidgets);
  });
}
