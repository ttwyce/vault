/// AI 入口与隐私提示的**纯判定层**（docs/07 §10.2 / C4）。
///
/// 不调模型、不发请求：只定义四个入口何时可见、属于哪级隐私、
/// 云端调用前提示里要写清多少字，以及哪些数据禁止进入 prompt。
library;

import 'agent_policy.dart' show PrivacyLevel;

enum AiEntryPoint { chatTab, searchUpgrade, readerSelection, relatedEntries }

class AiEntryPlan {
  const AiEntryPlan({
    required this.entry,
    required this.visible,
    required this.privacyLevel,
    required this.sendingChars,
    required this.hint,
    required this.needsAuthorization,
  });

  final AiEntryPoint entry;
  final bool visible;
  final PrivacyLevel privacyLevel;
  final int sendingChars;
  final String hint;
  final bool needsAuthorization;

  Map<String, Object?> toJson() => <String, Object?>{
        'entry': entry.name,
        'visible': visible,
        'privacy': privacyLevel.name,
        'sending_chars': sendingChars,
        'hint': hint,
        'needs_authorization': needsAuthorization,
      };
}

/// 云端调用必弹逐次授权，显示发送字数（C4）；
/// L0 数据（密码 / 日记 / 备注）永远不允许出现在任何入口的 prompt。
const Set<String> kNeverInPrompt = <String>{
  'password',
  'totp_secret',
  'secret_custom_fields',
  'credential_notes',
  'diary',
};

AiEntryPlan planAiEntry({
  required AiEntryPoint entry,
  required bool modelAvailable,
  required bool hasContext,
  int contextChars = 0,
  bool includesForbiddenData = false,
}) {
  if (includesForbiddenData) {
    return AiEntryPlan(
      entry: entry,
      visible: false,
      privacyLevel: PrivacyLevel.l0,
      sendingChars: 0,
      hint: '所选内容包含 L0 数据（密码 / 日记 / 备注），禁止进入 prompt',
      needsAuthorization: false,
    );
  }
  if (!modelAvailable) {
    return AiEntryPlan(
      entry: entry,
      visible: false,
      privacyLevel: PrivacyLevel.l0,
      sendingChars: 0,
      hint: '端侧 / 云端模型都未就绪，请到模型管理页配置',
      needsAuthorization: false,
    );
  }
  // 阅读器划词 / 相关推荐必须有上下文才出现；助手 Tab 与搜索升级始终可见。
  final contextRequired =
      entry == AiEntryPoint.readerSelection ||
      entry == AiEntryPoint.relatedEntries;
  if (contextRequired && !hasContext) {
    return AiEntryPlan(
      entry: entry,
      visible: false,
      privacyLevel: PrivacyLevel.l0,
      sendingChars: 0,
      hint: '先选中一段正文或打开条目详情',
      needsAuthorization: false,
    );
  }
  final cloud = entry == AiEntryPoint.searchUpgrade ||
      entry == AiEntryPoint.relatedEntries;
  return AiEntryPlan(
    entry: entry,
    visible: true,
    privacyLevel: cloud ? PrivacyLevel.l2 : PrivacyLevel.l1,
    sendingChars: contextChars,
    hint: cloud
        ? '将把这 $contextChars 字发送到云端模型，需逐次授权'
        : '端侧处理这 $contextChars 字，不外发',
    needsAuthorization: true,
  );
}

/// 隐私提示文案（C4）：显示发送字数与逐次授权，不显示数据内容。
String buildPrivacyNotice(AiEntryPlan plan) => plan.visible
    ? '${plan.hint}\n仅本次有效，可取消。'
    : plan.hint;
