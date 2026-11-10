import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/vault_session.dart';
import 'taxonomy_repository.dart';

/// 回收站 / 历史 / 分类标签的只读仓库。
///
/// 依赖 `vaultDatabaseProvider` 与 `writeGatewayProvider`（后者只用来解
/// 历史信封，不产生任何写）。测试里用 `test/support/test_harness.dart`
/// 一起 override 掉。
final Provider<TaxonomyRepository> taxonomyRepositoryProvider =
    Provider<TaxonomyRepository>((Ref ref) {
  return TaxonomyRepository(
    db: ref.watch(vaultDatabaseProvider),
    gateway: ref.watch(writeGatewayProvider),
  );
});
