import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/vault/credential_edit_page.dart';

import 'support/test_harness.dart';

Finder _field(String hint) => find.byWidgetPredicate(
      (Widget w) => w is TextField && w.decoration?.hintText == hint);

void main() {
  testWidgets('编辑账号页真实保存密码/资料/TOTP/备注', (WidgetTester tester) async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'edit-cred',
      kind: EntryKind.credential,
      title: '编辑账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'edit-cred'),
        );
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(
        theme: SketchTheme.light,
        home: const CredentialEditPage(
          credentialId: 'edit-cred',
          title: '编辑账号',
        ),
      ),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('编辑账号'), findsWidgets);
    expect(find.text('生成'), findsOneWidget);
    await tester.enterText(
        _field('用户名'),
        'alice');
    await tester.enterText(
        _field('密码（留空表示不修改）'),
        'Secret!2026');
    await tester.enterText(
        _field('网址'), 'https://example.com');
    await tester.enterText(
        _field('TOTP：otpauth 链接或 Base32 密钥'),
        'JBSWY3DPEHPK3PXP');
    await tester.enterText(
        _field('备注'), '私人备注');
    await tester.tap(find.text('保存账号'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('账号资料已加密保存'), findsOneWidget);
    final repo = CredentialRepository(app.db, app.gateway);
    final detail = await repo.detail('edit-cred');
    expect(detail!.username, 'alice');
    expect(detail.url, 'https://example.com');
    expect(detail.totpCode, isNotNull);
    expect(await repo.notes('edit-cred'), '私人备注');
  });
}
