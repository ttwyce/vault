/// M7 具体工具集（docs/07 §3 / §4）。
///
/// 把 `AgentTool` 抽象落到真实只读仓库 / 写入口：**每次调用先过
/// `checkToolCall` 统一闸门**，而不是每个工具自己判断密码边界。
/// 不联网、不调模型、不接 MCP；写类工具只提供确认预览，不擅自执行。
library;

import '../db/tables/entry_tables.dart';
import '../entry/entry_repository.dart';
import '../vault/credential_repository.dart';
import '../write/write_gateway.dart';
import 'agent_policy.dart';

/// 工具依赖。由会话装配层注入真实实例。
class AgentToolDeps {
  const AgentToolDeps({
    required this.entries,
    required this.credentials,
    required this.gateway,
  });

  final EntryRepository entries;
  final CredentialRepository credentials;
  final WriteGateway gateway;
}

/// 统一调用：先过闸门，再执行。返回可直接给模型的结果文本。
Future<ToolResult> invokeTool(
  AgentToolRegistry registry,
  String name,
  ToolCallContext ctx,
) async {
  final tool = registry.lookup(name);
  if (tool == null) {
    return ToolResult('未注册的工具：$name', isError: true);
  }
  final decision = checkToolCall(tool, ctx);
  if (decision.action == PolicyAction.deny) {
    return ToolResult(decision.reasons.join('；'), isError: true);
  }
  if (decision.action == PolicyAction.requireConfirm) {
    return ToolResult(decision.preview);
  }
  return tool.execute(ctx.args);
}

AgentToolRegistry buildDefaultToolRegistry(AgentToolDeps deps) =>
    AgentToolRegistry()
      ..register(_CredentialHealthTool(deps))
      ..register(_SearchEntriesTool(deps))
      ..register(_GetEntryTool(deps))
      ..register(_CreateNoteTool(deps));

/// credential_health：只返回聚合统计（docs/07 §4.3）。
class _CredentialHealthTool extends _BaseTool {
  const _CredentialHealthTool(this.deps);

  final AgentToolDeps deps;

  @override
  String get name => 'credential_health';

  @override
  String get description => '密码库健康统计：弱密码 / 重复 / 泄露 / 超期';

  @override
  RiskLevel get risk => RiskLevel.auto;

  @override
  PrivacyLevel get maxPrivacy => PrivacyLevel.l0;

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final nowMs = (args['now_ms'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final health = await deps.credentials.health(nowMs: nowMs);
    return ToolResult(
      '共 ${health.total} 个账号 · 弱 ${health.weak} · 重复 '
      '${health.reused} · 泄露 ${health.leaked} · 超期 ${health.outdated}',
    );
  }
}

/// search_entries：走 searchHybrid，默认排除 AI 日记。
class _SearchEntriesTool extends _BaseTool {
  const _SearchEntriesTool(this.deps);

  final AgentToolDeps deps;

  @override
  String get name => 'search_entries';

  @override
  String get description => '跨类型检索标题、正文与标签';

  @override
  RiskLevel get risk => RiskLevel.auto;

  @override
  PrivacyLevel get maxPrivacy => PrivacyLevel.l1;

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final query = (args['query'] as String?) ?? '';
    final nowMs = (args['now_ms'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final hits = await deps.entries.searchHybrid(query, nowMs: nowMs);
    if (hits.isEmpty) return const ToolResult('没有命中条目');
    return ToolResult(
      <String>[
        '命中 ${hits.length} 条：',
        for (final hit in hits.take(10)) '- ${hit.title} (${hit.id})',
      ].join('\n'),
    );
  }
}

/// get_entry：密码条目只给脱敏描述，绝不返回明文。
class _GetEntryTool extends _BaseTool {
  const _GetEntryTool(this.deps);

  final AgentToolDeps deps;

  @override
  String get name => 'get_entry';

  @override
  String get description => '读取单条内容；密码条目只返回脱敏描述';

  @override
  RiskLevel get risk => RiskLevel.auto;

  @override
  PrivacyLevel get maxPrivacy => PrivacyLevel.l1;

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final id = (args['id'] as String?) ?? '';
    final row = await deps.entries.getRow(id);
    if (row == null || row.deleted != 0) {
      return ToolResult('条目不存在：$id', isError: true);
    }
    if (row.kind == EntryKind.credential.code) {
      return const ToolResult(
        '密码条目已存在 · 内容不可读取（仅本地健康统计可用）',
      );
    }
    return ToolResult('${row.title}\n${row.body ?? ''}');
  }
}

/// create_note：confirm 级，闸门会先拦出确认卡片。
class _CreateNoteTool extends _BaseTool {
  const _CreateNoteTool(this.deps);

  final AgentToolDeps deps;

  @override
  String get name => 'create_note';

  @override
  String get description => '新建一条笔记';

  @override
  RiskLevel get risk => RiskLevel.confirm;

  @override
  PrivacyLevel get maxPrivacy => PrivacyLevel.l1;

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final title = (args['title'] as String?)?.trim() ?? '';
    final body = (args['body'] as String?) ?? '';
    if (title.isEmpty) return const ToolResult('标题不能为空', isError: true);
    final result = await deps.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.note,
      title: title,
      body: body,
    ));
    return ToolResult('已创建笔记 ${result.snapshot.id}：$title');
  }
}

abstract class _BaseTool implements AgentTool {
  const _BaseTool();

  @override
  Map<String, Object?> get schema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{},
      };
}
