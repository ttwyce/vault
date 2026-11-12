import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_card_variant.dart';

/// docs/10 §12 U1 相邻卡片圆角配方不重复测试。
void main() {
  test('单个索引落在 0..3；previous 相同则顺延', () {
    expect(sketchCardVariant(0), 0);
    expect(sketchCardVariant(3), 3);
    expect(sketchCardVariant(4), 0);
    expect(sketchCardVariant(-1), 1);
    expect(sketchCardVariant(0, previous: 0), 1);
    expect(sketchCardVariant(3, previous: 3), 0);
    expect(sketchCardVariant(1, previous: 3), 1);
  });

  test('长列表任意相邻两张都不同', () {
    final variants = sketchCardVariants(43);
    expect(variants, hasLength(43));
    for (var i = 1; i < variants.length; i++) {
      expect(variants[i], isNot(variants[i - 1]), reason: '第 $i 张与前一张撞配方');
      expect(variants[i], inInclusiveRange(0, kSketchCardVariants - 1));
    }
  });

  test('空列表 / 单张不报错', () {
    expect(sketchCardVariants(0), isEmpty);
    expect(sketchCardVariants(1), <int>[0]);
  });
}
