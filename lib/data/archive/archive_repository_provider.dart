import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import 'archive_repository.dart';

/// 归档只读仓库。测试里用 `TestApp` 的容器 override。
final Provider<ArchiveRepository> archiveRepositoryProvider =
    Provider<ArchiveRepository>((Ref ref) {
  final db = ref.watch(vaultDatabaseProvider);
  return ArchiveRepository(db);
});
