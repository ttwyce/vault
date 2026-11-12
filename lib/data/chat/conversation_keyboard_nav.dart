/// 对话抽屉键盘导航（docs/12 §3.3「↑↓ 选择、↵ 打开、Esc 清空」）。
///
/// 不碰焦点、不渲染：只把当前选中下标 / 候选会话 id 列表 / 按键
/// 映射成下一步状态，便于 widget 直接接 `Focus.onKeyEvent`。
library;

enum ConversationNavKey { up, down, enter, escape, other }

class ConversationNavState {
  const ConversationNavState({
    required this.selectedIndex,
    required this.query,
  });

  /// -1 表示没有选中项。
  final int selectedIndex;
  final String query;

  static const ConversationNavState initial = ConversationNavState(
    selectedIndex: -1,
    query: '',
  );
}

class ConversationNavResult {
  const ConversationNavResult({
    required this.state,
    required this.openId,
    required this.handled,
  });

  final ConversationNavState state;
  final String? openId;
  final bool handled;
}

/// [candidateIds] 是当前可见列表（分组顺序）的会话 id。
ConversationNavResult applyConversationNavKey(
  ConversationNavState state,
  ConversationNavKey key, {
  required List<String> candidateIds,
  required String query,
}) {
  switch (key) {
    case ConversationNavKey.escape:
      return const ConversationNavResult(
        state: ConversationNavState(selectedIndex: -1, query: ''),
        openId: null,
        handled: true,
      );
    case ConversationNavKey.up:
    case ConversationNavKey.down:
      if (candidateIds.isEmpty) {
        return ConversationNavResult(
          state: state,
          openId: null,
          handled: true,
        );
      }
      final next = key == ConversationNavKey.down
          ? (state.selectedIndex + 1) % candidateIds.length
          : state.selectedIndex <= 0
              ? candidateIds.length - 1
              : state.selectedIndex - 1;
      return ConversationNavResult(
        state: ConversationNavState(selectedIndex: next, query: query),
        openId: null,
        handled: true,
      );
    case ConversationNavKey.enter:
      final index = state.selectedIndex;
      if (index < 0 || index >= candidateIds.length) {
        return ConversationNavResult(
          state: state,
          openId: null,
          handled: false,
        );
      }
      return ConversationNavResult(
        state: state,
        openId: candidateIds[index],
        handled: true,
      );
    case ConversationNavKey.other:
      return ConversationNavResult(
        state: state,
        openId: null,
        handled: false,
      );
  }
}
