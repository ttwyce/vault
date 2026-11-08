// 私有字段 + 同义具名参数，与 WriteGateway 保持一致的写法。
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/tables/log_tables.dart';
import '../db/vault_database.dart';

/// 活动埋点。
///
/// ## 为什么这个模块必须在业务功能之前做
///
/// AI 日总结的数据源只有它。用户问「我上个月干了什么」，答案不能靠
/// 现算 —— 只能靠当时记下来的。埋点晚一天，那天就永远缺一段。
///
/// ## 核心设计：合并窗口，而不是流水账
///
/// 直接每次事件插一行会立刻爆炸：用户翻列表会连点 30 条笔记，
/// 编辑器自动保存 10 分钟能写上百次。这样的表既没用（信息密度极低）
/// 又贵（日总结要读几万行）。
///
/// 所以按 (kind, entryId) 做**时间窗口合并**：
///
/// | 事件 | 窗口 | 合并后的语义 |
/// |---|---|---|
/// | 浏览 / 归档阅读 | 30 分钟 | 一次"阅读会话"，dwellMs 累加 |
/// | 编辑 | 5 分钟 | 一次"编辑会话"，不区分击键 |
/// | 搜索 | 60 秒 | 同一关键词的连续输入（防打字机式刷屏） |
/// | 创建 / 剪藏 | 不合并 | 每次都算独立事件 |
///
/// 合并后的粒度恰好是日总结想要的：**"读了 5 篇、写了 3 条、搜了 8 次"**，
/// 而不是"点击了 47 次"。
///
/// ## 隐私
///
/// `query` 字段是**敏感数据**（搜索词能暴露用户在关心什么）。
/// 它只存在本地库（受 SQLCipher 保护），**不参与同步**（`activity` 不在
/// `SyncEntity` 列表里），也不随日志导出。日总结只用它做聚类，不外发。
class ActivityLogger {
  ActivityLogger({
    required VaultDatabase db,
    required this.deviceId,
    int Function()? now,
    this.viewWindow = const Duration(minutes: 30),
    this.editWindow = const Duration(minutes: 5),
    this.searchWindow = const Duration(seconds: 60),
  })  : _db = db,
        _now = now ?? _defaultNow;

  final VaultDatabase _db;

  /// 写进 `extra.device`，多设备时间线合并时用来区分来源。
  final String deviceId;

  final int Function() _now;

  final Duration viewWindow;
  final Duration editWindow;
  final Duration searchWindow;

  static int _defaultNow() => DateTime.now().millisecondsSinceEpoch;

  /// 默认保留期。一年足够回答"去年这个时候我在做什么"，
  /// 又不至于让这张表无限膨胀。
  static const Duration defaultRetention = Duration(days: 365);

  // ---------------------------------------------------------------------------
  // 记录
  // ---------------------------------------------------------------------------

  /// 打开一条条目。[dwell] 是已知的停留时长（离开页面时补记）。
  ///
  /// 典型用法：进入页面时 `view(id)`，离开时 `view(id, dwell: 实际停留)`。
  /// 第二次调用会落进同一个窗口，dwell 累加。
  Future<void> view(String entryId, {Duration? dwell}) {
    return _recordCoalescing(
      kind: ActivityKind.view,
      entryId: entryId,
      window: viewWindow,
      dwell: dwell,
    );
  }

  /// 阅读归档快照。与 [view] 分开统计 —— 读归档和读笔记是两种行为。
  Future<void> archiveView(String entryId, {Duration? dwell}) {
    return _recordCoalescing(
      kind: ActivityKind.archiveView,
      entryId: entryId,
      window: viewWindow,
      dwell: dwell,
    );
  }

  Future<void> recordCreate(String entryId) {
    return _recordCoalescing(
      kind: ActivityKind.create,
      entryId: entryId,
      window: Duration.zero,
    );
  }

