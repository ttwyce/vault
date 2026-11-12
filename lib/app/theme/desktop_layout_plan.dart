/// Windows 三栏布局判定（docs/08 §7「导航 · 列表 · 详情」）。
///
/// 不渲染、不读 MediaQuery：只按可用宽度决定栏数、各栏宽度与回退规则，
/// 供桌面外壳与页面共用。真机窗口尺寸限制仍属平台层。
library;

/// docs/08 §7：Windows 最小 900×600。
const double kWindowsMinWidth = 900;
const double kWindowsMinHeight = 600;

/// 三栏最小阈值：导航 68 + 列表 320 + 详情 420。
const double kThreeColumnMinWidth = 900;

enum DesktopLayout { compact, railOnly, threeColumn }

class DesktopLayoutPlan {
  const DesktopLayoutPlan({
    required this.layout,
    required this.navWidth,
    required this.listWidth,
    required this.detailWidth,
    required this.hint,
  });

  final DesktopLayout layout;
  final double navWidth;
  final double listWidth;
  final double detailWidth;
  final String hint;

  bool get showDetail => layout == DesktopLayout.threeColumn;
  bool get showNav => layout != DesktopLayout.compact;
}

DesktopLayoutPlan planDesktopLayout(double width, {bool isDesktop = true}) {
  if (!isDesktop || width < 600) {
    return const DesktopLayoutPlan(
      layout: DesktopLayout.compact,
      navWidth: 0,
      listWidth: 0,
      detailWidth: 0,
      hint: '紧凑单栏：底部导航 + 列表，详情走独立路由',
    );
  }
  if (width < kThreeColumnMinWidth) {
    return const DesktopLayoutPlan(
      layout: DesktopLayout.railOnly,
      navWidth: 68,
      listWidth: 0,
      detailWidth: 0,
      hint: '中等宽度：68px 图标侧栏 + 内容单栏，不硬塞三栏',
    );
  }
  const nav = 68.0;
  const list = 320.0;
  final detail = width - nav - list;
  return DesktopLayoutPlan(
    layout: DesktopLayout.threeColumn,
    navWidth: nav,
    listWidth: list,
    detailWidth: detail >= 420 ? detail : 420,
    hint: '宽屏三栏：导航 $nav · 列表 $list · 详情 ${detail >= 420 ? detail.toStringAsFixed(0) : "420"}',
  );
}
