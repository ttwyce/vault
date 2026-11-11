import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/features/settings/about_page.dart';
import 'package:vault/features/settings/settings_hub_page.dart';

/// docs/09 §10 上架材料：关于与隐私声明必须在 App 内可读。
void main() {
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('关于页展示零后端 / 加密 / 密码 AI / 无遥测 / 许可 / 恢复码',
      (WidgetTester tester) async {
    await pumpPage(tester, const AboutPage());
    for (final title in <String>[
      '数据在你手里',
      '端到端加密',
      '密码与 AI',
      '无遥测',
      '开源许可',
      '恢复码',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('SIL OFL 1.1'), findsWidgets);
    expect(find.textContaining('Gemma Terms'), findsWidgets);
  });

  testWidgets('设置中心有关于与隐私入口', (WidgetTester tester) async {
    await pumpPage(tester, const SettingsHubPage());
    expect(find.text('关于与隐私'), findsOneWidget);
    await tester.tap(find.text('关于与隐私'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('端到端加密'), findsOneWidget);
  });
}
