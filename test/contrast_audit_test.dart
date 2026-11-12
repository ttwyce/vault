import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/contrast_audit.dart';
import 'package:vault/app/theme/sketch_palette.dart';

/// docs/10 §10 / U3 主题对比度审计测试。
void main() {
  test('WCAG 已知值：黑白 21:1；同色 1:1', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 0.001));
    expect(contrastRatio(const Color(0xFF2D2D2D), const Color(0xFF2D2D2D)),
        closeTo(1.0, 0.001));
    expect(relativeLuminance(const Color(0xFFFFFFFF)), closeTo(1.0, 0.001));
    expect(relativeLuminance(const Color(0xFF000000)), closeTo(0.0, 0.001));
  });

  test('docs/10 §10 给出的 ink/muted on 纸白 均达标', () {
    final ink = contrastRatio(
      SketchPalette.light.ink,
      SketchPalette.light.bg,
    );
    final muted = contrastRatio(
      SketchPalette.light.muted,
      SketchPalette.light.bg,
    );
    expect(ink, greaterThan(4.5));
    expect(muted, greaterThan(4.5));
  });

  test('U3：亮暗双主题全部正文/次要文字在四类底面上 ≥ 4.5:1', () {
    for (final palette in <SketchPalette>[
      SketchPalette.light,
      SketchPalette.dark,
    ]) {
      final report = auditPaletteContrast(
        bg: palette.bg,
        surface: palette.surface,
        note: palette.note,
        noteAlt: palette.noteAlt,
        ink: palette.ink,
        muted: palette.muted,
      );
      expect(report.checks, hasLength(8));
      expect(report.allPassed, isTrue,
          reason: '${palette.isDark ? '暗' : '亮'}主题不达标：${report.failures().join('; ')}');
      expect(report.failures(), isEmpty);
    }
  });

  test('自定义不达标色板能明确报告失败项', () {
    final report = auditPaletteContrast(
      bg: const Color(0xFF777777),
      surface: const Color(0xFF777777),
      note: const Color(0xFF777777),
      noteAlt: const Color(0xFF777777),
      ink: const Color(0xFF888888),
      muted: const Color(0xFF888888),
    );
    expect(report.allPassed, isFalse);
    expect(report.failures(), hasLength(8));
    expect(report.checks.first.toJson()['ratio'], isA<double>());
  });
}
