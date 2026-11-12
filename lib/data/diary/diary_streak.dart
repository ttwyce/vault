/// 日记连续天数（docs/11 §1.4）。
///
/// 不弹提醒、不做打卡压迫感：只算「连续 N 天」并给出底部文案，
/// 断签变灰（streak=0）。真实月历 UI 按结果渲染。
library;

/// 日期键统一用 `YYYY-MM-DD`，与时区无关（由调用方用本地日期构造）。
String diaryDateKey(DateTime day) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

class DiaryStreak {
  const DiaryStreak({
    required this.days,
    required this.startedFromToday,
    required this.label,
  });

  final int days;
  final bool startedFromToday;
  final String label;

  bool get broken => days == 0;
}

/// 从 [writtenDays]（YYYY-MM-DD 集合）算连续天数。
///
/// 规则：
/// - 今天有日记 → 从今天往回数
/// - 今天没写但昨天有 → 从昨天往回数（还没断签）
/// - 昨天也没写 → 0（断签变灰）
DiaryStreak computeDiaryStreak({
  required Set<String> writtenDays,
  required DateTime today,
}) {
  final todayKey = diaryDateKey(today);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final yesterdayKey = diaryDateKey(yesterday);

  final String startKey;
  final bool startedFromToday;
  if (writtenDays.contains(todayKey)) {
    startKey = todayKey;
    startedFromToday = true;
  } else if (writtenDays.contains(yesterdayKey)) {
    startKey = yesterdayKey;
    startedFromToday = false;
  } else {
    return const DiaryStreak(
      days: 0,
      startedFromToday: false,
      label: '连续 0 天',
    );
  }
  final start = DateTime.parse(startKey);
  var count = 0;
  var cursor = start;
  while (writtenDays.contains(diaryDateKey(cursor))) {
    count++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return DiaryStreak(
    days: count,
    startedFromToday: startedFromToday,
    label: '连续 $count 天',
  );
}

/// 月历格子的三态（docs/11 §1.4：AI 日记未生成时显示空心圆）。
enum DiaryCellState { empty, userDiary, aiDiaryOnly }

DiaryCellState diaryCellState({
  required bool hasUserDiary,
  required bool hasAiDiary,
}) {
  if (hasUserDiary) return DiaryCellState.userDiary;
  if (hasAiDiary) return DiaryCellState.aiDiaryOnly;
  return DiaryCellState.empty;
}
