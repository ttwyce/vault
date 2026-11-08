import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';

/// 密码库。
///
/// 安全边界（docs/11 §4.4）：
/// - 密码明文永不进入 prompt、日志、向量
/// - 标了 secret 的自定义字段与密码同级加密
/// - 泄露检测只发哈希前 5 位
class VaultPage extends StatelessWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;

    return PageScaffold(
      title: '密码',
      subtitle: '42 个 · 安全评分 72',
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
                    '有 1 个密码出现在泄露库里，建议立刻改',
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
