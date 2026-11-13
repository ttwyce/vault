/// 页面里仍用原生控件的表单外壳。
///
/// 主题层已经把 Material 默认蓝色统一掉；这里再给 TextField / DropdownButton
/// 一个统一的 SketchFrame 容器与无下划线装饰，避免各页各写一份硬编码
/// `OutlineInputBorder` / `fontSize`。TextField 本身保留，既有测试的
/// `find.byType(TextField)` 与 `obscureText` 断言不受影响。
library;

import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';
import 'sketch_frame.dart';

class SketchFieldFrame extends StatelessWidget {
  const SketchFieldFrame({
    super.key,
    required this.child,
    this.fill,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(
      horizontal: SketchSpace.md,
      vertical: SketchSpace.xs,
    ),
  });

  final Widget child;
  final Color? fill;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = SketchPalette.of(context);
    return SketchFrame(
      radius: SketchRadii.pill,
      fill: fill ?? p.surface,
      borderColor: borderColor ?? p.lineSoft,
      strokeWidth: SketchStroke.hair,
      padding: padding,
      child: child,
    );
  }
}

/// 统一输入装饰：无 Material 下划线，保留 label / hint 语义。
InputDecoration sketchInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  Widget? suffixIcon,
}) {
  final p = SketchPalette.of(context);
  return InputDecoration(
    isDense: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    labelText: labelText,
    hintText: hintText,
    labelStyle: TextStyle(fontSize: 11.5, color: p.muted),
    hintStyle: TextStyle(fontSize: 11.5, color: p.muted),
    suffixIcon: suffixIcon,
  );
}
