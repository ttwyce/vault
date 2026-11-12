import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/diary/diary_streak.dart';

/// docs/11 §1.4 日记连续天数与月历三态测试。
void main() {
  final today = DateTime(2026, 11, 8);

  String day(int offset) =>
      diaryDateKey(DateTime(today.year, today.month, today.day + offset));

  test('今天有日记 → 从今天往回连续计数', () {
    final streak = computeDiaryStreak(
      writtenDays: <String>{day(0), day(-1), day(-2)},
      today: today,
    );
    expect(streak.days, 3);
    expect(streak.startedFromToday, isTrue);
    expect(streak.label, '连续 3 天');
    expect(streak.broken, isFalse);
  });

  test('今天没写但昨天有 → 从昨天算，还没断签', () {
    final streak = computeDiaryStreak(
      writtenDays: <String>{day(-1), day(-2)},
      today: today,
    );
    expect(streak.days, 2);
    expect(streak.startedFromToday, isFalse);
  });

  test('昨天也没写 / 中间断了一天 → 断签或截断', () {
    expect(
      computeDiaryStreak(writtenDays: <String>{day(-3)}, today: today).days,
      0,
    );
    final gap = computeDiaryStreak(
      writtenDays: <String>{day(0), day(-2)},
      today: today,
    );
    expect(gap.days, 1, reason: '中间空一天就截断');
  });

  test('月历三态：用户日记 > 仅 AI 日记 > 空', () {
    expect(
      diaryCellState(hasUserDiary: true, hasAiDiary: true),
      DiaryCellState.userDiary,
    );
    expect(
      diaryCellState(hasUserDiary: false, hasAiDiary: true),
      DiaryCellState.aiDiaryOnly,
    );
    expect(
      diaryCellState(hasUserDiary: false, hasAiDiary: false),
      DiaryCellState.empty,
    );
    expect(diaryDateKey(today), '2026-11-08');
  });
}
