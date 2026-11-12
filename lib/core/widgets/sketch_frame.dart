import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_palette.dart';

/// 手绘风的"纸片"容器：零模糊硬阴影 + 虚线描边 + 非对称圆角 + 轻微倾斜。
///
/// 为什么不直接用 `Container(decoration:)`：
/// `BoxDecoration` 的 `border` 只支持实线，虚线必须自己画；
/// 而硬阴影要画在容器外侧偏移处，也需要绕过裁剪。所以这里用
/// `CustomPaint` 统一画「阴影 → 填充 → 虚线边」，子组件只负责内容。
class SketchFrame extends StatelessWidget {
  const SketchFrame({
    super.key,
    required this.child,
    this.radius = SketchRadii.a,
    this.fill,
    this.borderColor,
    this.shadowColor,
    this.shadowOffset = SketchShadowOffset.card,
    this.strokeWidth = SketchStroke.normal,
    this.padding = const EdgeInsets.all(SketchSpace.md),
    this.tilt = SketchTilt.none,
    this.dash = SketchDash.dash,
    this.gap = SketchDash.gap,
    this.borderless = false,
  });

  final Widget child;
  final BorderRadius radius;
  final Color? fill;
  final Color? borderColor;
  final Color? shadowColor;
  final Offset shadowOffset;
  final double strokeWidth;
  final EdgeInsetsGeometry padding;
  final double tilt;
  final double dash;
  final double gap;

  /// 只画阴影不画虚线边（用于极轻的分组容器）
  final bool borderless;

  @override
  Widget build(BuildContext context) {
    final palette = SketchPalette.of(context);

    // docs/10 §2 ④ / U5：倾斜只作用于「纸片」的绘制层，
    // 正文（child）放在未旋转的上层，永远保持水平。
    final painterLayer = Transform.rotate(
      angle: tilt,
      child: CustomPaint(
        painter: SketchFramePainter(
          radius: radius,
          fill: fill ?? palette.surface,
          borderColor:
              borderless ? Colors.transparent : (borderColor ?? palette.line),
          shadowColor: shadowColor ?? palette.shadow,
          shadowOffset: shadowOffset,
          strokeWidth: strokeWidth,
          dash: dash,
          gap: gap,
        ),
      ),
    );
    final content = Padding(
      // 给阴影留出画布空间，否则会被祖先裁剪。
      padding: EdgeInsets.only(
        right: shadowOffset.dx,
        bottom: shadowOffset.dy,
      ),
      child: Padding(padding: padding, child: child),
    );
    // Positioned.fill 让绘制层拿到与内容相同的尺寸；
    // 旋转只发生在这层，content 保持水平（U5）。
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Positioned.fill(child: painterLayer),
        content,
      ],
    );
  }
}

class SketchFramePainter extends CustomPainter {
  const SketchFramePainter({
    required this.radius,
    required this.fill,
    required this.borderColor,
    required this.shadowColor,
    required this.shadowOffset,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final BorderRadius radius;
  final Color fill;
  final Color borderColor;
  final Color shadowColor;
  final Offset shadowOffset;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inner = Rect.fromLTWH(
      0,
      0,
      math.max(0, size.width - shadowOffset.dx),
      math.max(0, size.height - shadowOffset.dy),
    );
    if (inner.width <= 0 || inner.height <= 0) return;

    final rrect = radius.toRRect(inner);

    // 1. 硬阴影（零模糊）
    if (shadowOffset != Offset.zero && shadowColor.a > 0) {
      canvas.drawRRect(
        rrect.shift(shadowOffset),
        Paint()..color = shadowColor,
      );
    }

    // 2. 填充
    if (fill.a > 0) {
      canvas.drawRRect(rrect, Paint()..color = fill);
    }

    // 3. 虚线描边
    if (borderColor.a > 0) {
      _drawDashedRRect(canvas, rrect);
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect) {
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(SketchFramePainter old) =>
      old.radius != radius ||
      old.fill != fill ||
      old.borderColor != borderColor ||
      old.shadowColor != shadowColor ||
      old.shadowOffset != shadowOffset ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}

/// 卡片：默认表面色 + 虚线边 + 2px 硬阴影。
///
/// `variant` 用来轮换四套圆角，保证相邻卡片不重复（docs/10 §12 U1）。
class SketchCard extends StatelessWidget {
  const SketchCard({
    super.key,
    required this.child,
    this.variant = 0,
    this.fill,
    this.padding = const EdgeInsets.all(SketchSpace.md),
    this.tilt,
    this.shadowOffset = SketchShadowOffset.card,
  });

  final Widget child;
  final int variant;
  final Color? fill;
  final EdgeInsetsGeometry padding;
  final double? tilt;
  final Offset shadowOffset;

  @override
  Widget build(BuildContext context) {
    return SketchFrame(
      radius: SketchRadii.cycle(variant),
      fill: fill,
      padding: padding,
      shadowOffset: shadowOffset,
      tilt: tilt ?? (variant.isEven ? SketchTilt.left : SketchTilt.right),
      child: child,
    );
  }
}

/// 虚线分隔线。
class SketchDivider extends StatelessWidget {
  const SketchDivider({super.key, this.color, this.height = 1});

  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = SketchPalette.of(context);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _DashedLinePainter(color ?? palette.lineSoft),
        size: Size.infinite,
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = SketchStroke.hair
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final end = math.min(x + SketchDash.dash, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += SketchDash.dash + SketchDash.gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
