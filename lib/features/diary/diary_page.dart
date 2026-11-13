import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/session/vault_session.dart';
import '../../app/theme/sketch_metrics.dart';
import '../../app/theme/sketch_theme.dart';
import '../../core/icons/sketch_icons.dart';
import '../../core/widgets/page_scaffold.dart';
import '../../core/widgets/sketch_controls.dart';
import '../../core/widgets/sketch_frame.dart';
import '../../data/agent/ai_diary_schedule.dart';
import '../../data/agent/daily_summary_service.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/entry/entry_models.dart';
import '../../data/diary/diary_meta.dart';
import '../../data/diary/diary_month_summary.dart';
import '../../data/diary/diary_streak.dart';
import '../../data/write/write_gateway.dart';
import '../../data/entry/entry_repository_provider.dart';
import '../editor/editor_page.dart';
import '../../core/widgets/sketch_transitions.dart';

/// 日历格子里的状态点直径。刻意不放进 [SketchSpace]：
/// 那是间距语义，这里是一个具体图形的尺寸。
const double _dotSize = 6;

/// 月历格子的宽高比（宽 / 高）。太扁会挤到日期数字，太高会占满首屏。
const double _cellAspectRatio = 1.15;

/// 日记：月历 + 当日/当月条目列表。
///
/// 月历格子用「简化容器」（实线 + 对称圆角）而不是完整的 SketchFrame：
/// 一屏 42 个格子若都走虚线 CustomPainter，滚动会掉帧（docs/09 R14）。
class DiaryPage extends ConsumerStatefulWidget {
  const DiaryPage({super.key, this.initialMonth});

