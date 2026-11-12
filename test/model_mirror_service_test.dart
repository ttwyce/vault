import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/http_webdav_backend.dart';
import 'package:vault/data/search/model_mirror_service.dart';

/// docs/06 §5.4：模型 WebDAV 镜像用本地 HttpServer + 临时目录验证。
class _MirrorServer {
  _MirrorServer(this.server);
  final HttpServer server;
  final Map<String, List<int>> objects = <String, List<int>>{};
  final Map<String, String> etags = <String, String>{};
  int seq = 1;

  static Future<_MirrorServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dav = _MirrorServer(server);
    server.listen((HttpRequest request) async {
      final path = request.uri.path;
      if (request.method == 'PUT') {
        if (request.headers.value('if-none-match') == '*' &&
            dav.objects.containsKey(path)) {
          request.response.statusCode = 412;
          await request.response.close();
          return;
        }
        final bytes = await request.fold<List<int>>(
          <int>[], (List<int> acc, List<int> chunk) => acc..addAll(chunk));
        dav.objects[path] = bytes;
        final tag = '"m${dav.seq++}"';
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
  late _MirrorServer site;
  late Directory root;
  late HttpClientWebDavBackend backend;
  late List<int> payload;
  late String digest;

  setUp(() async {
    site = await _MirrorServer.start();
    root = await Directory.systemTemp.createTemp('vault-mirror-');
    backend = HttpClientWebDavBackend(
      HttpWebDavConfig(rootUrl: site.rootUrl),
    );
    payload = utf8.encode('gguf-weights-${'z' * 120}');
    digest = sha256.convert(payload).toString();
  });
  tearDown(() {
    backend.close();
    site.close();
    root.deleteSync(recursive: true);
  });

  Future<void> seedLocal(String id, List<int> bytes) async {
    final dir = Directory('${root.path}/$id');
    await dir.create(recursive: true);
    await File('${dir.path}/$id.gguf').writeAsBytes(bytes);
  }

  test('默认关闭：未勾选不上传也不拉取', () async {
    await seedLocal('m1', payload);
    final svc = ModelMirrorService(backend: backend, modelsRoot: root);
    final up = await svc.upload(
      modelId: 'm1',
      expectedSha256: digest,
      userOptedIn: false,
    );
    expect(up.ok, isFalse);
    expect(up.hint, contains('默认关闭'));
    expect(site.objects, isEmpty);
    site.objects[CloudLayout.modelPath('m1')] = payload;
    site.etags[CloudLayout.modelPath('m1')] = '"x"';
    final down = await svc.download(
      modelId: 'm1',
      expectedSha256: digest,
      userOptedIn: false,
    );
    expect(down.ok, isFalse);
  });

  test('勾选后条件上传到 /vault/models/，配额不足与坏校验拒绝', () async {
    await seedLocal('m2', payload);
    final svc = ModelMirrorService(backend: backend, modelsRoot: root);
    final quota = await svc.upload(
      modelId: 'm2',
      expectedSha256: digest,
      userOptedIn: true,
      quotaUsedBytes: 100000,
      quotaLimitBytes: 100010,
    );
    expect(quota.ok, isFalse);
    expect(quota.hint, contains('配额'));
    expect(site.objects, isEmpty);

    final bad = await svc.upload(
      modelId: 'm2',
      expectedSha256: '0' * 64,
      userOptedIn: true,
    );
    expect(bad.ok, isFalse);
    expect(bad.hint, contains('sha256'));

    final ok = await svc.upload(
      modelId: 'm2',
      expectedSha256: digest,
      userOptedIn: true,
    );
    expect(ok.ok, isTrue);
    expect(site.objects.containsKey(CloudLayout.modelPath('m2')), isTrue);
    expect(ok.etag, isNotNull);
  });

  test('重复 createOnly 触发 412 不覆盖云端', () async {
    await seedLocal('m3', payload);
    final svc = ModelMirrorService(backend: backend, modelsRoot: root);
    expect(
      (await svc.upload(
        modelId: 'm3',
        expectedSha256: digest,
        userOptedIn: true,
      )).ok,
      isTrue,
    );
    final before = List<int>.from(site.objects[CloudLayout.modelPath('m3')]!);
    final second = await svc.upload(
      modelId: 'm3',
      expectedSha256: digest,
      userOptedIn: true,
    );
    expect(second.ok, isFalse);
    expect(second.hint, contains('412'));
    expect(site.objects[CloudLayout.modelPath('m3')], before);
  });

  test('下载校验通过写本地；篡改 sha256 / 404 都不落盘', () async {
    site.objects[CloudLayout.modelPath('m4')] = payload;
    site.etags[CloudLayout.modelPath('m4')] = '"e1"';
    final svc = ModelMirrorService(backend: backend, modelsRoot: root);
    final ok = await svc.download(
      modelId: 'm4',
      expectedSha256: digest,
      userOptedIn: true,
    );
    expect(ok.ok, isTrue);
    expect(
      await File('${root.path}/m4/m4.gguf').readAsBytes(),
      payload,
    );

    final bad = await svc.download(
      modelId: 'm4',
      expectedSha256: '0' * 64,
      userOptedIn: true,
    );
    expect(bad.ok, isFalse);
    expect(bad.hint, contains('sha256'));

    final missing = await svc.download(
      modelId: 'not-there',
      expectedSha256: digest,
      userOptedIn: true,
    );
    expect(missing.ok, isFalse);
    expect(missing.hint, contains('404'));
  });

  test('非法 modelId 拒绝路径穿越', () async {
    final svc = ModelMirrorService(backend: backend, modelsRoot: root);
    expect(
      () => ModelMirrorService.pathFor('../evil'),
      throwsArgumentError,
    );
    await expectLater(
      svc.upload(
        modelId: '../evil',
        expectedSha256: digest,
        userOptedIn: true,
      ),
      throwsArgumentError,
    );
  });

  test('modelPath 与 /vault/items 分离且后缀 .gguf', () {
    expect(CloudLayout.modelPath('bge-small'),
        '/vault/models/bge-small.gguf');
    expect(CloudLayout.modelPath('bge-small'),
        isNot(startsWith('/vault/items')));
  });
}
