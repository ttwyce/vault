import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/chat/conversation_repository.dart';
import 'package:vault/data/chat/conversation_retention.dart';
import 'package:vault/data/db/vault_database.dart';

import 'support/test_harness.dart';

/// docs/09 R15 会话表膨胀判定层测试。
void main() {
  late TestApp app;
  late ConversationRepository repo;

  setUp(() async {
    app = await TestApp.create();
    repo = ConversationRepository(app.db);
  });
  tearDown(() async => app.dispose());

  test('分页计划 clamp 与游标', () {
    expect(MessagePagePlan.latest().limit, kMessagePageSize);
    expect(MessagePagePlan.latest(limit: 0).limit, kMessagePageSize);
    expect(MessagePagePlan.latest(limit: 500).limit, 200);
    final older = MessagePagePlan.latest().older(1000);
    expect(older.beforeMs, 1000);
    expect(older.limit, kMessagePageSize);
  });

  test('90 天内 / 无消息不归档；超期归档只留最近 5 条', () {
    const now = 1731052800000;
    expect(
      planConversationArchive(
        updatedAtMs: now - 10 * 86400000,
        nowMs: now,
        messageCount: 20,
      ).action,
      ConversationArchiveAction.keep,
    );
    expect(
      planConversationArchive(
        updatedAtMs: now - 100 * 86400000,
        nowMs: now,
        messageCount: 0,
      ).action,
      ConversationArchiveAction.keep,
    );
    final archived = planConversationArchive(
      updatedAtMs: now - 100 * 86400000,
      nowMs: now,
      messageCount: 20,
    );
    expect(archived.action, ConversationArchiveAction.archiveToSummary);
    expect(archived.keepRecentMessages, 5);
    expect(
      planConversationArchive(
        updatedAtMs: now - 100 * 86400000,
        nowMs: now,
        messageCount: 3,
      ).keepRecentMessages,
      3,
    );
  });

  test('批量归档按最老优先，且跳过保留期内会话', () {
    const now = 1731052800000;
    final batch = planArchiveBatch(
      <String, int>{
        'fresh': now - 86400000,
        'oldest': now - 200 * 86400000,
        'old': now - 100 * 86400000,
      },
      nowMs: now,
      messageCountById: const <String, int>{'fresh': 2, 'oldest': 4, 'old': 6},
    );
    expect(batch, <String>['oldest', 'old']);
  });

  test('messages(plan) 真实分页：最新一页倒序取回后恢复 append-only 顺序',
      () async {
    await app.db.into(app.db.messages).insert(
          MessagesCompanion.insert(
            id: 'm1',
            conversationId: 'c',
            role: 1,
            content: const Value<String?>('第一条'),
            createdAt: const Value<int?>(1000),
            hlc: '0000000000000001:0000:devA',
          ),
        );
    await app.db.into(app.db.messages).insert(
          MessagesCompanion.insert(
            id: 'm2',
            conversationId: 'c',
            role: 1,
            content: const Value<String?>('第二条'),
            createdAt: const Value<int?>(2000),
            hlc: '0000000000000002:0000:devA',
          ),
        );
    await app.db.into(app.db.messages).insert(
          MessagesCompanion.insert(
            id: 'm3',
            conversationId: 'c',
            role: 1,
            content: const Value<String?>('第三条'),
            createdAt: const Value<int?>(3000),
            hlc: '0000000000000003:0000:devA',
          ),
        );
    final latest = await repo.messages('c', plan: MessagePagePlan.latest(limit: 2));
    expect(latest.map((m) => m.content).toList(), <String>['第二条', '第三条']);
    final older = await repo.messages(
      'c',
      plan: MessagePagePlan.latest(limit: 2).older(2000),
    );
    expect(older.map((m) => m.content).toList(), <String>['第一条']);
    final all = await repo.messages('c');
    expect(all.map((m) => m.content).toList(),
        <String>['第一条', '第二条', '第三条']);
  });
}
