import '../db/vault_database.dart';

/// 同级分类拖拽排序的纯计算（docs/09 §4 / docs/11 §2.5）。
///
/// 只允许**同一 parentId 下**重排：把二级分类拖到一级、或跨父级换组，
/// 会改变归属语义，必须走明确的「改层级」操作，不能靠一次拖拽悄悄完成。
/// 页面只负责把手势交给这里，再把结果逐条交给 `WriteGateway.writeCategory`
/// （唯一写入口，oplog 与实体同事务）。
class CategoryReorder {
  const CategoryReorder({
    required this.categoryId,
    required this.parentId,
    required this.sortOrder,
    required this.name,
  });

  final String categoryId;
  final String? parentId;
  final int sortOrder;
  final String name;

  @override
  String toString() =>
      'CategoryReorder($categoryId parent=$parentId order=$sortOrder)';
}

/// 计算一组同级分类从 [oldIndex] 拖到 [newIndex] 后需要改写的行。
///
/// `ReorderableListView.onReorderItem`（Flutter 3.41+）已经替调用方
/// 修正过向下拖动时的索引，所以这里按「先移除再插入到 newIndex」处理，
/// 页面不再手写 `newIndex - 1`。只返回 `sortOrder` 真正变化的行，
/// 避免「拖回原位」也写一堆空 oplog。
List<CategoryReorder> reorderCategorySiblings({
  required List<CategoryRow> siblings,
  required int oldIndex,
  required int newIndex,
}) {
  if (siblings.isEmpty) return const <CategoryReorder>[];
  if (oldIndex < 0 || oldIndex >= siblings.length) {
    throw RangeError.range(oldIndex, 0, siblings.length - 1, 'oldIndex');
  }
  if (newIndex < 0 || newIndex >= siblings.length) {
    throw RangeError.range(newIndex, 0, siblings.length - 1, 'newIndex');
  }

  final reordered = List<CategoryRow>.from(siblings);
  final moved = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, moved);

  final changes = <CategoryReorder>[];
  for (var i = 0; i < reordered.length; i++) {
    final row = reordered[i];
    if (row.sortOrder == i) continue;
    changes.add(CategoryReorder(
      categoryId: row.id,
      parentId: row.parentId,
      sortOrder: i,
      name: row.name,
    ));
  }
  return changes;
}

/// 按 parentId 分组，组内按 sortOrder → id 稳定排序。
///
/// id 作为二级键是必须的：新建分类的 sortOrder 默认都是 0，只按
/// sortOrder 排会让顺序在每次重建时抖动。
List<CategoryRow> sortedSiblings(
  Iterable<CategoryRow> rows,
  String? parentId,
) {
  final group = rows
      .where((CategoryRow row) =>
          row.parentId == parentId && row.deleted == 0)
      .toList(growable: true);
  group.sort((CategoryRow a, CategoryRow b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
  });
  return group;
}
