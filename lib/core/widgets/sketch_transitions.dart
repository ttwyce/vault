/// 统一的页面 / 对话框过渡（docs/10 §9）。
///
/// 页面切换 200ms ease-out-cubic：淡入 + 2% 纵向位移，反向 pop 对称回放；
/// 对话框 120ms 淡入。系统开启「减少动效」时两者都退化为 Duration.zero，
/// 且位移用 Transform 表达，不产生布局位移。禁止弹性回弹与循环动画。
library;

import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';

final Duration _pageDuration = SketchMotion.page;
final Duration _dialogDuration = SketchMotion.hover;

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
    },
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
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: SketchMotion.ease,
          reverseCurve: SketchMotion.ease,
        ),
        child: child,
      );
    },
  );
}
