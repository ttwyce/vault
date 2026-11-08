// =============================================================================
// 语义色 ThemeExtension
//
// 为什么需要它：ColorScheme 只有 30 来个槽位，表达不了「三级表面 + 同步状态 +
// AI 专用色 + 焦点环」这些本产品必需的语义。用 ThemeExtension 承载，
// 业务代码通过 `context.colors.xxx` 访问，换肤时只改这里。
// =============================================================================

import 'package:flutter/material.dart';

import 'tokens.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.accentSoft,
    required this.onAccent,
    required this.ai,
    required this.aiSoft,
    required this.onAi,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.focusRing,
    required this.overlay,
    required this.shadow,
    required this.isDark,
  });

  /// 页面底色
  final Color canvas;

  /// 一级表面：卡片、列表、编辑器
  final Color surface;

  /// 二级表面：浮层、下拉、悬浮卡
  final Color surfaceRaised;

  /// 凹陷表面：代码块、搜索框、侧栏
  final Color surfaceSunken;

  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color accent;
  final Color accentHover;
  final Color accentPressed;

  /// 选中行背景、标签底
  final Color accentSoft;
  final Color onAccent;

  /// AI 生成内容专用（徽章、引用卡、Agent 对话）
  final Color ai;
  final Color aiSoft;
  final Color onAi;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  /// 焦点环（键盘导航）
  final Color focusRing;

  /// 遮罩
  final Color overlay;

  /// 浮层阴影；暗色模式为空
  final List<BoxShadow> shadow;

  final bool isDark;

  // ---- 亮色 ----
  static const AppSemanticColors light = AppSemanticColors(
    canvas: AppPalette.neutral50,
    surface: AppPalette.neutral0,
    surfaceRaised: AppPalette.neutral0,
    surfaceSunken: AppPalette.neutral100,
    border: AppPalette.neutral200,
    borderStrong: AppPalette.neutral300,
    textPrimary: AppPalette.neutral900,
    textSecondary: AppPalette.neutral600,
    textTertiary: AppPalette.neutral500,
    accent: AppPalette.teal700,
    accentHover: AppPalette.teal800,
    accentPressed: AppPalette.teal900,
    accentSoft: AppPalette.teal50,
    onAccent: AppPalette.neutral0,
    ai: AppPalette.violet600,
    aiSoft: AppPalette.violet50,
    onAi: AppPalette.neutral0,
    success: AppPalette.green600,
    successSoft: AppPalette.green50,
    warning: AppPalette.amber700,
    warningSoft: AppPalette.amber50,
    danger: AppPalette.red700,
    dangerSoft: AppPalette.red50,
    focusRing: Color(0x730F766E), // teal700 @ 45%
    overlay: Color(0x661C1917), // neutral900 @ 40%
    shadow: AppElevation.modal,
    isDark: false,
  );

  // ---- 暗色 ----
  static const AppSemanticColors dark = AppSemanticColors(
    canvas: AppPalette.neutral950,
    surface: AppPalette.darkSurface,
    surfaceRaised: AppPalette.darkSurfaceRaised,
    surfaceSunken: AppPalette.darkSurfaceSunken,
    border: AppPalette.darkBorder,
    borderStrong: AppPalette.darkBorderStrong,
    textPrimary: AppPalette.neutral100,
    textSecondary: AppPalette.neutral400,
    textTertiary: AppPalette.neutral500,
    accent: AppPalette.teal400,
    accentHover: AppPalette.teal300,
    accentPressed: AppPalette.teal100,
    accentSoft: Color(0x1F2DD4BF), // teal400 @ 12%
    onAccent: Color(0xFF062F2B),
    ai: AppPalette.violet400,
    aiSoft: Color(0x24A78BFA), // violet400 @ 14%
    onAi: Color(0xFF1B1035),
    success: AppPalette.green400,
    successSoft: Color(0x1F4ADE80),
    warning: AppPalette.amber400,
    warningSoft: Color(0x1FFBBF24),
    danger: AppPalette.red400,
    dangerSoft: Color(0x1FF87171),
    focusRing: Color(0x802DD4BF), // teal400 @ 50%
    overlay: Color(0x99100E0D), // 60% 近黑
    shadow: AppElevation.none, // 暗色不用阴影，靠背景提亮 + 描边
    isDark: true,
  );

  @override
  AppSemanticColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentHover,
    Color? accentPressed,
    Color? accentSoft,
    Color? onAccent,
    Color? ai,
    Color? aiSoft,
    Color? onAi,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? focusRing,
    Color? overlay,
    List<BoxShadow>? shadow,
    bool? isDark,
  }) {
    return AppSemanticColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentPressed: accentPressed ?? this.accentPressed,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      ai: ai ?? this.ai,
      aiSoft: aiSoft ?? this.aiSoft,
      onAi: onAi ?? this.onAi,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      focusRing: focusRing ?? this.focusRing,
      overlay: overlay ?? this.overlay,
      shadow: shadow ?? this.shadow,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentPressed: c(accentPressed, other.accentPressed),
      accentSoft: c(accentSoft, other.accentSoft),
      onAccent: c(onAccent, other.onAccent),
      ai: c(ai, other.ai),
      aiSoft: c(aiSoft, other.aiSoft),
      onAi: c(onAi, other.onAi),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      focusRing: c(focusRing, other.focusRing),
      overlay: c(overlay, other.overlay),
      shadow: t < 0.5 ? shadow : other.shadow,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}
