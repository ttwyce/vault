import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/features/vault/vault_page.dart';

import 'support/test_harness.dart';

/// 密码页「新增」按钮真实接线测试。
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> pumpVault(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: Scaffold(body: VaultPage())),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('空库显示真实空状态，不是写死的假账号',
      (WidgetTester tester) async {
    await pumpVault(tester);
    expect(find.textContaining('0 个'), findsWidgets);
    expect(find.text('GitHub'), findsNothing);
    expect(find.text('Cloudflare'), findsNothing);
    expect(find.text('还没有账号'), findsOneWidget);
  });

  testWidgets('新增账号写 kind=6 entry + credential 行，列表刷新',
      (WidgetTester tester) async {
    await pumpVault(tester);
    await tester.tap(find.text('新增'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).last, '测试账号');
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final entries = await (app.db.select(app.db.entries)
          ..where((t) => t.kind.equals(EntryKind.credential.code)))
        .get();
    expect(entries, hasLength(1));
    expect(entries.single.title, '测试账号');
    final credentials = await app.db.select(app.db.credentials).get();
    expect(credentials, hasLength(1));
    expect(credentials.single.id, entries.single.id);
    expect(find.text('测试账号'), findsOneWidget);
    expect(find.textContaining('1 个'), findsWidgets);
  });
}
