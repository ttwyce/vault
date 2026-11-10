import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/widgets/sketch_controls.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/history/history_page.dart';
import 'package:vault/features/trash/trash_page.dart';

import 'support/test_harness.dart';

/// 回收站与历史版本的页面测试。
void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
  });

  tearDown(() async {
    await app.dispose();
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(home: page),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('回收站显示已删除条目，点恢复后清空', (WidgetTester tester) async {
    final created = await app.gateway.writeEntry(
      EntryWrite.create(title: '待删', body: '内容'),
    );
    await app.gateway.writeEntry(EntryWrite.delete(id: created.snapshot.id));

    await pumpPage(tester, const TrashPage());

    expect(find.text('待删'), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);

    await tester.tap(find.text('恢复'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(await app.taxonomyRepo.trash(), isEmpty);
    expect((await app.repo.getRow(created.snapshot.id))!.deleted, 0);
  });

  testWidgets('回收站为空时显示空状态', (WidgetTester tester) async {
    await pumpPage(tester, const TrashPage());
    expect(find.text('回收站是空的'), findsOneWidget);
  });

  testWidgets('历史版本可恢复，生成新 rev 而不倒退', (WidgetTester tester) async {
    final created = await app.gateway.writeEntry(
      EntryWrite.create(title: 'v1', body: '甲'),
    );
    final id = created.snapshot.id;
    await app.gateway.writeEntry(
      EntryWrite.update(id: id, title: 'v2', body: '乙'),
    );

    await pumpPage(tester, HistoryPage(entryId: id));

    expect(find.text('r1'), findsOneWidget);
    expect(find.text('v1'), findsOneWidget);

    await tester.tap(find.text('恢复此版本'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    final row = await app.repo.getRow(id);
    expect(row!.body, '甲');
    expect(row.rev, 3);
  });

  testWidgets('回收站里的条目禁止回滚，先提示恢复', (WidgetTester tester) async {
    final created = await app.gateway.writeEntry(
      EntryWrite.create(title: 'v1', body: '甲'),
    );
    final id = created.snapshot.id;
    await app.gateway.writeEntry(
      EntryWrite.update(id: id, title: 'v2', body: '乙'),
    );
    await app.gateway.writeEntry(EntryWrite.delete(id: id));

    await pumpPage(tester, HistoryPage(entryId: id));

    expect(find.textContaining('请先恢复条目'), findsOneWidget);
    // 删除前编辑过一次，历史里会有多个版本；每个按钮都必须禁用，
    // 不能只取第一个（tester.widget 遇到多个会抛 Too many elements）。
    final buttons = tester.widgetList<SketchButton>(
      find.widgetWithText(SketchButton, '恢复此版本'),
    ).toList();
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.onPressed, isNull);
    }
  });
}
