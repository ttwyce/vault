import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_palette.dart';
import 'package:vault/app/theme/sketch_theme.dart';
import 'package:vault/app/theme/sketch_typography.dart';
import 'package:vault/data/agent/openai_compat.dart';

/// 主题层把原生控件统一到色板；自定义端点不泄漏到脱敏日志。
void main() {
  test('SketchTheme 覆盖原生控件的默认颜色 / 下划线', () {
    final theme = SketchTheme.build(
      palette: SketchPalette.light,
      brightness: Brightness.light,
      typography: SketchTypography.handwritten,
    );
    expect(theme.inputDecorationTheme.border, InputBorder.none);
    expect(theme.inputDecorationTheme.labelStyle?.color,
        SketchPalette.light.muted);
    expect(theme.switchTheme.thumbColor
        ?.resolve(<WidgetState>{WidgetState.selected}),
        SketchPalette.light.red);
    expect(theme.dialogTheme.backgroundColor, SketchPalette.light.surface);
    expect(theme.textButtonTheme.style?.foregroundColor
        ?.resolve(<WidgetState>{}), SketchPalette.light.ink);
    expect(theme.listTileTheme.titleTextStyle?.color,
        SketchPalette.light.ink);
  });

  test('tryCustomLlmEndpoint 只接受 https 且去掉尾斜杠', () {
    final endpoint = tryCustomLlmEndpoint(
      label: '  自建  ',
      baseUrl: 'https://llm.example.com/v1/',
      model: '  local-chat  ',
    );
    expect(endpoint, isNotNull);
    expect(endpoint!.id, kCustomLlmEndpointId);
    expect(endpoint.label, '自建');
    expect(endpoint.baseUrl, 'https://llm.example.com/v1');
    expect(endpoint.model, 'local-chat');
    expect(endpoint.isCustom, isTrue);

    expect(
      tryCustomLlmEndpoint(
          label: 'x', baseUrl: 'http://llm.example.com/v1', model: 'm'),
      isNull,
    );
    expect(
      tryCustomLlmEndpoint(
          label: 'x',
          baseUrl: 'https://user:pass@llm.example.com/v1',
          model: 'm'),
      isNull,
    );
    expect(
      tryCustomLlmEndpoint(
          label: 'x', baseUrl: 'https://llm.example.com/v1?key=1', model: 'm'),
      isNull,
    );
  });

  test('parseCustomLlmEndpoint 与 resolveLlmEndpoint 处理坏值 / 预设', () {
    const raw = '{"label":"自建","base_url":"https://x.example.com/v1",'
        '"model":"m"}';
    final parsed = parseCustomLlmEndpoint(raw);
    expect(parsed, isNotNull);
    expect(parsed!.baseUrl, 'https://x.example.com/v1');
    expect(parseCustomLlmEndpoint('{bad'), isNull);
    expect(resolveLlmEndpoint(kCustomLlmEndpointId, null), isNull);
    expect(resolveLlmEndpoint('deepseek', raw)!.id, 'deepseek');
    expect(resolveLlmEndpoint('unknown', raw), isNull);
  });

  test('自定义端点的脱敏日志不回显用户地址 / 模型名', () {
    final endpoint = tryCustomLlmEndpoint(
      label: '自建',
      baseUrl: 'https://secret.example.com/v1',
      model: 'private-model',
    )!;
    final log = redactedRequestLog(
      endpoint: endpoint,
      statusCode: 200,
      totalTokens: 7,
    );
    expect(log['url'], '<custom>/chat/completions');
    expect(log['model'], '<custom>');
    expect(log.toString(), isNot(contains('secret.example.com')));
    expect(log.toString(), isNot(contains('private-model')));
  });
}
