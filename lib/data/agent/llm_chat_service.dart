/// 真实 LLM 回答落进会话的编排（docs/07 §7 / §9）。
///
/// 不碰 Key 存储：调用方传入 [HttpLlmClient]、endpoint 与 apiKey；
/// 流式文本先过 [enforceOutputConstraints]（不编造引用 / 不泄密 /
/// 长度与 token 预算），再经 [ConversationWriter] append-only 落助手消息。
library;

import '../../core/identity/uuid_v7.dart';
import '../../core/sync/hlc.dart';
import '../db/vault_database.dart';
import '../chat/conversation_models.dart';
import '../chat/conversation_writer.dart';
import 'http_llm_client.dart';
import 'openai_compat.dart';
import 'system_prompt.dart';

class LlmChatReply {
  const LlmChatReply({
    required this.text,
    required this.draft,
    required this.log,
    required this.error,
    required this.removedCitations,
    required this.redactedSecrets,
  });

  final String text;
  final ConversationDraftState draft;
  final Map<String, Object?> log;
  final String? error;
  final List<String> removedCitations;
  final bool redactedSecrets;

  bool get ok => error == null;
}

/// 运行期 LLM 配置（Key 由安全存储/调用方注入，绝不写进 settings.json）。
class LlmRuntime {
  const LlmRuntime({
    required this.endpoint,
    required this.apiKey,
    required this.client,
  });

  final LlmEndpoint endpoint;
  final String apiKey;
  final HttpLlmClient client;
}

class LlmChatService {
  const LlmChatService({
    required this.db,
    required this.writer,
    required this.client,
  });

  final VaultDatabase db;
  final ConversationWriter writer;
  final HttpLlmClient client;

  Future<LlmChatReply> generateAndAppend({
    required LlmEndpoint endpoint,
    required String apiKey,
    required List<LlmMessage> messages,
    required ConversationDraftState draft,
    Set<String> existingEntryIds = const <String>{},
    Iterable<String> knownSecrets = const <String>[],
  }) async {
    final result = await client.streamChat(
      endpoint: endpoint,
      messages: messages,
      apiKey: apiKey,
    );
    if (!result.ok) {
      return LlmChatReply(
        text: '',
        draft: draft,
        log: result.log,
        error: result.error,
        removedCitations: const <String>[],
        redactedSecrets: false,
      );
    }
    final guard = enforceOutputConstraints(
      result.text,
      existingEntryIds: existingEntryIds,
      knownSecrets: knownSecrets,
    );
    if (guard.text.trim().isEmpty) {
      return LlmChatReply(
        text: '',
        draft: draft,
        log: result.log,
        error: '模型输出为空或全部被安全约束过滤',
        removedCitations: guard.removedCitations,
        redactedSecrets: guard.redactedSecrets,
      );
    }
    final next = await writer.append(
      draft: draft,
      role: 2,
      content: guard.text,
    );
    return LlmChatReply(
      text: guard.text,
      draft: next,
      log: result.log,
      error: null,
      removedCitations: guard.removedCitations,
      redactedSecrets: guard.redactedSecrets,
    );
  }
}

/// 便于调用方构造默认 writer（HLC / UUID 与聊天页一致）。
ConversationWriter buildConversationWriter(VaultDatabase db) =>
    ConversationWriter(
      db: db,
      clock: HlcClock(
        node: 'devA',
        now: () => DateTime.now().millisecondsSinceEpoch,
      ),
      uuid: UuidV7(),
      deviceId: 'devA',
    );
