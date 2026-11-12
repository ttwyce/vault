import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/diary/diary_month_summary.dart';

/// docs/11 §1.2 日记月历头汇总测试。
void main() {
  test('空月全 0；标签不出现 NaN', () {
    final s = planDiaryMonthSummary(const <DiaryDayEntry>[]);
    expect(s.totalEntries, 0);
    expect(s.activeDays, 0);
    expect(s.averageWords, 0);
    expect(s.label, '本月 0 篇 · 0 天有记录 · 平均 0 字');
  });

  test('篇数含 AI 日记；平均字数只算用户日记', () {
    final s = planDiaryMonthSummary(<DiaryDayEntry>[
      const DiaryDayEntry(day: 3, kind: 3, wordCount: 300),
      const DiaryDayEntry(day: 3, kind: 3, wordCount: 340),
      const DiaryDayEntry(day: 5, kind: 4, wordCount: 999),
    ]);
    expect(s.totalEntries, 3);
    expect(s.userDiaries, 2);
    expect(s.activeDays, 2);
    expect(s.averageWords, 320);
    expect(s.label, contains('平均 320 字'));
  });

  test('无用户日记时平均字数 0，不把 AI 字数混入', () {
    final s = planDiaryMonthSummary(const <DiaryDayEntry>[
      DiaryDayEntry(day: 1, kind: 4, wordCount: 200),
    ]);
    expect(s.totalEntries, 1);
    expect(s.averageWords, 0);
  });
}
