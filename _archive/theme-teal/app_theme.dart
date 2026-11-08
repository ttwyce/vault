// =============================================================================
// 主题装配
//
// 设计原则落地：
//   1. 边框优先于阴影 —— elevation 全部为 0，层级靠 border + 背景明度差
//   2. 一个强调色 —— 紫只出现在 AI 场景
//   3. 圆角克制 —— 控件 6 / 卡片 10 / 面板 14 / 弹层 20
//   4. 动效只解释因果 —— 组件级 transitionDuration 统一 120~200ms
// =============================================================================

import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';
import 'tokens.dart';

abstract final class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(AppSemanticColors.light, Brightness.light);

  static ThemeData get dark => _build(AppSemanticColors.dark, Brightness.dark);

  static ThemeData _build(AppSemanticColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accent,
      secondary: c.ai,
      onSecondary: c.onAi,
      secondaryContainer: c.aiSoft,
      onSecondaryContainer: c.ai,
      error: c.danger,
      onError: brightness == Brightness.light ? Colors.white : const Color(0xFF2A0A0A),
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerLowest: c.canvas,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surfaceSunken,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      onSurfaceVariant: c.textSecondary,
      outline: c.borderStrong,
      outlineVariant: c.border,
      shadow: const Color(0x1A1C1917),
      scrim: c.overlay,
      inverseSurface: brightness == Brightness.light
          ? AppPalette.neutral900
          : AppPalette.neutral100,
      onInverseSurface: brightness == Brightness.light
          ? AppPalette.neutral100
          : AppPalette.neutral900,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      dividerColor: c.border,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: _textTheme(c),
      primaryTextTheme: _textTheme(c),
      applyElevationOverlayColor: false,

      // ---------- 应用栏：无阴影、滚动不染色 ----------
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.lg,
        toolbarHeight: AppSizes.topBar,
        titleTextStyle: AppTypeScale.h3.copyWith(color: c.textPrimary),
        iconTheme: IconThemeData(color: c.textSecondary, size: AppSizes.icon),
      ),

      // ---------- 分隔线 ----------
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),

      // ---------- 卡片：描边而非阴影 ----------
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdR,
          side: BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ---------- 输入框 ----------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypeScale.body.copyWith(color: c.textTertiary),
        labelStyle: AppTypeScale.label.copyWith(color: c.textSecondary),
        floatingLabelStyle: AppTypeScale.label.copyWith(color: c.accent),
        helperStyle: AppTypeScale.caption.copyWith(color: c.textTertiary),
        errorStyle: AppTypeScale.caption.copyWith(color: c.danger),
        prefixIconColor: c.textTertiary,
        suffixIconColor: c.textTertiary,
        border: OutlineInputBorder(
          borderRadius: AppRadius.smR,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smR,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smR,
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smR,
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smR,
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smR,
          borderSide: BorderSide(color: c.border.withValues(alpha: 0.5)),
        ),
      ),

      // ---------- 按钮 ----------
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          c,
          bg: c.accent,
          fg: c.onAccent,
          bgHover: c.accentHover,
          bgPressed: c.accentPressed,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(
          c,
          bg: c.surface,
          fg: c.textPrimary,
          bgHover: c.surfaceSunken,
          bgPressed: c.surfaceSunken,
          border: c.border,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _buttonStyle(
          c,
          bg: Colors.transparent,
          fg: c.textSecondary,
          bgHover: c.surfaceSunken,
          bgPressed: c.surfaceSunken,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          iconSize: const WidgetStatePropertyAll(AppSizes.icon),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? c.textTertiary.withValues(alpha: 0.4)
                : c.textSecondary,
          ),
          overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed)
                ? c.accentSoft
                : c.surfaceSunken,
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.smR),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.sm)),
        ),
      ),

      // ---------- 导航 ----------
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.canvas,
        indicatorColor: c.accentSoft,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.smR,
        ),
        selectedIconTheme: IconThemeData(color: c.accent, size: AppSizes.icon),
        unselectedIconTheme: IconThemeData(color: c.textSecondary, size: AppSizes.icon),
        selectedLabelTextStyle: AppTypeScale.label.copyWith(color: c.accent),
        unselectedLabelTextStyle:
            AppTypeScale.label.copyWith(color: c.textSecondary),
        useIndicator: true,
        labelType: NavigationRailLabelType.all,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: c.accentSoft,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.smR,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppTypeScale.badge.copyWith(
            color: s.contains(WidgetState.selected) ? c.accent : c.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: AppSizes.iconLg,
            color: s.contains(WidgetState.selected) ? c.accent : c.textSecondary,
          ),
        ),
      ),

      // ---------- 列表 ----------
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.listInsetX,
          vertical: AppSpacing.xs,
        ),
        minVerticalPadding: AppSpacing.listInsetYCompact,
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        titleTextStyle: AppTypeScale.body.copyWith(color: c.textPrimary),
        subtitleTextStyle: AppTypeScale.bodySm.copyWith(color: c.textSecondary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdR),
      ),

      // ---------- 浮层 ----------
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlR,
          side: BorderSide(color: c.border),
        ),
        titleTextStyle: AppTypeScale.h3.copyWith(color: c.textPrimary),
        contentTextStyle: AppTypeScale.bodySm.copyWith(color: c.textSecondary),
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(32, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdR,
          side: BorderSide(color: c.border),
        ),
        textStyle: AppTypeScale.bodySm.copyWith(color: c.textPrimary),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypeScale.bodySm.copyWith(color: c.textPrimary),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: brightness == Brightness.light
              ? AppPalette.neutral900
              : c.surfaceRaised,
          borderRadius: AppRadius.smR,
          border: brightness == Brightness.light
              ? null
              : Border.all(color: c.border),
        ),
        textStyle: AppTypeScale.caption.copyWith(
          color: brightness == Brightness.light
              ? AppPalette.neutral100
              : c.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            brightness == Brightness.light ? AppPalette.neutral900 : c.surfaceRaised,
        contentTextStyle: AppTypeScale.bodySm.copyWith(
          color: brightness == Brightness.light
              ? AppPalette.neutral100
              : c.textPrimary,
        ),
        actionTextColor: brightness == Brightness.light
            ? AppPalette.teal300
            : c.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdR,
          side: brightness == Brightness.light
              ? BorderSide.none
              : BorderSide(color: c.border),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),

      // ---------- 其它 ----------
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceSunken,
        selectedColor: c.accentSoft,
        side: BorderSide.none,
        labelStyle: AppTypeScale.label.copyWith(color: c.textSecondary),
        secondaryLabelStyle: AppTypeScale.label.copyWith(color: c.accent),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xsR),
        showCheckmark: false,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.hovered)
              ? c.textTertiary.withValues(alpha: 0.6)
              : c.textTertiary.withValues(alpha: 0.3),
        ),
        crossAxisMargin: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceSunken,
        circularTrackColor: c.surfaceSunken,
        linearMinHeight: 2,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.22),
        selectionHandleColor: c.accent,
      ),
      focusColor: c.accent.withValues(alpha: 0.12),
      hoverColor: c.surfaceSunken,
      highlightColor: c.accentSoft,
    );
  }

  // ---------------------------------------------------------------------------
  // 按钮通用样式
  // ---------------------------------------------------------------------------
  static ButtonStyle _buttonStyle(
    AppSemanticColors c, {
    required Color bg,
    required Color fg,
    required Color bgHover,
    required Color bgPressed,
    Color? border,
    EdgeInsets? padding,
  }) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return bg.withValues(alpha: 0.4);
        if (s.contains(WidgetState.pressed)) return bgPressed;
        if (s.contains(WidgetState.hovered)) return bgHover;
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return fg.withValues(alpha: 0.5);
        return fg;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      side: border == null
          ? null
          : WidgetStatePropertyAll(BorderSide(color: border)),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      textStyle: WidgetStatePropertyAll(
        AppTypeScale.label.copyWith(fontWeight: FontWeight.w500),
      ),
      padding: WidgetStatePropertyAll(
        padding ??
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      minimumSize: const WidgetStatePropertyAll(
        Size(0, AppSizes.controlHeightDesktop),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.smR),
      ),
      // 动效克制：120ms 变色，无缩放
      animationDuration: AppMotion.micro,
      splashFactory: NoSplash.splashFactory,
    );
  }

  static TextTheme _textTheme(AppSemanticColors c) => TextTheme(
        displaySmall: AppTypeScale.display.copyWith(color: c.textPrimary),
        headlineLarge: AppTypeScale.h1.copyWith(color: c.textPrimary),
        headlineMedium: AppTypeScale.h2.copyWith(color: c.textPrimary),
        headlineSmall: AppTypeScale.h3.copyWith(color: c.textPrimary),
        titleLarge: AppTypeScale.h3.copyWith(color: c.textPrimary),
        titleMedium: AppTypeScale.body.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: AppTypeScale.bodySm.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: AppTypeScale.bodyLg.copyWith(color: c.textPrimary),
        bodyMedium: AppTypeScale.body.copyWith(color: c.textPrimary),
        bodySmall: AppTypeScale.bodySm.copyWith(color: c.textSecondary),
        labelLarge: AppTypeScale.label.copyWith(color: c.textPrimary),
        labelMedium: AppTypeScale.caption.copyWith(color: c.textSecondary),
        labelSmall: AppTypeScale.badge.copyWith(color: c.textTertiary),
      );
}
