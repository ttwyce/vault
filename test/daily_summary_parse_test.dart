import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/daily_summary.dart';

/// docs/07 §5.2 日总结模型输出解析测试。
void main() {
  final ids = <String>{'e1', 'e2'};

  test('合法 JSON：时间线归一化、引用去重校验、默认 day', () {
    final parsed = parseDailySummary(<String, Object?>{
      'headline': '今天在调限流',
      'date': '2026-11-12',
      'timeline': <Object?>[
        <String, Object?>{'at_ms': 200, 'what': '归档了文章'},
        <String, Object?>{'at_ms': 100, 'what': '写了笔记', 'entry_id': 'e1'},
        <String, Object?>{'at_ms': 100, 'what': '写了笔记', 'entry_id': 'e1'},
      ],
      'open_threads': <Object?>['冲突 UI'],
      'citations': <Object?>['e1', 'e1', '不存在', 'e2'],
    }, existingEntryIds: ids);
    expect(parsed.headline, '今天在调限流');
    expect(parsed.timeline, hasLength(2));
    expect(parsed.timeline.first.atMs, 100);
    expect(parsed.citations, <String>['e1', 'e2']);
    expect(parsed.granularity, SummaryGranularity.day);
    expect(parsed.toJson()['headline'], '今天在调限流');
  });

  test('字符串 JSON 同样可解析；week/month/year 合法', () {
    for (final g in <String>['week', 'month', 'year']) {
      final parsed = parseDailySummary(
        '{"headline":"摘要","date":"2026-11-12","granularity":"$g"}',
        existingEntryIds: ids,
      );
      expect(parsed.granularity.name, g);
    }
  });

  test('坏 JSON / 缺 headline / 坏 date / 非法 granularity 一律拒绝', () {
    expect(
      () => parseDailySummary('{坏', existingEntryIds: ids),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseDailySummary(<String, Object?>{'date': '2026-11-12'},
          existingEntryIds: ids),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseDailySummary(<String, Object?>{
        'headline': '摘要',
        'date': '2026/11/12',
      }, existingEntryIds: ids),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseDailySummary(<String, Object?>{
        'headline': '摘要',
        'date': '2026-11-12',
        'granularity': 'decade',
      }, existingEntryIds: ids),
      throwsA(isA<FormatException>()),
    );
  });
}
