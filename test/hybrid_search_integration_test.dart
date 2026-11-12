import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/entry/entry_models.dart';
import 'package:vault/data/entry/note_meta.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// `EntryRepository.searchHybrid` 的真实 FTS 接线测试。
const int _now = 1731052800000;

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create(now: () => _now));
  tearDown(() async => app.dispose());

  Future<void> add(
    String id,
    String title,
    String body, {
    EntryKind kind = EntryKind.note,
    int updatedAt = _now,
    String? meta,
  }) async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: id,
      kind: kind,
      title: title,
      body: body,
      meta: meta,
    ));
    if (updatedAt != _now) {
      await app.db.customStatement(
        'UPDATE entry SET updated_at = ? WHERE id = ?;',
        <Object?>[updatedAt, id],
      );
    }
  }

  test('中文短语查询走 FTS，命中正确条目', () async {
    await add('e1', '增量同步', '讲 WebDAV 限流与退避');
    await add('e2', '无关笔记', '今天天气不错');
    final hits = await app.repo.searchHybrid('同步', nowMs: _now);
    expect(hits.map((EntrySummary e) => e.id), contains('e1'));
    expect(hits.map((EntrySummary e) => e.id), isNot(contains('e2')));
  });

  test('类型限定与默认排除 AI 日记', () async {
    await add('e1', '日记同步', '今天调了同步', kind: EntryKind.diary);
    await add('e2', 'AI 同步总结', '生成文本也提到同步',
        kind: EntryKind.aiDiary);
    await add('e3', '笔记同步', '普通笔记', kind: EntryKind.note);

    final diaryOnly = await app.repo.searchHybrid('那篇日记 同步',
        nowMs: _now);
    expect(diaryOnly.map((EntrySummary e) => e.id), <String>['e1']);
    expect(
      diaryOnly.map((EntrySummary e) => e.id),
      isNot(contains('e2')),
      reason: 'AI 日记默认排除',
    );

    final withAi = await app.repo.searchHybrid(
      '同步',
      nowMs: _now,
      includeAiDiary: true,
    );
    expect(withAi.map((EntrySummary e) => e.id), contains('e2'));
  });

  test('时间意图过滤 + 时间衰减重排，最近条目优先', () async {
    await add('old', '同步旧文', '同步', updatedAt: _now - 900 * 86400000);
    await add('fresh', '同步新文', '同步', updatedAt: _now - 1000);
    final all = await app.repo.searchHybrid('同步', nowMs: _now);
    expect(all.map((EntrySummary e) => e.id).toList(),
        <String>['fresh', 'old']);

    final recent = await app.repo.searchHybrid('最近 同步', nowMs: _now);
    expect(recent.map((EntrySummary e) => e.id), <String>['fresh'],
        reason: '「最近」转为 30 天结构化过滤');
  });

  test('超短 / 空白查询不进 FTS，返回空', () async {
    await add('e1', '同步', '正文');
    expect(await app.repo.searchHybrid(' ', nowMs: _now), isEmpty);
  });

  test('置顶笔记在相同 FTS 名次下排到前面', () async {
    // 两条都命中「同步」；旧的那条置顶，验证 meta.pinned 参与重排。
    await add('older', '同步旧文', '同步正文',
        updatedAt: _now - 10 * 86400000,
        meta: const NoteMeta(pinned: true, wordCount: 4).toJsonString());
    await add('newer', '同步新文', '同步正文',
        meta: const NoteMeta(pinned: false, wordCount: 4).toJsonString());
    final results = await app.repo.searchHybrid('同步', nowMs: _now);
    expect(results, hasLength(2));
    expect(results.first.id, 'older', reason: '置顶 ×1.5 超过时间衰减');
  });
}
