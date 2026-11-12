/// 日记月历头汇总（docs/11 §1.2「本月 8 篇 · 连续 3 天 · 平均 320 字」）。
///
/// 不读库：输入当月各天的条目摘要，输出篇数 / 活跃天数 /
/// 用户日记平均字数；AI 日记不计入平均字数但计入总篇数。
library;

class DiaryDayEntry {
  const DiaryDayEntry({
    required this.day,
    required this.kind,
    this.wordCount = 0,
  });

  /// 月内第几日（1~31）。
  final int day;

  /// 3 用户日记 / 4 AI 日记。
  final int kind;
  final int wordCount;
}

class DiaryMonthSummary {
  const DiaryMonthSummary({
    required this.totalEntries,
    required this.userDiaries,
    required this.activeDays,
    required this.averageWords,
  });

  final int totalEntries;
  final int userDiaries;
  final int activeDays;
  final int averageWords;

  String get label =>
      '本月 $totalEntries 篇 · $activeDays 天有记录 · 平均 $averageWords 字';
}

DiaryMonthSummary planDiaryMonthSummary(Iterable<DiaryDayEntry> entries) {
  final list = entries.toList();
  final userWords = <int>[
    for (final e in list)
      if (e.kind == 3 && e.wordCount > 0) e.wordCount,
  ];
  final activeDays = <int>{for (final e in list) e.day}.length;
  return DiaryMonthSummary(
    totalEntries: list.length,
    userDiaries: list.where((DiaryDayEntry e) => e.kind == 3).length,
    activeDays: activeDays,
    averageWords: userWords.isEmpty
        ? 0
        : (userWords.reduce((int a, int b) => a + b) / userWords.length).round(),
  );
}
