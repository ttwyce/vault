import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/shell/app_shell.dart';
import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/core/widgets/sketch_transitions.dart';

import 'support/test_harness.dart';

/// 对话框局部样式与底部 tab 反馈。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('showSketchDialog 内部 TextField 与按钮都带 Sketch 边框',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: SketchTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showSketchDialog<void>(
              context: context,
              builder: (BuildContext dialogContext) => AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const TextField(),
                    TextButton(onPressed: () {}, child: const Text('取消')),
                  ],
                ),
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    final inputs = tester.widgetList<TextField>(find.byType(TextField));
    expect(inputs, isNotEmpty);
    expect(
      inputs.first.decoration?.enabledBorder,
      isNot(InputBorder.none),
    );
    final inner = tester.element(find.byType(TextField));
    final dialogTheme = Theme.of(inner);
    expect(dialogTheme.textButtonTheme.style?.side
        ?.resolve(<WidgetState>{}), isNotNull);
    expect(dialogTheme.outlinedButtonTheme.style?.side
        ?.resolve(<WidgetState>{}), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell 底部 tab 有按压反馈与切换动画', (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(theme: SketchTheme.light, home: const AppShell()),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AnimatedSwitcher), findsWidgets);
    final gesture = await tester.startGesture(
        tester.getCenter(find.text('日记').last));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
