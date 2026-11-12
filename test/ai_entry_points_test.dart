import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/agent_policy.dart' show PrivacyLevel;
import 'package:vault/data/agent/ai_entry_points.dart';

/// docs/07 §10.2 / C4 AI 入口与隐私提示测试。
void main() {
  test('L0 数据永远禁止进 prompt，任何模型状态都不显示入口', () {
    final plan = planAiEntry(
      entry: AiEntryPoint.readerSelection,
      modelAvailable: true,
      hasContext: true,
      contextChars: 100,
      includesForbiddenData: true,
    );
    expect(plan.visible, isFalse);
    expect(plan.sendingChars, 0);
    expect(plan.hint, contains('禁止'));
    expect(kNeverInPrompt, contains('password'));
    expect(kNeverInPrompt, contains('diary'));
  });

  test('模型未就绪 / 缺上下文一律隐藏并给明确引导', () {
    final noModel = planAiEntry(
      entry: AiEntryPoint.chatTab,
      modelAvailable: false,
      hasContext: false,
    );
    expect(noModel.visible, isFalse);
    expect(noModel.hint, contains('模型管理页'));

    final noSelection = planAiEntry(
      entry: AiEntryPoint.readerSelection,
      modelAvailable: true,
      hasContext: false,
    );
    expect(noSelection.visible, isFalse);
    expect(noSelection.hint, contains('先选中'));
  });

  test('云端入口必弹逐次授权并显示发送字数（C4）', () {
    final cloud = planAiEntry(
      entry: AiEntryPoint.searchUpgrade,
      modelAvailable: true,
      hasContext: true,
      contextChars: 320,
    );
    expect(cloud.visible, isTrue);
    expect(cloud.privacyLevel, PrivacyLevel.l2);
    expect(cloud.needsAuthorization, isTrue);
    expect(cloud.hint, contains('320 字'));
    expect(buildPrivacyNotice(cloud), contains('仅本次有效'));
    expect(cloud.toJson()['sending_chars'], 320);

    final local = planAiEntry(
      entry: AiEntryPoint.chatTab,
      modelAvailable: true,
      hasContext: false,
      contextChars: 0,
    );
    expect(local.privacyLevel, PrivacyLevel.l1);
    expect(local.needsAuthorization, isTrue);
    expect(local.hint, contains('不外发'));
  });
}
