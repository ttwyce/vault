import 'package:flutter/material.dart';

import '../../core/fonts/font_state.dart';
import '../../core/widgets/sketch_transitions.dart';
import 'sketch_metrics.dart';
import 'sketch_palette.dart';
import 'sketch_typography.dart';

/// 手绘风主题。
///
/// 字体不再是常量，而是由 [SketchTypography] 注入 —— 用户在设置里
/// 换字体、导入字体、切预设，都只改这一处（见 docs/15）。
abstract final class SketchTheme {
  const SketchTheme._();

  /// 默认亮色主题（手写预设）。测试与降级路径用它。
  static ThemeData get light => build(
        palette: SketchPalette.light,
        brightness: Brightness.light,
        typography: SketchTypography.handwritten,
      );

  static ThemeData get dark => build(
        palette: SketchPalette.dark,
        brightness: Brightness.dark,
        typography: SketchTypography.handwritten,
      );

  /// 从当前字体状态构建双主题。
  static ThemeData of(
    SketchPalette palette,
    FontState fonts,
  ) =>
      build(
        palette: palette,
        brightness: palette.isDark ? Brightness.dark : Brightness.light,
        typography: SketchTypography.resolve(fonts),
      );

  static ThemeData build({
    required SketchPalette palette,
    required Brightness brightness,
    required SketchTypography typography,
  }) {
    final p = palette;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.red,
      onPrimary: Colors.white,
      primaryContainer: p.note,
      onPrimaryContainer: p.ink,
      secondary: p.blue,
      onSecondary: Colors.white,
      secondaryContainer: p.noteAlt,
      onSecondaryContainer: p.blue,
      error: p.red,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
      outline: p.lineSoft,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // 全局字体走 ui 栈；局部样式由 textTheme 覆盖
      fontFamily: typography.ui.family,
      fontFamilyFallback: typography.ui.fallback,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.lineSoft,
      extensions: <ThemeExtension<dynamic>>[p, typography],
      textTheme: typography.textTheme(p),
      // 手绘风不叠水波纹，按压反馈由 SketchButton 自己做（位移 + 阴影变浅）
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      pageTransitionsTheme: kSketchPageTransitionsTheme,
      // 业务页里仍保留的原生 TextField / Switch / Checkbox / Dialog /
      // ListTile 不能落回 Material3 默认蓝色与标准圆角：一处统一到色板，
      // 避免「很多地方 UI 风格和主风格不一样」。
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        labelStyle: TextStyle(color: p.muted, fontSize: 11.5),
        hintStyle: TextStyle(color: p.muted, fontSize: 11.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SketchSpace.md,
          vertical: SketchSpace.sm,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.red,
        selectionColor: p.note,
        selectionHandleColor: p.blue,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? p.red : p.muted),
        trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? p.note : p.lineSoft),
        trackOutlineColor: WidgetStateProperty.all<Color>(p.line),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? p.red : Colors.transparent),
        checkColor: WidgetStateProperty.all<Color>(Colors.white),
        side: BorderSide(color: p.line, width: SketchStroke.hair),
        shape: RoundedRectangleBorder(borderRadius: SketchRadii.pill),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.blue,
        textColor: p.ink,
        titleTextStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        subtitleTextStyle: TextStyle(fontSize: 11.5, color: p.muted),
        shape: RoundedRectangleBorder(borderRadius: SketchRadii.pill),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: SketchRadii.c,
          side: BorderSide(color: p.line, width: SketchStroke.hair),
        ),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        contentTextStyle: TextStyle(fontSize: 12.5, color: p.ink),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all<Color>(p.ink),
          textStyle: WidgetStateProperty.all<TextStyle>(
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          overlayColor: WidgetStateProperty.all<Color>(Colors.transparent),
          shape: WidgetStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: SketchRadii.pill),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(fontSize: 12.5, color: p.ink),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all<Color>(p.surface),
          shape: WidgetStateProperty.all<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: SketchRadii.pill),
          ),
        ),
      ),
    );
  }
}

extension SketchThemeContext on BuildContext {
  SketchPalette get sketch => SketchPalette.of(this);

  TextTheme get texts => Theme.of(this).textTheme;

  /// 当前生效的排版系统（字体栈 + 元数据样式）
  SketchTypography get typography => type;
}
