/// 卡片圆角配方轮换（docs/10 §2 ① / §12 U1）。
///
/// 不渲染、不读主题：只保证「任意相邻两张卡片的 variant 不同」，
/// 避免各页面各写 `hashCode % 4` 导致相邻撞配方。
library;

/// 四套配方（与 `SketchRadii.cycle` 对应）。
const int kSketchCardVariants = 4;

/// 按列表索引给出配方；[previous] 是上一张卡片的配方，
/// 相同则顺延一位，保证相邻不重复。
int sketchCardVariant(int index, {int? previous}) {
  final base = index.abs() % kSketchCardVariants;
  if (previous == null) return base;
  if (base != previous) return base;
  return (base + 1) % kSketchCardVariants;
}

/// 批量：一次算完整列，逐个带上一张的结果。
List<int> sketchCardVariants(int count) {
  final out = <int>[];
  for (var i = 0; i < count; i++) {
    out.add(sketchCardVariant(i, previous: out.isEmpty ? null : out.last));
  }
  return List<int>.unmodifiable(out);
}
