import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/blob_cache_evictor.dart';
import 'package:vault/data/archive/http_blob_downloader.dart';

import 'support/test_harness.dart';

/// docs/05 §7：真实 blob 下载 + local=1 写回 + LRU 清理执行。
class _BlobServer {
  _BlobServer(this.server);
  final HttpServer server;
  int status = 200;
  List<int> payload = utf8.encode('hello blob');
  String get url => 'http://127.0.0.1:${server.port}/blob';

  static Future<_BlobServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _BlobServer(server);
    server.listen((HttpRequest request) async {
      request.response.statusCode = site.status;
      request.response.add(site.payload);
      await request.response.close();
    });
    return site;
  }

  void close() => server.close(force: true);
}

String _hash(String s) => s.padLeft(64, '0');

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() async => app.dispose());

  Future<void> seed(String id, String hash, int bytes, {bool local = false}) =>
      app.gateway.recordArchiveBlob(
        entryId: id,
        blobHash: hash,
        kind: 1,
        bytes: bytes,
        local: local,
      ).then((_) {});

  Future<int> localOf(String hash) async {
    final row = await (app.db.select(app.db.blobRefs)
          ..where((t) => t.blobHash.equals(hash)))
        .getSingle();
    return row.local;
  }

  test('真实 GET 成功 → 进度回调 + local=1', () async {
    final site = await _BlobServer.start();
    await seed('e1', _hash('a'), site.payload.length);
    final downloader = HttpBlobDownloader(gateway: app.gateway);
    final progress = <double>[];
    final result = await downloader.download(
      entryId: 'e1',
      blobHash: _hash('a'),
      url: Uri.parse(site.url),
      expectedBytes: site.payload.length,
      onProgress: progress.add,
    );
    expect(result.ok, isTrue);
    expect(result.bytes, site.payload.length);
    expect(result.progress, 1);
    expect(progress, isNotEmpty);
    expect(await localOf(_hash('a')), 1);
    downloader.close();
    site.close();
  });

  test('HTTP 404 / 断连都不写 local', () async {
    final site = await _BlobServer.start();
    await seed('e2', _hash('b'), 10);
    site.status = 404;
    final downloader = HttpBlobDownloader(gateway: app.gateway);
    final failed = await downloader.download(
      entryId: 'e2',
      blobHash: _hash('b'),
      url: Uri.parse(site.url),
      expectedBytes: 10,
    );
    expect(failed.ok, isFalse);
    expect(await localOf(_hash('b')), 0);
    downloader.close();
    site.close();
  });

  test('LRU 清理执行器把最老的 local=1 置 0、云端/条目不动', () async {
    await seed('e3', _hash('c'), 600, local: true);
    await seed('e4', _hash('d'), 600, local: true);
    final evictor = BlobCacheEvictor(db: app.db, gateway: app.gateway);
    final result = await evictor.run(maxBytes: 800);
    expect(result.evictedHashes, isNotEmpty);
    final locals = await localOf(_hash('c')) + await localOf(_hash('d'));
    expect(locals, lessThan(2));
    final rows = await app.db.select(app.db.blobRefs).get();
    expect(rows, hasLength(2), reason: '只改 local 标记，不删云端引用');
  });
}
