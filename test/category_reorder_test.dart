import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/taxonomy/category_reorder.dart';

/// 同级分类拖拽排序的纯函数测试。
CategoryRow _row(
  String id, {
  String? parentId,
  int sortOrder = 0,
  String name = '分类',
}) =>
    CategoryRow(
      id: id,
      kind: 1,
      parentId: parentId,
      name: name,
      sortOrder: sortOrder,
      entryCount: 0,
      createdAt: 1,
      updatedAt: 1,
      hlc: '0000000000000001:0000:devA',
      deleted: 0,
    );

void main() {
  group('sortedSiblings', () {
    test('只取同一 parentId 的未删除行，sortOrder 相同按 id 稳定排序', () {
      final rows = <CategoryRow>[
        _row('b', sortOrder: 0),
        _row('a', sortOrder: 0),
        _row('child', parentId: 'a', sortOrder: 0),
        _row('late', sortOrder: 5),
      ];
      // 再造一行已删的：它不能出现在排序结果里。
      final deleted = CategoryRow(
        id: 'gone',
        kind: 1,
        parentId: null,
        name: '分类',
        sortOrder: 1,
        entryCount: 0,
        createdAt: 1,
        updatedAt: 1,
        hlc: 'x',
        deleted: 1,
      );
      final roots = sortedSiblings(rows, null);
      expect(roots.map((CategoryRow r) => r.id).toList(),
          <String>['a', 'b', 'late']);
      final withDeleted = <CategoryRow>[...rows, deleted];
      expect(
        sortedSiblings(withDeleted, null).map((CategoryRow r) => r.id).toList(),
        <String>['a', 'b', 'late'],
        reason: '已删除分类不参与排序',
      );
      expect(sortedSiblings(rows, 'a').single.id, 'child');
    });
  });

  group('reorderCategorySiblings', () {
    test('向下拖：只返回 sortOrder 变化的行', () {
      final rows = <CategoryRow>[
        _row('a', sortOrder: 0, name: 'A'),
        _row('b', sortOrder: 1, name: 'B'),
        _row('c', sortOrder: 2, name: 'C'),
      ];
      final changes = reorderCategorySiblings(
        siblings: rows,
        oldIndex: 0,
        newIndex: 2,
      );

      expect(changes.map((CategoryReorder c) => c.categoryId).toList(),
          <String>['b', 'c', 'a']);
      expect(changes.first.sortOrder, 0);
      expect(changes.last.sortOrder, 2);
      expect(changes.first.name, 'B', reason: 'update 是整体替换，必须带原名');
    });

    test('向上拖与拖回原位不产生多余写入', () {
      final rows = <CategoryRow>[
        _row('a', sortOrder: 0),
        _row('b', sortOrder: 1),
        _row('c', sortOrder: 2),
      ];
      expect(
        reorderCategorySiblings(
          siblings: rows,
          oldIndex: 2,
          newIndex: 0,
        ).length,
        3,
      );
      expect(
        reorderCategorySiblings(
          siblings: rows,
          oldIndex: 1,
          newIndex: 1,
        ),
        isEmpty,
        reason: '拖回原位不该写一堆空 oplog',
      );
    });

    test('越界索引直接报错，不静默吞掉', () {
      final rows = <CategoryRow>[_row('a'), _row('b')];
      expect(
        () => reorderCategorySiblings(
          siblings: rows,
          oldIndex: 5,
          newIndex: 0,
        ),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => reorderCategorySiblings(
          siblings: rows,
          oldIndex: 0,
          newIndex: 5,
        ),
        throwsA(isA<RangeError>()),
      );
      expect(reorderCategorySiblings(
        siblings: const <CategoryRow>[],
        oldIndex: 0,
        newIndex: 0,
      ), isEmpty);
    });

    test('二级分类排序保持 parentId，不会被提升为一级', () {
      final rows = <CategoryRow>[
        _row('c1', parentId: 'root', sortOrder: 0),
        _row('c2', parentId: 'root', sortOrder: 1),
      ];
      final changes = reorderCategorySiblings(
        siblings: rows,
        oldIndex: 1,
        newIndex: 0,
      );
      expect(changes.every((CategoryReorder c) => c.parentId == 'root'),
          isTrue);
    });
  });
}
