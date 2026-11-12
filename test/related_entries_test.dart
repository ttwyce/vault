import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/related_entries.dart';

/// docs/07 §10.2 条目详情相关推荐测试。
void main() {
  test('标签/标题重合排序，top3 截断，分数为 0 不凑数', () {
    final hits = planRelatedEntries(
      currentId: 'a',
      currentTitle: 'WebDAV 同步限流',
      currentTags: <String>['同步', 'WebDAV'],
      candidates: <RelatedCandidate>[
        const RelatedCandidate(
          id: 'b',
          title: 'WebDAV 限流重试',
          kind: 1,
          tags: <String>['同步', 'WebDAV'],
        ),
        const RelatedCandidate(
          id: 'c',
          title: '同步冲突处理',
          kind: 1,
          tags: <String>['同步'],
        ),
        const RelatedCandidate(
          id: 'd',
          title: '完全无关的散步记录',
          kind: 1,
          tags: <String>[],
        ),
        const RelatedCandidate(
          id: 'e',
          title: '另一篇同步',
          kind: 1,
          tags: <String>['同步'],
        ),
        const RelatedCandidate(
          id: 'f',
          title: '第四篇同步',
          kind: 1,
          tags: <String>['同步'],
        ),
      ],
    );
    expect(hits, hasLength(3));
    expect(hits.first.id, 'b');
    expect(hits.first.reason, contains('标签重合'));
    expect(hits.every((RelatedHit h) => h.score > 0), isTrue);
    expect(hits.map((RelatedHit h) => h.id), isNot(contains('d')));
    expect(hits.map((RelatedHit h) => h.id), isNot(contains('a')));
  });

  test('密码 kind=6 / AI 日记 kind=4 永不推荐，排除自身', () {
    final hits = planRelatedEntries(
      currentId: 'a',
      currentTitle: '同步',
      currentTags: <String>['同步'],
      candidates: <RelatedCandidate>[
        const RelatedCandidate(
          id: 'secret',
          title: '同步密码',
          kind: 6,
          tags: <String>['同步'],
        ),
        const RelatedCandidate(
          id: 'ai',
          title: '同步日总结',
          kind: 4,
          tags: <String>['同步'],
        ),
        const RelatedCandidate(
          id: 'normal',
          title: '同步笔记',
          kind: 1,
          tags: <String>['同步'],
        ),
      ],
    );
    expect(hits.map((RelatedHit h) => h.id), <String>['normal']);
  });

  test('无共同标签与标题时返回空，不硬凑推荐', () {
    expect(
      planRelatedEntries(
        currentId: 'a',
        currentTitle: '甲',
        currentTags: <String>[],
        candidates: const <RelatedCandidate>[
          RelatedCandidate(id: 'b', title: '乙', kind: 1),
        ],
      ),
      isEmpty,
    );
  });
}