  /// 初始展示的月份；默认取当前时间。测试用它固定月份。
  final DateTime? initialMonth;

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage> {
  late DateTime _month;
  Map<int, List<EntrySummary>> _byDay = const <int, List<EntrySummary>>{};
  DiaryMonthSummary _monthSummary = planDiaryMonthSummary(
    const <DiaryDayEntry>[],
  );
  Map<String, List<String>> _citationsById = const <String, List<String>>{};
  int? _selectedDay;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final DateTime base = widget.initialMonth ?? DateTime.now();
    _month = DateTime(base.year, base.month);
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(entryRepositoryProvider);
    final Map<int, List<EntrySummary>> data =
        await repo.diaryForMonth(_month.year, _month.month);
    // 月历头汇总直接从真实 entry.meta 读 word_count（docs/11 §1.2），
    // 不用 snippet 长度猜，也不会把 AI 日记算进平均字数。
    final db = ref.read(vaultDatabaseProvider);
    final rows = await db.select(db.entries).get();
    final monthEntries = <DiaryDayEntry>[];
    final citationsById = <String, List<String>>{};
    for (final row in rows) {
      if (row.kind == EntryKind.aiDiary.code &&
          row.meta != null &&
          row.meta!.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(row.meta!);
          if (decoded is Map && decoded['citations'] is List) {
            citationsById[row.id] = <String>[
              for (final id in decoded['citations'] as List)
                if (id is String) id,
            ];
          }
        } on Object {
          // 坏 meta 跳过，不让整页崩（与月历头同一原则）。
        }
      }
      if (row.deleted != 0 ||
          (row.kind != EntryKind.diary.code &&
              row.kind != EntryKind.aiDiary.code)) {
        continue;
      }
      final meta = DiaryMeta.fromJson(row.meta);
      // 归属日期以 meta.date 为准（补写/跨时区），不从 createdAt 推。
      final date = DateTime.tryParse(meta.date);
      if (date == null ||
          date.year != _month.year ||
          date.month != _month.month) {
        continue;
      }
      monthEntries.add(DiaryDayEntry(
        day: date.day,
        kind: row.kind,
        wordCount: meta.wordCount,
      ));
    }
    final summary = planDiaryMonthSummary(monthEntries);
    if (!mounted) return;
    setState(() {
      _byDay = data;
      _monthSummary = summary;
      _citationsById = citationsById;
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = null;
      _loading = true;
    });
    _load();
  }

  void _selectDay(int day) {
    setState(() {
      _selectedDay = day;
    });
  }

  /// docs/11 §3.2「现在生成」：用选中日期（未选则今天）的真实活动埋点
  /// 生成一条 kind=4 日总结；端侧模型反思文本仍缺，不编造。
  Future<void> _generateAiDiary() async {
    final db = ref.read(vaultDatabaseProvider);
    final gateway = ref.read(writeGatewayProvider);
    final activity = ref.read(activityLoggerProvider);
    final now = DateTime.now();
    final target = DateTime(
      _month.year,
      _month.month,
      _selectedDay ?? (now.year == _month.year && now.month == _month.month
          ? now.day
          : 1),
    );
    final summary = await DailySummaryService(
      logger: activity,
      gateway: gateway,
      db: db,
    ).buildAndStore(target);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary == null
            ? '这一天没有活动记录，未生成'
            : '已生成 ${target.year}-${target.month}-${target.day} 日总结'),
      ),
    );
    await _load();
  }

  /// docs/07 §6.3：AI 日记不可编辑，只能只读查看 / 删除；
  /// 用户日记仍走编辑器。
  Future<void> _openDiaryTile(EntrySummary entry) async {
    if (entry.kind != EntryKind.aiDiary) {
      _openEditor(entryId: entry.id);
      return;
    }
    final row = await ref.read(entryRepositoryProvider).getRow(entry.id);
    if (!mounted || row == null) return;
    await showSketchDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(entry.title),
        content: SingleChildScrollView(
          child: Text(
            row.body?.trim().isNotEmpty == true
                ? row.body!
                : '（这条 AI 日记没有正文）',
            style: const TextStyle(fontSize: 12.5, height: 1.6),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(writeGatewayProvider).writeEntry(
                    EntryWrite.delete(id: entry.id),
                  );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              await _load();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _openEditor({String? entryId}) {
    // docs/11 §1.2：补写对过去任意一天，date 显式取月历选中日；
    // 没选日期时取今天所在月份里的今天（跨月补写按当前查看月份）。
    final day = _selectedDay ?? DateTime.now().day;
    final date = diaryKey(DateTime(_month.year, _month.month, day));
    Navigator.of(context).push(sketchPageRoute<void>(entryId == null
          ? EditorPage(initialKind: EntryKind.diary, initialDate: date)
          : EditorPage(entryId: entryId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '日记',
      actions: <Widget>[
        SketchButton(
          label: '生成 AI 日记',
          dense: true,
          onPressed: _generateAiDiary,
        ),
        SketchButton(
          label: '补写',
          tone: SketchTone.primary,
          dense: true,
          glyph: SketchGlyph.plus,
          onPressed: () => _openEditor(),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SketchSpace.lg,
          SketchSpace.lg,
          SketchSpace.lg,
          SketchSpace.xxl,
        ),
        children: <Widget>[
          _buildMonthNav(),
          const SizedBox(height: SketchSpace.md),
          _MonthCalendar(
            year: _month.year,
            month: _month.month,
            byDay: _byDay,
            selectedDay: _selectedDay,
            onSelectDay: _selectDay,
          ),
          const SizedBox(height: SketchSpace.md),
          _buildLegend(),
          const SizedBox(height: SketchSpace.md),
          _buildStreak(),
          const SizedBox(height: SketchSpace.xs),
          Text(
            _monthSummary.label,
            style: TextStyle(fontSize: 10.5, color: context.sketch.muted),
          ),
          const SizedBox(height: SketchSpace.xs),
          Text(
            _aiDiaryHint(),
            style: TextStyle(fontSize: 10.5, color: context.sketch.blue),
          ),
          const SizedBox(height: SketchSpace.md),
          ..._buildEntrySection(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 月份导航
  // ---------------------------------------------------------------------------

  Widget _buildMonthNav() {
    final p = context.sketch;
    return Row(
      children: <Widget>[
        SketchButton(
          label: '‹',
          tone: SketchTone.ghost,
          dense: true,
          onPressed: () => _changeMonth(-1),
        ),
        Expanded(
          child: Text(
            DateFormat('yyyy年M月').format(_month),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: p.ink,
            ),
          ),
        ),
        SketchButton(
          label: '›',
          tone: SketchTone.ghost,
          dense: true,
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 图例与列表
  // ---------------------------------------------------------------------------

  /// docs/11 §1.4：底部显示「连续 N 天」，断签变灰、不弹提醒。
  Widget _buildStreak() {
    final repo = ref.read(entryRepositoryProvider);
    final future = () async {
      final written = <String>{};
      for (var delta = -2; delta <= 0; delta++) {
        final month = DateTime(_month.year, _month.month + delta, 1);
        final byDay = await repo.diaryForMonth(month.year, month.month);
        for (final entry in byDay.entries) {
          if (entry.value.any((EntrySummary e) =>
              e.kind == EntryKind.diary)) {
            written.add(diaryDateKey(
              DateTime(month.year, month.month, entry.key),
            ));
          }
        }
      }
      return computeDiaryStreak(
        writtenDays: written,
        today: DateTime.now(),
      );
    }();
    return FutureBuilder<DiaryStreak>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<DiaryStreak> snap) {
        final streak = snap.data ??
            const DiaryStreak(
              days: 0,
              startedFromToday: false,
              label: '连续 0 天',
            );
        final p = context.sketch;
        return Text(
          streak.label,
          style: TextStyle(
            fontSize: 11,
            color: streak.broken ? p.muted : p.ink,
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    final p = context.sketch;
    return Row(
      children: <Widget>[
        _LegendItem(color: p.red, label: '有日记'),
        const SizedBox(width: SketchSpace.md),
        _LegendItem(color: Colors.transparent, borderColor: p.lineSoft, label: '仅 AI 日记'),
        const Spacer(),
        Text(
          '点日期看当天',
          style: TextStyle(fontSize: 10.5, height: 1.4, color: p.muted),
        ),
      ],
    );
  }

  /// docs/07 §5.2：把 23:50 排期判定显示给用户，不自动写库。
  String _aiDiaryHint() {
    final now = DateTime.now();
    final today = diaryKey(now);
    final todayEntries = _byDay[now.day] ?? const <EntrySummary>[];
    final generated = todayEntries.any(
      (EntrySummary e) => e.kind == EntryKind.aiDiary,
    );
    final decision = decideAiDiaryGeneration(
      now: now,
      generatedDate: generated ? today : null,
      // 移动端为主：不做后台常驻承诺。
      platform: AiDiaryPlatform.android,
    );
    return 'AI 日记排期：${decision.reason} · ${decision.platformHint}';
  }

  List<Widget> _buildEntrySection() {
    final p = context.sketch;

    if (_loading) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: SketchSpace.xl),
          child: Center(
            child: CircularProgressIndicator(color: p.red),
          ),
        ),
      ];
    }

    final int? selectedDay = _selectedDay;
    if (selectedDay != null) {
      return _buildDayEntries(selectedDay);
    }

    final List<_DayGroup> groups = <_DayGroup>[];
    for (final MapEntry<int, List<EntrySummary>> entry in _byDay.entries) {
      if (entry.value.isEmpty) continue;
      final List<EntrySummary> entries = <EntrySummary>[...entry.value]
        ..sort((EntrySummary a, EntrySummary b) =>
            b.updatedAt.compareTo(a.updatedAt));
      groups.add(_DayGroup(entry.key, entries));
    }
    groups.sort((_DayGroup a, _DayGroup b) => b.day.compareTo(a.day));

    if (groups.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: SketchSpace.xl),
          child: Text(
            '这个月还没有日记，点右上角补写',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.6, color: p.muted),
          ),
        ),
      ];
    }

    final List<Widget> widgets = <Widget>[];
    for (final _DayGroup group in groups) {
      widgets.add(_DateHeader(_dateLabel(group.day)));
      widgets.add(const SizedBox(height: SketchSpace.sm));
      for (int i = 0; i < group.entries.length; i++) {
        widgets.add(_DiaryTile(
          entry: group.entries[i],
          index: i,
          citations: _citationsById[group.entries[i].id] ??
              const <String>[],
          onTap: () => _openDiaryTile(group.entries[i]),
        ));
        widgets.add(const SizedBox(height: SketchSpace.sm));
      }
      widgets.add(const SizedBox(height: SketchSpace.md));
    }
    return widgets;
  }

  List<Widget> _buildDayEntries(int day) {
    final List<EntrySummary> entries =
        <EntrySummary>[...(_byDay[day] ?? const <EntrySummary>[])]
          ..sort((EntrySummary a, EntrySummary b) =>
              b.updatedAt.compareTo(a.updatedAt));

    final List<Widget> widgets = <Widget>[
      _DateHeader(_dateLabel(day)),
      const SizedBox(height: SketchSpace.sm),
    ];

    if (entries.isEmpty) {
      widgets.add(Text(
        '这一天还没有日记，点右上角补写',
        style: TextStyle(
          fontSize: 12.5,
          height: 1.6,
          color: context.sketch.muted,
        ),
      ));
    } else {
      for (int i = 0; i < entries.length; i++) {
        widgets.add(_DiaryTile(
          entry: entries[i],
          index: i,
          citations: _citationsById[entries[i].id] ?? const <String>[],
          onTap: () => _openDiaryTile(entries[i]),
        ));
        if (i != entries.length - 1) {
          widgets.add(const SizedBox(height: SketchSpace.sm));
        }
      }
    }
    return widgets;
  }

  String _dateLabel(int day) =>
      DateFormat('M月d日').format(DateTime(_month.year, _month.month, day));
}

/// 某一天的日记，按 `updatedAt` 倒序后的分组。
class _DayGroup {
  const _DayGroup(this.day, this.entries);

  final int day;
  final List<EntrySummary> entries;
}

/// 月历。周日起始（日 一 二 三 四 五 六）。
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.year,
    required this.month,
    required this.byDay,
    required this.selectedDay,
    required this.onSelectDay,
  });

  final int year;
  final int month;
  final Map<int, List<EntrySummary>> byDay;
  final int? selectedDay;
  final ValueChanged<int> onSelectDay;

  static const List<String> _weekdays = <String>[
    '日', '一', '二', '三', '四', '五', '六',
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final DateTime first = DateTime(year, month, 1);
    final int leadingBlanks = first.weekday % 7;
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    final DateTime now = DateTime.now();
    final bool currentMonth = now.year == year && now.month == month;

    final List<Widget> cells = <Widget>[
      for (final String weekday in _weekdays)
        Center(
          child: Text(
            weekday,
            style: TextStyle(fontSize: 10.5, height: 1.4, color: p.muted),
          ),
        ),
      for (int i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (int day = 1; day <= daysInMonth; day++)
        _DayCell(
          day: day,
          isToday: currentMonth && now.day == day,
          isSelected: selectedDay == day,
          hasUserDiary: _hasUserDiary(day),
          aiOnly: _aiOnly(day),
          onTap: () => onSelectDay(day),
        ),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: SketchSpace.xs,
      crossAxisSpacing: SketchSpace.xs,
      childAspectRatio: _cellAspectRatio,
      children: cells,
    );
  }

  bool _hasUserDiary(int day) =>
      (byDay[day] ?? const <EntrySummary>[]).any(
        (EntrySummary e) => e.kind == EntryKind.diary,
      );

  bool _aiOnly(int day) {
    final List<EntrySummary> entries =
        byDay[day] ?? const <EntrySummary>[];
    return entries.isNotEmpty &&
        entries.every((EntrySummary e) => e.kind == EntryKind.aiDiary);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasUserDiary,
    required this.aiOnly,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasUserDiary;
  final bool aiOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final bool marked = hasUserDiary || aiOnly;

    final Color fill = isSelected
        ? p.note
        : isToday
            ? p.red
            : marked
                ? p.surface
                : Colors.transparent;
    final Color borderColor =
        isSelected ? p.line : (isToday ? p.red : p.lineSoft);
    final Color numberColor = isSelected
        ? p.ink
        : isToday
            ? Colors.white
            : marked
                ? p.ink
                : p.muted;
    final Color dotColor = isToday ? Colors.white : p.red;
    final Color dotBorderColor = isToday ? Colors.white : p.lineSoft;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: SketchRadii.c,
          border: Border.all(color: borderColor, width: SketchStroke.hair),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: marked || isSelected || isToday
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: numberColor,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: _dotSize,
              child: hasUserDiary
                  ? Container(
                      width: _dotSize,
                      height: _dotSize,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    )
                  : aiOnly
                      ? Container(
                          width: _dotSize,
                          height: _dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: dotBorderColor,
                              width: SketchStroke.hair,
                            ),
                          ),
                        )
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.borderColor,
  });

  final Color color;
  final String label;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor == null
                ? null
                : Border.all(
                    color: borderColor!,
                    width: SketchStroke.hair,
                  ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.4,
            color: context.sketch.muted,
          ),
        ),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: context.sketch.ink,
      ),
    );
  }
}

