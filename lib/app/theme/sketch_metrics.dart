import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 间距：4px 基准，但比常规 UI 更松（手写体视觉重量轻）。
abstract final class SketchSpace {
  const SketchSpace._();

  static const double xs = 4;
  static const double sm = 7;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double xxl = 30;
}

/// 非对称圆角：每个角的水平/垂直半径都不同。
///
/// 这是手绘风的第一根支柱 —— 缺了它，其余规则加起来还是像模板。
/// 数值与 docs/10 §2① 的四套配方一一对应，相邻卡片必须轮换使用。
abstract final class SketchRadii {
  const SketchRadii._();

  // 18 26 16 28 / 26 16 30 18
  static const BorderRadius a = BorderRadius.only(
    topLeft: Radius.elliptical(18, 26),
    topRight: Radius.elliptical(26, 16),
    bottomRight: Radius.elliptical(16, 30),
    bottomLeft: Radius.elliptical(28, 18),
  );

  // 26 16 28 18 / 16 28 18 26
  static const BorderRadius b = BorderRadius.only(
    topLeft: Radius.elliptical(26, 16),
    topRight: Radius.elliptical(16, 28),
    bottomRight: Radius.elliptical(28, 18),
    bottomLeft: Radius.elliptical(18, 26),
  );

  // 14 20 16 22 / 20 14 24 16
  static const BorderRadius c = BorderRadius.only(
    topLeft: Radius.elliptical(14, 20),
    topRight: Radius.elliptical(20, 14),
    bottomRight: Radius.elliptical(16, 24),
    bottomLeft: Radius.elliptical(22, 16),
  );

  // 22 14 20 16 / 14 22 16 20
  static const BorderRadius d = BorderRadius.only(
    topLeft: Radius.elliptical(22, 14),
    topRight: Radius.elliptical(14, 22),
    bottomRight: Radius.elliptical(20, 16),
    bottomLeft: Radius.elliptical(16, 20),
  );

  /// 药丸 / 徽章：12 16 12 18 / 16 12 18 12
  static const BorderRadius pill = BorderRadius.only(
    topLeft: Radius.elliptical(12, 16),
    topRight: Radius.elliptical(16, 12),
    bottomRight: Radius.elliptical(12, 18),
    bottomLeft: Radius.elliptical(18, 12),
  );

  /// 抽屉：0 22 20 0 / 0 20 22 0
  static const BorderRadius drawerRight = BorderRadius.only(
    topRight: Radius.elliptical(22, 20),
    bottomRight: Radius.elliptical(20, 22),
  );

  static const List<BorderRadius> sets = [a, b, c, d];

  /// 按索引取一套，保证相邻元素不重复（见 docs/10 §12 U1）
  static BorderRadius cycle(int index) => sets[index % sets.length];
}

/// 零模糊硬阴影。
abstract final class SketchShadowOffset {
  const SketchShadowOffset._();

  static const Offset card = Offset(2, 2);
  static const Offset button = Offset(3, 3);
  static const Offset panel = Offset(4, 4);
  static const Offset floating = Offset(6, 6);
  static const Offset none = Offset.zero;
}

/// 倾斜角度（弧度）。1 度 ≈ 0.01745。
abstract final class SketchTilt {
  const SketchTilt._();

  static const double none = 0;

  /// -0.4deg
  static const double left = -0.007;
  static const double leftStrong = -0.012;
  static const double right = 0.007;
  static const double rightStrong = 0.012;

  /// 选中项比容器再歪一点，制造"手贴上去"的错位感
  static const double selected = -0.014;

  static double deg(double degrees) => degrees * math.pi / 180;
}

/// 描边宽度。
abstract final class SketchStroke {
  const SketchStroke._();

  static const double hair = 1.5;
  static const double normal = 2;
  static const double icon = 1.8;
}

/// 虚线节奏。
abstract final class SketchDash {
  const SketchDash._();

  static const double dash = 6;
  static const double gap = 4;
}

/// 动效时长。
abstract final class SketchMotion {
  const SketchMotion._();

  static const Duration hover = Duration(milliseconds: 120);
  static const Duration press = Duration(milliseconds: 120);
  static const Duration drawer = Duration(milliseconds: 280);
  static const Duration page = Duration(milliseconds: 200);

  static const Curve ease = Curves.easeOutCubic;
  static const Curve drawerCurve = Cubic(0.22, 1, 0.36, 1);

  /// 尊重系统「减少动效」
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

/// 断点。
enum SketchBreakpoint { compact, medium, expanded }

abstract final class SketchBreakpoints {
  const SketchBreakpoints._();

  static const double mediumMin = 600;
  static const double expandedMin = 840;

  static SketchBreakpoint of(double width) {
    if (width < mediumMin) return SketchBreakpoint.compact;
    if (width < expandedMin) return SketchBreakpoint.medium;
    return SketchBreakpoint.expanded;
  }
}

extension SketchBreakpointX on SketchBreakpoint {
  bool get isCompact => this == SketchBreakpoint.compact;

  /// 桌面侧栏（rail）在 expanded 才出现，其余用底部导航
  bool get useRail => this == SketchBreakpoint.expanded;
}
