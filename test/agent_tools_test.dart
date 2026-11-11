import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/activity/activity_logger.dart';
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
      activity: ActivityLogger(db: app.db, deviceId: 'devA'),
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

  test('注册表导出 17 个工具的 schema', () {
    expect(registry.length, 17);
    final names = registry.schemas()
        .map((Map<String, Object?> s) => s['name'] as String)
        .toSet();
    expect(names, <String>{
      'credential_health',
      'search_entries',
      'get_entry',
      'create_note',
      'list_categories',
      'list_tags',
      'entries_by_category',
      'entries_by_tags',
      'uncategorized_entries',
      'diary_for_month',
      'entry_history',
      'credential_smart_groups',
      'list_activity',
      'get_stats',
      'open_entry',
      'update_entry',
      'archive_url',
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

  test('分类/标签/分组/日记只读工具接真实仓库', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'e1',
      kind: EntryKind.diary,
      title: '日记',
      meta: '{"diary_date":"2026-11-08"}',
    ));
    final categories = await invokeTool(
      registry,
      'list_categories',
      ctx(),
    );
    expect(categories.content, contains('还没有分类'),
        reason: '空库返回明确文案而不是假装成功');

    final tags = await invokeTool(registry, 'list_tags', ctx());
    expect(tags.content, contains('还没有标签'));

    final uncategorized = await invokeTool(
      registry,
      'uncategorized_entries',
      ctx(),
    );
    expect(uncategorized.content, contains('未分类条目'));

    final diary = await invokeTool(
      registry,
      'diary_for_month',
      ctx(args: const <String, Object?>{'year': 2026, 'month': 11}),
    );
    expect(diary.content, contains('用户日记'));

    final groups = await invokeTool(
      registry,
      'credential_smart_groups',
      ctx(args: const <String, Object?>{'now_ms': 1731052800000}),
    );
    expect(groups.content, contains('已泄露'));
  });

  test('活动统计、深链、更新条目与归档 URL 工具', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'e1',
      kind: EntryKind.note,
      title: '原文',
      body: '正文',
    ));
    final activity = await invokeTool(registry, 'list_activity',
        ctx(args: const <String, Object?>{'date': '2026-11-08'}));
    expect(activity.content, contains('共 0 条活动'));

    final stats = await invokeTool(registry, 'get_stats',
        ctx(args: const <String, Object?>{'date': '2026-11-08'}));
    expect(stats.content, contains('这一天没有记录'));

    final deep = await invokeTool(registry, 'open_entry',
        ctx(args: const <String, Object?>{'id': 'e1'}));
    expect(deep.content, contains('vault://entry/e1'));

    final pending = await invokeTool(registry, 'update_entry',
        ctx(args: const <String, Object?>{'id': 'e1', 'title': '新标题'}));
    expect(pending.content, contains('内容预览'));
    final updated = await invokeTool(
      registry,
      'update_entry',
      ctx(args: const <String, Object?>{'id': 'e1', 'title': '新标题'},
          confirmed: true),
    );
    expect(updated.content, contains('已更新'));

    final archive = await invokeTool(
      registry,
      'archive_url',
      ctx(
        args: const <String, Object?>{
          'url': 'https://example.com/post',
        },
        confirmed: true,
      ),
    );
    expect(archive.content, contains('已排归档任务'));
    final badUrl = await invokeTool(
      registry,
      'archive_url',
      ctx(
        args: const <String, Object?>{'url': 'ftp://x/y'},
        confirmed: true,
      ),
    );
    expect(badUrl.isError, isTrue);
  });
}
