import 'package:flutter/material.dart';

import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_frame.dart';

/// 关于 / 隐私与加密声明（docs/09 §10 上架材料）。
///
/// 零后端、零遥测、数据本地加密是产品的核心承诺，必须在 App 内可读。
/// 字体 OFL 声明已随 `assets/licenses/font-notices.txt` 打包；Gemma 模型
/// 条款在用户下载该模型前也要能看见。这里只放静态说明文本，不新增 asset、
/// 不改 pubspec.yaml、不收集任何信息。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const List<(String, String)> _sections = <(String, String)>[
    (
      '数据在你手里',
      '没有自建后端，没有账号体系。笔记、日记、归档与密码先写入本机 '
          'SQLCipher 加密库，同步只连接你自己配置的 WebDAV 目录。',
    ),
    (
      '端到端加密',
      '本地库整库加密；同步出去的每个条目、墓碑与元数据都是独立加密信封。'
          'WebDAV 服务商只能看到密文与随机文件名。',
    ),
    (
      '密码与 AI',
      '密码、TOTP、secret 自定义字段与日记正文默认不出设备；'
          'AI 健康报告只返回聚合统计，任何工具都不返回明文。'
          '云端模型需要逐次授权。',
    ),
    (
      '无遥测',
      '不上传崩溃日志、使用统计或搜索词。活动埋点只存在本机，'
          '用于生成可溯源的时间线。',
    ),
    (
      '开源许可',
      '内置霞鹜文楷 Lite、Caveat、JetBrains Mono 均为 SIL OFL 1.1，'
          '许可声明见随包 assets/licenses/font-notices.txt。'
          '若下载 EmbeddingGemma 模型，还需遵守 Gemma Terms of Use；'
          'Qwen3-Embedding 为 Apache 2.0。',
    ),
    (
      '恢复码',
      '恢复码是库的备份钥匙：系统不存储原文，创建时只展示一次。'
          '请离线抄写，不要截图；遗失恢复码且忘记主密码时数据无法恢复。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '关于与隐私',
        subtitle: '离线优先 · 端侧加密 · 零遥测',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SketchSpace.lg,
            SketchSpace.md,
            SketchSpace.lg,
            SketchSpace.xxl,
          ),
          children: <Widget>[
            for (final (title, body) in _sections) ...<Widget>[
              SketchFrame(
                radius: SketchRadii.c,
                fill: p.surface,
                padding: const EdgeInsets.all(SketchSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: SketchSpace.sm),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.7,
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SketchSpace.md),
            ],
          ],
        ),
      ),
    );
  }
}
