import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/editor/editor_page.dart';

import 'support/test_harness.dart';

/// 编辑器测试。
///
/// 编辑器保存后要 `Navigator.pop`，所以页面必须包在一个能 push 的
/// Navigator 里 —— 直接 pump 成 home 的话，pop 根路由会抛错。
void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
  });

  tearDown(() async {
    await app.dispose();
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? entryId,
    EntryKind kind = EntryKind.note,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      parent: app.container,
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => EditorPage(entryId: entryId, initialKind: kind),
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

  testWidgets('新建：输入标题正文，保存后落库并 pop', (WidgetTester tester) async {
    await pumpEditor(tester);

    // 编辑器里两个 TextField：第 0 个是标题，第 1 个是正文
    await tester.enterText(find.byType(TextField).at(0), '第一篇');
    await tester.enterText(find.byType(TextField).at(1), '正文内容');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(EditorPage), findsNothing, reason: '保存成功后应该 pop');

    final rows = await app.repo.list(kind: EntryKind.note);
    expect(rows.length, 1);
    expect(rows.single.title, '第一篇');
    expect(rows.single.snippet, contains('正文内容'));
  });

  testWidgets('编辑：预填旧内容，改正文后 rev 递增', (WidgetTester tester) async {
    final created = await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.note,
      title: '旧标题',
      body: '旧正文',
    ));

    await pumpEditor(tester, entryId: created.snapshot.id);

    expect(find.text('旧标题'), findsOneWidget, reason: '标题输入框要预填');
    await tester.enterText(find.byType(TextField).at(1), '新正文');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final row = await app.repo.getRow(created.snapshot.id);
    expect(row, isNotNull);
    expect(row!.body, '新正文');
    expect(row.rev, 2, reason: '编辑要产生新版本');
    expect(row.title, '旧标题');
  });

  testWidgets('编辑时保留 meta（日记日期不能被清掉）', (WidgetTester tester) async {
    final created = await app.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.diary,
      title: '日记',
      body: '内容',
      meta: '{"date":"2026-11-08"}',
    ));

    await pumpEditor(tester, entryId: created.snapshot.id);
    await tester.enterText(find.byType(TextField).at(1), '改过的内容');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final row = await app.repo.getRow(created.snapshot.id);
    expect(row!.meta, contains('2026-11-08'), reason: 'meta 里存着日记日期，不能丢');
  });

  testWidgets('标题为空时用正文首行兜底', (WidgetTester tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.enterText(find.byType(TextField).at(1), '第一行\n第二行');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final rows = await app.repo.list(kind: EntryKind.note);
    expect(rows.single.title, '第一行');
  });
}
