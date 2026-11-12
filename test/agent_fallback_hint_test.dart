import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/agent_fallback_hint.dart';
import 'package:vault/data/agent/agent_loop.dart' show LoopStop;

/// docs/07 §11 C6 Agent 超时/失败降级提示测试。
void main() {
  test('超时 / 网络 / 模型异常都明确检索仍可用且可重试', () {
    for (final kind in <AgentFailureKind>[
      AgentFailureKind.timeout,
      AgentFailureKind.network,
      AgentFailureKind.modelError,
    ]) {
      final hint = planAgentFallback(
        stoppedBy: LoopStop.planExhausted,
        failure: kind,
      );
      expect(hint.retryable, isTrue, reason: kind.name);
      expect(hint.searchStillUsable, isTrue);
      expect(hint.detail, contains('检索'));
    }
  });

  test('预算耗尽不可重试；不谎称 AI 回答成功', () {
    final hint = planAgentFallback(
      stoppedBy: LoopStop.planExhausted,
      failure: AgentFailureKind.quota,
    );
    expect(hint.retryable, isFalse);
    expect(hint.title, contains('预算'));
    expect(hint.detail, contains('关键词检索'));
  });

  test('6 轮上限 / 拒绝 / 待确认三态各有文案', () {
    final maxTurns = planAgentFallback(
      stoppedBy: LoopStop.maxTurns,
      hasFtsResults: true,
    );
    expect(maxTurns.title, contains('6 轮'));
    expect(maxTurns.detail, contains('检索结果'));
    expect(
      planAgentFallback(stoppedBy: LoopStop.denied).retryable,
      isFalse,
    );
    expect(
      planAgentFallback(stoppedBy: LoopStop.needsConfirm).title,
      contains('确认'),
    );
    expect(
      planAgentFallback(stoppedBy: LoopStop.planExhausted).detail,
      contains('无失败'),
    );
  });
}
