import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/chat/conversation_keyboard_nav.dart';

/// docs/12 §3.3 对话抽屉键盘导航测试。
void main() {
  const ids = <String>['a', 'b', 'c'];

  test('↓ 循环下移、↑ 到末尾循环；空列表不越界', () {
    var state = ConversationNavState.initial;
    final down = applyConversationNavKey(
      state, ConversationNavKey.down,
      candidateIds: ids, query: '同步',
    );
    expect(down.state.selectedIndex, 0);
    expect(down.state.query, '同步');
    final up = applyConversationNavKey(
      ConversationNavState.initial,
      ConversationNavKey.up,
      candidateIds: ids,
      query: '',
    );
    expect(up.state.selectedIndex, 2);
    final empty = applyConversationNavKey(
      ConversationNavState.initial,
      ConversationNavKey.down,
      candidateIds: const <String>[],
      query: '',
    );
    expect(empty.state.selectedIndex, -1);
    expect(empty.handled, isTrue);
  });

  test('Enter 打开当前项；未选中不打开', () {
    final open = applyConversationNavKey(
      const ConversationNavState(selectedIndex: 1, query: 'x'),
      ConversationNavKey.enter,
      candidateIds: ids,
      query: 'x',
    );
    expect(open.openId, 'b');
    expect(open.handled, isTrue);
    final none = applyConversationNavKey(
      ConversationNavState.initial,
      ConversationNavKey.enter,
      candidateIds: ids,
      query: '',
    );
    expect(none.openId, isNull);
    expect(none.handled, isFalse);
  });

  test('Esc 清空搜索与选择；other 不处理', () {
    final esc = applyConversationNavKey(
      const ConversationNavState(selectedIndex: 2, query: '旧词'),
      ConversationNavKey.escape,
      candidateIds: ids,
      query: '旧词',
    );
    expect(esc.state.query, isEmpty);
    expect(esc.state.selectedIndex, -1);
    expect(esc.handled, isTrue);
    final other = applyConversationNavKey(
      ConversationNavState.initial,
      ConversationNavKey.other,
      candidateIds: ids,
      query: '',
    );
    expect(other.handled, isFalse);
  });
}
