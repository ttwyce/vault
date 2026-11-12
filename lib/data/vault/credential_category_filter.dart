/// 密码库的分类树过滤（docs/11 §4.2 A 左栏「分类树 + 智能分组」）。
///
/// 不读库：只把分类树、条目↔分类关联、当前选中分类与智能分组集合
/// 解析成要展示的 entry id 集合。两级分类，选父级时含子分类。
library;

class CategoryNode {
  const CategoryNode({required this.id, this.parentId});

  final String id;
  final String? parentId;
}

class EntryCategoryLink {
  const EntryCategoryLink({
    required this.entryId,
    required this.categoryId,
  });

  final String entryId;
  final String categoryId;
}

/// 选中分类为空时不过滤；[smartGroupIds] 为 null 表示没选智能分组。
Set<String> filterCredentialIdsByCategory({
  required Iterable<CategoryNode> categories,
  required Iterable<EntryCategoryLink> links,
  required String? selectedCategoryId,
  Set<String>? smartGroupIds,
}) {
  final all = links.map((EntryCategoryLink l) => l.entryId).toSet();
  Set<String> categoryIds;
  if (selectedCategoryId == null) {
    categoryIds = all;
  } else {
    final tree = categories.toList();
    final include = <String>{selectedCategoryId};
    // 两级树：只展开一层子分类，避免递归环。
    for (final node in tree) {
      if (node.parentId == selectedCategoryId) include.add(node.id);
    }
    categoryIds = <String>{
      for (final link in links)
        if (include.contains(link.categoryId)) link.entryId,
    };
  }
  if (smartGroupIds == null) return categoryIds;
  return categoryIds.intersection(smartGroupIds);
}

/// 左栏只显示有账号的分类（或它们的父级），避免空树占屏。
List<CategoryNode> categoriesWithCredentials({
  required Iterable<CategoryNode> categories,
  required Iterable<EntryCategoryLink> links,
}) {
  final nodes = categories.toList();
  final used = links.map((EntryCategoryLink l) => l.categoryId).toSet();
  final parents = <String>{
    for (final node in nodes)
      if (used.contains(node.id) && node.parentId != null) node.parentId!,
  };
  return <CategoryNode>[
    for (final node in nodes)
      if (used.contains(node.id) || parents.contains(node.id)) node,
  ];
}
