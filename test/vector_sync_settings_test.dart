import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/vector_sync_settings.dart';

/// docs/06 §7 向量同步开关测试。
void main() {
  test('默认关闭，JSON 往返，坏值回默认', () {
    expect(const VectorSyncSetting().enabled, isFalse);
    expect(VectorSyncSetting.fromJson(<String, Object?>{'enabled': true}).enabled,
        isTrue);
    expect(VectorSyncSetting.fromJson('坏值').enabled, isFalse);
    expect(VectorSyncSetting(mode: VectorSyncMode.enabled).toJson()['enabled'],
        isTrue);
  });

  test('关闭：需二次确认，不删云端也不清本地，明确换设备重算', () {
    final plan = planVectorSyncToggle(
      const VectorSyncSetting(mode: VectorSyncMode.enabled),
    );
    expect(plan.next.enabled, isFalse);
    expect(plan.needsSecondConfirm, isTrue);
    expect(plan.hint, contains('全量重算'));
    expect(plan.hint, contains('不会被删除'));
    expect(plan.actions.join(), contains('保留本地 entry_vec'));
  });

  test('开启：不需二次确认，强调 model_id/dim 校验与加密', () {
    final plan = planVectorSyncToggle(const VectorSyncSetting());
    expect(plan.next.enabled, isTrue);
    expect(plan.needsSecondConfirm, isFalse);
    expect(plan.hint, contains('加密'));
    expect(plan.actions.join(), contains('model_id / dim'));
  });
}
