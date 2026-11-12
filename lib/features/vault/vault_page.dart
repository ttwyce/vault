import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../core/widgets/secure_card.dart';
import '../../data/vault/credential_models.dart';
import '../../data/vault/credential_repository.dart';
import '../../app/session/flutter_clipboard_port.dart';
import '../../app/session/vault_session.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/db/vault_database.dart';
import '../../data/vault/credential_group_repository.dart';
import '../../data/vault/credential_groups.dart';

import '../../data/vault/credential_repository_provider.dart';
import '../../data/vault/credential_template.dart';
import '../editor/widgets/markdown_preview_view.dart';
import '../../data/vault/password_generator.dart';
import '../../data/vault/sensitive_clipboard.dart';
import '../../data/write/write_gateway.dart';

/// 密码库。
///
/// 安全边界（docs/11 §4.4）：
/// - 密码明文永不进入 prompt、日志、向量
/// - 标了 secret 的自定义字段与密码同级加密
/// - 泄露检测只发哈希前 5 位
///
/// 顶部健康提示与 subtitle 走 `CredentialRepository` 的真实聚合统计，
/// 不再显示写死的假数据。
class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  final TextEditingController _name = TextEditingController();
  CredentialSmartGroup? _activeGroup;
  List<CredentialGroupBucket> _buckets =
      const <CredentialGroupBucket>[];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addCredential() async {
    String? generated;
    String? templateId;
    String? groupId;
    final groupRepo =
        CredentialGroupRepository(db: ref.read(vaultDatabaseProvider));
    final groupsFuture = groupRepo.groups();
    final title = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext dialogContext, StateSetter setDialogState) {
          return AlertDialog(
            title: const Text('新增账号'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '账号名称'),
                  onSubmitted: (String value) =>
                      Navigator.of(dialogContext).pop(value),
                ),
                const SizedBox(height: SketchSpace.sm),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('字段模板（可选）'),
                  value: templateId,
                  items: <DropdownMenuItem<String>>[
                    for (final template in kDefaultFieldTemplates)
                      DropdownMenuItem<String>(
                        value: template.id,
                        child: Text(template.label),
                      ),
                  ],
                  onChanged: (String? value) =>
                      setDialogState(() => templateId = value),
                ),
                const SizedBox(height: SketchSpace.sm),
                FutureBuilder<List<CategoryRow>>(
                  future: groupsFuture,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<CategoryRow>> groupSnap,
                  ) {
                    final groups = groupSnap.data ?? const <CategoryRow>[];
                    if (groups.isEmpty) {
                      return Text(
                        '账号分组：暂无分组（可在设置里建）',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Theme.of(dialogContext)
                              .textTheme
                              .bodySmall
                              ?.color,
                        ),
                      );
                    }
                    return DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('账号分组（自动套用字段模板）'),
                      value: groupId,
                      items: <DropdownMenuItem<String>>[
                        for (final group in groups)
                          DropdownMenuItem<String>(
                            value: group.id,
                            child: Text(group.name),
                          ),
                      ],
                      onChanged: (String? value) =>
                          setDialogState(() => groupId = value),
                    );
                  },
                ),
                const SizedBox(height: SketchSpace.sm),
                TextButton(
                  onPressed: () => setDialogState(
                    () => generated = generatePassword(
                      const PasswordPolicy(),
                    ),
                  ),
                  child: const Text('生成强密码'),
                ),
                if (generated != null) ...<Widget>[
                  SelectableText(
                    generated!,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已用 K_item 字段级加密写入本地库，明文不会落盘。',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(dialogContext)
                          .textTheme
                          .bodySmall
                          ?.color,
                    ),
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(_name.text),
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
    final trimmed = title?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    final gateway = ref.read(writeGatewayProvider);
    final created = await gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.credential,
      title: trimmed,
    ));
    final db = ref.read(vaultDatabaseProvider);
    await db.into(db.credentials).insert(
          CredentialsCompanion.insert(id: created.snapshot.id),
        );
    final repo = ref.read(credentialRepositoryProvider);
    if (generated != null) {
      await repo.setPassword(created.snapshot.id, generated!);
    }
    if (groupId != null) {
      // 分组模板优先于固定模板：这正是 docs/11 §4.6 里分组的价值。
      await repo.setCustomFields(
        created.snapshot.id,
        await CredentialGroupRepository(
          db: ref.read(vaultDatabaseProvider),
        ).instantiateForGroup(groupId!),
      );
    } else if (templateId != null) {
      final template = templateById(templateId!);
      if (template != null) {
        await repo.setCustomFields(
          created.snapshot.id,
          template.instantiate(),
        );
      }
    }
    _name.clear();
    setState(() {});
  }

  Future<void> _openDetail(String id) async {
    final repo = ref.read(credentialRepositoryProvider);
    final detail = await repo.detail(id);
    if (detail == null || !mounted) return;
    final notes = await repo.notes(id);
    final notesController = TextEditingController(text: notes);
    var previewNotes = false;
    await showModalBottomSheet<void>(
      // 上面已用 mounted 守住异步间隙。
      // ignore: use_build_context_synchronously
      context: context,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext sheetContext, StateSetter setSheetState) {
          return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SketchSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                detail.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: sheetContext.sketch.ink,
                ),
              ),
              const SizedBox(height: SketchSpace.sm),
              Text('用户名：${detail.username ?? '未填写'}'),
              if (detail.totpCode != null)
                Text('当前 TOTP：${detail.totpCode}'),
              Text(detail.breached ? '状态：已泄露' : '状态：未发现泄露'),
              Text('secret 字段：${detail.secretFieldLabels.length} 个（掩码）'),
              Text(detail.healthSummary),
              const SizedBox(height: SketchSpace.sm),
              Text('备注（L0 端侧，不同步到云端上下文）',
                  style: TextStyle(fontSize: 10.5, color: sheetContext.sketch.muted)),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: '加粗 / 列表用 Markdown 写',
                ),
              ),
              if (previewNotes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SketchSpace.xs),
                  child: SizedBox(
                    height: 90,
                    child: MarkdownPreview(source: notesController.text),
                  ),
                ),
              const SizedBox(height: SketchSpace.xs),
              Row(
                children: <Widget>[
                  SketchButton(
                    label: '保存备注',
                    dense: true,
                    onPressed: () async {
                      await repo.setNotes(id, notesController.text);
                      setSheetState(() {});
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('备注已加密保存')),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: SketchSpace.sm),
                  SketchButton(
                    label: previewNotes ? '返回编辑' : '预览备注',
                    tone: SketchTone.ghost,
                    dense: true,
                    onPressed: () =>
                        setSheetState(() => previewNotes = !previewNotes),
                  ),
                ],
              ),
              const SizedBox(height: SketchSpace.md),
              Text(
                '密码与密钥以 K_item 密文存储，此页不展示明文。',
                style: TextStyle(fontSize: 10.5, color: sheetContext.sketch.blue),
              ),
              const SizedBox(height: SketchSpace.md),
              if (detail.totpCode != null)
                SketchButton(
                  label: '复制当前 TOTP（30 秒后清除）',
                  dense: true,
                  onPressed: () async {
                    await SensitiveClipboard(
                      port: const FlutterClipboardPort(),
                    ).copy(detail.totpCode!);
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('已复制，30 秒后自动从剪贴板清除'),
                        ),
                      );
                    }
                  },
                ),
              const SizedBox(height: SketchSpace.sm),
              SketchButton(
                label: '生成新密码并替换',
                dense: true,
                onPressed: () async {
                  final next = generatePassword(const PasswordPolicy());
                  await repo.setPassword(id, next);
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      );
        },
      ),
    );
    notesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final repo = ref.watch(credentialRepositoryProvider);
    final summaries = repo.listSummaries();
    final groups = repo.smartGroups(
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    return FutureBuilder<CredentialHealth>(
      future: repo.health(nowMs: DateTime.now().millisecondsSinceEpoch),
      builder: (BuildContext context, AsyncSnapshot<CredentialHealth> snap) {
        final health = snap.data ??
            const CredentialHealth(
              total: 0,
              weak: 0,
              reused: 0,
              leaked: 0,
              outdated: 0,
              favorite: 0,
            );
        return PageScaffold(
      title: '密码',
      subtitle: '${health.total} 个 · 弱 ${health.weak} · 重复 ${health.reused} · 超期 ${health.outdated}',
      actions: <Widget>[
        SketchButton(label: '新增', dense: true, onPressed: _addCredential),
      ],
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
            fill: p.note,
            tilt: SketchTilt.left,
            child: Row(
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: p.red, shape: BoxShape.circle),
                ),
                const SizedBox(width: SketchSpace.sm),
                Expanded(
                  child: Text(
                    health.leaked > 0
                        ? '有 ${health.leaked} 个密码出现在泄露库里，建议立刻改'
                        : '没有发现已泄露密码，${health.weak} 个弱密码建议更换',
                    style: TextStyle(fontSize: 11.5, color: p.ink),
                  ),
                ),
                Text('去看看 →',
                    style: TextStyle(fontSize: 10.5, color: p.blue)),
              ],
            ),
          ),
          const SizedBox(height: SketchSpace.lg),
          FutureBuilder<List<CredentialGroupBucket>>(
            future: groups,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<CredentialGroupBucket>> groupSnap,
            ) {
              final buckets = groupSnap.data ??
                  const <CredentialGroupBucket>[];
              _buckets = buckets;
              return Wrap(
                spacing: SketchSpace.sm,
                runSpacing: SketchSpace.sm,
                children: <Widget>[
                  for (final bucket in buckets)
                    GestureDetector(
                      onTap: () => setState(() {
                        _activeGroup = _activeGroup == bucket.group
                            ? null
                            : bucket.group;
                      }),
                      child: SketchTag(
                        '${bucket.label} ${bucket.ids.length}',
                        tone: _activeGroup == bucket.group
                            ? SketchTone.primary
                            : SketchTone.plain,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: SketchSpace.lg),
          FutureBuilder<List<CredentialSummary>>(
            future: summaries,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<CredentialSummary>> listSnap,
            ) {
              final all = listSnap.data ?? const <CredentialSummary>[];
              // 智能分组按 id 集合过滤；未选分组时显示全部。
              final activeIds = _buckets
                  .where((CredentialGroupBucket b) =>
                      b.group == _activeGroup)
                  .expand((CredentialGroupBucket b) => b.ids)
                  .toSet();
              final items = _activeGroup == null
                  ? all
                  : all
                      .where((CredentialSummary c) =>
                          activeIds.contains(c.id))
                      .toList();
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: SketchSpace.xl),
                  child: Text(
                    listSnap.connectionState == ConnectionState.waiting
                        ? '加载中…'
                        : '还没有账号',
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < items.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: SketchSpace.md),
                    GestureDetector(
                      onTap: () => _openDetail(items[i].id),
                      child: _VaultTile(
                        variant: i % 4,
                        letter: items[i].letter,
                        name: items[i].title,
                        account: items[i].username ?? '未填写用户名',
                        badges: <(String, SketchTone)>[
                          if (items[i].totpCode != null)
                            ('TOTP ${items[i].totpCode}', SketchTone.blue),
                          if (items[i].breached) ('已泄露', SketchTone.primary),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: SketchSpace.xl),
          SketchCard(
            variant: 0,
            fill: p.noteAlt,
            tilt: SketchTilt.none,
            child: Text(
              '泄露检测只发送密码哈希前 5 位，服务端无法还原原文。AI 永远读不到密码明文。',
              style: TextStyle(fontSize: 11, height: 1.6, color: p.blue),
            ),
          ),
        ],
        ),
      );
      },
    );
  }
}

class _VaultTile extends StatelessWidget {
  const _VaultTile({
    required this.variant,
    required this.letter,
    required this.name,
    required this.account,
    required this.badges,
  });

  final int variant;
  final String letter;
  final String name;
  final String account;
  final List<(String, SketchTone)> badges;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    final breached = badges.any(((String, SketchTone) b) => b.$1 == '已泄露');
    return SecureCard(
      accent: breached ? p.red : null,
      child: Row(
        children: <Widget>[
          SketchFrame(
            radius: const BorderRadius.all(Radius.circular(SecureCard.radius)),
            fill: p.note,
            padding: const EdgeInsets.all(6),
            shadowOffset: SketchShadowOffset.none,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.ink,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: SketchSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(account,
                    style: TextStyle(fontSize: 10.5, color: p.muted)),
              ],
            ),
          ),
          Wrap(
            spacing: SketchSpace.xs,
            children: <Widget>[
              for (final (label, tone) in badges)
                SketchTag(label, tone: tone, dense: true),
            ],
          ),
        ],
      ),
    );
  }
}
