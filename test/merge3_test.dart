import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/sync/line_diff.dart';
import 'package:vault/data/sync/merge3.dart';
import 'package:vault/data/write/entry_snapshot.dart';

String _hlc(int millis, String node) =>
    Hlc(millis: millis, counter: 0, node: node).encode();

EntrySnapshot _snapshot({
  String id = 'entry-1',
  EntryKind kind = EntryKind.note,
  String? title = '标题',
  String? body = '',
  String? meta,
  int createdAt = 1000,
  int updatedAt = 1000,
  int rev = 1,
  String? hlc,
  bool deleted = false,
  int? deletedAt,
}) {
  final code = kind.code;
  return EntrySnapshot(
    id: id,
    kind: code,
    title: title,
    body: body,
    meta: meta,
    createdAt: createdAt,
    updatedAt: updatedAt,
    hlc: hlc ?? _hlc(1000, 'devA'),
    rev: rev,
    contentHash: EntrySnapshot.computeContentHash(
      kind: code,
      title: title,
      body: body,
      meta: meta,
    ),
    deleted: deleted,
    deletedAt: deletedAt,
  );
}

MergeContext _context({String copyId = 'copy-1'}) {
  return MergeContext(
    nextHlc: _hlc(2000, 'devM'),
    nowMs: 1731052800000,
    localLabel: '设备 A，11-08 13:20',
    remoteLabel: '设备 B，11-08 13:25',
    conflictCopyId: copyId,
    conflictCopyHlc: _hlc(2001, 'devM'),
  );
}

Map<String, Object?> _meta(String? raw) {
  final decoded = jsonDecode(raw!);
  return Map<String, Object?>.from(decoded as Map);
}

