import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/audit/performance_baseline.dart';
import '../../data/audit/release_audit.dart';
import '../../data/activity/activity_logger.dart';
import '../../data/agent/agent_policy.dart' show AgentLoopLimits;
import '../../data/agent/agent_tools.dart';
import '../../data/agent/daily_summary_service.dart';
import '../../data/agent/daily_summary.dart' show SummaryGranularity;
import '../../data/agent/rollup_service.dart';
import '../../data/backup/backup_models.dart';
import '../../data/entry/entry_repository.dart';
import '../../data/platform/platform_capabilities.dart';
import '../../data/vault/credential_repository.dart';
import '../../data/search/embedding_manifest.dart';
import '../../data/search/model_downloader.dart';

/// 发布前自检 / 备份诊断页。
///
/// 把 M8/M9 的确定性判定层接到用户可见入口：六项检查结论、
/// 加密备份包 manifest 预览、/backup/ 路径与 7 天排期。
/// **不执行真实打包 / 上传**，也不冒充真实服务器集成验收。
class DiagnosticsPage extends ConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.sketch;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final specs = <EmbeddingModelSpec>[
      for (final spec in kDefaultModelSpecs)
        EmbeddingModelSpec.fromJson(spec),
    ];
    final db = ref.watch(vaultDatabaseProvider);
    final gateway = ref.watch(writeGatewayProvider);
    final toolRegistry = buildDefaultToolRegistry(AgentToolDeps(
      entries: EntryRepository(db),
      credentials: CredentialRepository(db, gateway),
      gateway: gateway,
    ));
    final report = runReleaseAudit(ReleaseAuditInput(
      logSamples: const <Map<String, Object?>>[
        <String, Object?>{'event': 'diagnostics_opened', 'count': 1},
      ],
      modelSpecs: specs,
      toolRegistry: toolRegistry,
      knownSecrets: const <String>[],
      nowMs: nowMs,
      checkExternalGates: true,
    ));
    final manifest = BackupManifest(
      schema: 1,
      vaultId: 'vault-local',
      createdAt: nowMs,
      entries: const <String, String>{},
      blobs: const <String, int>{},
      models: <String>[for (final spec in specs) spec.id],
    );

    return PageScaffold(
      title: '诊断与备份',
      subtitle:
          '${report.passed ? '自检通过' : '自检有未通过项'} · '
          '${toolRegistry.length} 个 Agent 工具',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SketchSpace.lg,
          SketchSpace.md,
          SketchSpace.lg,
          SketchSpace.xxl,
        ),
        children: <Widget>[
          SketchButton(
            label: '生成昨日总结',
            dense: true,
            onPressed: () async {
              final session = ref.read(vaultSessionProvider);
              final db = session.database;
              final gateway = session.gateway;
              final activity = session.activity;
              if (db == null || gateway == null || activity == null) return;
              final yesterday = DateTime.now()
                  .subtract(const Duration(days: 1));
              final summary = await DailySummaryService(
                logger: ActivityLogger(db: db, deviceId: 'local'),
                gateway: gateway,
                db: db,
              ).buildAndStore(yesterday);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(summary == null
                        ? '昨天没有活动记录'
                        : '已生成：${summary.headline}'),
                  ),
                );
              }
            },
          ),
          SketchButton(
            label: '生成上月摘要',
            dense: true,
            onPressed: () async {
              final session = ref.read(vaultSessionProvider);
              final db = session.database;
              final gateway = session.gateway;
              if (db == null || gateway == null) return;
              final now = DateTime.now();
              final monthKey =
                  '${now.year}-${now.month.toString().padLeft(2, '0')}';
              final summary = await RollupService(
                db: db,
                gateway: gateway,
              ).rollup(
                target: SummaryGranularity.month,
                periodKey: monthKey,
                from: '$monthKey-W1',
                to: '$monthKey-W5',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(summary == null
                        ? '没有可汇总的周摘要'
                        : '已生成：${summary.headline}'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: SketchSpace.lg),
          Text(
            '发布前确定性自检（不替代真实服务器集成用例）',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
          const SizedBox(height: SketchSpace.md),
          for (final check in report.checks)
            _CheckTile(check: check),
          const SizedBox(height: SketchSpace.xl),
          SketchCard(
            variant: 1,
            fill: p.note,
            tilt: SketchTilt.left,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '向量模型下载与索引重建',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: SketchSpace.sm),
                Text(
                  '源优先级：${kDefaultSourceOrder.map((ModelSource s) => s.name).join(' → ')}\n'
                  '每源 $kMaxAttemptsPerSource 次重试 · 校验失败换源 · 全源失败标记损坏\n'
                  '磁盘需 ≥ 1.5×disk_bytes · .part 断点续传',
                  style: TextStyle(fontSize: 11, height: 1.7, color: p.muted),
                ),
                const SizedBox(height: SketchSpace.sm),
                Text(
                  '备份排除三端四标记：${BackupExclusion(
                    androidDataExtraction: true,
                    androidFullBackup: true,
                    iosIsExcludedFromBackup: true,
                    windowsOutsideOneDrive: true,
                  ).allConfigured ? '已配置' : '未配置'} · '
                  '切换模型全量重建每批 20 条、cursor 可续\n'
                  '下载中/校验中检索降级纯 FTS\n'
                  'Agent 主循环最多 ${AgentLoopLimits().maxTurns} 轮、'
                  '工具结果截断 ${AgentLoopLimits().maxResultChars} 字；'
                  'MCP 适配器骨架已就位（transport 未连接）',
                  style: TextStyle(fontSize: 10.5, height: 1.7, color: p.blue),
                ),
              ],
            ),
          ),
          const SizedBox(height: SketchSpace.xl),
          SketchCard(
            variant: 3,
            fill: p.noteAlt,
            tilt: SketchTilt.none,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '性能基线（5000 条 / 真机）',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: SketchSpace.sm),
                Text(
                  '${PerfBudget.defaults.length} 项预算 · '
                  '${evaluatePerformance(const <PerfMetric, num>{}).failures().length} 项未测 · '
                  '发布门禁未通过',
                  style: TextStyle(fontSize: 11, color: p.red),
                ),
                Text(
                  '冷启动 < 1.2s、中文搜索 P95 < 150ms、混合检索 P95 < 300ms、'
                  '1000 条 60fps、5000 条重建 < 8min。未测 ≠ 达标。',
                  style: TextStyle(fontSize: 10.5, color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: SketchSpace.xl),
          SketchCard(
            variant: 0,
            fill: p.surface,
            tilt: SketchTilt.right,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '三端能力缺口（docs/08）',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: SketchSpace.sm),
                for (final platform in PlatformKind.values)
                  Text(
                    '${platform.name}：仍需原生 '
                    '${auditPlatformGaps().gapsFor(platform).length} 项 · '
                    '不可用 ${unavailableFor(platform).length} 项',
                    style: TextStyle(fontSize: 11, color: p.muted),
                  ),
                Text(
                  '纯逻辑已落地 ≠ 三端可用；原生模块与上架审核仍缺。',
                  style: TextStyle(fontSize: 10.5, color: p.blue),
                ),
              ],
            ),
          ),
          const SizedBox(height: SketchSpace.xl),
          SketchCard(
            variant: 2,
            fill: p.noteAlt,
            tilt: SketchTilt.none,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '加密备份包',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: SketchSpace.sm),
                Text(
                  '路径 ${backupPath('vault-${_datePart(nowMs)}.enc')} · '
                  '下次备份 ${_datePart(nextBackupAt(null, nowMs))}',
                  style: TextStyle(fontSize: 11, color: p.muted),
                ),
                const SizedBox(height: SketchSpace.sm),
                Text(
                  const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
                  style: context.typography.monoStyle(
                    size: 10,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: SketchSpace.sm),
                Text(
                  '真实 zip 打包与 WebDAV /backup/ 上传需 M8 平台层；'
                  '明文导出必须二次确认。',
                  style: TextStyle(fontSize: 10.5, color: p.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _datePart(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.check});

  final AuditCheck check;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Padding(
      padding: const EdgeInsets.only(bottom: SketchSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            check.passed ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: check.passed ? p.green : p.red,
          ),
          const SizedBox(width: SketchSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${check.id} · ${check.title}',
                  style: TextStyle(fontSize: 12, color: p.ink),
                ),
                if (check.detail.isNotEmpty)
                  Text(
                    check.detail,
                    style: TextStyle(fontSize: 10.5, color: p.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
