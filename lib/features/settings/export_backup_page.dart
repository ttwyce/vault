import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../data/backup/backup_models.dart';
import '../../data/backup/encrypted_backup_service.dart';
import '../../data/backup/markdown_exporter.dart';
import '../../data/backup/markdown_importer.dart';

/// 导出与备份页（docs/03 §10）。
///
/// 页面只负责二次确认、导入合并判定、/backup/ 隔离与 7 天排期展示；
/// 真实写盘 / 打包 / 联网由启动装配注入的 runner 与服务执行，
/// 未装配时按钮保持禁用或给出明确提示，不假装成功。
class ExportBackupPage extends StatefulWidget {
  const ExportBackupPage({
    super.key,
    this.backupServiceFactory,
    this.plaintextExportRunner,
    this.markdownImportRunner,
  });

  /// 真实加密备份服务由启动装配层注入（需要 VaultKeys + WebDavBackend）。
  final BackupUploader Function()? backupServiceFactory;
  /// 装配层把 [MarkdownExporter] + 已知敏感值打包成这个函数；
  /// 页面只负责二次确认与展示，不直接碰文件系统 / Provider。
  final Future<MarkdownExportResult> Function()? plaintextExportRunner;
  final Future<MarkdownImportResult> Function()? markdownImportRunner;

  @override
  State<ExportBackupPage> createState() => _ExportBackupPageState();
}

class _ExportBackupPageState extends State<ExportBackupPage> {
  PlaintextExportStage _stage = PlaintextExportStage.idle;
  bool _dangerAcknowledged = false;
  bool _secondConfirmed = false;

  final TextEditingController _hash = TextEditingController();
  final TextEditingController _localHash = TextEditingController();
  ImportAction? _importAction;
  String? _backupHint;
  String? _exportHint;
  String? _importHint;

  Future<void> _runPlaintextExport() async {
    final runner = widget.plaintextExportRunner;
    if (runner == null) {
      setState(() => _exportHint = '未装配 Markdown 导出器（需导出目录）');
      return;
    }
    final result = await runner();
    if (!mounted) return;
    setState(() => _exportHint = result.hint);
  }

  Future<void> _runMarkdownImport() async {
    final runner = widget.markdownImportRunner;
    if (runner == null) return;
    final result = await runner();
    if (!mounted) return;
    setState(() => _importHint =
        '插入 ${result.inserted.length} · 跳过 ${result.skipped.length} · '
        '冲突副本 ${result.conflictCopies.length} · 失败 ${result.failed.length}');
  }

  Future<void> _uploadBackup() async {
    final service = widget.backupServiceFactory?.call();
    if (service == null) return;
    final result = await service.upload(
      fileName: 'vault.enc',
      vaultId: 'vault-local',
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() => _backupHint = result.hint);
  }

  @override
  void dispose() {
    _hash.dispose();
    _localHash.dispose();
    super.dispose();
  }

