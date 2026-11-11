import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/credential_models.dart';
import 'package:vault/data/vault/hibp_client.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// 密码健康报告必须只返回统计，且走真实 credential 表。
void main() {
  late TestApp app;
  late CredentialRepository repo;

  setUp(() async {
    app = await TestApp.create(now: () => 1731052800000);
    repo = CredentialRepository(app.db, app.gateway);
  });
  tearDown(() async => app.dispose());

  Future<void> add(
    String id, {
    String? password,
    int breached = 0,
    int? changedAt,
  }) async {
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(
            id: id,
            password: Value<String?>(password),
            breached: Value<int>(breached),
            passwordChangedAt: Value<int?>(changedAt),
          ),
        );
  }

  test('空库健康报告全 0', () async {
    final health = await repo.health(nowMs: 1731052800000);
    expect(health.total, 0);
    expect(health.weak, 0);
    expect(health.leaked, 0);
  });

  test('弱 / 重复 / 泄露 / 超期统计，报告不含任何明文', () async {
    await add('c1', password: 'same-weak', changedAt: 1000);
    await add('c2', password: 'same-weak', breached: 2,
        changedAt: 1731052800000);
    await add('c3', password: 'Qwerty!2026#Long',
        changedAt: 1731052800000 - 1000);
    final health = await repo.health(nowMs: 1731052800000);
    expect(health.total, 3);
    expect(health.reused, 2, reason: '相同密码算重复');
    expect(health.leaked, 1, reason: 'breached=2 才算泄露');
    expect(health.outdated, 1, reason: 'passwordChangedAt 很旧');
    final json = health.toJson().toString();
    expect(json, isNot(contains('same-weak')));
    expect(json, isNot(contains('Qwerty')));
  });

  test('samples 的指纹不是明文', () async {
    await add('c1', password: 'hunter2');
    final samples = await repo.samples();
    expect(samples.single.passwordFingerprint, isNot('hunter2'));
    expect(samples.single.strength,
        estimatePasswordStrength('hunter2'));
  });
  test('listSummaries 从真实 entry 取标题，不含密码且跳过已删除', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-a',
      kind: EntryKind.credential,
      title: 'GitHub',
    ));
    await add('cred-a', password: 'hunter2');
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-b',
      kind: EntryKind.credential,
      title: '已删账号',
    ));
    await app.gateway.writeEntry(EntryWrite.delete(id: 'cred-b'));
    await add('cred-b', password: 'x');

    final items = await repo.listSummaries();
    expect(items, hasLength(1));
    expect(items.single.title, 'GitHub');
    expect(items.single.letter, 'G');
    expect(items.single.hasTotp, isFalse);
    expect(items.single.toString(), isNot(contains('hunter2')));
  });


  test('listSummaries 生成 TOTP 验证码但绝不外泄密钥', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-totp',
      kind: EntryKind.credential,
      title: '带 2FA 的账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(
            id: 'cred-totp',
            totpSecret: const Value<String?>(
                'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'),
          ),
        );
    final items = await repo.listSummaries(nowMs: 59000);
    expect(items.single.totpCode, '287082',
        reason: 'RFC 6238 8 位 94287082 的 6 位后缀');
    expect(items.single.toString(),
        isNot(contains('GEZDGNBVGY3TQOJQ')));
  });

  test('字段级加密：明文不落库，篡改 AAD 头会认证失败', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-enc',
      kind: EntryKind.credential,
      title: '加密账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-enc'),
        );
    await repo.setPassword('cred-enc', 'CorrectHorse!2026');

    final row = await (app.db.select(app.db.credentials)
          ..where((t) => t.id.equals('cred-enc')))
        .getSingle();
    expect(row.password, isNot('CorrectHorse!2026'));
    expect(row.password, isNot(contains('CorrectHorse')));
    expect(row.passwordChangedAt, isNotNull);

    // 健康报告能解出明文做强度估算，但对外只给统计。
    final health = await repo.health(nowMs: 1731052800000);
    expect(health.total, 1);
    expect(health.toJson().toString(), isNot(contains('CorrectHorse')));

    // 与另一个账号的密文互换 → AAD 绑定失败，绝不误解密。
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-other'),
        );
    await (app.db.update(app.db.credentials)
          ..where((t) => t.id.equals('cred-other')))
        .write(CredentialsCompanion(password: Value<String?>(row.password)));
    final other = await (app.db.select(app.db.credentials)
          ..where((t) => t.id.equals('cred-other')))
        .getSingle();
    await expectLater(
      app.gateway.openCredentialField(
        other.password!,
        credentialId: 'cred-other',
        field: 'password',
      ),
      throwsA(isA<Object>()),
    );
  });

  test('TOTP 密钥与 secret 自定义字段也走同一加密通道', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred-fields',
      kind: EntryKind.credential,
      title: '带密钥的账号',
    ));
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-fields'),
        );
    await repo.setTotpSecret(
      'cred-fields',
      'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
    );
    const fields = CustomFields(<CredentialField>[
      CredentialField(
        id: 'f1',
        label: '恢复码',
        value: 'xxxx-yyyy',
        type: CustomFieldType.text,
        secret: true,
        sort: 0,
      ),
    ]);
    await repo.setCustomFields('cred-fields', fields);

    final row = await (app.db.select(app.db.credentials)
          ..where((t) => t.id.equals('cred-fields')))
        .getSingle();
    expect(row.totpSecret, isNot(contains('GEZDGNBVGY3TQOJQ')));
    expect(row.customFields, isNot(contains('xxxx-yyyy')));
    expect(row.customFields, isNot(contains('恢复码')));

    final back = await repo.customFields('cred-fields');
    expect(back.fields.single.value, 'xxxx-yyyy');
    expect(back.fields.single.secret, isTrue);

    final summaries = await repo.listSummaries(nowMs: 59000);
    expect(summaries.single.totpCode, '287082',
        reason: '加密密钥仍能正确生成 RFC 6238 验证码');

    expect(
      () => repo.setTotpSecret('cred-fields', 'ABC1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('HIBP 离线判定：只比对后缀，命中写 breached=2、未命中写 1', () async {
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-hibp'),
        );
    await repo.setPassword('cred-hibp', 'password');
    final request = HibpChecker().requestFor('password');

    final hit = await repo.applyHibpResponse(
      'cred-hibp',
      responseBody: '${request.suffix}:12345\n',
      nowMs: 1731052800000,
    );
    expect(hit, isTrue);
    var row = await (app.db.select(app.db.credentials)
          ..where((t) => t.id.equals('cred-hibp')))
        .getSingle();
    expect(row.breached, 2);
    expect((await repo.health(nowMs: 1731052800000)).leaked, 1);

    final miss = await repo.applyHibpResponse(
      'cred-hibp',
      responseBody: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF:1\n',
      nowMs: 1731052800000,
    );
    expect(miss, isFalse);
    row = await (app.db.select(app.db.credentials)
          ..where((t) => t.id.equals('cred-hibp')))
        .getSingle();
    expect(row.breached, 1);
    expect((await repo.health(nowMs: 1731052800000)).leaked, 0);
  });
}
