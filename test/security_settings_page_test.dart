import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/features/settings/security_settings_page.dart';

import 'support/test_harness.dart';

/// 安全设置页的二次确认闸门与表单接线。
void main() {
  testWidgets('未勾选确认时改主密码与重置恢复码都被拦住',
      (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(
        theme: SketchTheme.light,
        home: const SecuritySettingsPage(),
      ),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('改主密码'), findsOneWidget);
    expect(find.text('重置恢复码'), findsOneWidget);
    expect(find.text('未确认'), findsNWidgets(2));
    await tester.tap(find.text('更新主密码'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('请先勾选二次确认'), findsOneWidget);

    await tester.tap(find.text('生成新恢复码'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('请先勾选'), findsOneWidget);

    // 勾选后闸门放行：不再显示「请先勾选」。
    await tester.tap(find.text('未确认').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('已确认'), findsOneWidget);
    await tester.tap(find.text('更新主密码'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('请先勾选'), findsNothing);
  });
}