class _DiaryTile extends StatelessWidget {
  const _DiaryTile({
    required this.entry,
    required this.index,
    required this.onTap,
    this.citations = const <String>[],
  });

  final EntrySummary entry;
  final int index;
  final VoidCallback onTap;
  final List<String> citations;

  @override
  Widget build(BuildContext context) {
    final p = context.sketch;
    final bool isAi = entry.kind == EntryKind.aiDiary;
    final String time = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(entry.updatedAt),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SketchCard(
        variant: index,
        fill: isAi ? p.note : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: p.ink,
                    ),
                  ),
                ),
                if (isAi) ...<Widget>[
                  const SizedBox(width: SketchSpace.sm),
                  const SketchTag(
                    'AI',
                    tone: SketchTone.blue,
                    dense: true,
                  ),
                ],
              ],
            ),
            if (entry.snippet.isNotEmpty) ...<Widget>[
              const SizedBox(height: SketchSpace.xs),
              Text(
                entry.snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.6, color: p.muted),
              ),
            ],
            if (isAi && citations.isNotEmpty) ...<Widget>[
              const SizedBox(height: SketchSpace.xs),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showCitations(context, citations),
                child: SketchTag(
                  '可溯源 · 引用 ${citations.length} 条',
                  tone: SketchTone.blue,
                  dense: true,
                ),
              ),
            ],
            const SizedBox(height: SketchSpace.sm),
            Text(
              time,
              style: TextStyle(fontSize: 10.5, height: 1.4, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }

  void _showCitations(BuildContext context, List<String> ids) {
    showSketchDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('引用原文'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final id in ids)
                  ListTile(
                    dense: true,
                    title: Text(id, style: const TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).push(sketchPageRoute<void>(EditorPage(entryId: id)));
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

}
