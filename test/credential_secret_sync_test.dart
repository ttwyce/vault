import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/vault/credential_models.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// T24（docs/09 §12）：账号 secret 字段跨设备同步的本地可判定部分。
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> seed() async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-t24',
      kind: EntryKind.credential,
      title: '共享账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-t24'),
        );
  }

  test('secret 自定义字段加密落库，另一设备读回仍是 secret 且值一致',
      () async {
    await seed();
    final deviceA = CredentialRepository(app.db, app.gateway);
    final fields = CustomFields(const <CredentialField>[
      CredentialField(
        id: 'f1',
        label: '恢复码',
        value: 'ABCD-EFGH-1234',
        type: CustomFieldType.text,
        secret: true,
        sort: 0,
      ),
    ]);
    await deviceA.setCustomFields('cred-t24', fields);

    final row = await (app.db.select(app.db.credentials)
          ..where((t) => t.id.equals('cred-t24')))
        .getSingle();
    expect(row.customFields, isNot(contains('ABCD-EFGH-1234')));

    // 用另一实例模拟设备 B 解密读取。
    final deviceB = CredentialRepository(app.db, app.gateway);
    final back = await deviceB.customFields('cred-t24');
    expect(back.fields, hasLength(1));
    expect(back.fields.single.secret, isTrue);
    expect(back.fields.single.value, 'ABCD-EFGH-1234');
  });

  test('AI 侧工具返回值不携带 secret 明文', () async {
    await seed();
    final repo = CredentialRepository(app.db, app.gateway);
    await repo.setPassword('cred-t24', 'Hunter2!long');
    final secrets = await repo.knownSecretValues();
    expect(secrets, contains('Hunter2!long'));
    expect(
      CredentialGuard.redact(<String, Object?>{
        'custom_fields': 'ABCD-EFGH-1234',
        'password': 'Hunter2!long',
        'title': '共享账号',
      })['custom_fields'],
      '[已隐藏]',
    );
    expect(
      CredentialGuard.containsSecret('这条回答夹带了明文',
          <String>['ABCD-EFGH-1234']),
      isFalse,
    );
  });
}
