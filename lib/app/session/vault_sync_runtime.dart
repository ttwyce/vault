/// 真实运行时的同步装配门面（不新增依赖、不改 `pubspec.yaml`）。
///
/// 把四个已各自验证过的真实组件接成一条完整链路：
/// `VaultDatabase` + `WriteGateway` → `DbSyncWorkspaceStore`（正文）/ 
/// `DbEntitySyncPort`（taxonomy / 保留策略）→ `SyncEngine` /
/// `EntitySyncEngine` → `SyncCoordinator` → `HttpClientWebDavBackend`。
///
/// **刻意不接 App 启动装配**：构造它需要 WebDAV 地址与凭据，而 M0 A5
/// （坚果云 / Nextcloud 真实行为）尚未确认。这个类只提供「配置就绪后
/// 一行调用」的落点，由设置页 / 未来的依赖注入层决定何时实例化。
library;

import '../../data/db/vault_database.dart';
import '../../data/sync/db_entity_sync_port.dart';
import '../../data/sync/sync_workspace_store.dart';
import '../../data/write/write_gateway.dart';
import '../../core/crypto/vault_keys.dart';
import '../../core/identity/uuid_v7.dart';
import '../../core/sync/encrypted_sync_codec.dart';
import '../../core/sync/hlc.dart';
import '../../core/sync/http_webdav_backend.dart';
import '../../core/sync/sync_coordinator.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/entity_sync_engine.dart';
import '../../core/sync/webdav_backend.dart';

/// 装配一个完整同步运行时所需的全部真实依赖。
class VaultSyncRuntime {
  VaultSyncRuntime._({
    required this.backend,
    required this.coordinator,
    required this.workspaceStore,
    required this.entityPort,
    required this.codec,
  });

  /// 真实 HTTP 后端。调用方负责在不再使用时 `dispose()`。
  final HttpClientWebDavBackend backend;

  final SyncCoordinator coordinator;
  final DbSyncWorkspaceStore workspaceStore;
  final DbEntitySyncPort entityPort;
  final EncryptedSyncPayloadCodec codec;

  /// 从已解锁的本地库 + WebDAV 配置装配整套同步链路。
  factory VaultSyncRuntime.create({
    required VaultDatabase db,
    required WriteGateway gateway,
    required VaultKeys keys,
    required HlcClock clock,
    required UuidV7 uuid,
    required String deviceId,
    required String vaultId,
    required String webDavRootUrl,
    String? username,
    String? password,
    int schema = 1,
    int Function()? now,
    int budgetLimit = 200,
  }) {
    final nowFn = now ?? (() => DateTime.now().millisecondsSinceEpoch);
    final codec = EncryptedSyncPayloadCodec(keys);
    final backend = HttpClientWebDavBackend(
      HttpWebDavConfig(
        rootUrl: webDavRootUrl,
        username: username,
        password: password,
      ),
    );
    final workspaceStore = DbSyncWorkspaceStore(
      db: db,
      gateway: gateway,
      codec: codec,
      clock: clock,
      uuid: uuid,
      deviceId: deviceId,
      vaultId: vaultId,
      schema: schema,
      now: nowFn,
    );
    final entityPort = DbEntitySyncPort(
      db: db,
      gateway: gateway,
      codec: codec,
    );
    final WebDavBackend sharedBackend = backend;
    final coordinator = SyncCoordinator(
      entryEngine: SyncEngine(
        backend: sharedBackend,
        codec: codec,
        budgetLimit: budgetLimit,
      ),
      entityEngine: EntitySyncEngine(
        backend: sharedBackend,
        codec: codec,
        port: entityPort,
      ),
      purgeRunner: entityPort,
      tombstoneLister: entityPort,
      backend: sharedBackend,
      workspaceLoader: () => workspaceStore.load(),
      commitEntryRun: (SyncRunResult result) => workspaceStore.commit(result),
      commitQuarantine: (Map<String, List<int>> payloads) =>
          gateway.quarantineOnly(payloads),
      syncState: () => entityPort.syncState(),
      now: nowFn,
    );
    return VaultSyncRuntime._(
      backend: backend,
      coordinator: coordinator,
      workspaceStore: workspaceStore,
      entityPort: entityPort,
      codec: codec,
    );
  }

  /// 跑一轮完整同步：正文 → taxonomy → 本地清理 → 云端墓碑 TTL。
  /// 顶层单飞锁忙时返回 `null`（本轮跳过，不排队）。
  Future<SyncRunReport?> sync({String trigger = 'runtime'}) =>
      coordinator.run(trigger: trigger);

  void dispose() => backend.close();
}
