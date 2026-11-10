import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/editor/editor_page.dart';

import 'support/test_harness.dart';

/// 编辑器的分类 / 标签选择测试。
void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
  });

  tearDown(() async {
    await app.dispose();
  });

  Future<void> pumpEditor(WidgetTester tester, {String? entryId}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => EditorPage(entryId: entryId),
                  ));
                },
                child: const Text('打开编辑器'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('打开编辑器'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('新建时选分类与标签，保存后关联落库',
      (WidgetTester tester) async {
    final cat = await app.gateway
        .writeCategory(CategoryWrite.create(name: '工作'));
    final tag =
        await app.gateway.writeTag(TagWrite.create(name: '同步'));

    await pumpEditor(tester);

    await tester.tap(find.text('未分类'));
    await settle(tester);
    await tester.tap(find.text('工作'));
    await settle(tester);

    await tester.tap(find.text('＋ 标签'));
    await settle(tester);
    await tester.tap(find.byType(CheckboxListTile));
    await settle(tester);
    await tester.tap(find.text('完成'));
    await settle(tester);

    await tester.enterText(find.byType(TextField).at(0), '带分类的笔记');
    await tester.enterText(find.byType(TextField).at(1), '正文');
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    final rows = await app.repo.list();
    expect(rows, hasLength(1));
    final id = rows.single.id;
    expect(await app.taxonomyRepo.categoryForEntry(id), cat.snapshot.id);
    expect(await app.taxonomyRepo.tagIdsForEntry(id),
        contains(tag.snapshot.id));
  });

  testWidgets('编辑已有条目时不改动关联，保存后关联仍保留',
      (WidgetTester tester) async {
    final cat = await app.gateway
        .writeCategory(CategoryWrite.create(name: '工作'));
    final tag =
        await app.gateway.writeTag(TagWrite.create(name: '同步'));
    final entry = await app.gateway.writeEntry(
      EntryWrite.create(title: '旧标题', body: '旧正文'),
    );
    final id = entry.snapshot.id;
    await app.gateway.setEntryTaxonomy(
      entryId: id,
      categoryId: cat.snapshot.id,
      tagIds: <String>[tag.snapshot.id],
    );

    await pumpEditor(tester, entryId: id);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('#同步'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '改过的正文');
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(await app.taxonomyRepo.categoryForEntry(id), cat.snapshot.id);
    expect(await app.taxonomyRepo.tagIdsForEntry(id),
        contains(tag.snapshot.id));
  });
}