  Future<void> recordEdit(String entryId) {
    return _recordCoalescing(
      kind: ActivityKind.edit,
      entryId: entryId,
      window: editWindow,
    );
  }

  /// 记一次搜索。
  ///
  /// 空查询与纯空白不记 —— 用户清空搜索框不是一次搜索。
  Future<void> recordSearch(String query, {int? resultCount}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future<void>.value();
    return _recordCoalescing(
      kind: ActivityKind.search,
      query: trimmed,
      window: searchWindow,
      extra: <String, Object?>{'results': ?resultCount},
    );
  }

  /// 剪藏（保存网页 / 分享进来）。
  Future<void> recordClip({String? entryId, String? source}) {
    return _recordCoalescing(
      kind: ActivityKind.clip,
      entryId: entryId,
      window: Duration.zero,
      extra: <String, Object?>{'source': ?source},
    );
  }

  /// 通用入口。上面每个方法最终都走这里。
  ///
  /// [window] 为 [Duration.zero] 表示不合并，直接插一行。
  Future<void> _recordCoalescing({
    required ActivityKind kind,
    String? entryId,
    String? query,
    required Duration window,
    Duration? dwell,
    Map<String, Object?>? extra,
  }) async {
    final now = _now();
    final extraJson = _encodeExtra(extra);

    await _db.transaction(() async {
      if (window > Duration.zero) {
        final since = now - window.inMilliseconds;
        final previous = await (_db.select(_db.activities)
              ..where((t) =>
                  t.kind.equals(kind.code) &
                  t.ts.isBiggerOrEqualValue(since) &
                  (entryId == null ? t.entryId.isNull() : t.entryId.equals(entryId)) &
                  (query == null ? t.query.isNull() : t.query.equals(query)))
              ..orderBy(<OrderClauseGenerator<dynamic>>[(t) => OrderingTerm.desc(t.ts)])
              ..limit(1))
            .getSingleOrNull();

        if (previous != null) {
          await (_db.update(_db.activities)..where((t) => t.id.equals(previous.id))).write(
            ActivitiesCompanion(
              // ts 更新到"最后一次活动"的时刻，这样日总结能看出会话何时结束；
              // 会话起点由窗口反推（ts - dwellMs）。
              ts: Value<int>(now),
              dwellMs: Value<int?>(
                dwell == null
                    ? previous.dwellMs
                    : (previous.dwellMs ?? 0) + dwell.inMilliseconds,
              ),
              extra: extraJson == null ? const Value<String?>.absent() : Value<String?>(extraJson),
            ),
          );
          return;
        }
      }

      await _db.into(_db.activities).insert(
            ActivitiesCompanion.insert(
              ts: now,
              kind: kind.code,
              entryId: Value<String?>(entryId),
              dwellMs: Value<int?>(dwell?.inMilliseconds),
              query: Value<String?>(query),
              extra: Value<String?>(extraJson),
            ),
          );
    });
  }

  String? _encodeExtra(Map<String, Object?>? extra) {
    if (extra == null || extra.isEmpty) return null;
    return jsonEncode(<String, Object?>{'device': deviceId, ...extra});
  }

  // ---------------------------------------------------------------------------
  // 读取（日总结的输入）
  // ---------------------------------------------------------------------------

