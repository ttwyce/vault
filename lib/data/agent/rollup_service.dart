/// 滚动摘要（docs/07 §5.3）：日 → 周(7) → 月(4) → 年(12)。
///
/// 不重读全部历史：只从本地 `kind=4` 条目里筛出指定层级与日期范围的
/// 摘要，合成上一层摘要并落库。引用逐层去重校验，绝不编造未发生的条目。
library;

import 'dart:convert';

import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../write/write_gateway.dart';
import 'daily_summary.dart';

class RollupService {
  const RollupService({required this.db, required this.gateway});

  final VaultDatabase db;
  final WriteGateway gateway;

  /// 读某一层级、[from]~[to] 之间的日/周/月摘要。
  Future<List<DailySummary>> readLayer(
    SummaryGranularity granularity,
    String from,
    String to,
  ) async {
    final rows = await db.select(db.entries).get();
    final out = <Map<String, Object?>>[];
    for (final row in rows) {
      if (row.kind != EntryKind.aiDiary.code || row.deleted != 0) continue;
      final raw = row.meta;
      if (raw == null || raw.isEmpty) continue;
      try {
        final map = Map<String, Object?>.from(
          jsonDecode(raw) as Map,
        );
        if (map['granularity'] != granularity.name) continue;
        final date = map['date']?.toString() ?? '';
        if (date.compareTo(from) < 0 || date.compareTo(to) > 0) continue;
        out.add(map);
      } on Object {
        // 坏 meta 跳过，不让整页滚动摘要崩。
      }
    }
    out.sort((Map<String, Object?> a, Map<String, Object?> b) =>
        (a['date']?.toString() ?? '').compareTo(b['date']?.toString() ?? ''));
    return <DailySummary>[
      for (final map in out)
        DailySummary(
          headline: map['headline']?.toString() ?? '',
          timeline: const <TimelineItem>[],
          openThreads: const <String>[],
          citations: _strings(map['citations']),
          date: map['date']?.toString() ?? '',
          granularity: granularity,
        ),
    ];
  }

  /// 生成上一层摘要。输入不足 [childCountFor] 也照常聚合，但明确写出
  /// 「仅 N 条」而不是假装有完整周期。
  Future<DailySummary?> rollup({
    required SummaryGranularity target,
    required String periodKey,
    required String from,
    required String to,
  }) async {
    final child = switch (target) {
      SummaryGranularity.week => SummaryGranularity.day,
      SummaryGranularity.month => SummaryGranularity.week,
      SummaryGranularity.year => SummaryGranularity.month,
      SummaryGranularity.day => null,
    };
    if (child == null) {
      throw ArgumentError('日摘要不能作为滚动目标');
    }
    final children = await readLayer(child, from, to);
    if (children.isEmpty) return null;

    final existing = <String>{
      for (final row in await db.select(db.entries).get())
        if (row.deleted == 0) row.id,
    };
    final citations = validateCitations(
      <String>[
        for (final item in children) ...item.citations,
      ],
      existing,
    );
    final expected = childCountFor(target);
    final summary = DailySummary(
      headline: '${_label(target)}汇总：${children.length}/$expected 条'
          '${child.name}摘要 · ${children.first.headline}',
      timeline: <TimelineItem>[
        for (final item in children)
          TimelineItem(
            atMs: 0,
            what: '${item.date}：${item.headline}',
          ),
      ],
      openThreads: const <String>[],
      citations: citations,
      date: periodKey,
      granularity: target,
    );
    await gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.aiDiary,
      title: '${_label(target)}摘要 $periodKey',
      meta: jsonEncode(summary.toJson()),
      body: summary.headline,
    ));
    return summary;
  }

  static List<String> _strings(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw.map((Object? v) => v.toString()).toList();
  }

  static String _label(SummaryGranularity g) => switch (g) {
        SummaryGranularity.week => '周',
        SummaryGranularity.month => '月',
        SummaryGranularity.year => '年',
        SummaryGranularity.day => '日',
      };
}
