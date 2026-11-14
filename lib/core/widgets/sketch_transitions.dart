/// 统一的页面 / 对话框过渡（docs/10 §9）。
///
/// 页面切换 220ms ease-out-cubic：淡入 + 2% 纵向位移；
/// 对话框 200ms 淡入 + 4% 缩放。系统开启「减少动效」时都退化为零，
/// 且位移用 Transform 表达，不产生布局位移。禁止回弹与循环动画。
library;

import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';

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
    pageBuilder: (BuildContext _, __, ___) => _SketchDialogTheme(
          parent: Theme.of(context),
          child: Builder(builder: (BuildContext inner) => builder(inner)),
        ),
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

/// 对话框局部主题：不碰全局 ThemeData，只给 showSketchDialog 里的
/// TextField / 按钮 / ListTile 补回手绘边框，避免「只有最外层有框」。
class _SketchDialogTheme extends StatelessWidget {
  const _SketchDialogTheme({required this.parent, required this.child});

  final ThemeData parent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = SketchPalette.of(context);
    // OutlineInputBorder 只接受圆形 BorderRadius，不能用 SketchRadii.pill
    // 的椭圆半径（会在 paint 阶段断言失败）。
    final border = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: p.line, width: SketchStroke.hair),
    );
    final focused = border.copyWith(
      borderSide: BorderSide(color: p.red, width: SketchStroke.normal),
    );
    final buttonStyle = ButtonStyle(
      side: WidgetStateProperty.all<BorderSide>(
          BorderSide(color: p.line, width: SketchStroke.hair)),
      shape: WidgetStateProperty.all<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: SketchRadii.pill)),
      foregroundColor: WidgetStateProperty.all<Color>(p.ink),
      backgroundColor: WidgetStateProperty.all<Color>(p.surface),
      padding: WidgetStateProperty.all<EdgeInsets>(
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
    );
    return Theme(
      data: parent.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: p.surface,
          border: border,
          enabledBorder: border,
          focusedBorder: focused,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SketchSpace.md,
            vertical: SketchSpace.sm,
          ),
          hintStyle: TextStyle(color: p.muted, fontSize: 11.5),
        ),
        textButtonTheme: TextButtonThemeData(style: buttonStyle),
        outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
        elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
        dialogTheme: parent.dialogTheme.copyWith(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: SketchRadii.b,
            side: BorderSide(color: p.line, width: SketchStroke.normal),
          ),
        ),
      ),
      child: child,
    );
  }
}
