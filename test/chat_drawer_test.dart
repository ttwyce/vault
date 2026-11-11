import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/search/cjk_segmenter.dart';
import 'package:vault/features/chat/chat_page.dart';
import 'package:vault/features/chat/widgets/conversation_drawer.dart';

import 'support/test_harness.dart';

/// docs/12 对话抽屉接线测试。
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 1400,
            child: ChatPage(),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('三横杠打开抽屉，主区仍在，关闭后抽屉消失',
      (WidgetTester tester) async {
    await pumpChat(tester);
    expect(find.byType(ConversationDrawer), findsNothing);

    await tester.tap(find.byTooltip('对话列表'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ConversationDrawer), findsOneWidget);
    expect(find.text('对话'), findsOneWidget);
    expect(find.text('还没有对话'), findsOneWidget);
    expect(find.text('聊天'), findsOneWidget, reason: '主区不重排、仍渲染');

    await tester.tap(find.text('收起抽屉'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ConversationDrawer), findsNothing);
  });

  testWidgets('点「新对话」进入草稿态且不产生会话记录',
      (WidgetTester tester) async {
    await pumpChat(tester);
    await tester.tap(find.text('开启新对话'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ConversationDrawer), findsNothing);
    expect(await app.db.select(app.db.conversations).get(), isEmpty,
        reason: 'T26：草稿态首条消息前不落库');
  });

  testWidgets('抽屉里真实会话可选中并收起', (WidgetTester tester) async {
    await app.db.into(app.db.conversations).insert(
          ConversationsCompanion.insert(
            id: 'conv-1',
            hlc: '0000000000000001:0000:devA',
            title: const Value<String?>('WebDAV 项目'),
            createdAt: const Value<int?>(1731052800000),
            updatedAt: const Value<int?>(1731052800000),
          ),
        );
    await pumpChat(tester);
    await tester.tap(find.byTooltip('对话列表'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('WebDAV 项目'), findsOneWidget);
    await tester.tap(find.text('WebDAV 项目'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ConversationDrawer), findsNothing);
  });

  testWidgets('抽屉搜索显示消息分区并可点开会话',
      (WidgetTester tester) async {
    await app.db.into(app.db.conversations).insert(
          ConversationsCompanion.insert(
            id: 'conv-search',
            hlc: '0000000000000001:0000:devA',
            title: const Value<String?>('WebDAV 项目'),
            createdAt: const Value<int?>(1731052800000),
            updatedAt: const Value<int?>(1731052800000),
          ),
        );
    await app.db.into(app.db.messages).insert(
          MessagesCompanion.insert(
            id: 'msg-1',
            conversationId: 'conv-search',
            role: 1,
            content: const Value<String?>('整理增量同步的限流策略'),
            createdAt: const Value<int?>(1731052800000),
            hlc: '0000000000000001:0000:devA',
          ),
        );
    await app.db.indexConversation(
      conversationId: 'conv-search',
      title: 'WebDAV 项目',
      body: CjkSegmenter.indexText('整理增量同步的限流策略'),
    );

    await pumpChat(tester);
    await tester.tap(find.byTooltip('对话列表'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField).last, '限流');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final direct = await app.db.searchConversationIds(
      CjkSegmenter.matchQuery('限流'),
    );
    expect(direct, isNotEmpty, reason: 'FTS 应命中');
    expect(find.text('消息'), findsOneWidget);
    expect(find.textContaining('限流策略'), findsOneWidget);
  });
}
