import 'package:flutter/widgets.dart';

/// 把「打开设置」这类全局动作从外壳往下传，避免 core/widgets 反向依赖 features。
///
/// 页面骨架 [PageScaffold] 通过它拿到设置入口；没有外壳包裹时（单独测某个页面）
/// 自动不显示齿轮，不需要额外分支。
class AppActions extends InheritedWidget {
  const AppActions({
    super.key,
    required this.openSettings,
    required super.child,
  });

  final VoidCallback openSettings;

  static AppActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppActions>();

  @override
  bool updateShouldNotify(AppActions oldWidget) =>
      oldWidget.openSettings != openSettings;
}