  void _advance() {
    setState(() {
      _stage = advancePlaintextExport(
        _stage,
        acknowledgedDanger: _dangerAcknowledged,
        secondConfirmation: _secondConfirmed,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '导出与备份',
        subtitle: '明文导出需二次确认 · 完成后真实写 Markdown 文件夹',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SketchSpace.lg,
            SketchSpace.md,
            SketchSpace.lg,
            SketchSpace.xxl,
          ),
          children: <Widget>[
            SketchCard(
              variant: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('明文导出（Markdown）',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.ink)),
                  const SizedBox(height: SketchSpace.sm),
                  Text(
                    '当前阶段：${_stage.name} · '
                    '${_stage == PlaintextExportStage.done ? '已允许平台层执行' : '尚未允许执行'}',
                    style: TextStyle(fontSize: 11.5, color: p.muted),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  CheckboxListTile(
                    value: _dangerAcknowledged,
                    contentPadding: EdgeInsets.zero,
                    title: Text('我已了解：明文文件不受本库加密保护',
                        style: TextStyle(fontSize: 11.5, color: p.ink)),
                    onChanged: (bool? v) =>
                        setState(() => _dangerAcknowledged = v ?? false),
                  ),
                  CheckboxListTile(
                    value: _secondConfirmed,
                    contentPadding: EdgeInsets.zero,
                    title: Text('二次确认：仍然要导出',
                        style: TextStyle(fontSize: 11.5, color: p.ink)),
                    onChanged: (bool? v) =>
                        setState(() => _secondConfirmed = v ?? false),
                  ),
                  SketchButton(
                    label: _stage == PlaintextExportStage.done
                        ? '执行明文导出'
                        : '推进确认流程',
                    dense: true,
                    onPressed: _stage == PlaintextExportStage.done
                        ? _runPlaintextExport
                        : _advance,
                  ),
                  if (_exportHint != null) ...<Widget>[
                    const SizedBox(height: SketchSpace.xs),
                    Text(_exportHint!,
                        style: TextStyle(fontSize: 10.5, color: p.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SketchSpace.lg),
            SketchCard(
              variant: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('导入无冲突合并判定',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.ink)),
                  const SizedBox(height: SketchSpace.sm),
                  TextField(
                    controller: _hash,
                    decoration: const InputDecoration(
                      hintText: '包内 content_hash',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  TextField(
                    controller: _localHash,
                    decoration: const InputDecoration(
                      hintText: '本地已有 hash（可空）',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  SketchButton(
                    label: '判定',
                    dense: true,
                    onPressed: () => setState(() {
                      final local = _localHash.text.trim();
                      _importAction = decideImport(
                        _hash.text.trim(),
                        local.isEmpty ? null : local,
                      );
                    }),
                  ),
                  if (_importAction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: SketchSpace.sm),
                      child: Text(
                        '动作：${_importAction!.name} · '
                        '${_importAction == ImportAction.conflictCopy ? '保留冲突副本，不覆盖' : '按规则合并'}',
                        style: TextStyle(fontSize: 11, color: p.blue),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SketchSpace.lg),
            SketchCard(
              variant: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('自动备份路径与排期',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.ink)),
                  const SizedBox(height: SketchSpace.sm),
                  Text(backupPath('vault.enc'),
                      style: context.typography.monoStyle(
                          size: 11, color: p.ink)),
                  Text(
                    '与 /vault/ 分离：${isBackupPath('/backup/vault.enc')} · '
                    '/vault/items 不算备份：${isBackupPath('/vault/items/x')}',
                    style: TextStyle(fontSize: 10.5, color: p.muted),
                  ),
                  Text(
                    '下次备份时间戳：${nextBackupAt(null, nowMs)}（首次启用立即）',
                    style: TextStyle(fontSize: 10.5, color: p.muted),
                  ),
                  Text(
                    '7 天周期；加密容器 VLT1 + K_item 信封 / '
                    'WebDAV /backup/ 条件 PUT 已接通。',
                    style: TextStyle(fontSize: 10.5, color: p.blue),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  SketchButton(
                    label: '导入 Markdown 文件夹',
                    tone: SketchTone.ghost,
                    dense: true,
                    onPressed: widget.markdownImportRunner == null
                        ? null
                        : _runMarkdownImport,
                  ),
                  if (_importHint != null) ...<Widget>[
                    const SizedBox(height: SketchSpace.xs),
                    Text(_importHint!,
                        style: TextStyle(fontSize: 10.5, color: p.muted)),
                  ],
                  const SizedBox(height: SketchSpace.sm),
                  SketchButton(
                    label: '上传加密备份',
                    dense: true,
                    onPressed: widget.backupServiceFactory == null
                        ? null
                        : _uploadBackup,
                  ),
                  if (_backupHint != null) ...<Widget>[
                    const SizedBox(height: SketchSpace.xs),
                    Text(_backupHint!,
                        style: TextStyle(fontSize: 10.5, color: p.muted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
