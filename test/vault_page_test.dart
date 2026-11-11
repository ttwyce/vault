import 'package:drift/drift.dart' show Value;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/data/vault/credential_models.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/vault/credential_group_repository.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/core/widgets/secure_card.dart';
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
    expect(find.byType(SecureCard), findsNothing);
    expect(find.text('已泄露 0'), findsOneWidget);
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

  testWidgets('新增弹窗生成强密码并以密文落库',
      (WidgetTester tester) async {
    await pumpVault(tester);
    await tester.tap(find.text('新增'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('生成强密码'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('已用 K_item'), findsOneWidget);
    final selectable = find.byType(SelectableText);
    expect(selectable, findsOneWidget);
    final generated = tester.widget<SelectableText>(selectable).data ?? '';
    expect(generated.length, 20);
    expect(generated, matches(RegExp(r'[A-Z]')));
    expect(generated, matches(RegExp(r'[^A-Za-z0-9]')));
    expect(find.textContaining('明文不会落盘'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '生成测试账号');
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final credentials = await app.db.select(app.db.credentials).get();
    expect(credentials, hasLength(1));
    expect(credentials.single.password, isNotNull);
    expect(credentials.single.password, isNot(generated),
        reason: '字段级加密后列里只能是密文');
    expect(credentials.single.password!, isNot(contains(generated)));
    // 仓库能解出原文，但健康报告仍只给统计。
    final repo = CredentialRepository(app.db, app.gateway);
    expect(
      await app.gateway.openCredentialField(
        credentials.single.password!,
        credentialId: credentials.single.id,
        field: 'password',
      ),
      generated,
    );
    final health = await repo.health(nowMs: 1731052800000);
    expect(health.toJson().toString(), isNot(contains(generated)));
  });

  testWidgets('新增时选字段模板，secret 字段以密文落库',
      (WidgetTester tester) async {
    await pumpVault(tester);
    await tester.tap(find.text('新增'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('开发平台').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField).last, '模板账号');
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final repo = CredentialRepository(app.db, app.gateway);
    final rows = await app.db.select(app.db.credentials).get();
    expect(rows, hasLength(1));
    final fields = await repo.customFields(rows.single.id);
    expect(fields.fields, hasLength(3));
    expect(fields.fields.map((CredentialField f) => f.id).toList(),
        <String>['username', 'url', 'token']);
    expect(fields.fields.last.secret, isTrue);
    expect(rows.single.customFields, isNotNull);
    expect(rows.single.customFields, isNot(contains('API Token')),
        reason: '模板标签也不能以明文落库');
  });

  testWidgets('点开账号详情不展示明文，可生成新密码替换',
      (WidgetTester tester) async {
    final repo = CredentialRepository(app.db, app.gateway);
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-ui',
      kind: EntryKind.credential,
      title: '详情 UI 账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-ui'),
        );
    await repo.setPassword('cred-ui', 'OldSecret!2026');
    await pumpVault(tester);

    await tester.tap(find.text('详情 UI 账号'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('此页不展示明文'), findsOneWidget);
    expect(find.textContaining('OldSecret'), findsNothing);

    final before = (await app.db.select(app.db.credentials).get())
        .single
        .password;
    await tester.tap(find.text('生成新密码并替换'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final after = (await app.db.select(app.db.credentials).get())
        .single
        .password;
    expect(after, isNot(before));
    expect(after, isNot('OldSecret!2026'));
  });

  testWidgets('点击已泄露智能分组只显示该组账号', (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'safe',
      kind: EntryKind.credential,
      title: '安全账号',
    ));
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'leaked',
      kind: EntryKind.credential,
      title: '泄露账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'safe'),
        );
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'leaked', breached: const Value<int>(2)),
        );
    await pumpVault(tester);

    expect(find.text('安全账号'), findsOneWidget);
    expect(find.text('泄露账号'), findsOneWidget);
    expect(find.textContaining('已泄露 1'), findsOneWidget);

    await tester.tap(find.textContaining('已泄露 1'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('泄露账号'), findsOneWidget);
    expect(find.text('安全账号'), findsNothing);

    // 再点一次取消筛选。
    await tester.tap(find.textContaining('已泄露 1'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('安全账号'), findsOneWidget);
  });

  testWidgets('详情弹窗可编辑备注且以密文落库', (WidgetTester tester) async {
    final repo = CredentialRepository(app.db, app.gateway);
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-notes-ui',
      kind: EntryKind.credential,
      title: '备注账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-notes-ui'),
        );
    await pumpVault(tester);
    await tester.tap(find.text('备注账号'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('备注（L0 端侧'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '**重点** 公司 VPN');
    await tester.tap(find.text('保存备注'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await repo.notes('cred-notes-ui'), '**重点** 公司 VPN');

    final row = await (app.db.select(app.db.credentials)
          ..where((t) => t.id.equals('cred-notes-ui')))
        .getSingle();
    expect(row.notes, isNot(contains('公司 VPN')));
  });

  testWidgets('新增时选账号分组会自动套用该组字段模板',
      (WidgetTester tester) async {
    final parent = await app.gateway.writeCategory(CategoryWrite.create(
      id: 'g-work',
      name: '工作开发',
      kind: EntryKind.credential,
    ));
    final groupRepo = CredentialGroupRepository(db: app.db, uuid: app.uuid);
    await groupRepo.addTemplateField(
      categoryId: parent.snapshot.id,
      label: '恢复码',
      type: 'secret',
      secret: true,
    );
    await pumpVault(tester);

    await tester.tap(find.text('新增'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // 分组下拉（两个 DropdownButton：模板、分组；等 FutureBuilder 完成）
    expect(find.byType(DropdownButton<String>), findsNWidgets(2));
    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('工作开发').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).last, '分组账号');
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final rows = await app.db.select(app.db.credentials).get();
    expect(rows, hasLength(1));
    final repo = CredentialRepository(app.db, app.gateway);
    final fields = await repo.customFields(rows.single.id);
    expect(fields.fields, hasLength(1));
    expect(fields.fields.single.label, '恢复码');
    expect(fields.fields.single.secret, isTrue);
    expect(fields.fields.single.value, isEmpty);
  });
}
