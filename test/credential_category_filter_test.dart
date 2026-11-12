import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/credential_category_filter.dart';

/// docs/11 §4.2 A 分类树过滤测试。
void main() {
  const tree = <CategoryNode>[
    CategoryNode(id: 'work'),
    CategoryNode(id: 'dev', parentId: 'work'),
    CategoryNode(id: 'ops', parentId: 'work'),
    CategoryNode(id: 'life'),
  ];
  const links = <EntryCategoryLink>[
    EntryCategoryLink(entryId: 'e1', categoryId: 'dev'),
    EntryCategoryLink(entryId: 'e2', categoryId: 'ops'),
    EntryCategoryLink(entryId: 'e3', categoryId: 'life'),
  ];

  test('选中父分类包含全部子分类；空选中不过滤', () {
    expect(
      filterCredentialIdsByCategory(
        categories: tree,
        links: links,
        selectedCategoryId: 'work',
      ),
      <String>{'e1', 'e2'},
    );
    expect(
      filterCredentialIdsByCategory(
        categories: tree,
        links: links,
        selectedCategoryId: null,
      ),
      <String>{'e1', 'e2', 'e3'},
    );
  });

  test('与智能分组求交集；智能分组为空则结果为空', () {
    expect(
      filterCredentialIdsByCategory(
        categories: tree,
        links: links,
        selectedCategoryId: 'work',
        smartGroupIds: <String>{'e2', 'e9'},
      ),
      <String>{'e2'},
    );
    expect(
      filterCredentialIdsByCategory(
        categories: tree,
        links: links,
        selectedCategoryId: null,
        smartGroupIds: <String>{},
      ),
      isEmpty,
    );
  });

  test('左栏只显示有账号的分类及其父级', () {
    final visible = categoriesWithCredentials(
      categories: tree,
      links: links,
    ).map((CategoryNode n) => n.id).toSet();
    expect(visible, <String>{'work', 'dev', 'ops', 'life'});
  });
}
