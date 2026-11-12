import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/desktop_layout_plan.dart';

/// docs/08 §7 桌面三栏布局判定测试。
void main() {
  test('移动 / 非桌面一律紧凑单栏', () {
    final plan = planDesktopLayout(390, isDesktop: false);
    expect(plan.layout, DesktopLayout.compact);
    expect(plan.showNav, isFalse);
    expect(plan.showDetail, isFalse);
    expect(plan.navWidth, 0);
  });

  test('600~900 只给 68px rail，不硬塞三栏', () {
    final plan = planDesktopLayout(840);
    expect(plan.layout, DesktopLayout.railOnly);
    expect(plan.navWidth, 68);
    expect(plan.showDetail, isFalse);
    expect(plan.hint, contains('不硬塞'));
  });

  test('≥900 三栏；详情至少 420', () {
    final plan = planDesktopLayout(kThreeColumnMinWidth);
    expect(plan.layout, DesktopLayout.threeColumn);
    expect(plan.navWidth, 68);
    expect(plan.listWidth, 320);
    expect(plan.detailWidth, 512);
    expect(plan.showDetail, isTrue);
    expect(kWindowsMinWidth, 900);
    expect(kWindowsMinHeight, 600);
  });

  test('边界 899 / 900 明确分档', () {
    expect(planDesktopLayout(899).layout, DesktopLayout.railOnly);
    expect(planDesktopLayout(900).layout, DesktopLayout.threeColumn);
  });
}
