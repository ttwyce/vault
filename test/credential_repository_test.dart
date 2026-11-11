import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/credential_models.dart';
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
    repo = CredentialRepository(app.db);
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

}
