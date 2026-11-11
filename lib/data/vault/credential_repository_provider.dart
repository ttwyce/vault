import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import 'credential_repository.dart';

/// 密码健康只读仓库。只返回聚合统计。
final Provider<CredentialRepository> credentialRepositoryProvider =
    Provider<CredentialRepository>((Ref ref) {
  final db = ref.watch(vaultDatabaseProvider);
  return CredentialRepository(db);
});