void main() {
  group('合并策略与短路（docs/04 §5.2）', () {
    test('按 kind 选择策略，未知 kind 保守走 LWW', () {
      expect(strategyForKind(EntryKind.note.code), MergeStrategy.text);
      expect(strategyForKind(EntryKind.thought.code), MergeStrategy.text);
      expect(strategyForKind(EntryKind.diary.code), MergeStrategy.text);
      expect(strategyForKind(EntryKind.aiDiary.code), MergeStrategy.lastWriteWins);
      expect(strategyForKind(EntryKind.bookmark.code), MergeStrategy.metaFields);
      expect(strategyForKind(EntryKind.credential.code), MergeStrategy.credential);
      expect(strategyForKind(999), MergeStrategy.lastWriteWins);
    });

    test('三路 hash 短路采用未变的一侧，且不凭 content_hash 字段猜', () {
      final base = _snapshot(body: 'base', rev: 2, hlc: _hlc(1000, 'devA'));
      final localWithFakeHash = _snapshot(
        body: 'base',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      ).copyWith(contentHash: 'stale-hash');
      final remote = _snapshot(
        body: 'remote',
        rev: 3,
        hlc: _hlc(1200, 'devB'),
      );
      final localEdited = _snapshot(
        body: 'local',
        rev: 3,
        hlc: _hlc(1100, 'devA'),
      );

      final adoptRemote = merge3(
        base: base,
        local: localWithFakeHash,
        remote: remote,
        context: _context(),
      );
      expect(adoptRemote.merged.body, 'remote');
      expect(adoptRemote.isConflict, isFalse);
      expect(adoptRemote.reason, contains('只有远端变了'));

      final keepLocal = merge3(
        base: base,
        local: localEdited,
        remote: _snapshot(body: 'base', rev: 2),
        context: _context(),
      );
      expect(keepLocal.merged.body, 'local');
      expect(keepLocal.reason, contains('只有本地变了'));

      final coincident = merge3(
        base: base,
        local: localEdited,
        remote: _snapshot(body: 'local', rev: 3, hlc: _hlc(1300, 'devB')),
        context: _context(),
      );
      expect(coincident.merged.body, 'local');
      expect(coincident.isConflict, isFalse);
      expect(coincident.reason, contains('巧合相同'));
    });

    test('三份快照 id 不一致直接拒绝合并', () {
      expect(
        () => merge3(
          base: _snapshot(body: 'base'),
          local: _snapshot(body: 'local'),
          remote: _snapshot(id: 'other', body: 'remote'),
          context: _context(),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => merge3(
          base: _snapshot(id: 'other', body: 'base'),
          local: _snapshot(body: 'local'),
          remote: _snapshot(body: 'remote'),
          context: _context(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('没有 base 时绝不猜共同祖先，远端另存冲突副本', () {
      final local = _snapshot(
        body: '本地版本',
        rev: 2,
        hlc: _hlc(1100, 'devA'),
      );
      final remote = _snapshot(
        body: '云端版本',
        rev: 2,
        hlc: _hlc(1200, 'devB'),
      );
      final context = _context(copyId: 'copy-no-base');
      final result = merge3(
        base: null,
        local: local,
        remote: remote,
        context: context,
      );

      expect(result.isConflict, isTrue);
      expect(result.merged.body, '本地版本');
      expect(result.reason, contains('没有 base'));
      expect(result.conflictCopy, isNotNull);
      final copy = result.conflictCopy!;
      expect(copy.id, context.conflictCopyId);
      expect(copy.body, '云端版本');
      expect(copy.rev, 1);
      expect(copy.deleted, isFalse);
      expect(copy.title, contains('冲突副本'));
      expect(copy.title, contains(context.remoteLabel));
      expect(
        copy.contentHash,
        EntrySnapshot.computeContentHash(
          kind: copy.kind,
          title: copy.title,
          body: copy.body,
          meta: copy.meta,
        ),
      );
    });
  });

  group('文本三方合并（T04 / T05 / T17 / T20）', () {
    test('T04：不同段落自动合并，两处修改都在且生成新 rev', () {
      final base = _snapshot(
        body: '开头\n第一段原文\n中间不变\n第二段原文\n结尾',
        meta: '{"tags":["公共"]}',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      );
      final local = _snapshot(
        body: '开头\nA 改第一段\n中间不变\n第二段原文\n结尾',
        meta: '{"tags":["公共","A"]}',
        rev: 3,
        hlc: _hlc(1100, 'devA'),
      );
      final remote = _snapshot(
        body: '开头\n第一段原文\n中间不变\nB 改第二段\n结尾',
        meta: '{"tags":["公共","B"]}',
        rev: 3,
        hlc: _hlc(1200, 'devB'),
      );
      final context = _context(copyId: 'copy-t04');
      final result = merge3(
        base: base,
        local: local,
        remote: remote,
        context: context,
      );

      expect(result.isConflict, isFalse);
      expect(result.conflictCopy, isNull);
      expect(result.reason, contains('不同段落'));
      expect(result.merged.body, contains('A 改第一段'));
      expect(result.merged.body, contains('B 改第二段'));
      expect(result.merged.body, contains('中间不变'));
      expect(result.merged.body, contains('结尾'));
      expect(result.merged.body, isNot(contains('<<<<<<<')));
      expect(result.merged.rev, 4);
      expect(result.merged.hlc, context.nextHlc);
      expect(result.merged.updatedAt, context.nowMs);
      expect(
        result.merged.contentHash,
        EntrySnapshot.computeContentHash(
          kind: result.merged.kind,
          title: result.merged.title,
          body: result.merged.body,
          meta: result.merged.meta,
        ),
      );

      final tags = (_meta(result.merged.meta)['tags'] as List)
          .map((Object? value) => value.toString())
          .toSet();
      expect(tags, <String>{'公共', 'A', 'B'});
    });

    test('T05：同一段落冲突保留双方内容，远端原样另存副本', () {
      final base = _snapshot(
        body: '开头\n同一段原文\n结尾',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      );
      final local = _snapshot(
        body: '开头\nA 改写同一段\n结尾',
        rev: 3,
        hlc: _hlc(1100, 'devA'),
      );
      final remote = _snapshot(
        body: '开头\nB 改写同一段\n结尾',
        rev: 3,
        hlc: _hlc(1200, 'devB'),
      );
      final context = _context(copyId: 'copy-t05');
      final result = merge3(
        base: base,
        local: local,
        remote: remote,
        context: context,
      );

      expect(result.isConflict, isTrue);
      expect(result.reason, contains('同一段落'));
      expect(
        result.merged.body,
        contains('<<<<<<< 本地（${context.localLabel}）'),
      );
      expect(result.merged.body, contains('======='));
      expect(
        result.merged.body,
        contains('>>>>>>> 云端（${context.remoteLabel}）'),
      );
      expect(result.merged.body, contains('A 改写同一段'));
      expect(result.merged.body, contains('B 改写同一段'));
      expect(result.merged.body, contains('开头'));
      expect(result.merged.body, contains('结尾'));
      expect(result.merged.rev, 4);

      final copy = result.conflictCopy!;
      expect(copy.id, context.conflictCopyId);
      expect(copy.body, remote.body);
      expect(copy.rev, 1);
      expect(copy.deleted, isFalse);
      expect(copy.title, contains('冲突副本'));
      expect(copy.title, contains(context.remoteLabel));
    });

    test('T17：冲突副本作为普通条目再次同步时不再冲突', () {
      final base = _snapshot(
        body: '开头\n同一段原文\n结尾',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      );
      final first = merge3(
        base: base,
        local: _snapshot(
          body: '开头\nA 改写同一段\n结尾',
          rev: 3,
          hlc: _hlc(1100, 'devA'),
        ),
        remote: _snapshot(
          body: '开头\nB 改写同一段\n结尾',
          rev: 3,
          hlc: _hlc(1200, 'devB'),
        ),
        context: _context(copyId: 'copy-t17'),
      );
      final copy = first.conflictCopy!;

      final resync = merge3(
        base: null,
        local: copy,
        remote: copy,
        context: _context(copyId: 'unused-copy'),
      );

      expect(resync.isConflict, isFalse);
      expect(resync.conflictCopy, isNull);
      expect(resync.merged.id, copy.id);
      expect(resync.merged.body, copy.body);
      expect(resync.reason, contains('巧合相同'));
    });

    test('T20：三台设备逐轮合并后最终包含三处编辑且无丢失', () {
      final base = _snapshot(
        body: 'P1\nP2\nP3\nP4',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      );
      final first = merge3(
        base: base,
        local: _snapshot(
          body: 'A1\nP2\nP3\nP4',
          rev: 3,
          hlc: _hlc(1100, 'devA'),
        ),
        remote: _snapshot(
          body: 'P1\nB2\nP3\nP4',
          rev: 3,
          hlc: _hlc(1200, 'devB'),
        ),
        context: _context(copyId: 'copy-t20-a'),
      );
      expect(first.isConflict, isFalse);
      expect(first.merged.body, contains('A1'));
      expect(first.merged.body, contains('B2'));

      final afterAb = first.merged;
      final second = merge3(
        base: afterAb,
        local: _snapshot(
          body: 'A1\nB2\nC3\nP4',
          rev: afterAb.rev + 1,
          hlc: _hlc(2100, 'devC'),
        ),
        remote: _snapshot(
          body: 'A1\nB2\nP3\nC4',
          rev: afterAb.rev + 1,
          hlc: _hlc(2200, 'devD'),
        ),
        context: _context(copyId: 'copy-t20-b'),
      );

      expect(second.isConflict, isFalse);
      expect(second.conflictCopy, isNull);
      expect(second.merged.body, contains('A1'));
      expect(second.merged.body, contains('B2'));
      expect(second.merged.body, contains('C3'));
      expect(second.merged.body, contains('C4'));
      expect(second.merged.body, isNot(contains('<<<<<<<')));
    });
  });

  group('按 kind 的合并语义（T13 / §5.3）', () {
    test('T13：设备时钟快 1 小时时 HLC 决定 LWW，不被墙上时间带偏', () {
      final base = _snapshot(
        kind: EntryKind.aiDiary,
        body: '原始 AI 日记',
        rev: 2,
        hlc: _hlc(900, 'devA'),
      );
      final local = _snapshot(
        kind: EntryKind.aiDiary,
        body: 'A 的 AI 日记',
        rev: 3,
        hlc: _hlc(1000, 'devA'),
      );
      final remote = _snapshot(
        kind: EntryKind.aiDiary,
        body: 'B 的 AI 日记（设备快 1 小时）',
        rev: 3,
        hlc: _hlc(1000 + 3600000, 'devB'),
      );
      final result = merge3(
        base: base,
        local: local,
        remote: remote,
        context: _context(),
      );

      expect(result.merged.body, remote.body);
      expect(result.reason, contains('LWW'));
      expect(result.isConflict, isFalse);
    });

    test('书签：正文 LWW，meta 字段级合并，tags 并集', () {
      final base = _snapshot(
        kind: EntryKind.bookmark,
        body: '归档正文 base',
        meta: '{"color":"blue","tags":["x"],"url":"https://a"}',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      );
      final local = _snapshot(
        kind: EntryKind.bookmark,
        body: '归档正文 local',
        meta: '{"color":"red","tags":["x","l"],"url":"https://a"}',
        rev: 3,
        hlc: _hlc(1100, 'devA'),
      );
      final remote = _snapshot(
        kind: EntryKind.bookmark,
        body: '归档正文 remote',
        meta: '{"color":"blue","tags":["x","r"],"url":"https://b"}',
        rev: 3,
        hlc: _hlc(1200, 'devB'),
      );
      final context = _context();
      final result = merge3(
        base: base,
        local: local,
        remote: remote,
        context: context,
      );

      expect(result.isConflict, isFalse);
      expect(result.reason, contains('meta 字段级合并'));
      expect(result.merged.body, '归档正文 remote');
      final meta = _meta(result.merged.meta);
      expect(meta['url'], 'https://b');
      expect(meta['color'], 'red');
      final tags = (meta['tags'] as List)
          .map((Object? value) => value.toString())
          .toSet();
      expect(tags, <String>{'x', 'l', 'r'});
      expect(result.merged.rev, 4);
      expect(result.merged.hlc, context.nextHlc);
      expect(
        result.merged.contentHash,
        EntrySnapshot.computeContentHash(
          kind: result.merged.kind,
          title: result.merged.title,
          body: result.merged.body,
          meta: result.merged.meta,
        ),
      );
    });

    test('密码条目：LWW + 旧值副本，绝不合并密码字段', () {
      final base = _snapshot(
        kind: EntryKind.credential,
        body: '凭据 base',
        meta: '{"password":"p0","username":"u"}',
        rev: 2,
        hlc: _hlc(1000, 'devA'),
      );
      final local = _snapshot(
        kind: EntryKind.credential,
        body: '凭据 local',
        meta: '{"password":"p-local","username":"u"}',
        rev: 3,
        hlc: _hlc(1100, 'devA'),
      );
      final remote = _snapshot(
        kind: EntryKind.credential,
        body: '凭据 remote',
        meta: '{"password":"p-remote","username":"u"}',
        rev: 3,
        hlc: _hlc(1200, 'devB'),
      );
      final context = _context(copyId: 'copy-credential');
      final result = merge3(
        base: base,
        local: local,
        remote: remote,
        context: context,
      );

      expect(result.isConflict, isTrue);
      expect(result.reason, contains('绝不合并密码字段'));
      expect(result.merged.body, '凭据 remote');
      expect(result.merged.meta, remote.meta);
      expect(result.merged.meta, isNot(contains('p-local')));
      expect(result.merged.body, isNot(contains('<<<<<<<')));

      final copy = result.conflictCopy!;
      expect(copy.id, context.conflictCopyId);
      expect(copy.body, '凭据 local');
      expect(copy.meta, local.meta);
      expect(copy.rev, 1);
    });
  });

  group('行级 diff 底层算子', () {
    test('替换 / 插入 / 删除都能生成 base 坐标上的 hunk', () {
      final base = <String>['A', 'B', 'C'];

      final replacement = diffHunks(base, <String>['A', 'B2', 'C']);
      expect(replacement, hasLength(1));
      expect(replacement.single.baseStart, 1);
      expect(replacement.single.baseEnd, 2);
      expect(replacement.single.replacement, <String>['B2']);

      final insertion = diffHunks(base, <String>['A', 'X', 'B', 'C']);
      expect(insertion, hasLength(1));
      expect(insertion.single.baseStart, 1);
      expect(insertion.single.baseEnd, 1);
      expect(insertion.single.replacement, <String>['X']);

      final deletion = diffHunks(base, <String>['A', 'C']);
      expect(deletion, hasLength(1));
      expect(deletion.single.baseStart, 1);
      expect(deletion.single.baseEnd, 2);
      expect(deletion.single.replacement, isEmpty);
    });

    test('只有一侧编辑时逐字还原该侧，不吞掉 base 行', () {
      final base = <String>['A', 'B', 'C'];
      final changed = <String>['A', 'X', 'B2', 'C'];
      final result = mergeLineHunks(
        base: base,
        local: diffHunks(base, changed),
        remote: const <TextHunk>[],
        localLabel: '设备 A',
        remoteLabel: '设备 B',
      );

      expect(result.hasConflict, isFalse);
      expect(result.lines, changed);
    });

    test('重叠 hunk 输出 git 风格冲突标记且两边内容都留', () {
      final base = <String>['A', 'B', 'C'];
      final result = mergeLineHunks(
        base: base,
        local: diffHunks(base, <String>['A', 'L', 'C']),
        remote: diffHunks(base, <String>['A', 'R', 'C']),
        localLabel: '设备 A',
        remoteLabel: '设备 B',
      );

      expect(result.hasConflict, isTrue);
      expect(result.text, contains('<<<<<<< 本地（设备 A）'));
      expect(result.text, contains('======='));
      expect(result.text, contains('>>>>>>> 云端（设备 B）'));
      expect(result.text, contains('L'));
      expect(result.text, contains('R'));
      expect(result.text, contains('A'));
      expect(result.text, contains('C'));
    });

    test('超过行数上限时拒绝 O(n·m) DP，并由 merge3 降级 LWW 留副本', () {
      final tooMany = List<String>.generate(
        kMaxDiffLines + 1,
        (int index) => 'line $index',
      );
      expect(
        () => diffHunks(tooMany, tooMany),
        throwsA(isA<LineDiffTooLarge>()),
      );

      final baseBody = tooMany.join('\n');
      final localLines = List<String>.of(tooMany)..[0] = 'A 的第 0 行';
      final remoteLines = List<String>.of(tooMany)..[0] = 'B 的第 0 行';
      final result = merge3(
        base: _snapshot(body: baseBody, rev: 2, hlc: _hlc(1000, 'devA')),
        local: _snapshot(
          body: localLines.join('\n'),
          rev: 3,
          hlc: _hlc(1100, 'devA'),
        ),
        remote: _snapshot(
          body: remoteLines.join('\n'),
          rev: 3,
          hlc: _hlc(1200, 'devB'),
        ),
        context: _context(copyId: 'copy-large'),
      );

      expect(result.isConflict, isTrue);
      expect(result.reason, contains('降级 LWW'));
      expect(result.merged.body, contains('B 的第 0 行'));
      expect(result.conflictCopy, isNotNull);
      expect(result.conflictCopy!.body, contains('A 的第 0 行'));
    });
  });
}
