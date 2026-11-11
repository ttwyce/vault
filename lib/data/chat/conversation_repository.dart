import 'package:drift/drift.dart';

import '../db/vault_database.dart';
import 'conversation_models.dart';

/// 会话只读仓库。把 `conversation` 表行转成 [ConversationSummary]，
/// 供抽屉分组与草稿态逻辑消费。写操作仍走 `WriteGateway`。
class ConversationRepository {
  ConversationRepository(this.db);

  final VaultDatabase db;

  Future<List<ConversationSummary>> list({int limit = 200}) async {
    final rows = await (db.select(db.conversations)
          ..where((t) => t.deleted.equals(0))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.desc(t.updatedAt),
          ])
          ..limit(limit))
        .get();
    return <ConversationSummary>[
      for (final row in rows)
        ConversationSummary(
          id: row.id,
          title: row.title,
          updatedAt: row.updatedAt ?? row.createdAt ?? 0,
          groupId: row.groupId,
          messageCount: row.messageCount,
        ),
    ];
  }

  /// 按 docs/12 §5 ④ 分好组直接给抽屉渲染。
  Future<List<ConversationGroup>> groups({
    required int nowMs,
    int limit = 200,
  }) async {
    final items = await list(limit: limit);
    return groupConversations(items, nowMs: nowMs);
  }
}
