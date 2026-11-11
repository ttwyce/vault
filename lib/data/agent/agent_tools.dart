/// M7 具体工具集（docs/07 §3 / §4）。
///
/// 把 `AgentTool` 抽象落到真实只读仓库 / 写入口：**每次调用先过
/// `checkToolCall` 统一闸门**，而不是每个工具自己判断密码边界。
/// 不联网、不调模型、不接 MCP；写类工具只提供确认预览，不擅自执行。
library;

import '../activity/activity_logger.dart';
import '../archive/archive_meta.dart';
import '../db/tables/entry_tables.dart';
import '../entry/entry_repository.dart';
import '../taxonomy/taxonomy_repository.dart';
import '../vault/credential_groups.dart';
import '../vault/credential_repository.dart';
import '../write/write_gateway.dart';
import 'agent_policy.dart';

/// 工具依赖。由会话装配层注入真实实例。
class AgentToolDeps {
  const AgentToolDeps({
    required this.entries,
    required this.credentials,
    required this.gateway,
    this.taxonomy,
    this.activity,
  });

  final EntryRepository entries;
  final CredentialRepository credentials;
  final WriteGateway gateway;

  /// 分类 / 标签 / 回收站只读仓库（可选，缺省时相关工具返回不可用）。
  final TaxonomyRepository? taxonomy;

  /// 活动埋点（可选，供 list_activity / get_stats 使用）。
  final ActivityLogger? activity;
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
      ..register(_CreateNoteTool(deps))
      ..register(_ListCategoriesTool(deps))
      ..register(_ListTagsTool(deps))
      ..register(_EntriesByCategoryTool(deps))
      ..register(_EntriesByTagsTool(deps))
      ..register(_UncategorizedTool(deps))
      ..register(_DiaryForMonthTool(deps))
      ..register(_EntryHistoryTool(deps))
      ..register(_CredentialGroupsTool(deps))
      ..register(_ListActivityTool(deps))
      ..register(_GetStatsTool(deps))
      ..register(_OpenEntryTool(deps))
      ..register(_UpdateEntryTool(deps))
      ..register(_ArchiveUrlTool(deps));

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


/// 以下工具只做本地只读聚合，全部 auto / L1，且统一过闸门。
abstract class _ReadOnlyTool extends _BaseTool {
  const _ReadOnlyTool(this.deps);

  final AgentToolDeps deps;

  @override
  RiskLevel get risk => RiskLevel.auto;

  @override
  PrivacyLevel get maxPrivacy => PrivacyLevel.l1;
}

class _ListCategoriesTool extends _ReadOnlyTool {
  const _ListCategoriesTool(super.deps);

  @override
  String get name => 'list_categories';

  @override
  String get description => '列出两级分类树（不含三级）';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final rows = await deps.entries.categories();
    if (rows.isEmpty) return const ToolResult('还没有分类');
    return ToolResult(<String>[
      '共 ${rows.length} 个分类：',
      for (final row in rows.take(20)) '- ${row.name} (${row.id})',
    ].join('\n'));
  }
}

class _ListTagsTool extends _ReadOnlyTool {
  const _ListTagsTool(super.deps);

  @override
  String get name => 'list_tags';

  @override
  String get description => '列出标签及使用次数';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final rows = await deps.entries.tags();
    if (rows.isEmpty) return const ToolResult('还没有标签');
    return ToolResult(<String>[
      '共 ${rows.length} 个标签：',
      for (final row in rows.take(20)) '- ${row.name} × ${row.count}',
    ].join('\n'));
  }
}

class _EntriesByCategoryTool extends _ReadOnlyTool {
  const _EntriesByCategoryTool(super.deps);

  @override
  String get name => 'entries_by_category';

  @override
  String get description => '按分类列出条目数（含子分类）';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final id = (args['category_id'] as String?) ?? '';
    if (id.isEmpty) return const ToolResult('缺少 category_id', isError: true);
    final ids = await deps.entries.entryIdsForCategory(id);
    return ToolResult('分类 $id 下共 ${ids.length} 条条目');
  }
}

class _EntriesByTagsTool extends _ReadOnlyTool {
  const _EntriesByTagsTool(super.deps);

  @override
  String get name => 'entries_by_tags';

  @override
  String get description => '多标签 AND 检索（不是 OR）';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final raw = args['tag_ids'];
    final ids = raw is List
        ? raw.map((Object? v) => v.toString()).toList()
        : <String>[];
    if (ids.isEmpty) return const ToolResult('缺少 tag_ids', isError: true);
    final found = await deps.entries.entryIdsWithAllTags(ids);
    return ToolResult('同时带 ${ids.length} 个标签的条目共 ${found.length} 条');
  }
}

class _UncategorizedTool extends _ReadOnlyTool {
  const _UncategorizedTool(super.deps);

  @override
  String get name => 'uncategorized_entries';

  @override
  String get description => '统计未分类条目';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final ids = await deps.entries.uncategorizedEntryIds();
    return ToolResult('未分类条目共 ${ids.length} 条');
  }
}

class _DiaryForMonthTool extends _ReadOnlyTool {
  const _DiaryForMonthTool(super.deps);

  @override
  String get name => 'diary_for_month';

  @override
  String get description => '按月列出用户日记（不含 AI 日记）';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final year = (args['year'] as num?)?.toInt() ?? DateTime.now().year;
    final month = (args['month'] as num?)?.toInt() ?? DateTime.now().month;
    final byDay = await deps.entries.diaryForMonth(year, month);
    final total = byDay.values.fold<int>(0, (int n, list) => n + list.length);
    return ToolResult('$year-$month 用户日记共 $total 条，分布在 ${byDay.length} 天');
  }
}

