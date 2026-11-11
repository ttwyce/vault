import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';

/// 密码模块的克制变体（docs/09 §15 / P10）。
///
/// 与手绘风共用纸白底、墨色、楷体与便签黄选中，但去掉「玩具感」：
/// 对称 10px 圆角、1.5px 实线边、0deg 倾斜、无硬偏移阴影；
/// 红色只留给危险/泄露状态，由调用方显式传入 [accent]。
class SecureCard extends StatelessWidget {
  const SecureCard({
    super.key,
    required this.child,
    this.fill,
    this.accent,
    this.padding = const EdgeInsets.all(SketchSpace.md),
  });

  final Widget child;
  final Color? fill;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  static const double radius = 10;
  static const double borderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill ?? p.surface,
        borderRadius: const BorderRadius.all(Radius.circular(radius)),
        border: Border.all(
          color: accent ?? p.lineSoft,
          width: borderWidth,
        ),
      ),
      child: child,
    );
  }
}
