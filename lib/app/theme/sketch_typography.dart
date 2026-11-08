import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/fonts/font_catalog.dart';
import '../../core/fonts/font_face.dart';
import '../../core/fonts/font_role.dart';
import '../../core/fonts/font_state.dart';
import 'sketch_palette.dart';

/// 一条字体栈：家族名 + 回退链。
///
/// `family == null` 表示交给平台默认字体。回退链必须显式给出，
/// 因为几乎不存在一个字体同时覆盖中文、西文和符号。
@immutable
class FontStack {
  const FontStack({this.family, this.fallback = const <String>[]});

  final String? family;
  final List<String> fallback;

  static const FontStack system = FontStack();

  factory FontStack.of(FontFace face) =>
      FontStack(family: face.family, fallback: face.fallback);

  bool get isSystem => family == null;

  TextStyle apply(TextStyle style) => style.copyWith(
        fontFamily: family,
        fontFamilyFallback: fallback,
      );

  @override
  bool operator ==(Object other) =>
      other is FontStack &&
      other.family == family &&
      listEquals(other.fallback, fallback);

  @override
  int get hashCode => Object.hash(family, Object.hashAll(fallback));
}

/// 排版系统：三个角色的字体栈 + 由此生成的 [TextTheme]。
///
/// 作为 ThemeExtension 挂在 ThemeData 上，业务代码用 `context.type` 读，
/// 不在任何 widget 里写死字体家族名。
@immutable
class SketchTypography extends ThemeExtension<SketchTypography> {
  const SketchTypography({
    required this.ui,
    required this.display,
    required this.mono,
  });

  final FontStack ui;
  final FontStack display;
  final FontStack mono;

  /// 全部走系统字体的兜底（ThemeExtension 缺失、字体加载失败时使用）。
  static const SketchTypography fallback = SketchTypography(
    ui: FontStack.system,
    display: FontStack.system,
    mono: FontStack.system,
  );

  /// 产品默认观感 = 手写预设。用于测试与"字体服务还没起来"的场景，
  /// 保证任何情况下首帧都不是系统字体。
  static const SketchTypography handwritten = SketchTypography(
    ui: FontStack(
      family: FontCatalog.wenKaiFamily,
      fallback: FontCatalog.cjkFallback,
    ),
    display: FontStack(
      family: FontCatalog.caveatFamily,
      fallback: <String>[FontCatalog.wenKaiFamily, ...FontCatalog.cjkFallback],
    ),
    mono: FontStack(
      family: FontCatalog.monoFamily,
      fallback: <String>['Consolas', 'Menlo', 'DejaVu Sans Mono', 'monospace'],
    ),
  );

  factory SketchTypography.resolve(FontState state) => SketchTypography(
        ui: FontStack.of(state.faceFor(FontRole.ui)),
        display: FontStack.of(state.faceFor(FontRole.display)),
        mono: FontStack.of(state.faceFor(FontRole.mono)),
      );

  // ---------------------------------------------------------------------------
  // 字号阶梯：与 docs/10 §4 一致，不随字体变化 ——
  // 不同字体的 x-height 差异靠行高吸收，不改字号，否则跨端对不齐。
  // ---------------------------------------------------------------------------

  TextTheme textTheme(SketchPalette p) {
    return TextTheme(
      displaySmall: display.apply(
        TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.3, color: p.ink),
      ),
      titleLarge: display.apply(
        TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.35, color: p.ink),
      ),
      titleMedium: ui.apply(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4, color: p.ink),
      ),
      bodyLarge: ui.apply(
        TextStyle(fontSize: 14.5, height: 1.9, color: p.ink),
      ),
      bodyMedium: ui.apply(
        TextStyle(fontSize: 13.5, height: 1.7, color: p.ink),
      ),
      bodySmall: ui.apply(
        TextStyle(fontSize: 11.5, height: 1.6, color: p.muted),
      ),
      labelMedium: mono.apply(
        TextStyle(fontSize: 11, height: 1.4, fontWeight: FontWeight.w600, color: p.muted),
      ),
      labelSmall: mono.apply(
        TextStyle(fontSize: 10.5, height: 1.5, color: p.muted),
      ),
    );
  }

  /// 元数据样式。时间、字数、标签、TOTP 秒数统一走它，
  /// 保证数字列天然对齐（这是等宽体唯一的、也是不可替代的价值）。
  TextStyle monoStyle({
    double size = 10.5,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.4,
    double? letterSpacing,
  }) {
    return mono.apply(
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color,
        letterSpacing: letterSpacing,
      ),
    );
  }

  @override
  SketchTypography copyWith({
    FontStack? ui,
    FontStack? display,
    FontStack? mono,
  }) {
    return SketchTypography(
      ui: ui ?? this.ui,
      display: display ?? this.display,
      mono: mono ?? this.mono,
    );
  }

  @override
  SketchTypography lerp(ThemeExtension<SketchTypography>? other, double t) {
    if (other is! SketchTypography) return this;
    return t < 0.5 ? this : other;
  }

  @override
  bool operator ==(Object other) =>
      other is SketchTypography &&
      other.ui == ui &&
      other.display == display &&
      other.mono == mono;

  @override
  int get hashCode => Object.hash(ui, display, mono);
}

extension SketchTypographyContext on BuildContext {
  SketchTypography get type =>
      Theme.of(this).extension<SketchTypography>() ?? SketchTypography.fallback;
}
