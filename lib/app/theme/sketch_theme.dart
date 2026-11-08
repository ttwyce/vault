import 'package:flutter/material.dart';

import '../../core/fonts/font_state.dart';
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
    );
  }
}

extension SketchThemeContext on BuildContext {
  SketchPalette get sketch => SketchPalette.of(this);

  TextTheme get texts => Theme.of(this).textTheme;

  /// 当前生效的排版系统（字体栈 + 元数据样式）
  SketchTypography get typography => type;
}
