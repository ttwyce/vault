import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/diary/diary_meta.dart';
import 'package:vault/data/diary/diary_review.dart';

/// 日记模板与年度回顾（docs/11 §1.5）。
void main() {
  test('模板清单有唯一 id 且预填正文可用', () {
    final ids = kDiaryTemplates.map((DiaryTemplate t) => t.id).toSet();
    expect(ids.length, kDiaryTemplates.length);
    expect(diaryTemplateById('review').body, contains('明天改什么'));
    expect(diaryTemplateById('unknown').id, 'free');
  });

  test('年度回顾按真实 meta 聚合月份 / 字数 / 心情 / 连续天数', () {
    List<DiaryReviewEntry> entries(int month, List<int> days,
            {String mood = '好', int words = 100}) =>
        <DiaryReviewEntry>[
          for (final day in days)
            DiaryReviewEntry(
              date: '2026-${month.toString().padLeft(2, '0')}-'
                  '${day.toString().padLeft(2, '0')}',
              words: words,
              mood: mood,
              backfilled: false,
            ),
        ];
    final review = buildDiaryYearReview(
      year: 2026,
      entries: <DiaryReviewEntry>[
        ...entries(1, <int>[1, 2, 3], mood: '平静'),
        ...entries(3, <int>[9], mood: '好', words: 250),
        ...entries(12, <int>[31], mood: '糟', words: 50,),
        const DiaryReviewEntry(
          date: '2025-12-31',
          words: 999,
          mood: '好',
          backfilled: true,
        ),
      ],
    );
    expect(review.totalEntries, 5, reason: '其它年份不计入');
    expect(review.totalWords, 300 + 250 + 50);
    expect(review.months.first.entries, 3);
    expect(review.months.first.averageWords, 100);
    expect(review.months[2].entries, 1);
    expect(review.moods, <String, int>{'平静': 3, '好': 1, '糟': 1});
    expect(review.longestStreak, 3);
    expect(review.activeDays, 5);
    expect(review.backfilled, 0);
    expect(review.hint, contains('最长连续 3 天'));
  });

  test('DiaryReviewEntry.fromMeta 保留补写与心情', () {
    final meta = buildDiaryMeta(
      date: '2026-11-08',
      body: '中文五个字加 test',
      createdAtMs: DateTime(2026, 11, 10).millisecondsSinceEpoch,
      mood: '一般',
    );
    final entry = DiaryReviewEntry.fromMeta(meta);
    expect(entry.words, 7);
    expect(entry.mood, '一般');
    expect(entry.backfilled, isTrue);
  });
}
