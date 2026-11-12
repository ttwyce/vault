/// AI 日记 23:50 自动生成排期（docs/11 §1.4 / docs/07 §5.2）。
///
/// 不启动定时器、不写库：只按「当前时刻 / 当天是否已生成 / 平台」
/// 判定这一刻该不该生成，以及三端各自的用户可见文案。
library;

/// 目标时刻 23:50（本地时间）。
const int kAiDiaryHour = 23;
const int kAiDiaryMinute = 50;

enum AiDiaryPlatform { windows, android, ios }

class AiDiaryScheduleDecision {
  const AiDiaryScheduleDecision({
    required this.shouldGenerate,
    required this.reason,
    required this.platformHint,
  });

  final bool shouldGenerate;
  final String reason;
  final String platformHint;
}

String platformHint(AiDiaryPlatform platform) => switch (platform) {
      AiDiaryPlatform.windows => '每天 23:50 自动生成（托盘常驻，可靠）',
      AiDiaryPlatform.android => '当日首次打开 App 时补算前一天（不做后台承诺）',
      AiDiaryPlatform.ios => '下次打开 App 时补算（前台补偿，BGTask 不可靠）',
    };

/// [now] 用本地时间；[generatedDate] 是当天已生成日记的 `meta.date`
/// （YYYY-MM-DD），为空表示尚未生成。
AiDiaryScheduleDecision decideAiDiaryGeneration({
  required DateTime now,
  required String? generatedDate,
  required AiDiaryPlatform platform,
}) {
  final hint = platformHint(platform);
  final date = '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  if (generatedDate == date) {
    return AiDiaryScheduleDecision(
      shouldGenerate: false,
      reason: '今天已生成过 AI 日记，不重复生成',
      platformHint: hint,
    );
  }
  // 移动端不做后台承诺：23:50 之后到当天结束都算「该补算」，
  // 次日首次打开则补算前一天（由调用方传入前一天的 now 再判一次）。
  final afterSchedule = now.hour > kAiDiaryHour ||
      (now.hour == kAiDiaryHour && now.minute >= kAiDiaryMinute);
  if (!afterSchedule) {
    return AiDiaryScheduleDecision(
      shouldGenerate: false,
      reason: '未到 23:50，等待当日定时窗口',
      platformHint: hint,
    );
  }
  return AiDiaryScheduleDecision(
    shouldGenerate: true,
    reason: platform == AiDiaryPlatform.windows
        ? '已到 23:50，触发生成当天日总结'
        : '前台补偿：补算 $date 的 AI 日记',
    platformHint: hint,
  );
}
