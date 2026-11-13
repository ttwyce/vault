/// 日记模板与年度回顾（docs/11 §1.5）。
///
/// 不碰数据库、不碰 UI：模板只产生预填正文；年度回顾把真实日记 meta
/// 聚合成月份篇数 / 平均字数 / 心情分布 / 最长连续天数。
library;

import 'diary_meta.dart';

class DiaryTemplate {
  const DiaryTemplate(this.id, this.label, this.body);

  final String id;
  final String label;
  final String body;
}

const List<DiaryTemplate> kDiaryTemplates = <DiaryTemplate>[
  DiaryTemplate('free', '自由记录', ''),
  DiaryTemplate(
    'daily',
    '三件事',
    '## 今天最重要的三件事\n\n1. \n2. \n3. \n\n## 感受\n\n',
  ),
  DiaryTemplate(
    'review',
    '复盘',
    '## 做了什么\n\n\n## 哪里不顺\n\n\n## 明天改什么\n\n',
  ),
  DiaryTemplate(
    'gratitude',
    '感恩',
    '## 今天想记住的\n\n\n## 感谢的人或事\n\n',
  ),
];

DiaryTemplate diaryTemplateById(String id) => kDiaryTemplates
    .where((DiaryTemplate t) => t.id == id)
    .firstOrNull ??
    kDiaryTemplates.first;

class DiaryReviewMonth {
  const DiaryReviewMonth({
    required this.month,
    required this.entries,
    required this.words,
  });

  final int month;
  final int entries;
  final int words;

  int get averageWords => entries == 0 ? 0 : (words / entries).round();
}

class DiaryYearReview {
  const DiaryYearReview({
    required this.year,
    required this.totalEntries,
    required this.totalWords,
    required this.months,
    required this.moods,
    required this.longestStreak,
    required this.activeDays,
    required this.backfilled,
  });

  final int year;
  final int totalEntries;
  final int totalWords;
  final List<DiaryReviewMonth> months;
  final Map<String, int> moods;
  final int longestStreak;
  final int activeDays;
  final int backfilled;

  String get hint => '$year 年共 $totalEntries 篇 · $totalWords 字 · '
      '$activeDays 天有记录 · 最长连续 $longestStreak 天';
}

class DiaryReviewEntry {
  const DiaryReviewEntry({
    required this.date,
    required this.words,
    required this.mood,
    required this.backfilled,
  });

  final String date;
  final int words;
  final String? mood;
  final bool backfilled;

  factory DiaryReviewEntry.fromMeta(DiaryMeta meta) => DiaryReviewEntry(
        date: meta.date,
        words: meta.wordCount,
        mood: meta.mood,
        backfilled: meta.backfilled,
      );
}

DiaryYearReview buildDiaryYearReview({
  required int year,
  required Iterable<DiaryReviewEntry> entries,
}) {
  final filtered = entries
      .where((DiaryReviewEntry e) => e.date.startsWith('$year-'))
      .toList()
    ..sort((DiaryReviewEntry a, DiaryReviewEntry b) =>
        a.date.compareTo(b.date));
  final byMonth = <int, List<DiaryReviewEntry>>{};
  final moods = <String, int>{};
  for (final entry in filtered) {
    final month = int.tryParse(entry.date.substring(5, 7)) ?? 0;
    if (month < 1 || month > 12) continue;
    byMonth.putIfAbsent(month, () => <DiaryReviewEntry>[]).add(entry);
    if (entry.mood != null) {
      moods[entry.mood!] = (moods[entry.mood!] ?? 0) + 1;
    }
  }
  final months = <DiaryReviewMonth>[
    for (var month = 1; month <= 12; month++)
      DiaryReviewMonth(
        month: month,
        entries: (byMonth[month] ?? const <DiaryReviewEntry>[]).length,
        words: (byMonth[month] ?? const <DiaryReviewEntry>[])
            .fold<int>(0, (int sum, DiaryReviewEntry e) => sum + e.words),
      ),
  ];
  final days = filtered.map((DiaryReviewEntry e) => e.date).toSet();
  return DiaryYearReview(
    year: year,
    totalEntries: filtered.length,
    totalWords: filtered.fold<int>(
        0, (int sum, DiaryReviewEntry e) => sum + e.words),
    months: List<DiaryReviewMonth>.unmodifiable(months),
    moods: Map<String, int>.unmodifiable(moods),
    longestStreak: _longestRun(days),
    activeDays: days.length,
    backfilled: filtered.where((DiaryReviewEntry e) => e.backfilled).length,
  );
}

/// 全年最长连续天数：把日期解析成天序号后扫一遍排序集合。
int _longestRun(Iterable<String> days) {
  final ordinals = <int>{
    for (final date in days)
      if (DateTime.tryParse(date) != null)
        DateTime.parse(date).millisecondsSinceEpoch ~/
            const Duration(days: 1).inMilliseconds,
  }.toList()
    ..sort();
  var best = 0;
  var run = 0;
  int? previous;
  for (final day in ordinals) {
    run = previous != null && day == previous + 1 ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }
  return best;
}
