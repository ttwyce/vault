import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/hybrid_search.dart';

/// docs/06 §1 / §2.1 混合检索纯判定层测试。
const int _now = 1731052800000;

void main() {
  group('查询预处理（docs/06 §1.2）', () {
    test('引号精确短语、类型限定、时间意图', () {
      final q = preprocessSearchQuery(
        '"flutter_gemma" 上个月 那篇日记',
        nowMs: _now,
      );
      expect(q.exactPhrase, isFalse,
          reason: '整串被引号包住才算精确短语，句中含引号不算');
      expect(q.ftsPhrase, contains('flutter_gemma'));
      expect(q.kinds, <int>{3, 4});
      expect(q.fromMs, _now - const Duration(days: 60).inMilliseconds);
    });

    test('纯精确短语查询', () {
      final q = preprocessSearchQuery('"同步冲突"', nowMs: _now);
      expect(q.exactPhrase, isTrue);
      expect(q.ftsPhrase, '同步冲突');
    });

    test('停用词只在 FTS 侧去掉，短查询降权向量', () {
      final q = preprocessSearchQuery('同步的笔记', nowMs: _now);
      expect(q.ftsPhrase, isNot(contains('的')));
      expect(q.kinds, <int>{1});
      final short = preprocessSearchQuery('同步', nowMs: _now);
      expect(short.vectorWeight, lessThan(1.0));
      expect(short.ftsWeight, greaterThan(1.0));
      // 类型限定词剥离后剩余查询变短，短查询权重同样生效。
      expect(q.vectorWeight, lessThan(1.0));
    });

    test('never 时间策略：不含时间词就没有 fromMs', () {
      final q = preprocessSearchQuery('WebDAV', nowMs: _now);
      expect(q.fromMs, isNull);
      expect(q.toMs, _now);
      expect(q.kinds, isEmpty);
    });
  });

  group('RRF 融合（docs/06 §1.1）', () {
    test('两路都命中的条目排第一，分数为两路之和', () {
      final fused = reciprocalRankFusion(
        ftsHits: const <RankedHit>[
          RankedHit('a', 1),
          RankedHit('b', 2),
        ],
        vectorHits: const <RankedHit>[
          RankedHit('a', 3),
          RankedHit('c', 1),
        ],
      );
      expect(fused.first.entryId, 'a');
      expect(fused.first.sources, <String>{'fts', 'vector'});
      expect(
        fused.first.score,
        closeTo(1 / 61 + 1 / 63, 1e-12),
      );
      expect(fused.map((FusedHit h) => h.entryId).toList(),
          <String>['a', 'c', 'b']);
    });

    test('结构化过滤把不在 allowedIds 的召回直接剔除', () {
      final fused = reciprocalRankFusion(
        ftsHits: const <RankedHit>[RankedHit('a', 1), RankedHit('b', 2)],
        vectorHits: const <RankedHit>[RankedHit('c', 1)],
        allowedIds: <String>{'b', 'c'},
      );
      expect(fused.map((FusedHit h) => h.entryId), isNot(contains('a')));
      expect(fused.map((FusedHit h) => h.entryId).toList(),
          <String>['c', 'b']);
    });

    test('短查询权重让 FTS 第一名超过向量第一名', () {
      final q = preprocessSearchQuery('同步', nowMs: _now);
      final fused = reciprocalRankFusion(
        ftsHits: const <RankedHit>[RankedHit('fts', 1)],
        vectorHits: const <RankedHit>[RankedHit('vec', 1)],
        ftsWeight: q.ftsWeight,
        vectorWeight: q.vectorWeight,
      );
      expect(fused.first.entryId, 'fts');
      expect(fused.first.score, greaterThan(fused.last.score));
    });

    test('limit 只返回前 N，非法 rank 跳过', () {
      final fused = reciprocalRankFusion(
        ftsHits: const <RankedHit>[
          RankedHit('a', 1),
          RankedHit('b', 2),
          RankedHit('bad', 0),
        ],
        vectorHits: const <RankedHit>[],
        limit: 1,
      );
      expect(fused, hasLength(1));
      expect(fused.single.entryId, 'a');
    });
  });

  group('重排与分块（docs/06 §2.1）', () {
    test('时间衰减：最近条目略高于旧条目，置顶再加权', () {
      double score(int updated, {bool pinned = false}) => rerankScore(
            rrfScore: 1 / 61,
            updatedAtMs: updated,
            nowMs: _now,
            pinned: pinned,
          );
      final fresh = score(_now);
      final old = score(_now - const Duration(days: 900).inMilliseconds);
      expect(fresh, greaterThan(old));
      expect(fresh, lessThan(old * 1.4),
          reason: '衰减不能让旧内容完全沉底');
      expect(score(_now, pinned: true), greaterThan(fresh));
    });

    test('credential 永不向量化', () {
      expect(shouldVectorize(6), isFalse);
      expect(
        planChunks(body: '密码正文很长', kind: 6).chunks,
        isEmpty,
      );
      expect(shouldVectorize(1), isTrue);
    });

    test('短正文不分块；长书签按 20 块封顶且相邻块有 overlap', () {
      expect(planChunks(body: '一段短文', kind: 1).chunks, hasLength(1));
      final long = List<String>.generate(
        400,
        (int i) => '第$i段 ${'字' * 160}',
      ).join('\n\n');
      final plan = planChunks(body: long, kind: 5);
      expect(plan.chunks.length, lessThanOrEqualTo(20));
      expect(plan.truncated, isTrue);
      expect(plan.chunks.first.start, 0);
      expect(plan.chunks[1].start, lessThan(plan.chunks.first.end),
          reason: '相邻块必须 overlap');
      expect(plan.chunks.last.end, lessThanOrEqualTo(long.length));
    });
  });

  test('docs/06 §8.1 命中来源标签如实反映关键词/语义状态', () {
    expect(
      hitSourceLabel(
        keywordHit: true,
        vectorHit: false,
        vectorEnabled: false,
      ),
      contains('语义未启用'),
    );
    expect(
      hitSourceLabel(
        keywordHit: true,
        vectorHit: false,
        vectorEnabled: true,
      ),
      '命中：关键词',
    );
    expect(
      hitSourceLabel(
        keywordHit: true,
        vectorHit: true,
        vectorEnabled: true,
      ),
      '命中：关键词 + 语义',
    );
    expect(
      hitSourceLabel(
        keywordHit: false,
        vectorHit: true,
        vectorEnabled: true,
      ),
      '命中：语义',
    );
  });

  test('docs/06 §2.1 分块命中先聚合到 entry 粒度，不重复累加', () {
    final aggregated = aggregateChunkHits(<RankedHit>[
      const RankedHit('a', 3),
      const RankedHit('a', 1), // 同 entry 的第二个 chunk
      const RankedHit('b', 2),
    ]);
    expect(aggregated.map((RankedHit h) => h.entryId).toList(),
        <String>['a', 'b']);
    expect(aggregated.first.rank, 1);

    // 未聚合时 a 的两个 chunk 会重复加分；聚合后每个 entry 只算一次。
    final fused = reciprocalRankFusion(
      ftsHits: const <RankedHit>[RankedHit('b', 1)],
      vectorHits: const <RankedHit>[
        RankedHit('a', 2),
        RankedHit('a', 3),
        RankedHit('a', 4),
      ],
    );
    expect(fused, hasLength(2));
    final a = fused.firstWhere((FusedHit h) => h.entryId == 'a');
    expect(a.score, closeTo(1.0 / (60 + 2), 0.0001),
        reason: '三个 chunk 只保留最佳名次');
  });
}
