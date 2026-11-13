/// 云端模型设置：多端点 / 自动拉取模型 / 上下文预算（docs/20 §5 A1）。
///
/// Key 与端点档案只写入系统安全区；页面不回显 Key、不写本地偏好。
/// 保存后即时通知 AppRuntime，ChatPage 用打包后的会话历史发请求。
library;

import 'dart:async';

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
import '../../data/agent/context_compressor.dart';
import '../../data/agent/http_llm_client.dart';
import '../../data/agent/http_model_catalog.dart';
import '../../data/agent/llm_chat_service.dart';
import '../../data/agent/llm_config_store.dart';
import '../../data/agent/openai_compat.dart';
import '../../data/agent/system_prompt.dart';

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

  List<LlmProfile> _profiles = <LlmProfile>[];
  String _activeId = kDefaultEndpoints.first.id;
  bool _isCustom = false;
  String _hint = '';
  String _contextHint = '';
  List<String> _remoteModels = <String>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
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

  LlmProfile? get _active {
    for (final profile in _profiles) {
      if (profile.id == _activeId) return profile;
    }
    return null;
  }

  Future<void> _load() async {
    final LlmConfig? config;
    try {
      config = await ref.read(llmConfigServiceProvider).load();
    } on Object {
      return;
    }
    if (!mounted || config == null) return;
    final loaded = config;
    setState(() {
      _profiles = loaded.profiles;
      _activeId = loaded.endpointId;
      _isCustom = loaded.endpointId == kCustomLlmEndpointId;
      final active = loaded.active;
      if (_isCustom && active != null) {
        _customLabel.text = active.label;
        _customBaseUrl.text = active.baseUrl;
        _customModel.text = active.model;
      }
      _hint = '已保存 ${_profiles.length} 个端点（Key 未显示）';
      _updateContextHint();
    });
  }

  void _updateContextHint() {
    final endpoint = _active?.toEndpoint() ??
        (_isCustom
            ? tryCustomLlmEndpoint(
                label: _customLabel.text,
                baseUrl: _customBaseUrl.text,
                model: _customModel.text,
              )
            : resolveLlmEndpoint(_activeId, null));
    if (endpoint == null) {
      _contextHint = '';
      return;
    }
    final plan = packLlmContext(
      systemPrompt: kSystemPrompt,
      history: const <LlmMessage>[],
      currentQuestion: '你好',
      maxTokens: endpoint.maxTokens,
    );
    _contextHint = '上下文预算 ${plan.budgetTokens} token'
        '（回答预留 $kDefaultCompletionReserveTokens，'
        '单次上限 ${endpoint.maxTokens}）；超预算自动压缩较早历史';
  }

  Future<void> _select(LlmProfile profile) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(llmConfigServiceProvider);
      await service.setActiveProfile(profile.id);
      final config = await service.load();
      final key = config?.apiKey ?? _apiKey.text.trim();
      if (key.isNotEmpty) {
        ref.read(appRuntimeProvider.notifier).setLlmRuntime(LlmRuntime(
              endpoint: profile.toEndpoint(),
              apiKey: key,
              client: HttpLlmClient(),
            ));
      }
      if (!mounted) return;
      setState(() {
        _activeId = profile.id;
        _isCustom = profile.id == kCustomLlmEndpointId;
        if (_isCustom) {
          _customLabel.text = profile.label;
          _customBaseUrl.text = profile.baseUrl;
          _customModel.text = profile.model;
        }
        _remoteModels = <String>[];
        _hint = '已切换到「${profile.label}」';
        _updateContextHint();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCustom() {
    setState(() {
      _isCustom = true;
      _activeId = kCustomLlmEndpointId;
      _customLabel.clear();
      _customBaseUrl.clear();
      _customModel.clear();
      _remoteModels = <String>[];
      _hint = '填写自定义端点，保存后即可切换';
      _updateContextHint();
    });
  }

  LlmProfile? _draftProfile() {
    final endpoint = tryCustomLlmEndpoint(
      label: _customLabel.text,
      baseUrl: _customBaseUrl.text,
      model: _customModel.text,
    );
    if (endpoint == null) return null;
    return LlmProfile(
      id: kCustomLlmEndpointId,
      label: endpoint.label,
      baseUrl: endpoint.baseUrl,
      model: endpoint.model,
    );
  }

  Future<void> _save() async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) {
      setState(() => _hint = '请先填写 Key');
      return;
    }
    final LlmProfile profile;
    if (_isCustom) {
      final draft = _draftProfile();
      if (draft == null) {
        setState(() => _hint = '自定义端点需要名称、https 地址与模型名');
        return;
      }
      profile = draft;
    } else {
      final endpoint = resolveLlmEndpoint(_activeId, null);
      if (endpoint == null) {
        setState(() => _hint = '端点配置无效，未保存');
        return;
      }
      profile = LlmProfile(
        id: endpoint.id,
        label: endpoint.label,
        baseUrl: endpoint.baseUrl,
        model: endpoint.model,
      );
    }
    setState(() => _busy = true);
    try {
      final service = ref.read(llmConfigServiceProvider);
      await service.saveProfile(profile: profile, apiKey: key);
      final loaded = await service.load();
      _profiles = loaded?.profiles ?? <LlmProfile>[profile];
      ref.read(appRuntimeProvider.notifier).setLlmRuntime(LlmRuntime(
            endpoint: profile.toEndpoint(),
            apiKey: key,
            client: HttpLlmClient(),
          ));
      _apiKey.clear();
      if (mounted) {
        setState(() {
          _activeId = profile.id;
          _hint = '已保存端点：${profile.label}（共 ${_profiles.length} 个）';
          _updateContextHint();
        });
      }
    } on Object {
      if (mounted) setState(() => _hint = '安全存储不可用，未保存');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetchModels() async {
    final endpoint = _isCustom
        ? tryCustomLlmEndpoint(
            label: _customLabel.text.isEmpty ? '自定义' : _customLabel.text,
            baseUrl: _customBaseUrl.text,
            model: _customModel.text.isEmpty ? 'placeholder' : _customModel.text,
          )
        : (_active?.toEndpoint() ?? resolveLlmEndpoint(_activeId, null));
    if (endpoint == null) {
      setState(() => _hint = '先填写合法的 https 接口地址');
      return;
    }
    final key = _apiKey.text.trim().isNotEmpty
        ? _apiKey.text.trim()
        : (await ref.read(llmConfigServiceProvider).load())?.apiKey ?? '';
    if (key.isEmpty) {
      setState(() => _hint = '获取模型列表需要先填写或已保存 Key');
      return;
    }
    setState(() => _busy = true);
    final catalog = HttpModelCatalog();
    try {
      final result = await catalog.listModels(
        baseUrl: endpoint.baseUrl,
        apiKey: key,
      );
      if (!mounted) return;
      setState(() {
        _remoteModels = result.models;
        _hint = result.hint;
      });
    } finally {
      catalog.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(LlmProfile profile) async {
    setState(() => _busy = true);
    try {
      await ref.read(llmConfigServiceProvider).removeProfile(profile.id);
      final loaded = await ref.read(llmConfigServiceProvider).load();
      if (!mounted) return;
      setState(() {
        _profiles = loaded?.profiles ?? <LlmProfile>[];
        _activeId = loaded?.endpointId ?? kDefaultEndpoints.first.id;
        _isCustom = _activeId == kCustomLlmEndpointId;
        _hint = loaded == null ? '已清除全部端点' : '已移除 ${profile.label}';
        _updateContextHint();
      });
      if (loaded == null) {
        ref.read(appRuntimeProvider.notifier).setLlmRuntime(null);
      }
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
          _profiles = <LlmProfile>[];
          _activeId = kDefaultEndpoints.first.id;
          _isCustom = false;
          _remoteModels = <String>[];
          _hint = '已清除云端 Key 与全部端点';
          _contextHint = '';
        });
      }
    } on Object {
      if (mounted) setState(() => _hint = '安全存储不可用，未清除');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final configured = ref.watch(appRuntimeProvider).llmRuntime != null;
    return Scaffold(
      backgroundColor: p.bg,
      body: PageScaffold(
        title: '云端模型',
        subtitle: '多端点 · 自动模型列表 · 上下文预算',
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
                  const SizedBox(height: SketchSpace.sm),
                  Text('已保存的端点', style: context.texts.bodySmall),
                  const SizedBox(height: SketchSpace.sm),
                  if (_profiles.isEmpty)
                    Text('还没有保存端点，选择预设或新增自定义端点。',
                        style: context.texts.bodySmall)
                  else
                    for (final profile in _profiles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: SketchSpace.xs),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: GestureDetector(
                                onTap: () => unawaited(_select(profile)),
                                child: SketchTag(
                                  '${profile.label} · ${profile.model}',
                                  tone: profile.id == _activeId
                                      ? SketchTone.primary
                                      : SketchTone.ghost,
                                  dense: true,
                                ),
                              ),
                            ),
                            SketchIconButton(
                              glyph: SketchGlyph.close,
                              tooltip: '移除 ${profile.label}',
                              onPressed: _busy ? null : () => _remove(profile),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: SketchSpace.md),
                  Wrap(
                    spacing: SketchSpace.sm,
                    runSpacing: SketchSpace.sm,
                    children: <Widget>[
                      for (final endpoint in kDefaultEndpoints)
                        _EndpointTag(
                          key: ValueKey<String>('endpoint-${endpoint.id}'),
                          label: endpoint.label,
                          selected: !_isCustom && _activeId == endpoint.id,
                          onTap: () => unawaited(_select(LlmProfile(
                            id: endpoint.id,
                            label: endpoint.label,
                            baseUrl: endpoint.baseUrl,
                            model: endpoint.model,
                          ))),
                        ),
                      _EndpointTag(
                        key: const ValueKey<String>('endpoint-custom'),
                        label: '新增自定义端点',
                        selected: _isCustom,
                        onTap: _startCustom,
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
                  const SizedBox(height: SketchSpace.sm),
                  SketchButton(
                    label: '自动获取模型列表',
                    glyph: SketchGlyph.search,
                    dense: true,
                    onPressed: _busy ? null : _fetchModels,
                  ),
                  if (_remoteModels.isNotEmpty) ...<Widget>[
                    const SizedBox(height: SketchSpace.sm),
                    Wrap(
                      spacing: SketchSpace.sm,
                      runSpacing: SketchSpace.sm,
                      children: <Widget>[
                        for (final model in _remoteModels)
                          GestureDetector(
                            onTap: () => setState(() {
                              _customModel.text = model;
                              if (!_isCustom) _startCustom();
                              _hint = '已选择模型 $model，保存后生效';
                            }),
                            child: SketchTag(model, dense: true),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: SketchSpace.md),
                  Wrap(
                    spacing: SketchSpace.sm,
                    runSpacing: SketchSpace.sm,
                    children: <Widget>[
                      SketchButton(
                        label: '保存',
                        tone: SketchTone.primary,
                        dense: true,
                        onPressed: _busy ? null : _save,
                      ),
                      SketchButton(
                        label: '清除全部',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('上下文信息', style: context.texts.titleSmall),
                  const SizedBox(height: SketchSpace.xs),
                  Text(
                    _contextHint.isEmpty
                        ? '保存端点后显示上下文预算。'
                        : _contextHint,
                    style: context.texts.bodySmall,
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  Text(
                    'Key 与端点档案只存系统安全区，不进 settings.json、日志或诊断输出；'
                    '聊天请求会带最近会话历史，超预算时自动压缩较早轮次。',
                    style: context.texts.bodySmall,
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
        Text(label, style: context.texts.bodySmall?.copyWith(color: p.muted)),
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
