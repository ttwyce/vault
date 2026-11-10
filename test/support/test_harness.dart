import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vault/app/session/vault_session.dart';
import 'package:vault/core/crypto/vault_keys.dart';
import 'package:vault/core/identity/uuid_v7.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/data/activity/activity_logger.dart';
import 'package:vault/data/db/database_key.dart';
import 'package:vault/data/db/database_opener.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/entry/entry_repository.dart';
import 'package:vault/data/entry/entry_repository_provider.dart';
import 'package:vault/data/taxonomy/taxonomy_repository.dart';
import 'package:vault/data/taxonomy/taxonomy_repository_provider.dart';
import 'package:vault/data/write/write_gateway.dart';

/// 页面测试的共享环境。
///
/// ## 为什么要有它
///
/// 页面（记录/日记/编辑器/组织）都要读 `entryRepositoryProvider`、
/// 写 `writeGatewayProvider`。如果每个测试文件各自搭一遍内存库 +
/// 加密 + providers，四份代码迟早漂移，而且某个 agent 改了环境
/// 别人不知道。
///
/// ## 用法
///
/// ```dart
/// late TestApp app;
/// setUp(() async { app = await TestApp.create(); });
/// tearDown(() async { await app.dispose(); });
///
/// await app.gateway.writeEntry(EntryWrite.create(title: 'x'));
/// await tester.pumpWidget(ProviderScope(
///   parent: app.container,          // 关键：把页面挂到真实容器下
///   child: MaterialApp(home: const RecordsPage()),
/// ));
/// ```
///
/// **注意**：测试里 pump 的 `ProviderScope` 必须 `parent: app.container`，
/// 否则页面读不到被 override 的 provider，会读到 `UnimplementedError`。
class TestApp {
  TestApp._({
    required this.container,
    required this.db,
    required this.opener,
    required this.keys,
    required this.clock,
    required this.gateway,
    required this.repo,
    required this.taxonomyRepo,
    required this.activity,
    required this.uuid,
  });

  final ProviderContainer container;
  final VaultDatabase db;
  final VaultDatabaseOpener opener;
  final VaultKeys keys;
  final HlcClock clock;
  final WriteGateway gateway;
  final EntryRepository repo;
  final TaxonomyRepository taxonomyRepo;
  final ActivityLogger activity;
  final UuidV7 uuid;

  /// 造一个内存环境。
  ///
  /// [now] 控制时间（HLC 与 activity 共用）；[seed] 控制随机，
  /// 让"每次生成的 id"在断言里可预期。
  static Future<TestApp> create({int Function()? now, int seed = 1}) async {
    final nowFn = now ?? () => 1731052800000;

    final opener = VaultDatabaseOpener(
      key: DatabaseKey.random(Random(seed)),
      inMemory: true,
    );
    final db = await opener.open();

    final keys = VaultKeys.generate();
    final clock = HlcClock(node: 'test-device', now: nowFn);
    final uuid = UuidV7(random: Random(seed), now: nowFn);

    final gateway = WriteGateway(
      db: db,
      keys: keys,
      clock: clock,
      deviceId: 'test-device',
      now: nowFn,
      uuid: uuid,
    );
    final repo = EntryRepository(db);
    final taxonomyRepo = TaxonomyRepository(db: db, gateway: gateway);
    final activity = ActivityLogger(db: db, deviceId: 'test-device', now: nowFn);

    final container = ProviderContainer(
      overrides: [
        vaultDatabaseProvider.overrideWithValue(db),
        writeGatewayProvider.overrideWithValue(gateway),
        entryRepositoryProvider.overrideWithValue(repo),
        taxonomyRepositoryProvider.overrideWithValue(taxonomyRepo),
        activityLoggerProvider.overrideWithValue(activity),
      ],
    );

    return TestApp._(
      container: container,
      db: db,
      opener: opener,
      keys: keys,
      clock: clock,
      gateway: gateway,
      repo: repo,
      taxonomyRepo: taxonomyRepo,
      activity: activity,
      uuid: uuid,
    );
  }

  /// 释放：**先关库再清密钥**（顺序不能反，见 `VaultSession.lock()` 的注释）。
  Future<void> dispose() async {
    container.dispose();
    await opener.close();
    keys.destroy();
  }
}
