/// 发布前性能基线的**纯判定层**（docs/README 关键预算 / docs/09 §11）。
///
/// 不跑基准测试、不造 5000 条数据：只把「目标值 → 实测值」的判定、
/// 「未测」的显式区分、以及不达标时的可执行建议写成可复现逻辑。
/// 真实性能测量必须由三端联调在真机上完成，这里绝不冒充已测。
library;

/// 性能指标。
enum PerfMetric {
  coldStartMs,
  syncIdleRequests,
  syncChangedRequests,
  reembed5000Ms,
  packageBytes,
  peakMemoryBytes,
  searchP95Ms,
  hybridSearchP95Ms,
  scrollFps,
}

/// 预算项。
class PerfBudget {
  const PerfBudget({
    required this.metric,
    required this.label,
    required this.limit,
    required this.lowerIsBetter,
    this.unit = 'ms',
  });

  final PerfMetric metric;
  final String label;
  final num limit;
  final bool lowerIsBetter;
  final String unit;

  /// 默认预算（docs/README 关键预算 + docs/09 §9 / docs/06 §9）。
  static const List<PerfBudget> defaults = <PerfBudget>[
    PerfBudget(
      metric: PerfMetric.coldStartMs,
      label: '冷启动到可交互',
      limit: 1200,
      lowerIsBetter: true,
    ),
    PerfBudget(
      metric: PerfMetric.syncIdleRequests,
      label: '常规同步（无变化）',
      limit: 3,
      lowerIsBetter: true,
      unit: '次',
    ),
    PerfBudget(
      metric: PerfMetric.syncChangedRequests,
      label: '常规同步（有变化）',
      limit: 200,
      lowerIsBetter: true,
      unit: '次',
    ),
    PerfBudget(
      metric: PerfMetric.reembed5000Ms,
      label: '5000 条向量重建',
      limit: 480000,
      lowerIsBetter: true,
    ),
    PerfBudget(
      metric: PerfMetric.packageBytes,
      label: '安装包体积',
      limit: 60 * 1024 * 1024,
      lowerIsBetter: true,
      unit: 'B',
    ),
    PerfBudget(
      metric: PerfMetric.peakMemoryBytes,
      label: '峰值内存',
      limit: 400 * 1024 * 1024,
      lowerIsBetter: true,
      unit: 'B',
    ),
    PerfBudget(
      metric: PerfMetric.searchP95Ms,
      label: '中文搜索 P95',
      limit: 150,
      lowerIsBetter: true,
    ),
    PerfBudget(
      metric: PerfMetric.hybridSearchP95Ms,
      label: '混合检索 P95（5000 条）',
      limit: 300,
      lowerIsBetter: true,
    ),
    PerfBudget(
      metric: PerfMetric.scrollFps,
      label: '1000 条列表滚动',
      limit: 60,
      lowerIsBetter: false,
      unit: 'fps',
    ),
  ];
}

enum PerfVerdict { pass, fail, unmeasured }

class PerfCheck {
  const PerfCheck({
    required this.metric,
    required this.verdict,
    required this.detail,
  });

  final PerfMetric metric;
  final PerfVerdict verdict;
  final String detail;
}

class PerformanceReport {
  const PerformanceReport(this.checks);

  final List<PerfCheck> checks;

  bool get allPassed =>
      checks.isNotEmpty &&
      checks.every((PerfCheck c) => c.verdict == PerfVerdict.pass);

  /// 未测不等于达标：有 unmeasured 时发布门禁不通过。
  bool get releaseReady => allPassed;

  List<PerfCheck> failures() => <PerfCheck>[
        for (final check in checks)
          if (check.verdict != PerfVerdict.pass) check,
      ];
}

/// 判定。[samples] 里没有的指标一律标为「未测」。
PerformanceReport evaluatePerformance(
  Map<PerfMetric, num> samples, {
  List<PerfBudget> budgets = PerfBudget.defaults,
}) {
  final checks = <PerfCheck>[];
  for (final budget in budgets) {
    final value = samples[budget.metric];
    if (value == null) {
      checks.add(PerfCheck(
        metric: budget.metric,
        verdict: PerfVerdict.unmeasured,
        detail: '${budget.label}：未测（需真机 / 真实服务器基线）',
      ));
      continue;
    }
    final ok = budget.lowerIsBetter
        ? value <= budget.limit
        : value >= budget.limit;
    checks.add(PerfCheck(
      metric: budget.metric,
      verdict: ok ? PerfVerdict.pass : PerfVerdict.fail,
      detail: ok
          ? '${budget.label}：$value ${budget.unit} ≤/≥ ${budget.limit} ${budget.unit}'
          : '${budget.label}：$value ${budget.unit} 超出预算 '
              '${budget.limit} ${budget.unit} → ${_advice(budget.metric)}',
    ));
  }
  return PerformanceReport(List<PerfCheck>.unmodifiable(checks));
}

String _advice(PerfMetric metric) => switch (metric) {
      PerfMetric.coldStartMs => '检查解锁 KDF 参数与启动装配串行链',
      PerfMetric.syncIdleRequests => '检查 sync/token 与 capability 缓存',
      PerfMetric.syncChangedRequests => '检查批量 PUT / 预算与去重',
      PerfMetric.reembed5000Ms => '检查分块数、批次大小与端侧推理吞吐',
      PerfMetric.packageBytes => '检查内置模型与字体资源',
      PerfMetric.peakMemoryBytes => '检查大 blob 一次性加载与列表缓存',
      PerfMetric.searchP95Ms => '检查 CjkSegmenter 与 FTS 索引',
      PerfMetric.hybridSearchP95Ms => '检查 RRF 候选集与重排开销',
      PerfMetric.scrollFps => '检查 RepaintBoundary 与多余重建',
    };
