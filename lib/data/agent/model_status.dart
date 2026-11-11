/// 聊天页顶部模型状态（docs/07 §10.1 / C5）。
///
/// 不联网、不读 API Key：只根据「端侧模型是否就绪 / 是否配置云端 Key /
/// 双模型路由决策」给出顶部文案与空状态引导。
/// 真实 Key 读取由平台层注入 [ModelAvailability.hasCloudKey]。
library;

import 'agent_policy.dart' show ModelRoute, decideModelRoute;

class ModelAvailability {
  const ModelAvailability({
    required this.onDeviceModelReady,
    required this.hasCloudKey,
    this.cloudProviderLabel = '云端模型',
  });

  final bool onDeviceModelReady;
  final bool hasCloudKey;
  final String cloudProviderLabel;
}

class ModelStatus {
  const ModelStatus({
    required this.subtitle,
    required this.guidance,
    required this.canAnswer,
  });

  final String subtitle;
  final String guidance;
  final bool canAnswer;
}

/// 当前任务（默认普通问答）的路由 → 顶部状态。
///
/// - 路由端侧但模型未就绪：明确「检索可用 / 生成未就绪」引导
/// - 路由云端但没 Key：明确提示去设置配置，绝不假装可回答
/// - 两端都可用：显示当前模型名
ModelStatus resolveModelStatus({
  required ModelAvailability availability,
  String task = 'chat',
  bool userChoseCloud = false,
  bool privacyAuthorized = false,
}) {
  final route = decideModelRoute(
    task,
    userChoseCloud: userChoseCloud,
    onDeviceModelReady: availability.onDeviceModelReady,
    privacyAuthorized: privacyAuthorized,
  );
  if (route.route == ModelRoute.cloud) {
    if (!availability.hasCloudKey) {
      return const ModelStatus(
        subtitle: '云端模型 · 未配置 API Key',
        guidance: '当前检索可用，但生成回复需要先在设置里配置 API Key。',
        canAnswer: false,
      );
    }
    return ModelStatus(
      subtitle: '${availability.cloudProviderLabel} · 已授权本次',
      guidance: '',
      canAnswer: true,
    );
  }
  if (!availability.onDeviceModelReady) {
    return const ModelStatus(
      subtitle: '端侧模型 · 未就绪',
      guidance: '检索与工具仍可用；下载端侧模型后可获得 AI 回复。'
          '也可在设置里配置云端模型。',
      canAnswer: false,
    );
  }
  return const ModelStatus(
    subtitle: '端侧模型 · 就绪',
    guidance: '',
    canAnswer: true,
  );
}
