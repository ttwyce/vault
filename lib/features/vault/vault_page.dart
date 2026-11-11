import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/vault/credential_models.dart';
import '../../data/vault/credential_repository.dart';
import '../../app/session/vault_session.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/db/vault_database.dart';
import '../../data/vault/credential_groups.dart';
import '../../data/vault/credential_repository_provider.dart';
import '../../data/vault/credential_template.dart';
import '../../data/vault/password_generator.dart';
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

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addCredential() async {
    String? generated;
    String? templateId;
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
    if (templateId != null) {
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
              return Wrap(
                spacing: SketchSpace.sm,
                runSpacing: SketchSpace.sm,
                children: <Widget>[
                  for (final bucket in buckets)
                    SketchTag('${bucket.label} ${bucket.ids.length}',
                        tone: SketchTone.plain),
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
              final items = listSnap.data ?? const <CredentialSummary>[];
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
                    _VaultTile(
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

    return SketchCard(
      variant: variant,
      tilt: variant.isEven ? SketchTilt.left : SketchTilt.right,
      child: Row(
        children: <Widget>[
          SketchFrame(
            radius: SketchRadii.d,
            fill: p.note,
            padding: const EdgeInsets.all(6),
            shadowOffset: SketchShadowOffset.card,
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
