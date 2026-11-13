import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/taxonomy/taxonomy_models.dart';
import 'package:vault/data/vault/credential_group_repository.dart';
import 'package:vault/data/vault/credential_models.dart';
import 'package:vault/data/db/tables/log_tables.dart';

import 'support/test_harness.dart';

/// docs/11 §4.6 账号分组与字段模板测试。
void main() {
  late TestApp app;
  late CredentialGroupRepository repo;

  setUp(() async {
    app = await TestApp.create();
    repo = CredentialGroupRepository(db: app.db, gateway: app.gateway);
  });
  tearDown(() async => app.dispose());

  test('groups 只返回 kind=6 的未删除分类', () async {
    await app.gateway.writeCategory(
        CategoryWrite.create(name: '笔记分类'));
    final parent = await app.gateway.writeCategory(CategoryWrite.create(
      name: '工作',
      kind: EntryKind.credential,
    ));
    await app.gateway.writeCategory(CategoryWrite.create(
      name: '开发',
      kind: EntryKind.credential,
      parentId: parent.snapshot.id,
    ));
    final groups = await repo.groups();
    expect(groups, hasLength(2));
    expect(groups.every((r) => r.kind == EntryKind.credential.code), isTrue);
  });

  test('模板字段去重、按 sortOrder 读回，实例化 secret 空字段', () async {
    await repo.addTemplateField(
      categoryId: 'g1',
      label: '恢复码',
      type: 'secret',
      secret: true,
      sortOrder: 1,
    );
    await repo.addTemplateField(
      categoryId: 'g1',
      label: '服务器',
      type: 'url',
      sortOrder: 0,
    );
    expect(
      () => repo.addTemplateField(categoryId: 'g1', label: '恢复码'),
      throwsA(isA<FormatException>()),
    );
    final rows = await repo.templateFields('g1');
    expect(rows.map((r) => r.label).toList(), <String>['服务器', '恢复码']);
    expect(rows.last.secret, isTrue);

    final fields = await repo.instantiateForGroup('g1');
    expect(fields.fields, hasLength(2));
    expect(fields.fields.first.type, CustomFieldType.url);
    expect(fields.fields.first.value, isEmpty);
    expect(fields.fields.last.secret, isTrue);
    expect(fields.fields.last.value, isEmpty);
  });

  test('模板写入走 WriteGateway 并产生 taxonomy oplog', () async {
    await repo.addTemplateField(
      categoryId: 'g1',
      label: '令牌',
      type: 'text',
      secret: true,
    );
    final rows = await app.db.select(app.db.oplogs).get();
    expect(
      rows.any((r) =>
          r.entity == SyncEntity.categoryFieldTemplate &&
          r.entityId.isNotEmpty),
      isTrue,
      reason: '模板必须进 oplog 才能跨设备同步',
    );
    expect(
      (await app.db.select(app.db.categoryFieldTemplates).get()).single.label,
      '令牌',
    );
  });

  test('无分组 / 无模板返回空字段；空 label 拒绝', () async {
    expect((await repo.instantiateForGroup(null)).fields, isEmpty);
    expect((await repo.instantiateForGroup('missing')).fields, isEmpty);
    expect(
      () => repo.addTemplateField(categoryId: 'g1', label: '  '),
      throwsA(isA<FormatException>()),
    );
  });
}
