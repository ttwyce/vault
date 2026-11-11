import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/agent_loop.dart';
import 'package:vault/data/agent/agent_policy.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/entry/entry_repository.dart';
import 'package:vault/data/write/write_gateway.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/data/agent/agent_tools.dart';

import 'support/test_harness.dart';

/// docs/07 §3 / §9 主循环与 MCP 骨架测试。
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
    Iterable<String> secrets = const <String>[],
    int? entryKind,
    bool mcpRemote = false,
  }) =>
      ToolCallContext(
        args: args,
        cloudModel: false,
        privacy: PrivacyLevel.l1,
        knownSecrets: secrets,
        userConfirmed: confirmed,
        privacyAuthorized: false,
        mcpRemote: mcpRemote,
        entryKind: entryKind,
      );

  AgentTurn health([int now = 1731052800000]) => AgentTurn(
        toolName: 'credential_health',
        context: ctx(args: <String, Object?>{'now_ms': now}),
      );

  test('最多 6 轮：计划 8 轮也只跑 6 轮', () async {
    final result = await runAgentLoop(
      registry,
      List<AgentTurn>.generate(8, (int i) => health()),
    );
    expect(result.turns, 6);
    expect(result.stoppedBy, LoopStop.maxTurns);
    expect(result.steps.every((AgentLoopStep s) =>
        s.action == PolicyAction.allow), isTrue);
  });

  test('工具结果超过 2000 字被截断', () async {
    for (var i = 0; i < 30; i++) {
      await app.gateway.writeEntry(EntryWrite.create(
        id: 'n$i',
        kind: EntryKind.note,
        title: '同步笔记$i',
        body: '增量同步',
      ));
    }
    final result = await runAgentLoop(
      registry,
      <AgentTurn>[
        AgentTurn(
          toolName: 'search_entries',
          context: ctx(args: const <String, Object?>{
            'query': '同步',
            'now_ms': 1731052800000,
          }),
        ),
      ],
      limits: const AgentLoopLimits(maxResultChars: 80),
    );
    expect(result.steps.single.output, contains('已截断'));
    expect(result.steps.single.output.length, lessThan(100));
  });

  test('deny 与 needConfirm 都立即停轮，不继续后续计划', () async {
    final denied = await runAgentLoop(
      registry,
      <AgentTurn>[
        AgentTurn(
          toolName: 'create_note',
          context: ctx(
            args: const <String, Object?>{'title': 'x', 'body': 'hunter2'},
            secrets: const <String>['hunter2'],
          ),
        ),
        health(),
      ],
    );
    expect(denied.stoppedBy, LoopStop.denied);
    expect(denied.turns, 1);

    final pending = await runAgentLoop(
      registry,
      <AgentTurn>[
        AgentTurn(
          toolName: 'create_note',
          context: ctx(args: const <String, Object?>{
            'title': '待确认',
            'body': '正文',
          }),
        ),
        health(),
      ],
    );
    expect(pending.stoppedBy, LoopStop.needsConfirm);
    expect(pending.steps.single.output, contains('内容预览'));
    expect(pending.turns, 1);
  });

  test('MCP 骨架：描述映射、不联网、密码条目被闸门拒绝', () async {
    const adapter = McpToolAdapter(
      remoteName: 'remote_search',
      description: '远程检索',
      schema: <String, Object?>{'type': 'object'},
    );
    expect(adapter.name, 'mcp/remote_search');
    expect(adapter.risk, RiskLevel.dangerous);
    expect(adapter.maxPrivacy, PrivacyLevel.l2);
    expect((await adapter.execute(const <String, Object?>{})).isError, isTrue);

    registry.register(adapter);
    final result = await runAgentLoop(
      registry,
      <AgentTurn>[
        AgentTurn(
          toolName: 'mcp/remote_search',
          context: ctx(entryKind: 6, mcpRemote: true),
        ),
      ],
    );
    expect(result.stoppedBy, LoopStop.denied);
    expect(result.steps.single.output, contains('第三方 MCP'));
  });
}
