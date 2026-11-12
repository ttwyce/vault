import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('切换会话后主区消息滚动复位到顶部', (WidgetTester tester) async {
    // 造两个会话，第二个带更多消息。
    for (final id in <String>['conv-a', 'conv-b']) {
      await app.db.into(app.db.conversations).insert(
            ConversationsCompanion.insert(
              id: id,
              hlc: '0000000000000001:0000:devA',
              title: Value<String?>(id),
              createdAt: const Value<int?>(1731052800000),
              updatedAt: const Value<int?>(1731052800000),
            ),
          );
    }
    for (var i = 0; i < 40; i++) {
      await app.db.into(app.db.messages).insert(
            MessagesCompanion.insert(
              id: 'm$i',
              conversationId: 'conv-a',
              role: 1,
              content: Value<String?>('消息 $i'),
              createdAt: Value<int?>(1731052800000 + i),
              hlc: '0000000000000001:0000:devA',
            ),
          );
    }
    await pumpChat(tester);

    // 打开抽屉选中 conv-a，滚动主区 ListView 到中段。
    await tester.tap(find.byTooltip('对话列表'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('conv-a').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).last);
    final controller = scrollable.widget.controller ??
        PrimaryScrollController.of(scrollable.context);
    controller.jumpTo(200);
    await tester.pump();
    expect(controller.offset, greaterThan(0));

    // 切换到 conv-b，滚动位置必须归零。
    await tester.tap(find.byTooltip('对话列表'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('conv-b').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.offset, 0.0);
  });

  testWidgets('抽屉键盘导航：Esc 清空搜索、↓ 选中后 Enter 打开会话',
      (WidgetTester tester) async {
    final conv = await app.db.into(app.db.conversations).insertReturning(
          ConversationsCompanion.insert(
            id: 'kb-conv',
            hlc: '0000000000000001:0000:devA',
            title: const Value<String?>('键盘会话'),
            createdAt: const Value<int?>(1731052800000),
            updatedAt: const Value<int?>(1731052800000),
          ),
        );
    await app.db.into(app.db.messages).insert(
          MessagesCompanion.insert(
            id: 'kb-msg',
            conversationId: conv.id,
            role: 1,
            content: const Value<String?>('键盘正文'),
            createdAt: const Value<int?>(1731052800001),
            hlc: '0000000000000001:0000:devA',
          ),
        );
    await pumpChat(tester);
    await tester.tap(find.byTooltip('对话列表'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final search = find.byType(TextField).last;
    await tester.enterText(search, '键盘');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<TextField>(search).controller?.text,
      isEmpty,
    );

    // ↓ 选中第一条可见会话，Enter 打开并收起抽屉。
    await tester.tap(search);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ConversationDrawer), findsNothing);
  });
}
