import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/agent_policy.dart';

/// docs/07 §3 / §4 / §9.2 Agent 策略闸门测试。
class _Tool implements AgentTool {
  const _Tool({
    required this.name,
    required this.risk,
    required this.maxPrivacy,
  });

  @override
  final String name;

  @override
  final RiskLevel risk;

  @override
  final PrivacyLevel maxPrivacy;

  @override
  String get description => '用于测试的工具：$name';

  @override
  Map<String, Object?> get schema => <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{},
      };

  @override
  Future<ToolResult> execute(Map<String, Object?> args) async =>
      const ToolResult('ok');
}

ToolCallContext _ctx({
  Map<String, Object?> args = const <String, Object?>{},
  bool cloudModel = false,
  PrivacyLevel privacy = PrivacyLevel.l0,
  bool userConfirmed = false,
  bool privacyAuthorized = false,
  bool mcpRemote = false,
  int? entryKind,
  bool dataLeavesDevice = false,
  Iterable<String> knownSecrets = const <String>[],
}) =>
    ToolCallContext(
      args: args,
      cloudModel: cloudModel,
      privacy: privacy,
      knownSecrets: knownSecrets,
      userConfirmed: userConfirmed,
      privacyAuthorized: privacyAuthorized,
      mcpRemote: mcpRemote,
      entryKind: entryKind,
      dataLeavesDevice: dataLeavesDevice,
    );

void main() {
  const auto = _Tool(
    name: 'get_stats',
    risk: RiskLevel.auto,
    maxPrivacy: PrivacyLevel.l1,
  );
  const confirm = _Tool(
    name: 'create_entry',
    risk: RiskLevel.confirm,
    maxPrivacy: PrivacyLevel.l1,
  );
  const dangerous = _Tool(
    name: 'web_search',
    risk: RiskLevel.dangerous,
    maxPrivacy: PrivacyLevel.l2,
  );

  test('auto 工具在已授权的常规上下文直接放行', () {
    expect(checkToolCall(auto, _ctx()).allowed, isTrue);
  });

  test('confirm 工具未确认时要求确认卡片，确认后放行', () {
    final pending = checkToolCall(confirm, _ctx());
    expect(pending.action, PolicyAction.requireConfirm);
    expect(pending.preview, contains('内容预览'));
    expect(pending.preview, contains('仅在本设备内处理'));
    expect(
      checkToolCall(confirm, _ctx(userConfirmed: true)).allowed,
      isTrue,
    );
  });

  test('dangerous 工具必须二次确认 + 显示数据流向', () {
    final denied = checkToolCall(
      dangerous,
      _ctx(privacy: PrivacyLevel.l2, dataLeavesDevice: true),
    );
    expect(denied.action, PolicyAction.deny,
        reason: 'L2 未授权直接拒绝，不落到确认卡片');
    final pending = checkToolCall(
      dangerous,
      _ctx(
        privacy: PrivacyLevel.l2,
        privacyAuthorized: true,
        dataLeavesDevice: true,
      ),
    );
    expect(pending.action, PolicyAction.requireConfirm);
    expect(pending.preview, contains('数据将离开设备'));
    expect(
      checkToolCall(
        dangerous,
        _ctx(
          privacy: PrivacyLevel.l2,
          privacyAuthorized: true,
          userConfirmed: true,
          dataLeavesDevice: true,
        ),
      ).allowed,
      isTrue,
    );
  });

  test('L2 必须逐次授权，不可记忆', () {
    final decision = checkToolCall(
      auto,
      _ctx(privacy: PrivacyLevel.l2, userConfirmed: true),
    );
    expect(decision.action, PolicyAction.deny);
    expect(decision.reasons.single, contains('逐次授权'));
  });

  group('docs/07 §4.3 密码绝对边界', () {
    test('密码明文夹带在参数里直接拒绝', () {
      final decision = checkToolCall(
        auto,
        _ctx(
          args: <String, Object?>{'query': '我的密码是 hunter2'},
          knownSecrets: <String>['hunter2'],
        ),
      );
      expect(decision.action, PolicyAction.deny);
    });

    test('密码条目走云端 / 第三方 MCP 一律拒绝', () {
      expect(
        checkToolCall(auto, _ctx(entryKind: 6, cloudModel: true)).action,
        PolicyAction.deny,
      );
      expect(
        checkToolCall(auto, _ctx(entryKind: 6, mcpRemote: true)).action,
        PolicyAction.deny,
      );
    });

    test('L0-only 工具不接受云端模型', () {
      const l0 = _Tool(
        name: 'credential_health',
        risk: RiskLevel.auto,
        maxPrivacy: PrivacyLevel.l0,
      );
      expect(
        checkToolCall(l0, _ctx(cloudModel: true)).action,
        PolicyAction.deny,
      );
      expect(checkToolCall(l0, _ctx()).allowed, isTrue);
    });

    test('双模型路由：密码/日记/日总结/TOTP 强制端侧', () {
      for (final task in <String>[
        'credential',
        'diary',
        'daily_summary',
        'totp',
        'ai_diary',
        'chat',
      ]) {
        expect(routeModelForTask(task), ModelRoute.onDevice);
      }
    });
  });

  group('注册表与主循环约束', () {
    test('同名工具拒绝重复注册，schema 列表可导出', () {
      final registry = AgentToolRegistry()
        ..register(auto)
        ..register(confirm);
      expect(registry.length, 2);
      expect(registry.lookup('get_stats'), isNotNull);
      expect(() => registry.register(auto), throwsA(isA<StateError>()));
      expect(registry.schemas().first['name'], 'get_stats');
    });

    test('最多 6 轮、工具结果截断 2000 字', () {
      const limits = AgentLoopLimits();
      expect(limits.canContinue(5), isTrue);
      expect(limits.canContinue(6), isFalse);
      final truncated = limits.truncate('x' * 3000);
      expect(truncated.length, lessThan(2100));
      expect(truncated, contains('已截断'));
    });
  });
}
