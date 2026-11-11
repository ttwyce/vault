import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/agent_policy.dart';
import 'package:vault/data/agent/agent_tools.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/entry/entry_repository.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// docs/07 §3 / §4 具体工具集接真实仓库测试。
void main() {
  late TestApp app;
  late AgentToolRegistry registry;

  setUp(() async {
    app = await TestApp.create(now: () => 1731052800000);
    registry = buildDefaultToolRegistry(AgentToolDeps(
      entries: EntryRepository(app.db),
      credentials: CredentialRepository(app.db, app.gateway),
      gateway: app.gateway,
    ));
  });
  tearDown(() async => app.dispose());

  ToolCallContext ctx({
    Map<String, Object?> args = const <String, Object?>{},
    bool confirmed = false,
    bool cloud = false,
    bool mcpRemote = false,
    int? entryKind,
    Iterable<String> secrets = const <String>[],
  }) =>
      ToolCallContext(
        args: args,
        cloudModel: cloud,
        privacy: PrivacyLevel.l1,
        knownSecrets: secrets,
        userConfirmed: confirmed,
        privacyAuthorized: false,
        mcpRemote: mcpRemote,
        entryKind: entryKind,
      );

  test('注册表导出 4 个工具的 schema', () {
    expect(registry.length, 4);
    final names = registry.schemas()
        .map((Map<String, Object?> s) => s['name'] as String)
        .toSet();
    expect(names, <String>{
      'credential_health',
      'search_entries',
      'get_entry',
      'create_note',
    });
  });

  test('credential_health 只给聚合统计，不含任何明文', () async {
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'c1'),
        );
    await CredentialRepository(app.db, app.gateway)
        .setPassword('c1', 'Secret!2026');
    final result = await invokeTool(
      registry,
      'credential_health',
      ctx(args: const <String, Object?>{'now_ms': 1731052800000}),
    );
    expect(result.isError, isFalse);
    expect(result.content, contains('共 1 个账号'));
    expect(result.content, isNot(contains('Secret!2026')));
  });

  test('search_entries 走真实 FTS 且排除 AI 日记', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'note',
      kind: EntryKind.note,
      title: '同步笔记',
      body: '增量同步',
    ));
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'ai',
      kind: EntryKind.aiDiary,
      title: '同步 AI 日记',
      body: '增量同步',
    ));
    final result = await invokeTool(
      registry,
      'search_entries',
      ctx(args: const <String, Object?>{
        'query': '同步',
        'now_ms': 1731052800000,
      }),
    );
    expect(result.content, contains('同步笔记'));
    expect(result.content, isNot(contains('AI 日记')));
  });

  test('get_entry 对密码条目只返回脱敏描述', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'cred',
      kind: EntryKind.credential,
      title: 'GitHub',
    ));
    final result = await invokeTool(
      registry,
      'get_entry',
      ctx(args: const <String, Object?>{'id': 'cred'}),
    );
    expect(result.content, contains('内容不可读取'));
    expect(result.content, isNot(contains('GitHub')));
  });

  test('create_note 未确认只给预览，确认后真实写库；密码边界一律拒绝',
      () async {
    final pending = await invokeTool(
      registry,
      'create_note',
      ctx(args: const <String, Object?>{
        'title': '工具建的笔记',
        'body': '正文',
      }),
    );
    expect(pending.content, contains('内容预览'));
    expect(await app.db.select(app.db.entries).get(), isEmpty);

    final done = await invokeTool(
      registry,
      'create_note',
      ctx(
        args: const <String, Object?>{
          'title': '工具建的笔记',
          'body': '正文',
        },
        confirmed: true,
      ),
    );
    expect(done.content, contains('已创建笔记'));
    expect(await app.db.select(app.db.entries).get(), hasLength(1));

    final denied = await invokeTool(
      registry,
      'create_note',
      ctx(
        args: const <String, Object?>{'title': '泄露', 'body': 'hunter2'},
        secrets: const <String>['hunter2'],
        confirmed: true,
      ),
    );
    expect(denied.isError, isTrue);
    expect(await app.db.select(app.db.entries).get(), hasLength(1));
  });
}
