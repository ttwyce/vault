import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/entry_tables.dart';
import 'dart:convert';

import 'package:vault/data/diary/diary_meta.dart';
import 'package:vault/data/entry/note_meta.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart' show TagWrite;
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

    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
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
    // 路由 pop 过渡约 300ms，要等它走完再断言 EditorPage 已消失
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

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

  testWidgets('预览按钮切换到实时预览并保留原文', (WidgetTester tester) async {
    await pumpEditor(tester);
    await tester.enterText(
      find.byType(TextField).last,
      '# 标题\n- [x] 完成项',
    );
    await tester.tap(find.text('预览'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('标题'), findsWidgets);
    expect(find.text('完成项'), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);

    await tester.tap(find.text('编辑'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('预览'), findsOneWidget);
  });

  testWidgets('新建日记保存完整 meta（date/word_count/backfilled）',
      (WidgetTester tester) async {
    await pumpEditor(tester, kind: EntryKind.diary);
    await tester.enterText(find.byType(TextField).first, '日记标题');
    await tester.enterText(find.byType(TextField).last, '今天同步成功');
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final rows = await app.db.select(app.db.entries).get();
    expect(rows, hasLength(1));
    final meta = DiaryMeta.fromJson(rows.single.meta);
    expect(meta.date, diaryKey(DateTime.now()));
    expect(meta.wordCount, 6);
    expect(meta.backfilled, isFalse);
  });

  testWidgets('补写过去日期：initialDate 显式落到日记 meta.date',
      (WidgetTester tester) async {
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
                    builder: (_) => const EditorPage(
                      initialKind: EntryKind.diary,
                      initialDate: '2020-01-02',
                    ),
                  ));
                },
                child: const Text('打开补写'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开补写'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField).first, '补写标题');
    await tester.enterText(find.byType(TextField).last, '旧事重记');
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final rows = await app.db.select(app.db.entries).get();
    final meta = DiaryMeta.fromJson(rows.single.meta);
    expect(meta.date, '2020-01-02');
    expect(meta.backfilled, isTrue);
  });

  testWidgets('输入 # 触发行内标签提示', (WidgetTester tester) async {
    await pumpEditor(tester);
    await tester.enterText(find.byType(TextField).last, '看看 #同步');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('输入 #同步'), findsOneWidget);
    expect(find.textContaining('上限 8'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '普通正文');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('输入 #'), findsNothing);
  });

  testWidgets('分类/标签建议只展示、点采纳才写入关联',
      (WidgetTester tester) async {
    await app.gateway.writeTag(TagWrite.create(name: '同步'));
    await pumpEditor(tester);
    await tester.enterText(find.byType(TextField).first, '同步限流');
    await tester.enterText(find.byType(TextField).last, '同步限流重试');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('建议（点采纳'), findsOneWidget);

    // 未点采纳前不写任何关联；点后才写入。
    await tester.tap(find.textContaining('建议（点采纳'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('#同步'), findsWidgets);
  });

  testWidgets('新建笔记保存 pinned/word_count meta',
      (WidgetTester tester) async {
    await pumpEditor(tester);
    await tester.enterText(find.byType(TextField).first, '同步笔记');
    await tester.enterText(find.byType(TextField).last, '今天同步成功');
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final rows = await app.db.select(app.db.entries).get();
    final meta = NoteMeta.fromJson(jsonDecode(rows.single.meta!));
    expect(meta.pinned, isFalse);
    expect(meta.wordCount, 6);
  });

  testWidgets('新建笔记点置顶后保存 meta.pinned=true',
      (WidgetTester tester) async {
    await pumpEditor(tester);
    await tester.enterText(find.byType(TextField).first, '置顶笔记');
    await tester.tap(find.text('置顶'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('已置顶'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final rows = await app.db.select(app.db.entries).get();
    expect(NoteMeta.fromJson(jsonDecode(rows.single.meta!)).pinned, isTrue);
  });

  testWidgets('编辑已有置顶笔记时回显已置顶且保存不丢',
      (WidgetTester tester) async {
    final created = await app.gateway.writeEntry(EntryWrite.create(
      id: 'pinned-edit',
      title: '旧置顶',
      body: '旧正文',
      meta: const NoteMeta(pinned: true, wordCount: 3).toJsonString(),
    ));
    await pumpEditor(tester, entryId: created.snapshot.id);
    expect(find.text('已置顶'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '新的正文内容');
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final row = await app.repo.getRow('pinned-edit');
    final meta = NoteMeta.fromJson(jsonDecode(row!.meta!));
    expect(meta.pinned, isTrue);
    expect(meta.wordCount, 6);
  });
}
