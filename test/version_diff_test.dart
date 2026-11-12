import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/sync/version_diff.dart';

/// docs/10 第 23 屏 版本对比展示测试。
void main() {
  test('相同文本只有上下文行，无增删', () {
    final view = buildVersionDiff('甲\n乙', '甲\n乙');
    expect(view.degraded, isFalse);
    expect(view.addedCount, 0);
    expect(view.removedCount, 0);
    expect(view.lines.every((DiffLine l) => l.kind == DiffLineKind.context),
        isTrue);
    expect(view.summary, '+0 / -0');
  });

  test('替换一行：先 - 旧行再 + 新行，行号连续', () {
    final view = buildVersionDiff('甲\n乙\n丙', '甲\n新\n丙');
    expect(view.degraded, isFalse);
    expect(view.removedCount, 1);
    expect(view.addedCount, 1);
    final removed = view.lines
        .where((DiffLine l) => l.kind == DiffLineKind.removed)
        .single;
    final added = view.lines
        .where((DiffLine l) => l.kind == DiffLineKind.added)
        .single;
    expect(removed.text, '乙');
    expect(removed.marker, '-');
    expect(removed.oldNumber, 2);
    expect(added.text, '新');
    expect(added.marker, '+');
    expect(added.newNumber, 2);
    expect(view.summary, '+1 / -1');
  });

  test('纯插入 / 纯删除', () {
    final insert = buildVersionDiff('甲\n丙', '甲\n乙\n丙');
    expect(insert.addedCount, 1);
    expect(insert.removedCount, 0);
    final remove = buildVersionDiff('甲\n乙\n丙', '甲\n丙');
    expect(remove.addedCount, 0);
    expect(remove.removedCount, 1);
  });

  test('超过行数上限降级为统计视图，不跑 O(n·m) DP', () {
    final big = List<String>.generate(30, (int i) => '行$i').join('\n');
    final view = buildVersionDiff(big, '$big\n新增', maxLines: 10);
    expect(view.degraded, isTrue);
    expect(view.lines, isEmpty);
    expect(view.summary, contains('降级'));
  });
}
