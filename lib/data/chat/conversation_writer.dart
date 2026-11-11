import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/identity/uuid_v7.dart';
import '../../core/sync/hlc.dart';
import '../db/vault_database.dart';
import 'conversation_models.dart';

/// 会话消息的写入口（docs/12 §6 / T25 / T26）。
///
/// **append-only**：只 INSERT，不 UPDATE / DELETE 已有消息。草稿态会话在
/// 第一条用户消息到达时才创建 conversation（不产生空记录）。
class ConversationWriter {
  ConversationWriter({
    required this.db,
    required this.clock,
    required this.uuid,
    required this.deviceId,
    int Function()? now,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final VaultDatabase db;

  /// 会话 / 消息目前不参与同步。将来接会话同步通道时，写入必须扩展
  /// `WriteGateway` 的会话分支，不能在这里偷偷绕过唯一写入口。
  final HlcClock clock;
  final UuidV7 uuid;
  final String deviceId;
  final int Function() _now;

  /// 追加一条消息。返回实际落库后的会话 id。
  ///
  /// [draft] 处于草稿态且 [role] 是用户消息时，先创建 conversation 再写消息，
  /// 两步在同一事务里；重复调用（已落库）不会重复创建。
  Future<ConversationDraftState> append({
    required ConversationDraftState draft,
    required int role,
    required String content,
    String? conversationId,
    List<String> citations = const <String>[],
  }) async {
    final nowMs = _now();
    final hlc = clock.tick().encode();
    final messageId = uuid.next();
    final targetId = draft.currentId ?? conversationId ?? uuid.next();
    final needsCreate = draft.hasDraft || draft.currentId == null;

    await db.transaction(() async {
      if (needsCreate) {
        await db.into(db.conversations).insertOnConflictUpdate(
              ConversationsCompanion.insert(
                id: targetId,
                hlc: hlc,
                title: Value<String?>(deriveConversationTitle(null, content)),
                createdAt: Value<int?>(nowMs),
                updatedAt: Value<int?>(nowMs),
                messageCount: const Value<int>(1),
              ),
            );
      } else {
        final existing = await (db.select(db.conversations)
              ..where((t) => t.id.equals(targetId)))
            .getSingleOrNull();
        if (existing == null) {
          throw StateError('会话 $targetId 不存在，无法追加消息');
        }
        await (db.update(db.conversations)
              ..where((t) => t.id.equals(targetId)))
            .write(ConversationsCompanion(
          updatedAt: Value<int?>(nowMs),
          messageCount: Value<int>(existing.messageCount + 1),
        ));
      }
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: messageId,
              conversationId: targetId,
              role: role,
              content: Value<String?>(content),
              citations: Value<String?>(jsonEncode(citations)),
              createdAt: Value<int?>(nowMs),
              hlc: hlc,
            ),
          );
    });

    return ConversationDraftState(
      hasDraft: false,
      currentId: targetId,
      persisted: true,
    );
  }
}
