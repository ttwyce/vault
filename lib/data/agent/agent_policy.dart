/// AI Agent 的工具注册表与策略闸门（docs/07 §3 / §4 / §9）。
///
/// 不调模型、不联网、不碰 MCP：只定义「工具长什么样、调用前怎么分级、
/// 什么情况下必须确认 / 必须拒绝、确认卡片显示什么、主循环最多几轮」。
/// 二期接 MCP 时只需实现 `McpToolAdapter implements AgentTool`，
/// 主循环与策略层零改动。
library;

import '../vault/credential_models.dart';

/// 风险分级（docs/07 §4.1）。
enum RiskLevel { auto, confirm, dangerous }

/// 隐私分级（docs/07 §4.2）。
enum PrivacyLevel { l0, l1, l2 }

/// 工具执行结果。
class ToolResult {
  const ToolResult(this.content, {this.isError = false});

  final String content;
  final bool isError;
}

/// 工具抽象（为 MCP 预留）。
abstract interface class AgentTool {
  String get name;
  String get description;
  Map<String, Object?> get schema;
  RiskLevel get risk;
  PrivacyLevel get maxPrivacy;

  Future<ToolResult> execute(Map<String, Object?> args);
}

/// 一次工具调用的上下文。
class ToolCallContext {
  const ToolCallContext({
    required this.args,
    required this.cloudModel,
    required this.privacy,
    required this.knownSecrets,
    this.userConfirmed = false,
    this.privacyAuthorized = false,
    this.mcpRemote = false,
    this.entryKind,
    this.dataLeavesDevice = false,
    this.outgoingChars = 0,
  });

  final Map<String, Object?> args;

  /// 是否走云端模型（L0 任务走云端一律拒绝）。
  final bool cloudModel;

  /// 本次调用涉及的数据级别。
  final PrivacyLevel privacy;
  final bool userConfirmed;
  final bool privacyAuthorized;
  final bool mcpRemote;
  final int? entryKind;
  final bool dataLeavesDevice;
  final int outgoingChars;

  /// 已知明文（密码 / TOTP / secret 字段），用于 prompt 扫描。
  final Iterable<String> knownSecrets;
}

/// 闸门判定。
enum PolicyAction { allow, requireConfirm, deny }

class PolicyDecision {
  const PolicyDecision(this.action, this.reasons, this.preview);

  final PolicyAction action;
  final List<String> reasons;
  final String preview;

  bool get allowed => action == PolicyAction.allow;
}

/// 确认卡片内容（docs/07 §4.1）：人话操作 + 完整内容预览 + 是否离开设备。
String buildConfirmationPreview({
  required String toolName,
  required String humanAction,
  required String contentPreview,
  required bool dataLeavesDevice,
  required String modelName,
}) {
  final flow = dataLeavesDevice
      ? '数据将离开设备，发送给 $modelName'
      : '数据仅在本设备内处理';
  return '$humanAction\n内容预览：$contentPreview\n$flow';
}

/// 策略闸门：**所有工具执行前统一过一遍**，不靠每个工具自觉。
///
/// docs/07 §4.3 的绝对边界在这里写成代码：
/// 1. 密码明文进 prompt → 拒绝
/// 2. 密码字段进向量化 → 拒绝（entryKind=6 且 cloudModel）
/// 3. 密码条目被 get_entry 返回明文 → 工具侧必须脱敏，这里再挡一次
/// 4. 密码同步到第三方 MCP → 拒绝
/// 5. 密码相关 AI 分析走云端 → 拒绝
PolicyDecision checkToolCall(AgentTool tool, ToolCallContext ctx) {
  final reasons = <String>[];
  final argsText = ctx.args.toString();

  if (CredentialGuard.containsSecret(argsText, ctx.knownSecrets)) {
    return const PolicyDecision(
      PolicyAction.deny,
      <String>['密码 / TOTP / secret 字段明文不得进入任何 prompt 上下文'],
      '',
    );
  }
  final credential = ctx.entryKind == 6;
  if (credential && ctx.cloudModel) {
    return const PolicyDecision(
      PolicyAction.deny,
      <String>['密码相关分析必须走端侧 L0，禁止云端模型'],
      '',
    );
  }
  if (credential && ctx.mcpRemote) {
    return const PolicyDecision(
      PolicyAction.deny,
      <String>['密码条目不得同步到第三方 MCP server'],
      '',
    );
  }
  if (tool.maxPrivacy == PrivacyLevel.l0 && ctx.cloudModel) {
    return const PolicyDecision(
      PolicyAction.deny,
      <String>['该工具只允许 L0 端侧数据，不接受云端模型'],
      '',
    );
  }
  if (ctx.privacy == PrivacyLevel.l2 && !ctx.privacyAuthorized) {
    return const PolicyDecision(
      PolicyAction.deny,
      <String>['L2 全量内容必须逐次授权，不可记忆'],
      '',
    );
  }
  if (ctx.privacy == PrivacyLevel.l2 && !ctx.userConfirmed) {
    reasons.add('L2 全量内容需要确认卡片');
  }
  if (ctx.privacy == PrivacyLevel.l1 &&
      ctx.dataLeavesDevice &&
      !ctx.privacyAuthorized) {
    reasons.add('L1 脱敏片段离开设备前必须逐次授权');
  }
  if (tool.risk == RiskLevel.confirm && !ctx.userConfirmed) {
    reasons.add('写入类操作需要确认卡片');
  }
  if (tool.risk == RiskLevel.dangerous &&
      (!ctx.userConfirmed || !ctx.privacyAuthorized)) {
    reasons.add('dangerous 操作需要二次确认并显示数据流向');
  }

  final preview = buildConfirmationPreview(
    toolName: tool.name,
    humanAction: tool.description,
    contentPreview: argsText.length > 500
        ? '${argsText.substring(0, 500)}…'
        : argsText,
    dataLeavesDevice: ctx.dataLeavesDevice,
    modelName: ctx.cloudModel ? '云端模型' : '端侧模型',
  );
  if (reasons.isNotEmpty) {
    return PolicyDecision(
      PolicyAction.requireConfirm,
      List<String>.unmodifiable(reasons),
      preview,
    );
  }
  return PolicyDecision(
    PolicyAction.allow,
    const <String>[],
    preview,
  );
}

