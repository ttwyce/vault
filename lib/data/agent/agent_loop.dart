/// Agent 主循环（docs/07 §3 / §9）。
///
/// 不调模型：由上层按 `plan` 给出每轮想调用的工具与参数，这里负责
/// **6 轮上限、工具结果 2000 字截断、统一闸门、遇到确认/拒绝即停**。
/// 二期接 MCP 时主循环零改动 —— [McpToolAdapter] 就是为它预留的。
library;

import 'agent_policy.dart';
import 'agent_tools.dart';

/// 一轮计划。
class AgentTurn {
  const AgentTurn({required this.toolName, required this.context});

  final String toolName;
  final ToolCallContext context;
}

class AgentLoopResult {
  const AgentLoopResult(this.steps, this.stoppedBy);

  final List<AgentLoopStep> steps;
  final LoopStop stoppedBy;

  int get turns => steps.length;
}

enum LoopStop { planExhausted, maxTurns, denied, needsConfirm }

class AgentLoopStep {
  const AgentLoopStep({
    required this.toolName,
    required this.action,
    required this.output,
  });

  final String toolName;
  final PolicyAction action;
  final String output;
}

/// 执行主循环。计划超过 6 轮也只跑前 6 轮。
Future<AgentLoopResult> runAgentLoop(
  AgentToolRegistry registry,
  Iterable<AgentTurn> plan, {
  AgentLoopLimits limits = const AgentLoopLimits(),
}) async {
  final steps = <AgentLoopStep>[];
  var stoppedBy = LoopStop.planExhausted;
  var turn = 0;
  for (final item in plan) {
    if (!limits.canContinue(turn)) {
      stoppedBy = LoopStop.maxTurns;
      break;
    }
    final tool = registry.lookup(item.toolName);
    final decision = tool == null
        ? null
        : checkToolCall(tool, item.context);
    if (decision == null) {
      steps.add(AgentLoopStep(
        toolName: item.toolName,
        action: PolicyAction.deny,
        output: '未注册的工具：${item.toolName}',
      ));
      stoppedBy = LoopStop.denied;
      break;
    }
    if (decision.action == PolicyAction.deny) {
      steps.add(AgentLoopStep(
        toolName: item.toolName,
        action: PolicyAction.deny,
        output: limits.truncate(decision.reasons.join('；')),
      ));
      stoppedBy = LoopStop.denied;
      break;
    }
    if (decision.action == PolicyAction.requireConfirm) {
      steps.add(AgentLoopStep(
        toolName: item.toolName,
        action: PolicyAction.requireConfirm,
        output: limits.truncate(decision.preview),
      ));
      stoppedBy = LoopStop.needsConfirm;
      break;
    }
    final result = await invokeTool(registry, item.toolName, item.context);
    steps.add(AgentLoopStep(
      toolName: item.toolName,
      action: PolicyAction.allow,
      output: limits.truncate(result.content),
    ));
    turn++;
  }
  return AgentLoopResult(List<AgentLoopStep>.unmodifiable(steps), stoppedBy);
}

/// MCP 适配器骨架（docs/07 §3.3）。
///
/// 只把远程 server 的 tool 描述映射成本地 [AgentTool]，**不发网络请求**：
/// `execute` 一律返回「未连接」，由二期平台层注入真实 transport。
/// 远程工具固定 L2 隐私、dangerous 风险，密码条目由闸门直接拒绝。
class McpToolAdapter implements AgentTool {
  const McpToolAdapter({
    required this.remoteName,
    required this.description,
    required this.schema,
  });

  final String remoteName;
  @override
  final String description;
  @override
  final Map<String, Object?> schema;

  @override
  String get name => 'mcp/$remoteName';

  @override
  RiskLevel get risk => RiskLevel.dangerous;

  @override
  PrivacyLevel get maxPrivacy => PrivacyLevel.l2;

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async =>
      const ToolResult('远程 MCP transport 尚未连接', isError: true);
}
