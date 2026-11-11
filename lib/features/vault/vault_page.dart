import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/vault/credential_models.dart';
import '../../data/vault/credential_repository_provider.dart';

/// 密码库。
///
/// 安全边界（docs/11 §4.4）：
/// - 密码明文永不进入 prompt、日志、向量
/// - 标了 secret 的自定义字段与密码同级加密
/// - 泄露检测只发哈希前 5 位
///
/// 顶部健康提示与 subtitle 走 `CredentialRepository` 的真实聚合统计，
/// 不再显示写死的假数据。
class VaultPage extends ConsumerWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.sketch;
    final repo = ref.watch(credentialRepositoryProvider);
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
        SketchButton(label: '新增', dense: true, onPressed: () {}),
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
          _VaultTile(
            variant: 1,
            letter: 'G',
            name: 'GitHub',
            account: 'user@example.com · 30 天前',
            badges: const <(String, SketchTone)>[
              ('TOTP', SketchTone.plain),
              ('常用', SketchTone.plain),
            ],
          ),
          const SizedBox(height: SketchSpace.md),
          _VaultTile(
            variant: 2,
            letter: 'C',
            name: 'Cloudflare',
            account: 'admin@example.com · 92 天前',
            badges: const <(String, SketchTone)>[
              ('TOTP', SketchTone.plain),
              ('已泄露', SketchTone.primary),
            ],
          ),
          const SizedBox(height: SketchSpace.md),
          _VaultTile(
            variant: 3,
            letter: '阿',
            name: '阿里云',
            account: 'admin@example.com · 210 天前',
            badges: const <(String, SketchTone)>[
              ('TOTP', SketchTone.plain),
              ('重复', SketchTone.blue),
            ],
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
