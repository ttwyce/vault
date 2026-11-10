import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/taxonomy_tables.dart';
import 'package:vault/features/organize/organize_page.dart';

import 'support/test_harness.dart';

/// 组织页测试（本轮只读展示）。
///
/// 分类 / 标签没有公开写 API，测试数据直接 `app.db.into(...)` 插入。
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

    await tester.pumpWidget(ProviderScope(
      parent: app.container,
      child: const MaterialApp(home: OrganizePage()),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('显示分类名称与条目数', (WidgetTester tester) async {
    await app.db.into(app.db.categories).insert(
          CategoriesCompanion.insert(
            id: 'c1',
            kind: 1,
            name: '工作',
            hlc: 'x',
            entryCount: const Value(5),
          ),
        );

    await pumpOrganize(tester);

    expect(find.text('工作'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('标签云显示名称与使用次数', (WidgetTester tester) async {
    await app.db.into(app.db.tags).insert(
          TagsCompanion.insert(
            id: 't1',
            name: 'flutter',
            hlc: 'x',
            usageCount: const Value(3),
          ),
        );

    await pumpOrganize(tester);

    expect(find.text('flutter · 3'), findsOneWidget);
  });

  testWidgets('两级分类树都渲染出来', (WidgetTester tester) async {
    await app.db.into(app.db.categories).insert(
          CategoriesCompanion.insert(
            id: 'c1',
            kind: 1,
            name: '工作',
            hlc: 'x',
          ),
        );
    await app.db.into(app.db.categories).insert(
          CategoriesCompanion.insert(
            id: 'c2',
            kind: 1,
            name: '开发',
            parentId: const Value('c1'),
            hlc: 'x',
          ),
        );

    await pumpOrganize(tester);

    expect(find.text('工作'), findsOneWidget);
    expect(find.text('开发'), findsOneWidget);
  });

  testWidgets('无数据时显示两个空状态', (WidgetTester tester) async {
    await pumpOrganize(tester);

    expect(find.text('还没有分类'), findsOneWidget);
    expect(find.text('还没有标签'), findsOneWidget);
  });
}
