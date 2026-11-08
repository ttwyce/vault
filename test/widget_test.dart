import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/shell/app_shell.dart';
import 'package:vault/app/theme/sketch_theme.dart';

/// 外壳的渲染测试。
///
/// 不直接 pump `VaultApp`：它依赖 `fontServiceProvider`，而 `FontService.boot()`
/// 需要 path_provider 平台通道，单测里没有。这里用默认手写主题包一层，
/// 验证的仍然是「外壳 + 五个分区」这条真实路径。
Widget _harness() => ProviderScope(
      child: MaterialApp(theme: SketchTheme.light, home: const AppShell()),
    );

const List<String> _sections = <String>['聊天', '记录', '日记', '归档', '密码'];

void main() {
  testWidgets('移动端底部导航渲染五个分区', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    for (final label in _sections) {
      expect(find.text(label), findsWidgets, reason: '缺少分区：$label');
    }
  });

  testWidgets('桌面端侧栏渲染五个分区入口', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // 侧栏是纯图标 + Tooltip，文字只在悬停时出现，所以按 tooltip 匹配
    for (final label in _sections) {
      expect(find.byTooltip(label), findsWidgets, reason: '缺少分区入口：$label');
    }
  });
}
