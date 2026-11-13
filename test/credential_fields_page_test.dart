import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/vault/credential_models.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/features/vault/credential_fields_page.dart';

import 'support/test_harness.dart';

/// 自定义字段编辑页：真实字段级加密读写 / 模板 / secret / 排序。
void main() {
  late TestApp app;
  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<String> seed() async {
    const id = 'cred-fields';
    await app.gateway.writeEntry(EntryWrite.create(
      id: id,
      kind: EntryKind.credential,
      title: '字段账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: id),
        );
    return id;
  }

  Future<void> pumpPage(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: MaterialApp(
        theme: SketchTheme.light,
        home: CredentialFieldsPage(credentialId: id, title: '字段账号'),
      ),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('新增/编辑/保存字段后真实加密落库并可解回',
      (WidgetTester tester) async {
    final id = await seed();
    await pumpPage(tester, id);

    await tester.tap(find.text('新增字段'));
    await tester.pump(const Duration(milliseconds: 100));
    // Passkey 登记卡片也有 4 个输入框；动态字段用固定 hint 区分。
    // hintText 不是 child Text，用 decoration 精确匹配。
    final dynamicFields = find.byWidgetPredicate(
      (Widget w) =>
          w is TextField &&
          (w.decoration?.hintText == '字段名' ||
              w.decoration?.hintText == '字段值'),
    );
    expect(dynamicFields, findsNWidgets(2));
    await tester.enterText(dynamicFields.at(0), '备用邮箱');
    await tester.enterText(dynamicFields.at(1), 'me@example.com');
    await tester.tap(find.text('保存全部字段'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final repo = CredentialRepository(app.db, app.gateway);
    final loaded = await repo.customFields(id);
    expect(loaded.fields, hasLength(1));
    expect(loaded.fields.single.label, '备用邮箱');
    expect(loaded.fields.single.value, 'me@example.com');
    final row = (await app.db.select(app.db.credentials).get()).single;
    expect(row.customFields, isNotNull);
    expect(row.customFields, isNot(contains('me@example.com')),
        reason: '字段值不能以明文落库');
  });

  testWidgets('套用模板新增字段，secret 字段默认掩码且可显示',
      (WidgetTester tester) async {
    final id = await seed();
    await pumpPage(tester, id);

    await tester.tap(find.text('开发平台'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('secret 字段'), findsNothing);
    // 4 个 Passkey 输入 + 模板 3×2 个动态字段输入。
    expect(find.byType(TextField), findsNWidgets(10));
    // 开发平台模板只有 1 个 secret（API Token）；切成普通字段后
    // 保存，应验证 toggle 真的落库，而不是误断言仍有 secret。
    await tester.tap(find.text('秘密字段'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('普通字段'), findsWidgets);

    await tester.tap(find.text('保存全部字段'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final loaded = await CredentialRepository(app.db, app.gateway)
        .customFields(id);
    expect(loaded.fields, hasLength(3));
    expect(loaded.fields.any((CredentialField f) => f.secret), isFalse);
    expect(loaded.fields.any((CredentialField f) => !f.secret), isTrue);
  });

  testWidgets('删除与上下移会改变保存后的 sort',
      (WidgetTester tester) async {
    final id = await seed();
    final repo = CredentialRepository(app.db, app.gateway);
    await repo.setCustomFields(
      id,
      const CustomFields(<CredentialField>[
        CredentialField(
          id: 'a', label: 'A', value: '1',
          type: CustomFieldType.text, secret: false, sort: 0,
        ),
        CredentialField(
          id: 'b', label: 'B', value: '2',
          type: CustomFieldType.text, secret: false, sort: 1,
        ),
      ]),
    );
    await pumpPage(tester, id);

    await tester.tap(find.text('下移').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('保存全部字段'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final reordered = await repo.customFields(id);
    expect(reordered.fields.first.id, 'b');

    await tester.tap(find.text('删除').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('保存全部字段'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final removed = await repo.customFields(id);
    expect(removed.fields, hasLength(1));
  });
}
