import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/vault_database.dart';
import '../search/cjk_segmenter.dart';
import 'conversation_models.dart';

/// 会话搜索结果：会话分区 + 消息分区（docs/12 §3）。
class ConversationSearchResult {
  const ConversationSearchResult({
    required this.conversations,
    required this.messages,
  });

  final List<ConversationSummary> conversations;
  final List<ConversationMessageHit> messages;
}

class ConversationMessageHit {
  const ConversationMessageHit({
    required this.conversationId,
    required this.conversationTitle,
    required this.excerpt,
  });

  final String conversationId;
  final String conversationTitle;
  final String excerpt;
}

/// 一条可渲染的会话消息。
class ConversationMessageView {
  const ConversationMessageView({
    required this.role,
    required this.content,
    required this.citations,
  });

  /// 1 user / 2 assistant / 3 tool。
  final int role;
  final String content;
  final List<String> citations;

  bool get isUser => role == 1;
}

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

  /// 会话 FTS 检索（docs/12 §3）：命中会话 + 命中消息两个分区。
  Future<ConversationSearchResult> search(String rawQuery) async {
    final match = CjkSegmenter.matchQuery(rawQuery);
    if (!CjkSegmenter.isSearchable(rawQuery)) {
      return const ConversationSearchResult(
        conversations: <ConversationSummary>[],
        messages: <ConversationMessageHit>[],
      );
    }
    final ids = await db.searchConversationIds(match);
    final all = await list(limit: 500);
    final byId = <String, ConversationSummary>{
      for (final item in all) item.id: item,
    };
    final conversations = <ConversationSummary>[
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
    final hits = <ConversationMessageHit>[];
    for (final id in ids) {
      for (final message in await messages(id)) {
        if (message.content.contains(rawQuery.trim())) {
          hits.add(ConversationMessageHit(
            conversationId: id,
            conversationTitle: byId[id]?.title ?? id,
            excerpt: message.content,
          ));
        }
      }
    }
    return ConversationSearchResult(
      conversations: List<ConversationSummary>.unmodifiable(conversations),
      messages: List<ConversationMessageHit>.unmodifiable(hits),
    );
  }

  /// 按 docs/12 §5 ④ 分好组直接给抽屉渲染。
  Future<List<ConversationGroup>> groups({
    required int nowMs,
    int limit = 200,
  }) async {
    final items = await list(limit: limit);
    return groupConversations(items, nowMs: nowMs);
  }

  /// 读取某会话的消息（append-only 顺序）。
  Future<List<ConversationMessageView>> messages(String conversationId) async {
    final rows = await (db.select(db.messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy(<OrderClauseGenerator<dynamic>>[
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.hlc),
          ]))
        .get();
    return <ConversationMessageView>[
      for (final row in rows)
        ConversationMessageView(
          role: row.role,
          content: row.content ?? '',
          citations: _decodeCitations(row.citations),
        ),
    ];
  }

  static List<String> _decodeCitations(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded.map((Object? v) => v.toString()).toList();
    } on FormatException {
      return const <String>[];
    }
  }
}
