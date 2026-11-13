/// 云端模型设置（docs/20 §5 A1）。
///
/// Key 与自定义端点配置只经 LlmConfigService 写入系统安全区；页面不显示
/// 已保存的 Key、不写本地偏好、不发请求。保存后即时通知 AppRuntime，
/// ChatPage 下次重建就能拿到 LlmRuntime；未配置时保持「不会回答」的诚实状态。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/app_runtime.dart';
import '../../app/session/llm_runtime_provider.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_field.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/agent/http_llm_client.dart';
import '../../data/agent/llm_chat_service.dart';
import '../../data/agent/llm_config_store.dart';
import '../../data/agent/openai_compat.dart';

class LlmSettingsPage extends ConsumerStatefulWidget {
  const LlmSettingsPage({super.key});

  @override
  ConsumerState<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends ConsumerState<LlmSettingsPage> {
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _customLabel = TextEditingController();
  final TextEditingController _customBaseUrl = TextEditingController();
  final TextEditingController _customModel = TextEditingController();
  late String _endpointId;
  String _hint = '';
  bool _busy = false;

  bool get _isCustom => _endpointId == kCustomLlmEndpointId;

  @override
  void initState() {
    super.initState();
    _endpointId = kDefaultEndpoints.first.id;
    _load();
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _customLabel.dispose();
    _customBaseUrl.dispose();
    _customModel.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final LlmConfig? config;
    try {
      config = await ref.read(llmConfigServiceProvider).load();
    } on Object {
      return;
    }
    if (!mounted || config == null) return;
    final savedEndpointId = config.endpointId;
    final endpoint = savedEndpointId == kCustomLlmEndpointId
        ? parseCustomLlmEndpoint(config.customEndpointRaw ?? '')
        : null;
    setState(() {
      _endpointId = savedEndpointId;
      if (endpoint != null) {
        _customLabel.text = endpoint.label;
        _customBaseUrl.text = endpoint.baseUrl;
        _customModel.text = endpoint.model;
      }
      // 输入框留空：已保存的 Key 不回填到可截图 / 可复制的表单里。
      _hint = '已保存云端 Key（未显示），可直接清除或覆盖';
    });
  }

  Future<void> _save() async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) {
      setState(() => _hint = '请先填写 Key');
      return;
    }
    final LlmEndpoint? endpoint;
    if (_isCustom) {
      endpoint = tryCustomLlmEndpoint(
        label: _customLabel.text,
        baseUrl: _customBaseUrl.text,
        model: _customModel.text,
      );
      if (endpoint == null) {
        setState(() => _hint = '自定义端点需要名称、https 地址与模型名');
        return;
      }
    } else {
      endpoint = resolveLlmEndpoint(_endpointId, null);
    }
    if (endpoint == null) {
      setState(() => _hint = '端点配置无效，未保存');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(llmConfigServiceProvider).save(
            endpointId: endpoint.id,
            apiKey: key,
            customEndpoint: _isCustom ? endpoint : null,
          );
      ref.read(appRuntimeProvider.notifier).setLlmRuntime(LlmRuntime(
            endpoint: endpoint,
            apiKey: key,
            client: HttpLlmClient(),
          ));
      _apiKey.clear();
      if (mounted) setState(() => _hint = '已保存，模型回复现在可用');
    } on Object {
      if (mounted) setState(() => _hint = '安全存储不可用，未保存');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    try {
      await ref.read(llmConfigServiceProvider).clear();
      ref.read(appRuntimeProvider.notifier).setLlmRuntime(null);
      _apiKey.clear();
      _customLabel.clear();
      _customBaseUrl.clear();
      _customModel.clear();
      if (mounted) {
        setState(() {
          _endpointId = kDefaultEndpoints.first.id;
          _hint = '已清除云端 Key 与自定义端点';
        });
      }
    } on Object {
      if (mounted) setState(() => _hint = '安全存储不可用，未清除');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _select(String id) {
    if (_busy) return;
    setState(() => _endpointId = id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    // watch：Key 保存 / 清除后立即重建状态说明。
    final configured = ref.watch(appRuntimeProvider).llmRuntime != null;
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '云端模型',
        subtitle: '预设 / 自定义 OpenAI 兼容端点 · Key 只存系统安全区',
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
                  Text(
                    configured ? '状态：已配置' : '状态：未配置（不会生成模型回复）',
                    style: context.texts.bodyMedium,
                  ),
                  const SizedBox(height: SketchSpace.md),
                  Text('选择端点', style: context.texts.bodySmall),
                  const SizedBox(height: SketchSpace.sm),
                  Wrap(
                    spacing: SketchSpace.sm,
                    runSpacing: SketchSpace.sm,
                    children: <Widget>[
                      for (final endpoint in kDefaultEndpoints)
                        _EndpointTag(
                          key: ValueKey<String>('endpoint-${endpoint.id}'),
                          label: endpoint.label,
                          selected: _endpointId == endpoint.id,
                          onTap: () => _select(endpoint.id),
                        ),
                      _EndpointTag(
                        key: const ValueKey<String>('endpoint-custom'),
                        label: '自定义端点',
                        selected: _isCustom,
                        onTap: () => _select(kCustomLlmEndpointId),
                      ),
                    ],
                  ),
                  if (_isCustom) ...<Widget>[
                    const SizedBox(height: SketchSpace.lg),
                    _LabeledField(
                      key: const ValueKey<String>('custom-label'),
                      label: '名称',
                      controller: _customLabel,
                      hintText: '例如：自建网关',
                    ),
                    const SizedBox(height: SketchSpace.sm),
                    _LabeledField(
                      key: const ValueKey<String>('custom-base-url'),
                      label: '接口地址',
                      controller: _customBaseUrl,
                      hintText: 'https://example.com/v1',
                    ),
                    const SizedBox(height: SketchSpace.sm),
                    _LabeledField(
                      key: const ValueKey<String>('custom-model'),
                      label: '模型名',
                      controller: _customModel,
                      hintText: '例如：my-model',
                    ),
                  ],
                  const SizedBox(height: SketchSpace.md),
                  _LabeledField(
                    key: const ValueKey<String>('api-key'),
                    label: 'API Key',
                    controller: _apiKey,
                    hintText: '保存后不再显示',
                    obscureText: true,
                  ),
                  const SizedBox(height: SketchSpace.md),
                  Row(
                    children: <Widget>[
                      SketchButton(
                        label: '保存',
                        tone: SketchTone.primary,
                        dense: true,
                        onPressed: _busy ? null : _save,
                      ),
                      const SizedBox(width: SketchSpace.sm),
                      SketchButton(
                        label: '清除',
                        dense: true,
                        onPressed: _busy ? null : _clear,
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
                'Key 与自定义端点不写入 settings.json、不进入日志与诊断输出；'
                '清除 AI 数据时会一并删除。真实云端回复仍需外网与厂商可用性验收，'
                '未配置时聊天页只保存你的消息。',
                style: context.texts.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointTag extends StatelessWidget {
  const _EndpointTag({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SketchTag(
          label,
          tone: selected ? SketchTone.primary : SketchTone.ghost,
          dense: true,
        ),
      );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label,
            style: context.texts.bodySmall
                ?.copyWith(color: p.muted)),
        const SizedBox(height: SketchSpace.xs),
        SketchFieldFrame(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            decoration: sketchInputDecoration(context, hintText: hintText),
          ),
        ),
      ],
    );
  }
}
