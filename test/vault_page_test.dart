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
import 'package:vault/data/vault/credential_meta.dart';
import 'package:vault/data/vault/hibp_client.dart';
import 'package:vault/data/vault/http_hibp_client.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/core/widgets/secure_card.dart';
import 'package:vault/features/vault/vault_page.dart';

import 'support/test_harness.dart';

/// 密码页「新增」按钮真实接线测试。
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> pumpVault(
    WidgetTester tester, {
    HttpHibpClient Function()? hibpClientFactory,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(
        home: Scaffold(
          body: VaultPage(hibpClientFactory: hibpClientFactory),
        ),
      ),
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
    final groupRepo = CredentialGroupRepository(db: app.db, gateway: app.gateway);
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
    final entry = await app.repo.getRow(rows.single.id);
    expect(
      CredentialMeta.fromJson(entry!.meta).categoryHint,
      '工作开发',
    );
  });

  testWidgets('带 TOTP 的账号详情提供复制且注明 30 秒清除',
      (WidgetTester tester) async {
    final repo = CredentialRepository(app.db, app.gateway);
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-totp-ui',
      kind: EntryKind.credential,
      title: 'TOTP 账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-totp-ui'),
        );
    await repo.setTotpSecret(
      'cred-totp-ui',
      'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
    );
    await pumpVault(tester);
    await tester.tap(find.text('TOTP 账号'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('当前 TOTP：'), findsOneWidget);
    expect(find.text('复制当前 TOTP（30 秒后清除）'), findsOneWidget);
    await tester.tap(find.text('复制当前 TOTP（30 秒后清除）'));
    await tester.pump(const Duration(milliseconds: 300));
    // SensitiveClipboard 的 30 秒定时器在测试环境不推进；这里只保证点击不抛异常。
    expect(tester.takeException(), isNull);
  });

  testWidgets('备注可切换 Markdown 预览，返回编辑仍可保存',
      (WidgetTester tester) async {
    final repo = CredentialRepository(app.db, app.gateway);
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-notes-preview',
      kind: EntryKind.credential,
      title: '备注账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-notes-preview'),
        );
    await pumpVault(tester);
    await tester.tap(find.text('备注账号'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.widgetWithText(TextField, '加粗 / 列表用 Markdown 写'),
      '**重点**',
    );
    await tester.tap(find.text('预览备注'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('返回编辑'), findsOneWidget);
    await tester.tap(find.text('返回编辑'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('预览备注'), findsOneWidget);
    await tester.tap(find.text('保存备注'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await repo.notes('cred-notes-preview'), '**重点**');
  });

  testWidgets('详情提供密码复制通道，且页面始终不展示明文',
      (WidgetTester tester) async {
    final repo = CredentialRepository(app.db, app.gateway);
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-copy',
      kind: EntryKind.credential,
      title: '可复制账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-copy'),
        );
    await repo.setPassword('cred-copy', 'MySecret!234');
    await pumpVault(tester);
    await tester.tap(find.text('可复制账号'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('复制密码（30 秒后清除）'), findsOneWidget);
    expect(find.text('MySecret!234'), findsNothing);
    expect(await repo.passwordForClipboard('cred-copy'), 'MySecret!234');
    await tester.tap(find.text('复制密码（30 秒后清除）'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('MySecret!234'), findsNothing);
  });

  testWidgets('详情可编辑账号资料且以密文落库', (WidgetTester tester) async {
    final repo = CredentialRepository(app.db, app.gateway);
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-profile-ui',
      kind: EntryKind.credential,
      title: '资料账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-profile-ui'),
        );
    await pumpVault(tester);
    await tester.tap(find.text('资料账号'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('编辑资料'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.widgetWithText(TextField, '用户名'),
      'alice@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '网址'),
      'https://example.com',
    );
    await tester.tap(find.text('保存资料'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final row = await (app.db.select(app.db.credentials)
          ..where((t) => t.id.equals('cred-profile-ui')))
        .getSingle();
    expect(row.username, isNot(contains('alice@example.com')));
    final profile = await repo.profile('cred-profile-ui');
    expect(profile.username, 'alice@example.com');
    expect(profile.url, 'https://example.com');
  });

  testWidgets('分类芯片按真实 entry_category 过滤账号（父级含子分类）',
      (WidgetTester tester) async {
    await app.gateway.writeCategory(CategoryWrite.create(
      id: 'c-work',
      name: '工作',
      kind: EntryKind.credential,
    ));
    await app.gateway.writeCategory(CategoryWrite.create(
      id: 'c-dev',
      name: '开发',
      parentId: 'c-work',
      kind: EntryKind.credential,
    ));
    for (final id in <String>['cred-cat-a', 'cred-cat-b']) {
      await app.gateway.writeEntry(EntryWrite.create(
        id: id,
        kind: EntryKind.credential,
        title: id,
      ));
      await app.db.into(app.db.credentials).insert(
            CredentialsCompanion.insert(id: id),
          );
    }
    await app.gateway.setEntryTaxonomy(
      entryId: 'cred-cat-a',
      categoryId: 'c-dev',
      tagIds: const <String>[],
    );
    await pumpVault(tester);
    expect(find.text('cred-cat-a'), findsOneWidget);
    expect(find.text('cred-cat-b'), findsOneWidget);
    await tester.tap(find.text('工作'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('cred-cat-a'), findsOneWidget);
    expect(find.text('cred-cat-b'), findsNothing);
  });

  testWidgets('健康卡「检查泄露」逐条真实 HIBP 检查并落库',
      (WidgetTester tester) async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-ui-hibp',
      kind: EntryKind.credential,
      title: '在线检查账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-ui-hibp'),
        );
    final repo = CredentialRepository(app.db, app.gateway);
    await repo.setPassword('cred-ui-hibp', 'Hunter2!long');
    final checker = HibpChecker();
    final request = checker.requestFor('Hunter2!long');

    await pumpVault(
      tester,
      hibpClientFactory: () =>
          _FakeHibpHit(checker.parseResponse('${request.suffix}:7')),
    );
    await tester.tap(find.text('检查泄露 →'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final row = await (app.db.select(app.db.credentials)
          ..where((t) => t.id.equals('cred-ui-hibp')))
        .getSingle();
    expect(row.breached, 2);
    expect(find.textContaining('已完成'), findsWidgets);
  });
}

class _FakeHibpHit extends HttpHibpClient {
  _FakeHibpHit(this._suffixes);

  final Set<String> _suffixes;

  @override
  Future<HibpFetchResult> fetchRange(HibpRequest request) async =>
      HibpFetchResult(
        body: <String>[
          for (final suffix in _suffixes) '$suffix:7',
        ].join('\r\n'),
        hint: 'fake HIBP',
      );

  @override
  void close({bool force = true}) {}
}
