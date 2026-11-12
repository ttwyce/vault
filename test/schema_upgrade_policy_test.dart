import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/schema_upgrade_policy.dart';

/// docs/03 §9 schema 双向判定测试。
void main() {
  test('云端更高一律拒绝，不写回', () {
    final plan = planSchemaUpgrade(
      localSchema: 3,
      remoteSchema: 4,
      deviceVersions: const <String, int>{},
      deviceIds: const <String>[],
    );
    expect(plan.action, SchemaSyncAction.rejectTooNew);
    expect(plan.writeBackSchema, isNull);
    expect(plan.reason, contains('升级 App'));
  });

  test('一致正常同步；云端更低但设备未升级，允许但不写回', () {
    expect(
      planSchemaUpgrade(
        localSchema: 3,
        remoteSchema: 3,
        deviceVersions: const <String, int>{},
        deviceIds: const <String>[],
      ).action,
      SchemaSyncAction.allow,
    );
    final outdated = planSchemaUpgrade(
      localSchema: 3,
      remoteSchema: 2,
      deviceVersions: const <String, int>{'devA': 3, 'devB': 2},
      deviceIds: const <String>['devA', 'devB'],
    );
    expect(outdated.action, SchemaSyncAction.allow);
    expect(outdated.writeBackSchema, isNull);
    expect(outdated.reason, contains('devB'));
  });

  test('全部设备已升级才写回新 schema；缺版本信息视为未升级', () {
    final ready = planSchemaUpgrade(
      localSchema: 3,
      remoteSchema: 1,
      deviceVersions: const <String, int>{'devA': 3, 'devB': 4},
      deviceIds: const <String>['devA', 'devB'],
    );
    expect(ready.action, SchemaSyncAction.allowThenUpgrade);
    expect(ready.writeBackSchema, 3);

    final unknown = planSchemaUpgrade(
      localSchema: 3,
      remoteSchema: 1,
      deviceVersions: const <String, int>{},
      deviceIds: const <String>['devA'],
    );
    expect(unknown.action, SchemaSyncAction.allow);
    expect(unknown.writeBackSchema, isNull);
  });
}
