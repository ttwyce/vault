/// 主题对比度的**纯判定层**（docs/10 §10 / U3）。
///
/// 不依赖 Flutter 渲染：按 WCAG 2.1 相对亮度公式计算任意两色对比度，
/// 并审计亮 / 暗两套色板的正文色在各类底面上的对比度，让 U3
/// 「亮暗双主题下所有正文对比度 ≥ 4.5:1」可回归验证。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;

/// WCAG 相对亮度（sRGB 线性化）。
double relativeLuminance(Color color) {
  // Flutter 3.27+ 的 Color.r/g/b 已是 0~1 归一化 double；
  // 旧版是 0~255 int，这里做兼容判断，避免两套 SDK 算出不同亮度。
  double channel(double value) {
    final c = value > 1.0 ? value / 255.0 : value;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// 对比度 (L1+0.05)/(L2+0.05)，范围 1~21。
double contrastRatio(Color foreground, Color background) {
  final a = relativeLuminance(foreground);
  final b = relativeLuminance(background);
  final brighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (brighter + 0.05) / (darker + 0.05);
}

const double kMinBodyContrast = 4.5;

class ContrastCheck {
  const ContrastCheck({
    required this.foregroundName,
    required this.backgroundName,
    required this.ratio,
    required this.passed,
  });

  final String foregroundName;
  final String backgroundName;
  final double ratio;
  final bool passed;

  Map<String, Object?> toJson() => <String, Object?>{
        'foreground': foregroundName,
        'background': backgroundName,
        'ratio': ratio,
        'passed': passed,
      };
}

class ContrastReport {
  const ContrastReport(this.checks);

  final List<ContrastCheck> checks;

  bool get allPassed =>
      checks.every((ContrastCheck c) => c.passed);

  List<String> failures() => <String>[
        for (final c in checks)
          if (!c.passed)
            '${c.foregroundName} on ${c.backgroundName}: '
            '${c.ratio.toStringAsFixed(2)}:1 < $kMinBodyContrast',
      ];
}

/// 审计一套色板：ink / muted 在 bg / surface / note / noteAlt 上。
ContrastReport auditPaletteContrast({
  required Color bg,
  required Color surface,
  required Color note,
  required Color noteAlt,
  required Color ink,
  required Color muted,
  double minRatio = kMinBodyContrast,
}) {
  final backgrounds = <(String, Color)>[
    ('bg', bg),
    ('surface', surface),
    ('note', note),
    ('noteAlt', noteAlt),
  ];
  final foregrounds = <(String, Color)>[
    ('ink', ink),
    ('muted', muted),
  ];
  final out = <ContrastCheck>[];
  for (final foreground in foregrounds) {
    for (final background in backgrounds) {
      final ratio = contrastRatio(foreground.$2, background.$2);
      out.add(ContrastCheck(
        foregroundName: foreground.$1,
        backgroundName: background.$1,
        ratio: ratio,
        passed: ratio >= minRatio,
      ));
    }
  }
  return ContrastReport(List<ContrastCheck>.unmodifiable(out));
}
