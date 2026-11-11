


/// M9 发布前硬化 / M7 Agent 的确定性检查清单（docs/09 §11 / §12）。
///
/// 不跑真实模型 / 服务器 / 真机：只做「每次发版前都能跑、结果可复现」的那部分。
/// 输出结构化报告，UI / CI 可直接消费。真实 26 个集成用例与 5000 条性能
/// 基线仍要外部服务器与真机，不在本清单里冒充完成。

library;

import 'dart:convert';
import '../../data/search/hybrid_search.dart';
import '../agent/agent_policy.dart';
import '../agent/daily_summary.dart';
import '../backup/security_audit.dart';
import '../vault/credential_models.dart';
import '../search/embedding_manifest.dart';

class AuditCheck {
  const AuditCheck({
    required this.id,
    required this.title,
    required this.passed,
    this.detail = '',
  });

  final String id;
  final String title;
  final bool passed;
  final String detail;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'passed': passed,
        'detail': detail,
      };
}

class ReleaseAuditReport {
  const ReleaseAuditReport(this.checks);

  final List<AuditCheck> checks;

  bool get passed => checks.every((AuditCheck c) => c.passed);

  List<String> failures() => <String>[
        for (final check in checks)
          if (!check.passed) '${check.id}: ${check.title} — ${check.detail}',
      ];
}

class ReleaseAuditInput {
  const ReleaseAuditInput({
    required this.logSamples,
    required this.modelSpecs,
    required this.toolRegistry,
    this.knownSecrets = const <String>[],
    this.smokeQuery = '同步',
    this.nowMs = 1731052800000,
  });

  /// 待扫描的日志 payload 样本。
  final List<Map<String, Object?>> logSamples;

  /// manifest 里的模型 spec（已解析）。
  final List<EmbeddingModelSpec> modelSpecs;
  final AgentToolRegistry toolRegistry;
  final Iterable<String> knownSecrets;
  final String smokeQuery;
  final int nowMs;
}

ReleaseAuditReport runReleaseAudit(ReleaseAuditInput input) {
  final checks = <AuditCheck>[];

  // ① 明文泄露扫描（docs/09 §11）：所有日志样本都必须干净。
  final leaks = <String>[];
  for (final sample in input.logSamples) {
    final report = SecurityAuditReport(scanStructuredLog(
      sample,
      knownSecrets: input.knownSecrets,
    ));
    leaks.addAll(report.summary());
  }
  checks.add(AuditCheck(
    id: 'A1',
    title: '日志 / prompt 明文零泄露',
    passed: leaks.isEmpty,
    detail: leaks.isEmpty ? '扫描通过' : leaks.join('；'),
  ));

  // ② 工程红线：密码不向量化、AI 日记不向量化（docs/07 §6.3）。
  final vectorizationOk = !shouldVectorize(6) &&
      !AiDiaryRules.shouldVectorize(AiDiaryRules.kind);
  checks.add(AuditCheck(
    id: 'A2',
    title: '密码 / AI 日记不进入向量化流程',
    passed: vectorizationOk,
  ));

  // ③ 模型配置坑（docs/06 §3.2）：每个 spec 都要过 auditModelConfig。
  final modelIssues = <String>[];
  for (final spec in input.modelSpecs) {
    for (final issue in auditModelConfig(spec).issues) {
      modelIssues.add('${spec.id}: $issue');
    }
  }
  checks.add(AuditCheck(
    id: 'A3',
    title: '向量模型 manifest 配置正确',
    passed: modelIssues.isEmpty,
    detail: modelIssues.isEmpty ? '${input.modelSpecs.length} 个模型通过' : modelIssues.join('；'),
  ));

  // ④ 工具注册表：同名重复会在 register 时抛错，这里再校验密码边界闸门。
  final secretCall = checkToolCall(
    const _AuditTool(),
    ToolCallContext(
      args: <String, Object?>{'password': 'hunter2'},
      cloudModel: true,
      privacy: PrivacyLevel.l0,
      knownSecrets: input.knownSecrets,
      entryKind: 6,
    ),
  );
  checks.add(AuditCheck(
    id: 'A4',
    title: 'CredentialGuard 密码绝对边界生效',
    passed: secretCall.action == PolicyAction.deny,
    detail: secretCall.reasons.join('；'),
  ));

  // ⑤ 查询预处理：中文短语必须仍可搜，且默认不把密码带进 FTS。
  final parsed = preprocessSearchQuery(input.smokeQuery, nowMs: input.nowMs);
  checks.add(AuditCheck(
    id: 'A5',
    title: '混合检索预处理烟测',
    passed: parsed.ftsPhrase.trim().isNotEmpty &&
        !parsed.ftsPhrase.contains('password'),
    detail: 'ftsPhrase=${parsed.ftsPhrase}',
  ));

  // ⑥ 自定义字段的 secret 值在任何工具返回值里都必须被脱敏。
  final fields = const CustomFields(<CredentialField>[
    CredentialField(
      id: 'f1',
      label: '恢复码',
      value: 'xxxx-xxxx',
      type: CustomFieldType.text,
      secret: true,
      sort: 0,
    ),
  ]);
  final redacted = CredentialGuard.redact(<String, Object?>{
    'custom_fields': fields.toJsonString(),
  });
  checks.add(AuditCheck(
    id: 'A6',
    title: 'secret 自定义字段整体脱敏',
    passed: !jsonEncode(redacted).contains('xxxx-xxxx'),
  ));

  return ReleaseAuditReport(List<AuditCheck>.unmodifiable(checks));
}

/// 用于审计的最小工具实现，不承担真实执行。
class _AuditTool implements AgentTool {
  const _AuditTool();

  @override
  String get name => 'audit_probe';

  @override
  String get description => '发布前审计探针';

  @override
  Map<String, Object?> get schema => const <String, Object?>{
        'type': 'object',
      };

  @override
  RiskLevel get risk => RiskLevel.auto;

  @override
  PrivacyLevel get maxPrivacy => PrivacyLevel.l0;

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async =>
      const ToolResult('ok');
}

/// 把 [ReleaseAuditReport] 转成可写进 sync_log / CI 产物的 JSON。
Map<String, Object?> releaseAuditToJson(ReleaseAuditReport report) =>
    <String, Object?>{
      'passed': report.passed,
      'checks': <Object?>[
        for (final check in report.checks) check.toJson(),
      ],
      'failures': report.failures(),
    };

/// 顺带复用 SyncEntity 常量做一次「实体名收敛」检查：
/// 新增实体必须走写入口，不能出现拼写漂移。
bool hasUnexpectedEntities(Iterable<String> observed, Set<String> allowed) =>
    observed.any((String entity) => !allowed.contains(entity));
