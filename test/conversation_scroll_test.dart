import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/chat/conversation_scroll.dart';

/// docs/12 §5 ③ 会话切换滚动目标测试。
void main() {
  test('草稿 / 无会话 / 空会话回顶部', () {
    expect(
      planConversationScroll(conversationId: null, messageCount: 0).target,
      ConversationScrollTarget.top,
    );
    expect(
      planConversationScroll(
        conversationId: 'c',
        messageCount: 0,
        isDraft: true,
      ).target,
      ConversationScrollTarget.top,
    );
  });

  test('已有会话且有消息 → 定位到最新消息（底部）', () {
    final plan = planConversationScroll(
      conversationId: 'c',
      messageCount: 12,
    );
    expect(plan.goToBottom, isTrue);
    expect(plan.reason, contains('最新'));
    expect(
      scrollOffsetFor(plan, maxExtent: 640, hasMessages: true),
      640.0,
    );
    expect(
      scrollOffsetFor(plan, maxExtent: 0, hasMessages: true),
      0.0,
      reason: '内容未超出视口时不滚动',
    );
  });

  test('hasMessages=false 永远回 0，不沿用旧 offset', () {
    final plan = planConversationScroll(
      conversationId: 'c',
      messageCount: 12,
    );
    expect(
      scrollOffsetFor(plan, maxExtent: 640, hasMessages: false),
      0.0,
    );
  });
}
