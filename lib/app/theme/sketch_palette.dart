import 'package:flutter/material.dart';

/// 手绘风的语义色板。
///
/// 规则（见 docs/10-UI设计方案.md §3）：
/// - 红：只给 AI 动作 / 当前状态 / 主按钮
/// - 蓝：只给旁注 / 链接 / 待你决定
/// - 绿：只给已完成的勾选
/// - 便签黄：选中态 / AI 生成内容 / 重要结论
/// - 墨：其余一切
@immutable
class SketchPalette extends ThemeExtension<SketchPalette> {
  const SketchPalette({
    required this.bg,
    required this.surface,
    required this.note,
    required this.noteAlt,
    required this.ink,
    required this.muted,
    required this.line,
    required this.lineSoft,
    required this.red,
    required this.blue,
    required this.green,
    required this.shadow,
    required this.scrim,
    required this.isDark,
  });

  /// 页面底色（纸白）
  final Color bg;

  /// 卡片 / 面板
  final Color surface;

  /// 便签黄：选中态、AI 生成物
  final Color note;

  /// 蓝笔便签：旁注、说明
  final Color noteAlt;

  /// 正文、描边
  final Color ink;

  /// 次要文字
  final Color muted;

  /// 主描边
  final Color line;

  /// 次描边、分隔线
  final Color lineSoft;

  final Color red;
  final Color blue;
  final Color green;

  /// 硬阴影颜色（暗色下换成半透明白）
  final Color shadow;

  /// 抽屉 / 弹层遮罩
  final Color scrim;

  final bool isDark;

  static const SketchPalette light = SketchPalette(
    bg: Color(0xFFFDFBF7),
    surface: Color(0xFFFFFFFF),
    note: Color(0xFFFFF9C4),
    noteAlt: Color(0xFFE9F0FA),
    ink: Color(0xFF2D2D2D),
    muted: Color(0xFF6B6459),
    line: Color(0xFF2D2D2D),
    lineSoft: Color(0xFFB9B4A9),
    red: Color(0xFFFF4D4D),
    blue: Color(0xFF2D5DA1),
    green: Color(0xFF3C8B5B),
    shadow: Color(0xFF2D2D2D),
    scrim: Color(0x422D2D2D),
    isDark: false,
  );

  static const SketchPalette dark = SketchPalette(
    bg: Color(0xFF0B0C10),
    surface: Color(0xFF14161B),
    note: Color(0xFF2A2A1E),
    noteAlt: Color(0xFF1A2434),
    ink: Color(0xFFF4F5F7),
    muted: Color(0xFF9AA3B2),
    line: Color(0xFFE8EAEE),
    lineSoft: Color(0xFF4A505C),
    red: Color(0xFFFF6B6B),
    blue: Color(0xFF7FA6E8),
    green: Color(0xFF5FC98A),
    shadow: Color(0x59E8EAEE),
    scrim: Color(0x99000000),
    isDark: true,
  );

  /// 便捷读取：`context.sketch.ink`
  static SketchPalette of(BuildContext context) =>
      Theme.of(context).extension<SketchPalette>() ?? light;

  @override
  SketchPalette copyWith({
    Color? bg,
    Color? surface,
    Color? note,
    Color? noteAlt,
    Color? ink,
    Color? muted,
    Color? line,
    Color? lineSoft,
    Color? red,
    Color? blue,
    Color? green,
    Color? shadow,
    Color? scrim,
    bool? isDark,
  }) {
    return SketchPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      note: note ?? this.note,
      noteAlt: noteAlt ?? this.noteAlt,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      lineSoft: lineSoft ?? this.lineSoft,
      red: red ?? this.red,
      blue: blue ?? this.blue,
      green: green ?? this.green,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  SketchPalette lerp(ThemeExtension<SketchPalette>? other, double t) {
    if (other is! SketchPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return SketchPalette(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      note: c(note, other.note),
      noteAlt: c(noteAlt, other.noteAlt),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      line: c(line, other.line),
      lineSoft: c(lineSoft, other.lineSoft),
      red: c(red, other.red),
      blue: c(blue, other.blue),
      green: c(green, other.green),
      shadow: c(shadow, other.shadow),
      scrim: c(scrim, other.scrim),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}
