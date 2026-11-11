import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/daily_summary.dart';

/// docs/07 §5 / §6 日总结与 AI 日记判定层测试。
void main() {
  group('活动聚合与时间线（docs/07 §5.2）', () {
    test('编辑 / 剪藏比单纯浏览更重要，只取前 N 个', () {
      final ranked = rankActivities(
        <ActivityDigest>[
          const ActivityDigest(
            entryId: 'viewed',
            title: '浏览',
            views: 3,
            edits: 0,
            clips: 0,
            searches: 0,
            dwellMs: 0,
          ),
          const ActivityDigest(
            entryId: 'edited',
            title: '编辑',
            views: 0,
            edits: 2,
            clips: 0,
            searches: 0,
            dwellMs: 0,
          ),
          const ActivityDigest(
            entryId: 'idle',
            title: '无活动',
            views: 0,
            edits: 0,
            clips: 0,
            searches: 0,
            dwellMs: 0,
          ),
        ],
        limit: 2,
      );
      expect(ranked.map((ActivityDigest a) => a.entryId).toList(),
          <String>['edited', 'viewed']);
      expect(ranked, isNot(contains('idle')));
    });

    test('停留时长计入分量，时间线升序且去重', () {
      const long = ActivityDigest(
        entryId: 'long',
        title: '读了很久',
        views: 1,
        edits: 0,
        clips: 0,
        searches: 0,
        dwellMs: 18 * 60 * 1000,
      );
      expect(long.dwellMinutes, 18);
      expect(long.weight, greaterThan(1));

      final timeline = normalizeTimeline(<TimelineItem>[
        const TimelineItem(atMs: 200, what: '下午归档'),
        const TimelineItem(atMs: 100, what: '上午记录'),
        const TimelineItem(atMs: 100, what: '上午记录'),
      ]);
      expect(timeline.map((TimelineItem t) => t.what).toList(),
          <String>['上午记录', '下午归档']);
    });
  });

  group('滚动摘要（docs/07 §5.3）', () {
    test('周读 7 日、月读 4 周、年读 12 月', () {
      expect(childCountFor(SummaryGranularity.day), 0);
      expect(childCountFor(SummaryGranularity.week), 7);
      expect(childCountFor(SummaryGranularity.month), 4);
      expect(childCountFor(SummaryGranularity.year), 12);
    });
  });

  group('引用校验（docs/07 §6.2）', () {
    test('不存在 / 重复的引用被剔除，绝不展示假引用', () {
      final valid = validateCitations(
        <String>['e1', 'missing', 'e1', 'e2'],
        <String>{'e1', 'e2'},
      );
      expect(valid, <String>['e1', 'e2']);
    });

    test('模型输出 JSON 结构可序列化', () {
      const summary = DailySummary(
        headline: '今天主要调 WebDAV 限流',
        timeline: <TimelineItem>[
          TimelineItem(atMs: 1000, what: '记录退避策略', entryId: 'e1'),
        ],
        openThreads: <String>['冲突副本 UI 未设计'],
        citations: <String>['e1'],
        date: '2026-11-11',
      );
      final json = summary.toJson();
      expect(json['headline'], '今天主要调 WebDAV 限流');
      expect((json['timeline'] as List).single['entry_id'], 'e1');
      expect(json['citations'], <String>['e1']);
    });
  });

  group('AI 日记三条硬规则（docs/07 §6.1 / §6.3）', () {
    test('物理隔离：kind=4 独立视图', () {
      expect(AiDiaryRules.isAiDiary(4), isTrue);
      expect(AiDiaryRules.isAiDiary(3), isFalse);
    });

    test('默认检索排除，只有用户显式开关才纳入', () {
      expect(AiDiaryRules.includeInSearch(userOptedIn: false), isFalse);
      expect(AiDiaryRules.includeInSearch(userOptedIn: true), isTrue);
    });

    test('AI 日记不向量化，用户日记可向量化', () {
      expect(AiDiaryRules.shouldVectorize(4), isFalse);
      expect(AiDiaryRules.shouldVectorize(3), isTrue);
    });

    test('AI 日记不可编辑；用户日记可编辑', () {
      expect(AiDiaryRules.isEditable(4), isFalse);
      expect(AiDiaryRules.isEditable(3), isTrue);
    });

    test('长度必须 150~300 字', () {
      expect(AiDiaryRules.isValidLength('x' * 149), isFalse);
      expect(AiDiaryRules.isValidLength('x' * 150), isTrue);
      expect(AiDiaryRules.isValidLength('x' * 300), isTrue);
      expect(AiDiaryRules.isValidLength('x' * 301), isFalse);
    });
  });
}
