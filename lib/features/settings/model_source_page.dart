/// 自定义端侧模型下载源页（docs/06 §5）。
///
/// 内置 manifest 的 sha256 是占位且 sources 为空，这里让用户提供真实
/// URL / sha256 / 字节数，保存进安全区后调用真实 HttpModelDownloader
/// 下载、校验并记录结果。不内置模型二进制、不新增依赖。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/app_runtime.dart';
import '../../app/session/model_source_provider.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_field.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/search/embedding_manifest.dart';
import '../../data/search/model_source_store.dart';

class ModelSourcePage extends ConsumerStatefulWidget {
  const ModelSourcePage({super.key});

  @override
  ConsumerState<ModelSourcePage> createState() => _ModelSourcePageState();
}

class _ModelSourcePageState extends ConsumerState<ModelSourcePage> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _sha = TextEditingController();
  final TextEditingController _bytes = TextEditingController();
  late String _modelId;
  String _hint = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _modelId = EmbeddingModelSpec.fromJson(kDefaultModelSpecs.first).id;
    _load();
  }

  @override
  void dispose() {
    _url.dispose();
    _sha.dispose();
    _bytes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await ref.read(modelSourceServiceProvider).loadAll();
    final source = all[_modelId];
    if (source == null || !mounted) return;
    setState(() {
      _url.text = source.url;
      _sha.text = source.sha256;
      _bytes.text = source.bytes.toString();
      _hint = '已保存「$_modelId」的下载源';
    });
  }

  Future<void> _save() async {
    final bytes = int.tryParse(_bytes.text.trim());
    final source = ModelDownloadSource(
      modelId: _modelId,
      url: _url.text.trim(),
      sha256: _sha.text.trim(),
      bytes: bytes ?? 0,
    );
    if (!source.valid) {
      setState(() => _hint = '需要 http(s) URL、64 位小写 sha256、正数 bytes');
      return;
    }
    await ref.read(modelSourceServiceProvider).save(source);
    if (mounted) setState(() => _hint = '下载源已保存，可开始下载');
  }

  Future<void> _download() async {
    final service = ref.read(modelSourceServiceProvider);
    final source = (await service.loadAll())[_modelId];
    if (source == null) {
      setState(() => _hint = '请先保存下载源');
      return;
    }
    final factory = ref.read(appRuntimeProvider).modelDownloaderFactory;
    if (factory == null) {
      setState(() => _hint = '未装配 models 目录');
      return;
    }
    setState(() => _busy = true);
    final downloader = factory();
    try {
      final outcome = await downloader.download(
        modelId: source.modelId,
        expectedSha256: source.sha256,
        modelBytes: source.bytes,
        sourceUrls: <String>[source.url],
      );
      if (mounted) setState(() => _hint = outcome.hint);
    } finally {
      downloader.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final specs = <EmbeddingModelSpec>[
      for (final raw in kDefaultModelSpecs) EmbeddingModelSpec.fromJson(raw),
    ];
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '模型下载源',
        subtitle: '自定义 URL / sha256 / 字节数 · 只存系统安全区',
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    spacing: SketchSpace.sm,
                    runSpacing: SketchSpace.sm,
                    children: <Widget>[
                      for (final spec in specs)
                        GestureDetector(
                          onTap: () {
                            setState(() => _modelId = spec.id);
                            _load();
                          },
                          child: SketchTag(
                            spec.name,
                            tone: spec.id == _modelId
                                ? SketchTone.primary
                                : SketchTone.ghost,
                            dense: true,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: SketchSpace.lg),
                  _Field('模型文件 URL', _url),
                  const SizedBox(height: SketchSpace.sm),
                  _Field('sha256（64 位小写）', _sha),
                  const SizedBox(height: SketchSpace.sm),
                  _Field('文件字节数', _bytes),
                  const SizedBox(height: SketchSpace.md),
                  Wrap(
                    spacing: SketchSpace.sm,
                    runSpacing: SketchSpace.sm,
                    children: <Widget>[
                      SketchButton(
                        label: '保存下载源',
                        dense: true,
                        onPressed: _busy ? null : _save,
                      ),
                      SketchButton(
                        label: '下载并校验',
                        tone: SketchTone.primary,
                        dense: true,
                        onPressed: _busy ? null : _download,
                      ),
                    ],
                  ),
                  if (_hint.isNotEmpty) ...<Widget>[
                    const SizedBox(height: SketchSpace.sm),
                    Text(_hint, style: context.texts.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SketchSpace.lg),
            SketchFrame(
              radius: SketchRadii.c,
              fill: p.noteAlt,
              borderColor: p.lineSoft,
              padding: const EdgeInsets.all(SketchSpace.lg),
              child: Text(
                '内置清单的 sha256 是占位值，必须替换成真实文件的校验值；'
                '下载器会写 .part、校验 sha256，失败换源或标记损坏。'
                '端侧模型推理仍需平台运行时，不在这里假称可用。',
                style: context.texts.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.controller);
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => SketchFieldFrame(
        child: TextField(
          controller: controller,
          decoration: sketchInputDecoration(context, hintText: label),
        ),
      );
}
