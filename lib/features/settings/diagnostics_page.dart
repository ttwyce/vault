import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/agent/agent_policy.dart';
import '../../data/audit/release_audit.dart';
import '../../data/backup/backup_models.dart';
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
    final report = runReleaseAudit(ReleaseAuditInput(
      logSamples: const <Map<String, Object?>>[
        <String, Object?>{'event': 'diagnostics_opened', 'count': 1},
      ],
      modelSpecs: specs,
      toolRegistry: AgentToolRegistry(),
      knownSecrets: const <String>[],
      nowMs: nowMs,
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
      subtitle: report.passed ? '自检通过' : '自检有未通过项',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SketchSpace.lg,
          SketchSpace.md,
          SketchSpace.lg,
          SketchSpace.xxl,
        ),
        children: <Widget>[
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
                  '下载中/校验中检索降级纯 FTS',
                  style: TextStyle(fontSize: 10.5, height: 1.7, color: p.blue),
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
