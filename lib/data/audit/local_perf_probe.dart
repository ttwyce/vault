/// 本地性能探针（docs/09 §11）。
///
/// **不冒充真机发布基线**：只测本机可确定的 Dart 工作量（FTS 查询、
/// 1000 条列表构建），输出诊断信息；真机冷启动、5000 条重建、滚动 fps、
/// 包体积、峰值内存仍必须由外部测量后喂给 `evaluatePerformance`。
library;

import '../entry/entry_repository.dart';

class LocalPerfProbeResult {
  const LocalPerfProbeResult({
    required this.searchRuns,
    required this.searchTotalMs,
    required this.listRows,
    required this.listBuildMs,
  });

  final int searchRuns;
  final int searchTotalMs;
  final int listRows;
  final int listBuildMs;

  double get searchAvgMs =>
      searchRuns == 0 ? 0 : searchTotalMs / searchRuns;

  String get hint => '本机探针：FTS $searchRuns 次平均 '
      '${searchAvgMs.toStringAsFixed(2)}ms · '
      '构建 $listRows 行 ${listBuildMs}ms（不替代真机 5000 条基线）';
}

class LocalPerfProbe {
  const LocalPerfProbe({required this.repo, this.searchRuns = 30});

  final EntryRepository repo;
  final int searchRuns;

  Future<LocalPerfProbeResult> run({String query = '笔记'}) async {
    final searchWatch = Stopwatch()..start();
    for (var i = 0; i < searchRuns; i++) {
      await repo.search(query, limit: 50);
    }
    searchWatch.stop();

    final listWatch = Stopwatch()..start();
    final rows = await repo.list(limit: 1000);
    // 模拟列表构建：每条摘要转成展示字符串，不让编译器整段优化掉。
    final built = <String>[
      for (final row in rows) '${row.title}|${row.snippet}',
    ];
    listWatch.stop();
    return LocalPerfProbeResult(
      searchRuns: searchRuns,
      searchTotalMs: searchWatch.elapsedMilliseconds,
      listRows: built.length,
      listBuildMs: listWatch.elapsedMilliseconds,
    );
  }
}