/// 主循环约束（docs/07 §2 / §9.2）：最多 6 轮、工具结果截断 2000 token。
class AgentLoopLimits {
  const AgentLoopLimits({this.maxTurns = 6, this.maxResultChars = 2000});

  final int maxTurns;
  final int maxResultChars;

  bool canContinue(int turn) => turn < maxTurns;

  String truncate(String result) => result.length <= maxResultChars
      ? result
      : '${result.substring(0, maxResultChars)}…（已截断）';
}

/// 工具注册表：同名工具不能重复注册（拼错一个字符串就同步不上，
/// 与 SyncEntity 同样的收敛理由）。
class AgentToolRegistry {
  AgentToolRegistry();

  final Map<String, AgentTool> _tools = <String, AgentTool>{};

  void register(AgentTool tool) {
    if (_tools.containsKey(tool.name)) {
      throw StateError('Agent 工具重复注册：${tool.name}');
    }
    _tools[tool.name] = tool;
  }

  AgentTool? lookup(String name) => _tools[name];

  List<Map<String, Object?>> schemas() => <Map<String, Object?>>[
        for (final tool in _tools.values)
          <String, Object?>{
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.schema,
          },
      ];

  int get length => _tools.length;
}

/// 双模型路由（docs/07 §2.2）：密码 / 日记 / 日总结 / TOTP 强制端侧。
enum ModelRoute { onDevice, cloud }

/// docs/07 §2.2 的三类任务。
const Set<String> kForcedOnDeviceTasks = <String>{
  'credential',
  'diary',
  'daily_summary',
  'totp',
  'ai_diary',
  'chat',
};

const Set<String> kUserChoiceTasks = <String>{
  'search',
  'summarize_note',
};

const Set<String> kCloudOnlyTasks = <String>{
  'long_doc_analysis',
  'complex_reasoning',
};

/// 路由决策附加信息：为什么走这条路、需要什么授权。
class ModelRouteDecision {
  const ModelRouteDecision({
    required this.route,
    required this.reason,
    required this.needsAuthorization,
  });

  final ModelRoute route;
  final String reason;
  final bool needsAuthorization;
}

ModelRoute routeModelForTask(String task) =>
    decideModelRoute(task).route;

/// 双模型路由完整判定（docs/07 §2.2）。
///
/// - 密码/日记/日总结/TOTP/AI 日记/chat：**强制端侧 L0**，任何授权都不能改
/// - 检索/笔记摘要：用户可选；未选择或端侧模型未就绪 → 端侧
/// - 长文分析/复杂推理：云端需 L2 逐次授权；未授权一律降级端侧，
///   绝不因为「任务想要云端」就偷偷发数据
ModelRouteDecision decideModelRoute(
  String task, {
  bool userChoseCloud = false,
  bool onDeviceModelReady = true,
  bool privacyAuthorized = false,
}) {
  if (kForcedOnDeviceTasks.contains(task)) {
    return const ModelRouteDecision(
      route: ModelRoute.onDevice,
      reason: 'L0 数据强制端侧，不随配置改变',
      needsAuthorization: false,
    );
  }
  if (kCloudOnlyTasks.contains(task)) {
    if (!privacyAuthorized) {
      return const ModelRouteDecision(
        route: ModelRoute.onDevice,
        reason: '云端任务未获 L2 逐次授权，降级端侧',
        needsAuthorization: true,
      );
    }
    return const ModelRouteDecision(
      route: ModelRoute.cloud,
      reason: '已获 L2 逐次授权，允许本次云端调用',
      needsAuthorization: true,
    );
  }
  if (kUserChoiceTasks.contains(task) &&
      userChoseCloud &&
      privacyAuthorized) {
    return const ModelRouteDecision(
      route: ModelRoute.cloud,
      reason: '用户选择云端且已逐次授权',
      needsAuthorization: true,
    );
  }
  if (!onDeviceModelReady) {
    return const ModelRouteDecision(
      route: ModelRoute.onDevice,
      reason: '端侧模型未就绪，检索降级为纯 FTS（不出设备）',
      needsAuthorization: false,
    );
  }
  return const ModelRouteDecision(
    route: ModelRoute.onDevice,
    reason: '默认端侧；未选择云端或未授权',
    needsAuthorization: false,
  );
}
