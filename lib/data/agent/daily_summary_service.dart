/// 日总结流水线（docs/07 §5 / §6）。
///
/// **不调模型**：这里只把 ActivityLogger 的真实日聚合转换成可溯源的时间线，
/// 用 `validateCitations` 剔除不存在的引用，再以 kind=4（AI 日记）落库。
/// headline 是事实描述而不是生成文本 —— 可信、可验证，一周后也不会退化成
/// 「正确的废话」。端侧模型负责的反思文本留给 M7 后续。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../activity/activity_logger.dart';
import '../db/tables/entry_tables.dart';
import '../db/vault_database.dart';
import '../write/write_gateway.dart';
import '../agent/daily_summary.dart';

class DailySummaryService {
  DailySummaryService({
    required this.logger,
    required this.gateway,
    required this.db,
  });

  final ActivityLogger logger;
  final WriteGateway gateway;
  final VaultDatabase db;

  /// 生成并落库某一天的日总结。返回 null 表示这一天没有活动，不写空条目。
  Future<DailySummary?> buildAndStore(DateTime day) async {
    final activity = await logger.summarizeDay(day);
    if (activity.isEmpty) return null;

    // 只保留当天真实存在、未删除的条目作为引用。
    final existing = <String>{};
    for (final id in activity.touchedEntryIds) {
      final row = await (db.select(db.entries)
            ..where((t) => t.id.equals(id) & t.deleted.equals(0)))
          .getSingleOrNull();
      if (row != null) existing.add(id);
    }
    final citations = validateCitations(
      activity.touchedEntryIds,
      existing,
    );

    final timeline = <TimelineItem>[
      if (activity.firstAt != null)
        TimelineItem(
          atMs: activity.firstAt!.millisecondsSinceEpoch,
          what: '开始记录：${activity.headline}',
        ),
      for (final query in _unique(activity.searchQueries).take(5))
        TimelineItem(
          atMs: activity.lastAt?.millisecondsSinceEpoch ??
              day.millisecondsSinceEpoch,
          what: '搜索了「$query」',
        ),
      if (activity.lastAt != null)
        TimelineItem(
          atMs: activity.lastAt!.millisecondsSinceEpoch,
          what: '当天共 ${activity.totalEvents} 次活动',
        ),
    ];

    final summary = DailySummary(
      headline: activity.headline,
      timeline: normalizeTimeline(timeline),
      openThreads: const <String>[],
      citations: citations,
      date: _date(activity.day),
    );

    await gateway.writeEntry(EntryWrite.create(
      kind: EntryKind.aiDiary,
      title: '${_date(activity.day)} · 日总结',
      meta: jsonEncode(summary.toJson()),
      body: _body(summary),
    ));
    return summary;
  }

  static Iterable<String> _unique(Iterable<String> values) {
    final seen = <String>{};
    return values.where((String v) => v.isNotEmpty && seen.add(v));
  }

  static String _date(DateTime day) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }

  static String _body(DailySummary summary) {
    final buffer = StringBuffer(summary.headline);
    for (final item in summary.timeline) {
      buffer.writeln();
      buffer.write('- ${item.what}');
    }
    if (summary.citations.isNotEmpty) {
      buffer.writeln();
      buffer.write('引用 ${summary.citations.length} 条原文。');
    }
    return buffer.toString();
  }
}
