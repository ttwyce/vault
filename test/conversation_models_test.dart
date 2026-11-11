import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/chat/conversation_models.dart';

/// docs/12 §3 / §5 与 T25 / T26 的会话纯判定层测试。
const int _day = 86400000;
const int _now = 1731052800000;

ConversationSummary _conv(
  String id,
  int updatedAt, {
  String? groupId,
  String? groupName,
  String? title,
}) =>
    ConversationSummary(
      id: id,
      title: title,
      updatedAt: updatedAt,
      groupId: groupId,
      groupName: groupName,
    );

void main() {
  group('会话分组（docs/12 §5 ④）', () {
    test('日期分四组，未来时间不落到更早', () {
      expect(sectionFor(_now, _now), ConversationSection.today);
      expect(sectionFor(_now + 1000, _now), ConversationSection.today);
      expect(sectionFor(_now - _day - 1, _now),
          ConversationSection.yesterday);
      expect(sectionFor(_now - 3 * _day, _now),
          ConversationSection.thisWeek);
      expect(sectionFor(_now - 30 * _day, _now),
          ConversationSection.earlier);
    });

    test('用户分组优先，且不再出现在日期分组里', () {
      final groups = groupConversations(
        <ConversationSummary>[
          _conv('a', _now, groupId: 'g1', groupName: 'WebDAV 项目'),
          _conv('b', _now - 1000),
          _conv('c', _now - 2 * _day),
        ],
        nowMs: _now,
      );
      expect(groups.first.key, 'group:g1');
      expect(groups.first.label, 'WebDAV 项目');
      expect(groups.first.conversations.single.id, 'a');
      final dateKeys = groups.skip(1).map((ConversationGroup g) => g.key);
      expect(dateKeys, <String>[
        'date:today',
        'date:thisWeek',
      ]);
      expect(
        groups.expand((ConversationGroup g) => g.conversations),
        isNot(contains(_conv('a', _now))),
      );
    });

    test('组内按 updatedAt 倒序，空分组不输出', () {
      final groups = groupConversations(
        <ConversationSummary>[
          _conv('old', _now - 1000),
          _conv('new', _now),
        ],
        nowMs: _now,
      );
      expect(groups, hasLength(1));
      expect(groups.single.conversations.map(
        (ConversationSummary c) => c.id,
      ).toList(), <String>['new', 'old']);
    });
  });

  group('T26 草稿态（docs/12 §5 ②）', () {
    test('点新对话不落库；切走直接丢弃', () {
      final draft = ConversationDraftState.initial.startDraft();
      expect(draft.hasDraft, isTrue);
      expect(draft.persisted, isFalse);
      expect(draft.currentId, isNull);
      final discarded = draft.discardDraft();
      expect(discarded.hasDraft, isFalse);
      expect(discarded.persisted, isFalse);
    });

    test('发出第一条消息才落库，重复提交幂等', () {
      final draft = ConversationDraftState.initial.startDraft();
      final committed = draft.commitFirstMessage('conv-1');
      expect(committed.persisted, isTrue);
      expect(committed.currentId, 'conv-1');
      expect(committed.hasDraft, isFalse);
      expect(committed.commitFirstMessage('conv-2').currentId, 'conv-1');
    });

    test('非草稿态不会凭空创建会话', () {
      final selected =
          ConversationDraftState.initial.selectExisting('conv-9');
      expect(selected.commitFirstMessage('conv-x').currentId, 'conv-9');
      expect(selected.persisted, isTrue);
    });
  });

  group('T25 消息 append-only', () {
    test('按 createdAt / hlc / id 稳定排序，同毫秒不乱序', () {
      final ordered = orderMessages(<ConversationMessage>[
        const ConversationMessage(
            id: 'm2', createdAt: 1000, hlc: '...:0001:devA'),
        const ConversationMessage(
            id: 'm1', createdAt: 1000, hlc: '...:0000:devA'),
        const ConversationMessage(
            id: 'm3', createdAt: 2000, hlc: '...:0000:devA'),
      ]);
      expect(ordered.map((ConversationMessage m) => m.id).toList(),
          <String>['m1', 'm2', 'm3']);
      expect(() => ordered.add(const ConversationMessage(
            id: 'x', createdAt: 1, hlc: '')), throwsUnsupportedError,
          reason: '返回不可变列表，调用方不能就地改写历史');
    });
  });

  group('标题兜底', () {
    test('有标题用标题；无标题取首条消息前 20 字；空消息给新对话', () {
      expect(deriveConversationTitle('  我的会话  ', '正文'), '我的会话');
      expect(deriveConversationTitle(null, '短问题'), '短问题');
      expect(deriveConversationTitle(null, 'x' * 30), '${'x' * 20}…');
      expect(deriveConversationTitle(null, null), '新对话');
      expect(deriveConversationTitle('  ', '  '), '新对话');
    });
  });
}
