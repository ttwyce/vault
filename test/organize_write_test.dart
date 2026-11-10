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
}
