/// 云端模型设置（docs/20 §5 A1）。
///
/// Key 只经 LlmConfigService 写入系统安全区；页面不显示已保存的 Key、
/// 不写本地偏好、不发请求。保存后即时通知 AppRuntime，ChatPage
/// 下次重建就能拿到 LlmRuntime；未配置时保持「不会回答」的诚实状态。
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
  late String _endpointId;
  String _hint = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _endpointId = kDefaultEndpoints.first.id;
    _load();
  }

  @override
  void dispose() {
    _apiKey.dispose();
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
    setState(() {
      _endpointId = savedEndpointId;
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
    setState(() => _busy = true);
    try {
      await ref.read(llmConfigServiceProvider).save(
            endpointId: _endpointId,
            apiKey: key,
          );
      LlmEndpoint? endpoint;
      for (final candidate in kDefaultEndpoints) {
        if (candidate.id == _endpointId) {
          endpoint = candidate;
          break;
        }
      }
      if (endpoint != null) {
        ref.read(appRuntimeProvider.notifier).setLlmRuntime(LlmRuntime(
              endpoint: endpoint,
              apiKey: key,
              client: HttpLlmClient(),
            ));
      }
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
      if (mounted) setState(() => _hint = '已清除云端 Key');
    } on Object {
      if (mounted) setState(() => _hint = '安全存储不可用，未清除');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        subtitle: '自带 Key（BYOK）· 只存系统安全区',
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
                    style: TextStyle(fontSize: 12.5, color: p.ink),
                  ),
                  const SizedBox(height: SketchSpace.md),
                  DropdownButton<String>(
                    value: _endpointId,
                    isExpanded: true,
                    items: <DropdownMenuItem<String>>[
                      for (final endpoint in kDefaultEndpoints)
                        DropdownMenuItem<String>(
                          value: endpoint.id,
                          child: Text(endpoint.label,
                              style: TextStyle(fontSize: 12, color: p.ink)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (String? value) {
                            if (value != null) {
                              setState(() => _endpointId = value);
                            }
                          },
                  ),
                  const SizedBox(height: SketchSpace.sm),
                  TextField(
                    controller: _apiKey,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'API Key'),
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
                    Text(_hint,
                        style: TextStyle(fontSize: 11, color: p.muted)),
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
                'Key 不写入 settings.json、不进入日志与诊断输出；'
                '清除 AI 数据时会一并删除。真实云端回复仍需外网与厂商可用性验收，'
                '未配置时聊天页只保存你的消息。',
                style: TextStyle(fontSize: 11.5, height: 1.7, color: p.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