class _EntryHistoryTool extends _ReadOnlyTool {
  const _EntryHistoryTool(super.deps);

  @override
  String get name => 'entry_history';

  @override
  String get description => '列出条目的历史版本数';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final id = (args['id'] as String?) ?? '';
    final taxonomy = deps.taxonomy;
    if (taxonomy == null || id.isEmpty) {
      return const ToolResult('历史仓库未装配或缺少 id', isError: true);
    }
    final versions = await taxonomy.history(id);
    return ToolResult('条目 $id 有 ${versions.length} 个历史版本');
  }
}

class _CredentialGroupsTool extends _ReadOnlyTool {
  const _CredentialGroupsTool(super.deps);

  @override
  String get name => 'credential_smart_groups';

  @override
  String get description => '账号智能分组计数（收藏/未分组/泄露/重复/超期）';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final nowMs = (args['now_ms'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final health = await deps.credentials.samples();
    final ids = <String>[
      for (final row in await deps.credentials
          .db
          .select(deps.credentials.db.credentials)
          .get())
        row.id,
    ];
    final samples = samplesForGroups(health, ids);
    final buckets = groupCredentials(samples, nowMs: nowMs);
    return ToolResult(<String>[
      for (final bucket in buckets)
        '${bucket.label} ${bucket.ids.length}',
    ].join(' · '));
  }
}


class _ListActivityTool extends _ReadOnlyTool {
  const _ListActivityTool(super.deps);

  @override
  String get name => 'list_activity';

  @override
  String get description => '列出某天的本地活动时间线（不参与同步）';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final activity = deps.activity;
    if (activity == null) {
      return const ToolResult('活动仓库未装配', isError: true);
    }
    final dateStr = (args['date'] as String?) ?? '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return const ToolResult('缺少合法 date', isError: true);
    final rows = await activity.timelineForDay(date);
    return ToolResult(<String>[
      '$dateStr 共 ${rows.length} 条活动：',
      for (final row in rows.take(10)) '- ${row.kind} @ ${row.ts}',
    ].join('\n'));
  }
}

class _GetStatsTool extends _ReadOnlyTool {
  const _GetStatsTool(super.deps);

  @override
  String get name => 'get_stats';

  @override
  String get description => '统计某天的活动事件数（事实，不含洞察）';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final activity = deps.activity;
    if (activity == null) {
      return const ToolResult('活动仓库未装配', isError: true);
    }
    final dateStr = (args['date'] as String?) ?? '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return const ToolResult('缺少合法 date', isError: true);
    final summary = await activity.summarizeDay(date);
    return ToolResult('${summary.headline} · 共 ${summary.totalEvents} 次活动');
  }
}

class _OpenEntryTool extends _ReadOnlyTool {
  const _OpenEntryTool(super.deps);

  @override
  String get name => 'open_entry';

  @override
  String get description => '返回条目深链，UI 可渲染成卡片';

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final id = (args['id'] as String?) ?? '';
    final row = id.isEmpty ? null : await deps.entries.getRow(id);
    if (row == null || row.deleted != 0) {
      return const ToolResult('条目不存在', isError: true);
    }
    return ToolResult('vault://entry/$id · ${row.title}');
  }
}

/// confirm：更新条目（保留 meta，rev 递增）。
class _UpdateEntryTool extends _BaseTool {
  const _UpdateEntryTool(this.deps);

  final AgentToolDeps deps;

  @override
  String get name => 'update_entry';

  @override
  String get description => '修改已有条目的标题 / 正文';

  @override
  RiskLevel get risk => RiskLevel.confirm;

  @override
  PrivacyLevel get maxPrivacy => PrivacyLevel.l1;

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final id = (args['id'] as String?) ?? '';
    final row = id.isEmpty ? null : await deps.entries.getRow(id);
    if (row == null) return const ToolResult('条目不存在', isError: true);
    final result = await deps.gateway.writeEntry(EntryWrite.update(
      id: id,
      title: (args['title'] as String?) ?? row.title,
      body: (args['body'] as String?) ?? row.body,
      meta: row.meta,
    ));
    return ToolResult('已更新 $id 到 rev ${result.snapshot.rev}');
  }
}

/// confirm：归档网址（只建 L1 元数据层，真实抓取排任务）。
class _ArchiveUrlTool extends _BaseTool {
  const _ArchiveUrlTool(this.deps);

  final AgentToolDeps deps;

  @override
  String get name => 'archive_url';

  @override
  String get description => '归档一个 URL（默认仅元数据层）';

  @override
  RiskLevel get risk => RiskLevel.confirm;

  @override
  PrivacyLevel get maxPrivacy => PrivacyLevel.l1;

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async {
    final url = (args['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) return const ToolResult('缺少 url', isError: true);
    final ArchiveMeta meta;
    try {
      meta = ArchiveMeta(
        url: url,
        site: ArchiveMeta.siteOf(url),
        status: ArchiveStatus.metadata,
        policy: RecheckPolicy.monthly,
      );
    } on FormatException catch (e) {
      return ToolResult(e.message, isError: true);
    }
    final result = await deps.gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.bookmark,
      title: url,
      meta: meta.toJsonString(),
    ));
    return ToolResult('已排归档任务 ${result.snapshot.id}：$url');
  }
}
