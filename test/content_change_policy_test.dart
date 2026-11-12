import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/content_change_policy.dart';

/// docs/05 §6.2 内容变更检测成本控制测试。
void main() {
  const now = 1731052800000;

  test('手动标记 / 30 天内访问才排重抓，其余不进队列', () {
    final batch = planChangeCheckBatch(
      <ChangeCheckCandidate>[
        const ChangeCheckCandidate(
          entryId: 'watched',
          watchChanges: true,
          lastVisitedAtMs: null,
        ),
        ChangeCheckCandidate(
          entryId: 'recent',
          watchChanges: false,
          lastVisitedAtMs: now - 10 * 86400000,
        ),
        ChangeCheckCandidate(
          entryId: 'old',
          watchChanges: false,
          lastVisitedAtMs: now - 60 * 86400000,
        ),
        const ChangeCheckCandidate(
          entryId: 'never',
          watchChanges: false,
          lastVisitedAtMs: null,
        ),
      ],
      nowMs: now,
    );
    expect(batch, <String>['watched', 'recent']);
  });

  test('首次快照不提示变更；相同 simhash 不提示', () {
    expect(
      planContentChange(
        previousSimhash: null,
        newSimhash: '00000000000000ff',
      ).action,
      ContentChangeAction.firstSnapshot,
    );
    final same = planContentChange(
      previousSimhash: '00000000000000ff',
      newSimhash: '00000000000000ff',
    );
    expect(same.action, ContentChangeAction.unchanged);
    expect(same.keepPreviousAsHistory, isFalse);
  });

  test('汉明距离 > 3 提示变更且保留旧版 history', () {
    final changed = planContentChange(
      previousSimhash: '0000000000000000',
      newSimhash: '00000000000000ff',
    );
    expect(changed.action, ContentChangeAction.promptChange);
    expect(changed.keepPreviousAsHistory, isTrue);
    expect(changed.hint, contains('旧版'));
  });

  test('threshold 可调；坏指纹不当变更', () {
    expect(
      planContentChange(
        previousSimhash: '坏值',
        newSimhash: '00000000000000ff',
      ).action,
      ContentChangeAction.unchanged,
    );
    expect(
      planContentChange(
        previousSimhash: '0000000000000000',
        newSimhash: '000000000000000f',
        threshold: 100,
      ).action,
      ContentChangeAction.unchanged,
    );
  });
}
