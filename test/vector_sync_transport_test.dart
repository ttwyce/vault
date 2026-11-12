import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/http_webdav_backend.dart';
import 'package:vault/data/search/vector_sync_policy.dart';
import 'package:vault/data/search/vector_sync_transport.dart';

/// docs/06 §7：真实 WebDAV GET / 条件 PUT 用本地 HttpServer 验证。
class _VecServer {
  _VecServer(this.server);
  final HttpServer server;
  final Map<String, List<int>> objects = <String, List<int>>{};
  final Map<String, String> etags = <String, String>{};
  final List<String> calls = <String>[];
  int etagSeq = 100;

  static Future<_VecServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dav = _VecServer(server);
    server.listen((HttpRequest request) async {
      dav.calls.add(request.method);
      final path = request.uri.path;
      if (request.method == 'PUT') {
        final ifNone =
            request.headers.value('if-none-match') == '*';
        final ifMatch = request.headers.value('if-match');
        final exists = dav.objects.containsKey(path);
        if (ifNone && exists) {
          request.response.statusCode = 412;
          await request.response.close();
          return;
        }
        if (ifMatch != null && dav.etags[path] != ifMatch) {
          request.response.statusCode = 412;
          await request.response.close();
          return;
        }
        final bytes = await request.fold<List<int>>(
          <int>[], (List<int> acc, List<int> chunk) => acc..addAll(chunk));
        dav.objects[path] = bytes;
        final tag = '"e${dav.etagSeq++}"';
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

VectorEnvelope _envelope({
  String modelId = 'gemma-300m',
  int dim = 256,
  String dtype = 'int8',
}) =>
    VectorEnvelope(
      modelId: modelId,
      dim: dim,
      dtype: dtype,
      bytesBase64: base64.encode(<int>[1, 2, 3, 4]),
    );

void main() {
  late _VecServer site;
  late HttpClientWebDavBackend backend;
  late VectorExpectation expected;

  setUp(() async {
    site = await _VecServer.start();
    backend = HttpClientWebDavBackend(
      HttpWebDavConfig(rootUrl: site.rootUrl),
    );
    expected = const VectorExpectation(
      modelId: 'gemma-300m',
      dim: 256,
      dtype: 'int8',
    );
  });
  tearDown(() {
    backend.close();
    site.close();
  });

  test('条件上传走真实 PUT，路径是 /vault/vec/<name>，带 If-None-Match',
      () async {
    final transport = VectorSyncTransport(
      backend: backend,
      expected: expected,
    );
    final name = 'a' * 32 + '.enc';
    expect(transport.pathFor(name), CloudLayout.vectorPath(name));
    final pushed = await transport.push(name, _envelope());
    expect(pushed.ok, isTrue);
    expect(pushed.etag, isNotNull);
    expect(site.objects.containsKey(CloudLayout.vectorPath(name)), isTrue);
    expect(site.calls, contains('PUT'));
  });

  test('上传规格不符的封包被拒绝，不发 PUT', () async {
    final transport = VectorSyncTransport(
      backend: backend,
      expected: expected,
    );
    final rejected = await transport.push(
      'b' * 32 + '.enc',
      _envelope(modelId: 'other-model'),
    );
    expect(rejected.ok, isFalse);
    expect(rejected.hint, contains('model_id'));
    expect(site.calls, isEmpty);
  });

  test('拉取规格匹配的封包被接受；不匹配 / 坏 JSON / 404 都需重算',
      () async {
    final transport = VectorSyncTransport(
      backend: backend,
      expected: expected,
    );
    final name = 'c' * 32 + '.enc';
    final path = CloudLayout.vectorPath(name);

    site.objects[path] = utf8.encode(jsonEncode(_envelope().toJson()));
    site.etags[path] = '"e1"';
    final good = await transport.pull(name);
    expect(good.accepted, isTrue);
    expect(good.envelope!.modelId, 'gemma-300m');

    site.objects[path] =
        utf8.encode(jsonEncode(_envelope(dim: 768).toJson()));
    final wrong = await transport.pull(name);
    expect(wrong.accepted, isFalse);
    expect(wrong.needsRecompute, isTrue);
    expect(wrong.hint, contains('dim'));

    site.objects[path] = utf8.encode('{坏 JSON');
    final bad = await transport.pull(name);
    expect(bad.needsRecompute, isTrue);

    site.objects.remove(path);
    final missing = await transport.pull(name);
    expect(missing.needsRecompute, isTrue);
  });

  test('更新必须带 ETag；过期 ETag 触发 412 且不覆盖云端', () async {
    final transport = VectorSyncTransport(
      backend: backend,
      expected: expected,
    );
    final name = 'd' * 32 + '.enc';
    final first = await transport.push(name, _envelope());
    expect(first.ok, isTrue);
    final stale = await transport.push(
      name,
      _envelope(),
      ifMatchEtag: '"expired"',
    );
    expect(stale.ok, isFalse);
    expect(stale.hint, contains('412'));
    // 云端仍是第一次的内容。
    expect(
      utf8.decode(site.objects[CloudLayout.vectorPath(name)]!),
      jsonEncode(_envelope().toJson()),
    );
  });
}
