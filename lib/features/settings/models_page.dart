/// 模型管理页（docs/10 第 18 屏 / docs/06 §7）。
///
/// 这里只展示**可确定的纯状态**：默认模型清单、四态检索降级、
/// 源优先级、磁盘检查与备份排除配置。真实下载 / 校验 / 端侧推理
/// 需要模型文件与平台层，不在这里假装已下载或显示假进度。
library;

import 'package:flutter/material.dart';

import '../../../app/theme/sketch_metrics.dart';
import '../../../app/theme/sketch_theme.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/icons/sketch_icons.dart';
import '../../../core/widgets/sketch_controls.dart';
import '../../../core/widgets/sketch_frame.dart';
import '../../../data/search/embedding_manifest.dart';
import '../../../data/search/model_downloader.dart';

class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    // 默认状态：模型未下载、无索引构建 —— 诚实展示，不假装有进度。
    final degradation = planSearchDegradation(
      modelState: ModelState.idle,
      modelDownloaded: false,
    );
    final specs = <EmbeddingModelSpec>[
      for (final raw in kDefaultModelSpecs) EmbeddingModelSpec.fromJson(raw),
    ];

    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '模型管理',
        subtitle: '端侧模型与检索降级（未接真实下载）',
        showSettings: false,
        leading: SketchIconButton(
          glyph: SketchGlyph.close,
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        child: ListView(
          padding: const EdgeInsets.all(SketchSpace.lg),
          children: <Widget>[
            SketchFrame(
              radius: SketchRadii.b,
              fill: p.surface,
              borderColor: p.line,
              padding: const EdgeInsets.all(SketchSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '检索状态',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  Text(
                    degradation.uiHint.isEmpty
                        ? '完整混合检索'
                        : degradation.uiHint,
                    style: TextStyle(fontSize: 12, color: p.ink),
                  ),
                  Text(
                    'FTS ${degradation.ftsEnabled ? '可用' : '不可用'} · '
                    '向量 ${degradation.vectorEnabled ? '可用' : '未启用'} · '
                    '未配置云端 Key',
                    style: TextStyle(fontSize: 11, color: p.muted),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  Text(
                    '任何状态下关键词检索都可用；模型下载中静默、'
                    '索引构建中只用已构建部分的向量。',
                    style: TextStyle(fontSize: 10.5, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SketchSpace.lg),
            SketchFrame(
              radius: SketchRadii.d,
              fill: p.noteAlt,
              borderColor: p.lineSoft,
              padding: const EdgeInsets.all(SketchSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '默认模型清单（${specs.length} 个）',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  for (final spec in specs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SketchSpace.xs),
                      child: Text(
                        '${spec.name} · ${spec.dim} 维 ${spec.quant} · '
                        '${(spec.diskBytes / 1024 / 1024).toStringAsFixed(0)} MB '
                        '（需 ${(requiredDiskBytes(spec) / 1024 / 1024).toStringAsFixed(0)} MB 空间）',
                        style: TextStyle(fontSize: 11, color: p.ink),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SketchSpace.lg),
            SketchFrame(
              radius: SketchRadii.c,
              fill: p.surface,
              borderColor: p.line,
              padding: const EdgeInsets.all(SketchSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '下载源优先级（${kDefaultSourceOrder.length} 个）',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  for (var i = 0; i < kDefaultSourceOrder.length; i++)
                    Text(
                      '${i + 1}. ${kDefaultSourceOrder[i].name}',
                      style: TextStyle(fontSize: 11, color: p.ink),
                    ),
                  const SizedBox(height: SketchSpace.sm),
                  const Text(
                    '每源 3 次重试、全源失败才标记损坏；模型文件不进系统备份'
                    '（三端四标记需平台层落配置）。',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF6B6459)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
