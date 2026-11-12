import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/vault_keys.dart';
import 'package:vault/core/sync/http_webdav_backend.dart';
import 'package:vault/data/backup/encrypted_backup_service.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// docs/03 §10：加密备份真实打包 / WebDAV 上传拉取用本地服务器验证。
class _BackupServer {
  _BackupServer(this.server);
  final HttpServer server;
  final Map<String, List<int>> objects = <String, List<int>>{};
  final Map<String, String> etags = <String, String>{};
  int seq = 1;

  static Future<_BackupServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dav = _BackupServer(server);
    server.listen((HttpRequest request) async {
      final path = request.uri.path;
      if (request.method == 'PUT') {
        final ifNone = request.headers.value('if-none-match') == '*';
        if (ifNone && dav.objects.containsKey(path)) {
          request.response.statusCode = 412;
          await request.response.close();
          return;
        }
        final bytes = await request.fold<List<int>>(
          <int>[], (List<int> acc, List<int> chunk) => acc..addAll(chunk));
        dav.objects[path] = bytes;
        final tag = '"b${dav.seq++}"';
        dav.etags[path] = tag;
        request.response.headers.set('etag', tag);
        request.response.statusCode = 201;
        await request.response.close();
        return;
      }
      if (request.method == 'GET' || request.method == 'HEAD') {
        final bytes = dav.objects[path];
        if (bytes == null) {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }
        request.response.headers.set('etag', dav.etags[path]!);
        if (request.method == 'GET') request.response.add(bytes);
        await request.response.close();
        return;
      }
      request.response.statusCode = 405;
      await request.response.close();
    });
    return dav;
  }

  String get rootUrl => 'http://127.0.0.1:${server.port}';
  void close() => server.close(force: true);
}

void main() {
  late TestApp app;
  late _BackupServer site;
  late HttpClientWebDavBackend backend;
  late VaultKeys keys;

  setUp(() async {
    app = await TestApp.create();
    site = await _BackupServer.start();
    backend = HttpClientWebDavBackend(
      HttpWebDavConfig(rootUrl: site.rootUrl),
    );
    keys = VaultKeys.generate();
  });
  tearDown(() async {
    backend.close();
    site.close();
    await app.dispose();
  });

  Future<EncryptedBackupService> service() async =>
      EncryptedBackupService(db: app.db, backend: backend, keys: keys);

  test('真实条目打包加密上传到 /backup/，再拉取解密校验 manifest', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'note-a',
      kind: EntryKind.note,
      title: '备份笔记',
      body: '正文 A',
    ));
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'note-b',
      kind: EntryKind.note,
      title: '另一条',
      body: '正文 B',
    ));
    final svc = await service();
    final uploaded = await svc.upload(
      fileName: 'vault.enc',
      vaultId: 'vault-1',
      nowMs: 1731052800000,
    );
    expect(uploaded.ok, isTrue);
    expect(uploaded.bytes, greaterThan(8));
    expect(site.objects.containsKey('/backup/vault.enc'), isTrue);
    // 密文里不出现明文标题。
    final wire = site.objects['/backup/vault.enc']!;
    expect(String.fromCharCodes(wire), isNot(contains('备份笔记')));

    final restored = await svc.restore('vault.enc');
    expect(restored.ok, isTrue);
    expect(restored.manifest!.entries, hasLength(2));
    expect(restored.manifest!.vaultId, 'vault-1');
    expect(restored.hint, contains('2 条条目'));
  });

  test('路径隔离：非法文件名 / 非 /backup/ 路径被拒绝', () async {
    final svc = await service();
    final bad = await svc.upload(
      fileName: '../vault/evil.enc',
      vaultId: 'v',
      nowMs: 1,
    );
    expect(bad.ok, isFalse);
    expect(site.objects, isEmpty);
    final restoreBad = await svc.restore('../vault/evil.enc');
    expect(restoreBad.ok, isFalse);
  });

  test('篡改密文 / 错误密钥 / 坏容器都解密失败', () async {
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'note-c',
      kind: EntryKind.note,
      title: 'C',
      body: '正文 C',
    ));
    final svc = await service();
    expect(
      (await svc.upload(
        fileName: 'vault.enc',
        vaultId: 'v',
        nowMs: 1,
      )).ok,
      isTrue,
    );

    // 篡改一个密文字节（不动容器头）。
    final wire = site.objects['/backup/vault.enc']!;
    final tampered = List<int>.from(wire);
    tampered.last ^= 0x01;
    site.objects['/backup/vault.enc'] = tampered;
    expect((await svc.restore('vault.enc')).ok, isFalse);

    // 换密钥。
    final other = EncryptedBackupService(
      db: app.db,
      backend: backend,
      keys: VaultKeys.generate(),
    );
    expect((await other.restore('vault.enc')).ok, isFalse);

    // 坏 magic。
    site.objects['/backup/vault.enc'] = <int>[0, 0, 0, 0, 0, 0, 0, 1, 9];
    expect((await svc.restore('vault.enc')).hint, contains('magic'));
  });

  test('createOnly 重复上传触发 412，不覆盖云端备份', () async {
    final svc = await service();
    final first = await svc.upload(
      fileName: 'vault.enc',
      vaultId: 'v',
      nowMs: 1,
    );
    expect(first.ok, isTrue);
    final before = List<int>.from(site.objects['/backup/vault.enc']!);
    final second = await svc.upload(
      fileName: 'vault.enc',
      vaultId: 'v',
      nowMs: 2,
    );
    expect(second.ok, isFalse);
    expect(second.hint, contains('412'));
    expect(site.objects['/backup/vault.enc'], before);
  });
}
