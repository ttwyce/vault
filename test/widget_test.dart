import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/shell/app_shell.dart';
import 'package:vault/app/theme/sketch_theme.dart';

import 'support/test_harness.dart';

/// 外壳的渲染测试。
///
/// 不直接 pump `VaultApp`：它依赖 `fontServiceProvider`，而 `FontService.boot()`
/// 需要 path_provider 平台通道，单测里没有。这里用默认手写主题包一层，
/// 验证的仍然是「外壳 + 五个分区」这条真实路径。
///
/// **必须挂在 TestApp 的 container 下**：M1 时代五个分区都是占位页，
/// 裸 `ProviderScope` 能跑；M2 接了真仓库之后，RecordsPage / DiaryPage
/// 会一路读到 `vaultBootstrapProvider` —— 那个 provider 在测试里故意抛
/// `UnimplementedError`，于是页面崩、provider 进入 error state，
/// 后续所有测试都被污染。用 `UncontrolledProviderScope` 注入内存库即可。
Widget _harness(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: SketchTheme.light, home: const AppShell()),
    );

const List<String> _sections = <String>['聊天', '记录', '日记', '归档', '密码'];

void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
  });

  tearDown(() async {
    await app.dispose();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(_harness(app.container));
    // 不用 pumpAndSettle：列表的加载圈是无限动画，会一直触发重绘。
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('移动端底部导航渲染五个分区', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpShell(tester);

    for (final label in _sections) {
      expect(find.text(label), findsWidgets, reason: '缺少分区：$label');
    }
  });

  testWidgets('桌面端侧栏渲染五个分区入口', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpShell(tester);

    // 侧栏是纯图标 + Tooltip，文字只在悬停时出现，所以按 tooltip 匹配
    for (final label in _sections) {
      expect(find.byTooltip(label), findsWidgets, reason: '缺少分区入口：$label');
    }
  });

  testWidgets('桌面 Ctrl+Tab 循环切换分区', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpShell(tester);

    // 默认在「聊天」；Ctrl+Tab 应切到「记录」。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('还没有内容，点右上角新建'), findsWidgets,
        reason: 'Ctrl+Tab 后应切到记录页');
  });
}
