import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/bottom_nav_fit.dart';

/// docs/10 §12 U7 底部导航 375px 不换行测试。
void main() {
  test('375px / 5 项：每项 75px，不缩写不横向滚动', () {
    final plan = planBottomNavFit(availableWidth: kMobileMinWidth);
    expect(plan.perTabWidth, 75.0);
    expect(plan.needsAbbreviate, isFalse);
    expect(plan.horizontalOverflow, isFalse);
    expect(plan.suggestedFontSize, 10.5);
    expect(plan.hint, contains('不换行'));
  });

  test('更窄宽度缩写；极窄才判定横向溢出', () {
    final narrow = planBottomNavFit(availableWidth: 240);
    expect(narrow.needsAbbreviate, isTrue);
    expect(narrow.horizontalOverflow, isFalse);
    expect(narrow.suggestedFontSize, 10.0);
    expect(
      planBottomNavFit(availableWidth: 150).horizontalOverflow,
      isTrue,
    );
  });

  test('异常 tabCount / 宽度不崩', () {
    expect(planBottomNavFit(availableWidth: 375, tabCount: 0).perTabWidth, 0);
    expect(planBottomNavFit(availableWidth: 0).horizontalOverflow, isTrue);
  });
}
