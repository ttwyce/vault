import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import 'entry_repository.dart';

/// 条目只读仓库。
///
/// 依赖 `vaultDatabaseProvider`（会话解锁后才可用）。
/// 正常路径下只有主界面能读到它；测试里用 `test/support/test_harness.dart`
/// 直接 override 成内存库。
final Provider<EntryRepository> entryRepositoryProvider =
    Provider<EntryRepository>((Ref ref) {
  final db = ref.watch(vaultDatabaseProvider);
  return EntryRepository(db);
});
