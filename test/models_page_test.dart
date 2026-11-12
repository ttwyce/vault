import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/features/settings/models_page.dart';
import 'package:vault/features/settings/settings_hub_page.dart';

import 'support/test_harness.dart';

/// docs/10 第 18 屏 / docs/06 §7 模型管理页测试。
void main() {
  testWidgets('模型页展示清单/源优先级/降级提示，不假装有下载进度',
      (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: ModelsPage()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('模型管理'), findsOneWidget);
    expect(find.textContaining('下载模型可启用语义搜索'), findsOneWidget);
    expect(find.textContaining('默认模型清单'), findsOneWidget);
    expect(find.textContaining('下载源优先级'), findsOneWidget);
    expect(find.textContaining('modelScope'), findsOneWidget);
    expect(find.textContaining('真实下载按装配层注入'), findsOneWidget);
  });

  testWidgets('设置中心有模型管理入口', (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: SettingsHubPage()),
    ));
    expect(find.text('模型管理'), findsOneWidget);
    await tester.tap(find.text('模型管理'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('默认模型清单'), findsOneWidget);
  });

  testWidgets('下载弹窗无下载源时诚实拒绝，不假装下载',
      (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: ModelsPage()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('下载首个模型'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('开始'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('未装配下载器'), findsOneWidget);
  });
}
