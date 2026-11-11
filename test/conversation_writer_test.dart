import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/identity/uuid_v7.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/data/chat/conversation_models.dart';
import 'package:vault/data/chat/conversation_repository.dart';
import 'package:vault/data/chat/conversation_writer.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/features/chat/chat_page.dart';
import 'package:vault/data/vault/credential_repository.dart';

import 'support/test_harness.dart';

/// T25 / T26：消息 append-only、草稿首条消息才落库。
void main() {
  late TestApp app;
  late ConversationWriter writer;
  late ConversationRepository repo;

  setUp(() async {
    app = await TestApp.create(now: () => 1731052800000);
    writer = ConversationWriter(
      db: app.db,
      clock: HlcClock(node: 'devA', now: () => 1731052800000),
      uuid: UuidV7(random: Random(301), now: () => 1731052800000),
      deviceId: 'devA',
      now: () => 1731052800000,
    );
    repo = ConversationRepository(app.db);
  });
  tearDown(() async => app.dispose());

  test('草稿态不发消息不落库；首条消息创建会话', () async {
    final draft = ConversationDraftState.initial.startDraft();
    expect(await app.db.select(app.db.conversations).get(), isEmpty);
    final state = await writer.append(
      draft: draft,
      role: 1,
      content: '把 RFC 6578 收进来',
    );
    expect(state.persisted, isTrue);
    final rows = await app.db.select(app.db.conversations).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, '把 RFC 6578 收进来');
    expect(rows.single.messageCount, 1);
  });

  test('T25 append-only：消息只追加不改写，顺序稳定', () async {
    var state = await writer.append(
      draft: ConversationDraftState.initial.startDraft(),
      role: 1,
      content: '第一条',
    );
    state = await writer.append(
      draft: state,
      role: 2,
      content: '第二条',
    );
    final messages = await repo.messages(state.currentId!);
    expect(messages.map((ConversationMessageView m) => m.content).toList(),
        <String>['第一条', '第二条']);
    expect(messages.first.isUser, isTrue);
    expect(messages.last.isUser, isFalse);
    expect(
      await app.db.select(app.db.messages).get(),
      hasLength(2),
    );
  });

  test('草稿切走直接丢弃，不产生空会话', () async {
    final discarded = ConversationDraftState.initial
        .startDraft()
        .discardDraft();
    expect(discarded.persisted, isFalse);
    expect(await app.db.select(app.db.conversations).get(), isEmpty);
  });

  testWidgets('聊天页发送按钮把消息写进真实表',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: Scaffold(body: ChatPage())),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.text('开启新对话'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byType(TextField).last,
      '测试第一条消息',
    );
    await tester.tap(find.text('发送'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final conversations = await app.db.select(app.db.conversations).get();
    expect(conversations, hasLength(1));
    final messages = await app.db.select(app.db.messages).get();
    expect(messages, hasLength(1));
    expect(messages.single.content, '测试第一条消息');
    expect(find.text('测试第一条消息'), findsOneWidget);
  });

  testWidgets('聊天框夹带已存密码明文时拒绝发送，正常消息仍可发',
      (WidgetTester tester) async {
    final repo = CredentialRepository(app.db, app.gateway);
    await app.db.into(app.db.credentials).insert(
          CredentialsCompanion.insert(id: 'cred-guard'),
        );
    await repo.setPassword('cred-guard', 'UniquePass!2026');

    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: app.container,
      child: const MaterialApp(home: Scaffold(body: ChatPage())),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.enterText(
      find.byType(TextField).last,
      '我的密码是 UniquePass!2026 请记住',
    );
    await tester.tap(find.text('发送'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('已阻止发送'), findsOneWidget);
    expect(await app.db.select(app.db.messages).get(), isEmpty);

    // 等 SnackBar 退场，避免它改变 widget 树导致 tap 落到别处。
    await tester.pump(const Duration(seconds: 2));
    await tester.enterText(
      find.byType(TextField).last,
      '今天整理同步笔记',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await app.db.select(app.db.messages).get(), hasLength(1));
  });

  test('会话 FTS：中文消息可搜到，且分会话/消息两区', () async {
    var state = await writer.append(
      draft: ConversationDraftState.initial.startDraft(),
      role: 1,
      content: '把增量同步的限流策略整理一下',
    );
    state = await writer.append(
      draft: state,
      role: 2,
      content: '已经记录了退避的三档策略',
    );
    await writer.append(
      draft: ConversationDraftState.initial.startDraft(),
      role: 1,
      content: '今天天气不错',
    );

    final result = await ConversationRepository(app.db).search('限流');
    expect(result.conversations, hasLength(1));
    expect(result.conversations.single.id, state.currentId);
    expect(result.messages, hasLength(1));
    expect(result.messages.single.excerpt, contains('限流'));

    expect(
      (await ConversationRepository(app.db).search('天气'))
          .conversations,
      hasLength(1),
    );
    expect(
      (await ConversationRepository(app.db).search('不存在的词'))
          .conversations,
      isEmpty,
    );
  });
}
