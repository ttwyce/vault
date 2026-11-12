import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/diary/diary_meta.dart';

/// docs/11 §1.3 日记 meta 测试。
void main() {
  test('JSON 往返保留 date/weather/mood/word_count/backfilled', () {
    final meta = DiaryMeta(
      date: '2026-11-08',
      weather: '阴',
      mood: '平静',
      wordCount: 320,
      backfilled: true,
    );
    final back = DiaryMeta.fromJson(meta.toJsonString());
    expect(back.date, '2026-11-08');
    expect(back.weather, '阴');
    expect(back.mood, '平静');
    expect(back.wordCount, 320);
    expect(back.backfilled, isTrue);
    expect(back.copyWith(mood: '好').mood, '好');
  });

  test('非法 date / 非法 mood / 坏 JSON 一律拒绝', () {
    expect(
      () => DiaryMeta.fromJson(<String, Object?>{'date': '2026-2-3'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => DiaryMeta.fromJson(<String, Object?>{'date': '2026-02-30'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => DiaryMeta.fromJson(<String, Object?>{
        'date': '2026-11-08',
        'mood': '狂喜',
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => DiaryMeta.fromJson('不是 JSON'),
      throwsA(isA<FormatException>()),
    );
  });

  test('字数统计：中文按字、英文按词、忽略 Markdown 标记', () {
    expect(countDiaryWords('今天同步成功'), 6);
    expect(countDiaryWords('hello WebDAV world'), 3);
    expect(countDiaryWords('# **标题**\n正文'), 4);
  });

  test('补写判定：归属日期早于创建当天；同一天不算补写', () {
    final created = DateTime(2026, 11, 10, 2, 0).millisecondsSinceEpoch;
    expect(
      isBackfilled(date: '2026-11-09', createdAtMs: created),
      isTrue,
      reason: '凌晨两点写前一天，date 显式写 09 号',
    );
    expect(isBackfilled(date: '2026-11-10', createdAtMs: created), isFalse);
    final built = buildDiaryMeta(
      date: '2026-11-09',
      body: '补写一段正文',
      createdAtMs: created,
      mood: '一般',
    );
    expect(built.backfilled, isTrue);
    expect(built.wordCount, greaterThan(0));
    expect(built.mood, '一般');
  });
}
