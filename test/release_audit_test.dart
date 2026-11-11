import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/agent_policy.dart';
import 'package:vault/data/audit/release_audit.dart';
import 'package:vault/data/search/embedding_manifest.dart';

/// M9 发布前确定性检查清单测试。
void main() {
  ReleaseAuditInput cleanInput() => ReleaseAuditInput(
        logSamples: <Map<String, Object?>>[
          <String, Object?>{'event': 'sync_ok', 'count': 3},
        ],
        modelSpecs: <EmbeddingModelSpec>[
          for (final spec in kDefaultModelSpecs)
            EmbeddingModelSpec.fromJson(spec),
        ],
        toolRegistry: AgentToolRegistry(),
        knownSecrets: <String>['hunter2'],
      );

  test('干净输入：六项检查全通过，JSON 可导出', () {
    final report = runReleaseAudit(cleanInput());
    expect(report.passed, isTrue);
    expect(report.checks, hasLength(6));
    expect(report.failures(), isEmpty);
    expect(jsonEncode(releaseAuditToJson(report)), contains('"passed":true'));
  });

  test('日志夹带密码 / 密钥材料时 A1 失败，报告给出可执行摘要', () {
    final input = ReleaseAuditInput(
      logSamples: <Map<String, Object?>>[
        <String, Object?>{'password': 'hunter2', 'raw': 'a' * 64},
      ],
      modelSpecs: <EmbeddingModelSpec>[
        for (final spec in kDefaultModelSpecs)
          EmbeddingModelSpec.fromJson(spec),
      ],
      toolRegistry: AgentToolRegistry(),
      knownSecrets: <String>['hunter2'],
    );
    final report = runReleaseAudit(input);
    expect(report.passed, isFalse);
    expect(report.failures().single, contains('A1'));
    expect(report.failures().single, contains('password'));
  });

  test('模型配置坑被 A3 抓出', () {
    final broken = EmbeddingModelSpec.fromJson(<String, Object?>{
      ...kDefaultModelSpecs[3],
      'pooling': 'mean',
    });
    final input = ReleaseAuditInput(
      logSamples: <Map<String, Object?>>[<String, Object?>{'event': 'ok'}],
      modelSpecs: <EmbeddingModelSpec>[broken],
      toolRegistry: AgentToolRegistry(),
    );
    final report = runReleaseAudit(input);
    expect(report.checks.firstWhere((AuditCheck c) => c.id == 'A3').passed,
        isFalse);
    expect(report.failures().any((String f) => f.contains('pooling')), isTrue);
  });

  test('实体名收敛检查：白名单外实体被拒绝', () {
    expect(
      hasUnexpectedEntities(
        <String>['entry', 'category', 'typo_entity'],
        <String>{'entry', 'category', 'tag'},
      ),
      isTrue,
    );
    expect(
      hasUnexpectedEntities(
        <String>['entry', 'category'],
        <String>{'entry', 'category', 'tag'},
      ),
      isFalse,
    );
  });

  test('打开外部门禁时 A7/A8/A9 明确不通过，报告给出可执行摘要', () {
    cleanInput(); // 确认构造器可用
    final report = runReleaseAudit(ReleaseAuditInput(
      logSamples: const <Map<String, Object?>>[
        <String, Object?>{'event': 'ok'},
      ],
      modelSpecs: <EmbeddingModelSpec>[
        for (final spec in kDefaultModelSpecs)
          EmbeddingModelSpec.fromJson(spec),
      ],
      toolRegistry: AgentToolRegistry(),
      checkExternalGates: true,
    ));
    expect(report.checks, hasLength(9));
    expect(report.passed, isFalse);
    expect(report.failures().length, 3);
    expect(report.failures().join(), contains('A7'));
    expect(report.failures().join(), contains('A8'));
    expect(report.failures().join(), contains('A9'));
  });
}
