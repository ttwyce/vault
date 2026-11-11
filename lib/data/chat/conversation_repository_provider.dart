import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import 'conversation_repository.dart';

/// 会话只读仓库。抽屉 / 设置页从这里读分组。
final Provider<ConversationRepository> conversationRepositoryProvider =
    Provider<ConversationRepository>((Ref ref) {
  final db = ref.watch(vaultDatabaseProvider);
  return ConversationRepository(db);
});
