import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/features/settings/settings_hub_page.dart';
import 'package:vault/features/settings/sync_settings_page.dart';

import 'support/test_harness.dart';

/// docs/10 第 12 屏 同步设置页测试。
void main() {
  testWidgets('合法输入也停在 A5 闸门，不显示可启动状态',
      (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: SyncSettingsPage()),
    ));
    await tester.enterText(
      find.widgetWithText(TextField, 'WebDAV 地址（https）'),
      'https://dav.example.com/vault/',
    );
    await tester.enterText(
        find.widgetWithText(TextField, '账号'), 'user');
    await tester.enterText(
        find.widgetWithText(TextField, '应用密码'), 'app-pass');
    await tester.tap(find.text('校验配置'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('needsA5'), findsOneWidget);
    expect(find.text('https://dav.example.com/vault'), findsWidgets);
    expect(find.textContaining('不启动同步'), findsWidgets);
    expect(find.textContaining('不会写入本地库'), findsOneWidget);
  });

  testWidgets('非法 URL 给出全部错误，不出现 A5 提示',
      (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: SyncSettingsPage()),
    ));
    await tester.tap(find.text('校验配置'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('invalid'), findsOneWidget);
    expect(find.textContaining('https'), findsWidgets);
    expect(find.text('needsA5'), findsNothing);
  });

  testWidgets('设置中心有同步设置入口', (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: SettingsHubPage()),
    ));
    expect(find.text('同步设置'), findsOneWidget);
  });
}