  /// 某一天的活动时间线。按时间升序。
  ///
  /// [day] 按**本地时区**切分 —— 用户说"今天"，指的是他手机上的今天。
  Future<List<ActivityRow>> timelineForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.activities)
          ..where((t) =>
              t.ts.isBiggerOrEqualValue(start.millisecondsSinceEpoch) &
              t.ts.isSmallerThanValue(end.millisecondsSinceEpoch))
          ..orderBy(<OrderClauseGenerator<dynamic>>[(t) => OrderingTerm.asc(t.ts)]))
        .get();
  }

  /// 一天的聚合摘要。**日总结真正要喂给模型的是它，不是原始时间线。**
  ///
  /// 原始时间线可能有几百行，直接塞进 prompt 会浪费 token 且噪声极大。
  Future<DayActivitySummary> summarizeDay(DateTime day) async {
    final rows = await timelineForDay(day);

    final byKind = <ActivityKind, int>{};
    final dwellByKind = <ActivityKind, int>{};
    final entryIds = <String>{};
    final queries = <String>[];

    for (final row in rows) {
      final kind = ActivityKind.fromCode(row.kind);
      if (kind == null) continue;
      byKind[kind] = (byKind[kind] ?? 0) + 1;
      final dwell = row.dwellMs ?? 0;
      if (dwell > 0) {
        dwellByKind[kind] = (dwellByKind[kind] ?? 0) + dwell;
      }
      if (row.entryId != null) entryIds.add(row.entryId!);
      if (kind == ActivityKind.search && row.query != null) {
        queries.add(row.query!);
      }
    }

    return DayActivitySummary(
      day: DateTime(day.year, day.month, day.day),
      totalEvents: rows.length,
      countByKind: byKind,
      dwellByKind: dwellByKind,
      touchedEntryIds: entryIds.toList(growable: false),
      searchQueries: queries,
      firstAt: rows.isEmpty ? null : DateTime.fromMillisecondsSinceEpoch(rows.first.ts),
      lastAt: rows.isEmpty ? null : DateTime.fromMillisecondsSinceEpoch(rows.last.ts),
    );
  }

  // ---------------------------------------------------------------------------
  // 维护
  // ---------------------------------------------------------------------------

  /// 清理过期记录。返回删除行数。
  ///
  /// 由 `job_queue` 里的周期任务调用（M2 之后接上）。
  Future<int> prune({Duration retention = defaultRetention}) async {
    final cutoff = _now() - retention.inMilliseconds;
    return (_db.delete(_db.activities)..where((t) => t.ts.isSmallerThanValue(cutoff))).go();
  }
}

/// 一天的聚合活动。日总结的输入。
class DayActivitySummary {
  const DayActivitySummary({
    required this.day,
    required this.totalEvents,
    required this.countByKind,
    required this.dwellByKind,
    required this.touchedEntryIds,
    required this.searchQueries,
    this.firstAt,
    this.lastAt,
  });

  final DateTime day;
  final int totalEvents;
  final Map<ActivityKind, int> countByKind;
  final Map<ActivityKind, int> dwellByKind;

  /// 当天碰过的条目（去重）。日总结据此去取标题与摘要。
  final List<String> touchedEntryIds;

  /// 当天搜过的词（去重前）。
  final List<String> searchQueries;

  final DateTime? firstAt;
  final DateTime? lastAt;

  bool get isEmpty => totalEvents == 0;

  /// 一句话概括，用于 UI 的时间线标题。
  ///
  /// 刻意用"读了/写了/搜了"这种朴素措辞，不用"洞察""总结" ——
  /// 这一行是**事实**，AI 生成的判断在别处。
  String get headline {
    if (isEmpty) return '这一天没有记录';
    final parts = <String>[];
    final created = countByKind[ActivityKind.create] ?? 0;
    final edited = countByKind[ActivityKind.edit] ?? 0;
    final viewed = (countByKind[ActivityKind.view] ?? 0) +
        (countByKind[ActivityKind.archiveView] ?? 0);
    final searched = countByKind[ActivityKind.search] ?? 0;
    final clipped = countByKind[ActivityKind.clip] ?? 0;

    if (created > 0) parts.add('新建 $created 条');
    if (edited > 0) parts.add('编辑 $edited 次');
    if (viewed > 0) parts.add('阅读 $viewed 次');
    if (clipped > 0) parts.add('剪藏 $clipped 篇');
    if (searched > 0) parts.add('搜索 $searched 次');
    return parts.join(' · ');
  }

  @override
  String toString() => 'DayActivitySummary(${day.toIso8601String().split('T').first}, '
      '$totalEvents events, ${touchedEntryIds.length} entries)';
}
