/// 统一的页面 / 对话框过渡（docs/10 §9）。
///
/// 页面切换 220ms ease-out-cubic：淡入 + 2% 纵向位移；
/// 对话框 200ms 淡入 + 4% 缩放。系统开启「减少动效」时都退化为零，
/// 且位移用 Transform 表达，不产生布局位移。禁止回弹与循环动画。
library;

import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';

final Duration _pageDuration = const Duration(milliseconds: 220);
final Duration _dialogDuration = const Duration(milliseconds: 200);

Widget sketchPageTransition(
  BuildContext context,
  Animation<double> animation,
  Widget child,
) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
  final curved = CurvedAnimation(
    parent: animation,
    curve: SketchMotion.ease,
    reverseCurve: SketchMotion.ease,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.02),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

class SketchPageTransitionsBuilder extends PageTransitionsBuilder {
  const SketchPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      sketchPageTransition(context, animation, child);
}

/// 所有平台共用的过渡主题；覆盖 Flutter 默认路由（包括未被
/// `sketchPageRoute` 包裹的 MaterialPageRoute）。
const PageTransitionsTheme kSketchPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: SketchPageTransitionsBuilder(),
    TargetPlatform.iOS: SketchPageTransitionsBuilder(),
    TargetPlatform.windows: SketchPageTransitionsBuilder(),
    TargetPlatform.macOS: SketchPageTransitionsBuilder(),
    TargetPlatform.linux: SketchPageTransitionsBuilder(),
    TargetPlatform.fuchsia: SketchPageTransitionsBuilder(),
  },
);

Route<T> sketchPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: _pageDuration,
    reverseTransitionDuration: _pageDuration,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondary,
      Widget child,
    ) =>
        sketchPageTransition(context, animation, child),
  );
}

Future<T?> showSketchDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.45),
    transitionDuration: _dialogDuration,
    // ignore: unnecessary_underscores
    pageBuilder: (BuildContext _, __, ___) => builder(context),
    transitionBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondary,
      Widget child,
    ) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: SketchMotion.ease,
        reverseCurve: SketchMotion.ease,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
