// =============================================================================
// BuildContext 快捷访问
//
// 目标：让业务代码读起来像设计稿。
//   context.colors.surface / context.text.h3 / 16.vGap / context.isCompact
// =============================================================================

import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';
import 'tokens.dart';

extension AppThemeContext on BuildContext {
  /// 语义色（必须在 AppTheme 下使用，否则抛错以便尽早发现问题）
  AppSemanticColors get colors {
    final ext = Theme.of(this).extension<AppSemanticColors>();
    assert(ext != null, 'AppSemanticColors 未注册，请使用 AppTheme.light / AppTheme.dark');
    return ext!;
  }

  TextTheme get text => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// 当前断点（基于窗口宽度，桌面可拖拽缩放）
  AppBreakpoint get breakpoint => AppBreakpoints.of(MediaQuery.sizeOf(this).width);

  bool get isCompact => breakpoint.isCompact;
  bool get isMultiPane => breakpoint.isMultiPane;

  /// 移动端用 44px 触控高度，桌面用 36px
  double get controlHeight => breakpoint.isTouch
      ? AppSizes.controlHeightTouch
      : AppSizes.controlHeightDesktop;

  EdgeInsets get panelPadding =>
      EdgeInsets.all(breakpoint.isCompact ? AppSpacing.lg : AppSpacing.panelPadding);

  /// 尊重系统「减少动效」设置
  Duration motion(Duration d) => AppMotion.respect(this, d);
}

extension AppGap on num {
  /// 纵向间距
  SizedBox get vGap => SizedBox(height: toDouble());

  /// 横向间距
  SizedBox get hGap => SizedBox(width: toDouble());
}

/// 常用装饰器，避免到处写 BoxDecoration
extension AppDecorations on BuildContext {
  /// 一级表面（卡片 / 列表）
  BoxDecoration get surfaceCard => BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.mdR,
        border: Border.all(color: colors.border),
      );

  /// 二级表面（浮层）
  BoxDecoration get raisedCard => BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: AppRadius.mdR,
        border: Border.all(color: colors.border),
        boxShadow: colors.shadow,
      );

  /// 凹陷（代码块 / 内嵌输入）
  BoxDecoration get sunkenPanel => BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: AppRadius.mdR,
      );

  /// AI 引用卡
  BoxDecoration get aiCard => BoxDecoration(
        color: colors.aiSoft,
        borderRadius: AppRadius.mdR,
        border: Border.all(color: colors.ai.withValues(alpha: 0.2)),
      );

  /// 焦点环（键盘导航）
  BoxDecoration focusRingDecoration({BorderRadius? radius}) => BoxDecoration(
        borderRadius: radius ?? AppRadius.smR,
        border: Border.all(color: colors.focusRing, width: 2),
      );
}
