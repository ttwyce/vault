/// 移动端底部导航五项不换行判定（docs/10 §12 U7）。
///
/// 不读 MediaQuery、不渲染：只按可用宽度与标签数量算出每项可用宽度，
/// 给出「是否需要缩写 / 是否会横向溢出」以及建议的最小字号。
library;

/// 375px 是 U7 指定的最窄验收宽度。
const double kMobileMinWidth = 375.0;

/// 五个 Tab 各留出图标 + 文字的最小可用宽度（含左右内边距）。
const double kMinTabWidth = 56.0;

class BottomNavFitPlan {
  const BottomNavFitPlan({
    required this.perTabWidth,
    required this.needsAbbreviate,
    required this.horizontalOverflow,
    required this.hint,
    required this.suggestedFontSize,
  });

  final double perTabWidth;
  final bool needsAbbreviate;
  final bool horizontalOverflow;
  final String hint;
  final double suggestedFontSize;
}

BottomNavFitPlan planBottomNavFit({
  required double availableWidth,
  int tabCount = 5,
  double minTabWidth = kMinTabWidth,
}) {
  final per = tabCount <= 0 ? 0.0 : availableWidth / tabCount;
  final need = per < minTabWidth;
  return BottomNavFitPlan(
    perTabWidth: per,
    needsAbbreviate: need,
    horizontalOverflow: per <= 0 || need && per < minTabWidth * 0.75,
    hint: need
        ? '每项宽度不足，标签用单字缩写并禁止换行（fontSize ≤ 10）'
        : '每项宽度足够，五行导航不换行、无横向滚动',
    suggestedFontSize: need ? 10.0 : 10.5,
  );
}
