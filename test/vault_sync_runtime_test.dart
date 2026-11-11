import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/vault_sync_runtime.dart';
import 'package:vault/core/crypto/vault_keys.dart';
import 'package:vault/core/identity/uuid_v7.dart';
import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/device_watermark.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/core/sync/sync_payloads.dart';
import 'package:vault/data/db/database_key.dart';
import 'package:vault/data/db/database_opener.dart';
import 'package:vault/data/db/vault_database.dart';
import 'package:vault/data/write/write_gateway.dart';

/// 装配门面的端到端测试：真实内存加密库 + 真实 `HttpClientWebDavBackend`
/// + 本地 HttpServer。验证「配置就绪后一行 `sync()` 就能跑完整链路」。
/// **不接 App 启动装配**（那需要 M0 A5 与账号配置），这里只测装配本身。
class _TinyDav {
  _TinyDav(this.server);

  final HttpServer server;
  final Map<String, List<int>> files = <String, List<int>>{};
  final Map<String, String> etags = <String, String>{};
  int _etag = 10;

  static Future<_TinyDav> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dav = _TinyDav(server);
    server.listen((HttpRequest r) async {
      await dav._handle(r);
    });
    return dav;
  }

  String get rootUrl => 'http://127.0.0.1:${server.port}';

  Future<void> close() => server.close(force: true);

  Future<void> _handle(HttpRequest r) async {
    final path = r.uri.path;
    final res = r.response;
    res.headers.set('DAV', '1');
    switch (r.method) {
      case 'OPTIONS':
        res.headers.set('Allow', 'PROPFIND, REPORT, GET, PUT, DELETE, MKCOL');
        await res.close();
      case 'GET':
        if (!files.containsKey(path)) {
          res.statusCode = 404;
        } else {
          res.headers.set('ETag', etags[path]!);
          res.add(files[path]!);
        }
        await res.close();
      case 'PUT':
        final body = await r.fold<List<int>>(
          <int>[],
          (List<int> p, List<int> c) => <int>[...p, ...c],
        );
        final tag = '"e${_etag++}"';
        files[path] = body;
        etags[path] = tag;
        res.statusCode = 201;
        res.headers.set('ETag', tag);
        await res.close();
      case 'PROPFIND':
        await r.drain<void>();
        res.statusCode = 207;
        final xml = StringBuffer(
            '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">');
        for (final entry in files.entries) {
          if (!entry.key.startsWith('$path/')) continue;
          xml.write('<d:response><d:href>${Uri.encodeComponent(entry.key)}</d:href>'
              '<d:propstat><d:prop><d:getetag>${etags[entry.key]}</d:getetag>'
              '</d:prop></d:propstat></d:response>');
        }
        xml.write('</d:multistatus>');
        res.write(xml.toString());
        await res.close();
      default:
        res.statusCode = 404;
        await res.close();
    }
  }
}

void main() {
  late VaultDatabaseOpener opener;
  late VaultDatabase db;
  late VaultKeys keys;
  late _TinyDav dav;
  late VaultSyncRuntime runtime;
  const int now = 1731052800000;

  setUp(() async {
    opener = VaultDatabaseOpener(
      key: DatabaseKey.random(Random(101)),
      inMemory: true,
    );
    db = await opener.open();
    keys = VaultKeys.generate();
    final clock = HlcClock(node: 'devA', now: () => now);
    final uuid = UuidV7(random: Random(103), now: () => now);
    final gateway = WriteGateway(
      db: db,
      keys: keys,
      clock: clock,
      deviceId: 'devA',
      now: () => now,
      uuid: uuid,
    );
    dav = await _TinyDav.start();

    // 服务器预置 meta / 其它设备水位，让 L1 可以静默。
    final codec = _JsonCodec();
    dav.files[CloudLayout.metaPath] =
        codec.encodeMeta(const SyncVaultMeta(vaultId: 'vault-runtime', schema: 1));
    dav.etags[CloudLayout.metaPath] = '"meta-e1"';
    final otherPath = CloudLayout.devicePath('devB');
    dav.files[otherPath] = codec.encodeWatermark(DeviceWatermark(
      deviceId: 'devB',
      maxHlc: Hlc(millis: 1000, counter: 0, node: 'devB'),
      lastSeen: 1000,
      schema: 1,
    ));
    dav.etags[otherPath] = '"dev-e1"';
    await db.into(db.deviceWatermarks).insert(
          DeviceWatermarksCompanion.insert(
            deviceId: 'devB',
            maxHlc: const Value<String?>('00000000000003e8:0000:devB'),
          ),
        );
    await db.into(db.syncStates).insert(
          SyncStatesCompanion.insert(
            path: otherPath,
            etag: const Value<String?>('"dev-e1"'),
          ),
        );

    runtime = VaultSyncRuntime.create(
      db: db,
      gateway: gateway,
      keys: keys,
      clock: clock,
      uuid: uuid,
      deviceId: 'devA',
      vaultId: 'vault-runtime',
      webDavRootUrl: dav.rootUrl,
      now: () => now,
    );
  });

  tearDown(() async {
    runtime.dispose();
    await dav.close();
    keys.destroy();
    await opener.close();
  });

  test('装配门面把真实 DB / HTTP / 统一调度串起来，一行 sync() 可跑',
      () async {
    final report = await runtime.sync(trigger: 'integration');

    expect(report, isNotNull);
    expect(report!.entry.isFailed, isFalse);
    expect(report.entry.isIdle, isTrue);
    expect(report.entry.watermarkPublished, isTrue);
    expect(report.entity.isFailed, isFalse);
    expect(report.retention.executed, isTrue);
    expect(
      dav.files.containsKey(CloudLayout.devicePath('devA')),
      isTrue,
      reason: '设备水位必须通过真实 HTTP 落到服务器',
    );
    final logs = await db.select(db.syncLogs).get();
    expect(logs, isNotEmpty, reason: '整轮同步必须写 sync_log');
  });

  test('dispose 关闭 HTTP 客户端后不再发请求', () async {
    runtime.dispose();
    expect(
      await db.select(db.syncLogs).get(),
      isEmpty,
      reason: '装配本身不发请求',
    );
  });
}

/// 最小 JSON 编码器：仅为预置服务器文件用，运行时内部用真实加密 codec。
class _JsonCodec {
  List<int> encodeMeta(SyncVaultMeta meta) =>
      utf8.encode(jsonEncode(meta.toJson()));

  List<int> encodeWatermark(DeviceWatermark w) =>
      utf8.encode(jsonEncode(w.toJson()));
}
