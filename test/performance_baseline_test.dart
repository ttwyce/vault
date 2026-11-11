import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/audit/performance_baseline.dart';

/// docs/README 关键预算 / docs/09 §11 性能基线判定层测试。
void main() {
  test('9 项预算齐备，空样本全部标未测且发布门禁不通过', () {
    expect(PerfBudget.defaults, hasLength(9));
    final report = evaluatePerformance(const <PerfMetric, num>{});
    expect(report.checks, hasLength(9));
    expect(
      report.checks
          .every((PerfCheck c) => c.verdict == PerfVerdict.unmeasured),
      isTrue,
    );
    expect(report.allPassed, isFalse);
    expect(report.releaseReady, isFalse,
        reason: '未测不等于达标');
    expect(report.failures(), hasLength(9));
  });

  test('全部达标时门禁通过；任一项未测仍不通过', () {
    final good = <PerfMetric, num>{
      PerfMetric.coldStartMs: 900,
      PerfMetric.syncIdleRequests: 3,
      PerfMetric.syncChangedRequests: 120,
      PerfMetric.reembed5000Ms: 300000,
      PerfMetric.packageBytes: 50 * 1024 * 1024,
      PerfMetric.peakMemoryBytes: 300 * 1024 * 1024,
      PerfMetric.searchP95Ms: 100,
      PerfMetric.hybridSearchP95Ms: 250,
      PerfMetric.scrollFps: 60,
    };
    expect(evaluatePerformance(good).releaseReady, isTrue);

    final partial = Map<PerfMetric, num>.from(good)
      ..remove(PerfMetric.scrollFps);
    final partialReport = evaluatePerformance(partial);
    expect(partialReport.allPassed, isFalse);
    expect(partialReport.failures().single.verdict,
        PerfVerdict.unmeasured);
  });

  test('超标给出可执行建议，边界值算达标', () {
    final report = evaluatePerformance(<PerfMetric, num>{
      PerfMetric.coldStartMs: 1200,
      PerfMetric.syncIdleRequests: 4,
      PerfMetric.searchP95Ms: 200,
      PerfMetric.hybridSearchP95Ms: 350,
      PerfMetric.reembed5000Ms: 600000,
      PerfMetric.packageBytes: 70 * 1024 * 1024,
      PerfMetric.peakMemoryBytes: 500 * 1024 * 1024,
      PerfMetric.syncChangedRequests: 250,
      PerfMetric.scrollFps: 58,
    });
    expect(report.allPassed, isFalse);
    final fails = report.failures();
    expect(fails, hasLength(8), reason: '冷启动恰好 1200 是边界达标');
    expect(fails.map((PerfCheck c) => c.metric),
        isNot(contains(PerfMetric.coldStartMs)));
    expect(fails.map((PerfCheck c) => c.metric),
        contains(PerfMetric.syncIdleRequests));
    expect(fails.map((PerfCheck c) => c.metric),
        contains(PerfMetric.scrollFps), reason: 'fps 越高越好，58 未达标');
    expect(
      fails
          .firstWhere((PerfCheck c) =>
              c.metric == PerfMetric.reembed5000Ms)
          .detail,
      contains('分块数'),
    );
  });

  test('fps 方向：60 达标、59 不达标', () {
    expect(
      evaluatePerformance(<PerfMetric, num>{
        PerfMetric.scrollFps: 60,
      }).checks.last.verdict,
      PerfVerdict.pass,
    );
    expect(
      evaluatePerformance(<PerfMetric, num>{
        PerfMetric.scrollFps: 59,
      }).checks.last.verdict,
      PerfVerdict.fail,
    );
  });
}
