import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/ai_diary_schedule.dart';

/// docs/11 §1.4 AI 日记排期测试。
void main() {
  final at2350 = DateTime(2026, 11, 12, 23, 50);

  test('23:50 触发；23:49 等待；当天已生成不重复', () {
    expect(
      decideAiDiaryGeneration(
        now: at2350,
        generatedDate: null,
        platform: AiDiaryPlatform.windows,
      ).shouldGenerate,
      isTrue,
    );
    expect(
      decideAiDiaryGeneration(
        now: DateTime(2026, 11, 12, 23, 49),
        generatedDate: null,
        platform: AiDiaryPlatform.windows,
      ).reason,
      contains('未到'),
    );
    expect(
      decideAiDiaryGeneration(
        now: at2350,
        generatedDate: '2026-11-12',
        platform: AiDiaryPlatform.windows,
      ).shouldGenerate,
      isFalse,
    );
    expect(
      decideAiDiaryGeneration(
        now: at2350,
        generatedDate: '2026-11-11',
        platform: AiDiaryPlatform.windows,
      ).shouldGenerate,
      isTrue,
      reason: '昨天生成过不影响今天',
    );
  });

  test('三端文案不承诺后台自动', () {
    final windows = decideAiDiaryGeneration(
      now: at2350,
      generatedDate: null,
      platform: AiDiaryPlatform.windows,
    );
    expect(windows.platformHint, contains('托盘常驻'));
    final android = decideAiDiaryGeneration(
      now: at2350,
      generatedDate: null,
      platform: AiDiaryPlatform.android,
    );
    expect(android.reason, contains('前台补偿'));
    expect(android.platformHint, contains('不做后台承诺'));
    expect(
      platformHint(AiDiaryPlatform.ios),
      contains('BGTask 不可靠'),
    );
  });

  test('次日首次打开补算前一天', () {
    final previous = decideAiDiaryGeneration(
      now: DateTime(2026, 11, 11, 9, 0),
      generatedDate: null,
      platform: AiDiaryPlatform.android,
    );
    expect(previous.shouldGenerate, isFalse,
        reason: '传当天 9 点还没到定时窗口；补算由调用方传前一天 23:50 触发');
    final backfill = decideAiDiaryGeneration(
      now: DateTime(2026, 11, 11, 23, 55),
      generatedDate: null,
      platform: AiDiaryPlatform.android,
    );
    expect(backfill.shouldGenerate, isTrue);
    expect(backfill.reason, contains('2026-11-11'));
  });
}
