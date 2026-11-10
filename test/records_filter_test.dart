import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/widgets/sketch_controls.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/records/records_page.dart';

import 'support/test_harness.dart';

/// 记录页筛选：分类 OR（含子级）、标签 AND、两者取交集。
///
/// 重点在读侧 SQL 的语义 —— 页面看着"筛出来了"但把 OR / AND 写反，
/// 用户会以为筛选坏了，而且这种错在小数据量下根本看不出来。
void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
  });

  tearDown(() async {
    await app.dispose();
  });

  /// 造数据：工作（父）› 周报（子）、生活，另有未分类一条。
  ///
  /// 标签：同步 / 重要。A 两个都有，B 只有同步，D 只有重要。
  Future<_Seed> seed() async {
    final work =
        await app.gateway.writeCategory(CategoryWrite.create(name: '工作'));
    final child = await app.gateway.writeCategory(
      CategoryWrite.create(name: '周报', parentId: work.snapshot.id),
    );
    final life =
        await app.gateway.writeCategory(CategoryWrite.create(name: '生活'));
    final sync = await app.gateway.writeTag(TagWrite.create(name: '同步'));
    final important =
        await app.gateway.writeTag(TagWrite.create(name: '重要'));

    Future<String> entry(
      String title, {
      String? categoryId,
      List<String> tagIds = const <String>[],
    }) async {
      final created =
          await app.gateway.writeEntry(EntryWrite.create(title: title));
      await app.gateway.setEntryTaxonomy(
        entryId: created.snapshot.id,
        categoryId: categoryId,
        tagIds: tagIds,
      );
      return created.snapshot.id;
    }

    final a = await entry(
      '周报一',
      categoryId: child.snapshot.id,
      tagIds: <String>[sync.snapshot.id, important.snapshot.id],
    );
    final b = await entry(
      '工作一',
      categoryId: work.snapshot.id,
      tagIds: <String>[sync.snapshot.id],
    );
    final c = await entry('生活一', categoryId: life.snapshot.id);
    final d = await entry(
      '未分类一',
      tagIds: <String>[important.snapshot.id],
    );

    return _Seed(
      workId: work.snapshot.id,
      childId: child.snapshot.id,
      lifeId: life.snapshot.id,
      aId: a,
      bId: b,
      cId: c,
      dId: d,
      syncId: sync.snapshot.id,
      importantId: important.snapshot.id,
    );
  }

  Future<void> pumpRecords(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: Scaffold(body: RecordsPage())),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  test('分类筛选包含子分类里的条目', () async {
    final s = await seed();
    final ids = await app.repo.entryIdsForCategory(s.workId);

    expect(ids, containsAll(<String>[s.aId, s.bId]));
    expect(ids, isNot(contains(s.cId)));
    expect(ids, isNot(contains(s.dId)));
  });

  test('未分类筛选只返回没有有效分类关联的条目', () async {
    final s = await seed();
    final ids = await app.repo.uncategorizedEntryIds();

    expect(ids, contains(s.dId));
    expect(ids, isNot(contains(s.aId)));
    expect(ids, isNot(contains(s.cId)));
  });

  test('多标签是 AND 不是 OR', () async {
    final s = await seed();
    final both = await app.repo.entryIdsWithAllTags(
      <String>[s.syncId, s.importantId],
    );

    expect(both, contains(s.aId));
    expect(both, isNot(contains(s.bId))); // 只带「同步」
    expect(both, isNot(contains(s.dId))); // 只带「重要」
  });

  testWidgets('点一级分类 chip：父级与子级的条目都在，其它的消失',
      (WidgetTester tester) async {
    await seed();
    await pumpRecords(tester);

    expect(find.text('周报一'), findsOneWidget);
    expect(find.text('生活一'), findsOneWidget);

    await tester.tap(find.widgetWithText(SketchTag, '工作'));
    await settle(tester);

    expect(find.text('周报一'), findsOneWidget);
    expect(find.text('工作一'), findsOneWidget);
    expect(find.text('生活一'), findsNothing);
    expect(find.text('未分类一'), findsNothing);
  });

  testWidgets('选两个标签：只剩同时带两个的条目',
      (WidgetTester tester) async {
    await seed();
    await pumpRecords(tester);

    // 列表脚注也会显示标签名，必须用 chip 容器限定 finder。
    await tester.tap(find.widgetWithText(SketchTag, '同步'));
    await settle(tester);
    await tester.tap(find.widgetWithText(SketchTag, '重要'));
    await settle(tester);

    expect(find.text('周报一'), findsOneWidget);
    expect(find.text('工作一'), findsNothing);
    expect(find.text('未分类一'), findsNothing);

    // 清除筛选后四条全回来
    await tester.tap(find.text('清除筛选'));
    await settle(tester);
    expect(find.text('工作一'), findsOneWidget);
    expect(find.text('未分类一'), findsOneWidget);
  });

  testWidgets('「未分类」是筛选项，不等于「不筛选」',
      (WidgetTester tester) async {
    await seed();
    await pumpRecords(tester);

    await tester.tap(find.widgetWithText(SketchTag, '未分类'));
    await settle(tester);

    expect(find.text('未分类一'), findsOneWidget);
    expect(find.text('周报一'), findsNothing);
    expect(find.text('生活一'), findsNothing);
  });
}

class _Seed {
  const _Seed({
    required this.workId,
    required this.childId,
    required this.lifeId,
    required this.aId,
    required this.bId,
    required this.cId,
    required this.dId,
    required this.syncId,
    required this.importantId,
  });

  final String workId;
  final String childId;
  final String lifeId;
  final String aId;
  final String bId;
  final String cId;
  final String dId;
  final String syncId;
  final String importantId;
}
