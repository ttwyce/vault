import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/audit/local_perf_probe.dart';
import 'package:vault/data/entry/entry_repository.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

void main() {
  test('本机性能探针返回真实查询/列表耗时，不冒充发布基线', () async {
    final app = await TestApp.create();
    addTearDown(app.dispose);
    for (var i = 0; i < 5; i++) {
      await app.gateway.writeEntry(EntryWrite.create(
        id: 'perf-$i',
        title: '笔记 $i',
        body: '正文内容',
      ));
    }
    final result = await LocalPerfProbe(
      repo: EntryRepository(app.db),
      searchRuns: 3,
    ).run();
    expect(result.searchRuns, 3);
    expect(result.listRows, 5);
    expect(result.hint, contains('不替代真机 5000 条基线'));
    expect(result.searchTotalMs, greaterThanOrEqualTo(0));
    expect(result.listBuildMs, greaterThanOrEqualTo(0));
  });
}
