import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/data/vault/totp_setup.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/vault/totp_setup_page.dart';
import 'package:vault/features/vault/vault_page.dart';

import 'support/test_harness.dart';

/// 分组拖拽与 TOTP 绑定（docs/09 §8 / docs/11 §4.4）。
void main() {
  late TestApp app;
  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<String> seed({String id = 'cred-x'}) async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: id,
      kind: EntryKind.credential,
      title: '账号 $id',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: id),
        );
    return id;
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(theme: SketchTheme.light, home: page),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test('otpauth URI 与 Base32 密钥解析', () {
    final parsed = parseOtpauthUri(
      'otpauth://totp/GitHub:alice?secret=jbswy3dpehpk3pxp&issuer=GitHub',
    );
    expect(parsed, isNotNull);
    expect(parsed!.secret, 'JBSWY3DPEHPK3PXP');
    expect(parsed.label, 'GitHub:alice');
    expect(normalizeTotpSecret('jbsw-y3dp ehpk3pxp'), 'JBSWY3DPEHPK3PXP');
    expect(parseOtpauthUri('https://example.com'), isNull);
    expect(parseOtpauthUri('otpauth://totp/x?secret=!!!'), isNull);
    expect(normalizeTotpSecret('含中文'), isNull);
  });

  testWidgets('TOTP 页面保存 otpauth 后生成真实验证码并加密落库',
      (WidgetTester tester) async {
    final id = await seed();
    await pumpPage(
      tester,
      TotpSetupPage(credentialId: id, title: '账号 $id'),
    );
    await tester.enterText(
      find.byType(TextField),
      'otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
    );
    await tester.tap(find.text('保存密钥'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('TOTP 已加密保存'), findsOneWidget);
    final row = (await app.db.select(app.db.credentials).get())
        .where((CredentialRow r) => r.id == id)
        .single;
    expect(row.totpSecret, isNotNull);
    expect(row.totpSecret, isNot(contains('JBSWY3DPEHPK3PXP')));
    final summary =
        await CredentialRepository(app.db, app.gateway).listSummaries();
    expect(summary.single.totpCode, isNotNull);
    expect(summary.single.totpCode, hasLength(6));
    final entry = await (app.db.select(app.db.entries)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(entry.meta, contains('has_totp'));
  });

  testWidgets('密码页存在可拖拽卡片与分组 DragTarget',
      (WidgetTester tester) async {
    await seed();
    await app.gateway.writeCategory(CategoryWrite.create(
      id: 'cat-work',
      name: '工作',
      kind: EntryKind.credential,
    ));
    await app.gateway.setEntryTaxonomy(
      entryId: 'cred-x',
      categoryId: 'cat-work',
    );
    await pumpPage(tester, const VaultPage());

    expect(find.byType(Draggable<String>), findsWidgets);
    expect(find.byType(DragTarget<String>), findsWidgets);
    expect(find.text('工作'), findsWidgets);
  });
}
