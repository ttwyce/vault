import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/log_tables.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/organize/organize_page.dart';

import 'support/test_harness.dart';

/// 组织页的写操作测试。
///
/// 重点不是「点了有没有反应」，而是**每次写都必须留下 oplog**：
/// 分类和标签是独立同步实体，绕过写入口的话页面看着成功，
/// 另一台设备永远收不到。
void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
  });

  tearDown(() async {
    await app.dispose();
  });

  Future<void> pumpOrganize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: OrganizePage()),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> settleDialog(WidgetTester tester) async {
    // bottom sheet 和 AlertDialog 都有约 250ms 的入场 / 退场动画。
    // 只 pump 100ms 时 sheet 还在屏幕外，tap 会落到视口之外变成空点击。
    // 固定推进 4 帧而不是 pumpAndSettle：页面里有进度圈，settle 永不结束。
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('新建分类：列表更新且写入 category oplog',
      (WidgetTester tester) async {
    await pumpOrganize(tester);

    await tester.tap(find.text('＋ 分类'));
    await settleDialog(tester);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '工作');
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('工作'), findsOneWidget);
    expect(await app.repo.categories(), hasLength(1));
    final pending = await app.gateway.pending();
    expect(
      pending.where((r) => r.entity == SyncEntity.category),
      hasLength(1),
    );
  });

  testWidgets('新建标签：写入 tag oplog', (WidgetTester tester) async {
    await pumpOrganize(tester);

    await tester.tap(find.text('＋ 标签'));
    await settleDialog(tester);
    await tester.enterText(find.byType(TextField).first, '同步');
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('同步 · 0'), findsOneWidget);
    expect(await app.repo.tags(), hasLength(1));
    final pending = await app.gateway.pending();
    expect(pending.where((r) => r.entity == SyncEntity.tag), hasLength(1));
  });

  testWidgets('删除分类走写入口：分类消失但条目还在',
      (WidgetTester tester) async {
    final cat = await app.gateway
        .writeCategory(CategoryWrite.create(name: '工作'));
    final entry = await app.gateway.writeEntry(
      EntryWrite.create(title: '一条笔记'),
    );
    await app.gateway.setEntryTaxonomy(
      entryId: entry.snapshot.id,
      categoryId: cat.snapshot.id,
    );

    await pumpOrganize(tester);
    await tester.tap(find.text('工作'));
    await settleDialog(tester);
    await tester.tap(find.text('删除'));
    await settleDialog(tester);
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(await app.repo.categories(), isEmpty);
    expect(await app.repo.getRow(entry.snapshot.id), isNotNull);
    expect(
      await app.taxonomyRepo.categoryForEntry(entry.snapshot.id),
      isNull,
    );
  });

  testWidgets('分类树渲染两级可拖拽列表，同级排序写入 sortOrder',
      (WidgetTester tester) async {
    await app.gateway.writeCategory(CategoryWrite.create(id: 'cat-a', name: '甲'));
    await app.gateway.writeCategory(CategoryWrite.create(id: 'cat-b', name: '乙'));
    await app.gateway.writeCategory(
      CategoryWrite.create(id: 'cat-a-1', name: '甲的子级', parentId: 'cat-a'),
    );

    await pumpOrganize(tester);

    // 扁平展开两级树，只有一个 ReorderableListView（跨父级拖动由页面拒绝）。
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.text('分类（长按拖动可同级排序）'), findsOneWidget);
    expect(find.text('甲'), findsOneWidget);
    expect(find.text('乙'), findsOneWidget);
    expect(find.text('甲的子级'), findsOneWidget);

    // 模拟一级列表把「甲」拖到「乙」之后（onReorderItem 已修正索引）。
    final roots = find.byKey(const ValueKey<String>('category-roots'));
    final list = tester.widget<ReorderableListView>(roots);
    // 扁平顺序是 [甲, 甲的子级, 乙]；把甲拖到「乙」的位置（索引 2）。
    list.onReorderItem!(0, 2);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    final rows = await app.repo.categories();
    final byId = <String, int>{
      for (final row in rows) row.id: row.sortOrder,
    };
    expect(byId['cat-b'], 0);
    expect(byId['cat-a'], 1);
    // 二级分类的 parentId 与顺序都没被拖动影响。
    expect(byId['cat-a-1'], 0);
    expect(rows.firstWhere((row) => row.id == 'cat-a-1').parentId, 'cat-a');

    // 每次排序都必须经过唯一写入口，留下可同步的 category oplog。
    final categoryOps = (await app.gateway.pending())
        .where((row) => row.entity == SyncEntity.category)
        .toList();
    expect(categoryOps, isNotEmpty);
  });
}
