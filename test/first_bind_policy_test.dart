import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/first_bind_policy.dart';

/// docs/04 §8.1 首次绑定三选一策略测试。
void main() {
  test('云端为空 / 本地为空都不弹三选一', () {
    expect(
      needsFirstBindChoice(cloudHasVault: false, localHasData: true),
      isFalse,
    );
    expect(
      needsFirstBindChoice(cloudHasVault: true, localHasData: false),
      isFalse,
    );
    expect(
      planFirstBind(cloudHasVault: false, localHasData: false),
      isEmpty,
    );
    expect(
      needsFirstBindChoice(cloudHasVault: true, localHasData: true),
      isTrue,
    );
  });

  test('三选一顺序、推荐项、备份目标、二次确认', () {
    final plans = planFirstBind(
      cloudHasVault: true,
      localHasData: true,
    );
    expect(plans, hasLength(3));
    expect(
      plans.map((FirstBindPlan p) => p.option).toList(),
      <FirstBindOption>[
        FirstBindOption.merge,
        FirstBindOption.preferCloud,
        FirstBindOption.preferLocal,
      ],
    );
    expect(plans[0].recommended, isTrue);
    expect(plans[0].backupTarget, 'none');
    expect(plans[1].backupTarget, 'trash');
    expect(plans[2].backupTarget, 'quarantine');
    expect(plans[2].needsSecondConfirm, isTrue);
    expect(plans.every((FirstBindPlan p) => p.allowed), isTrue);
    expect(plans[2].toJson()['reason'], contains('二次确认'));
  });

  test('执行清单都要求重建索引，且步骤非空', () {
    for (final option in FirstBindOption.values) {
      final execution = executionFor(option);
      expect(execution.steps, isNotEmpty);
      expect(execution.rebuildIndexes, isTrue);
      expect(execution.isEmpty, isFalse);
    }
    expect(
      executionFor(FirstBindOption.merge).steps.join(),
      contains('冲突副本'),
    );
    expect(
      executionFor(FirstBindOption.preferCloud).steps.join(),
      contains('trash'),
    );
    expect(
      executionFor(FirstBindOption.preferLocal).steps.join(),
      contains('quarantine'),
    );
  });
}
