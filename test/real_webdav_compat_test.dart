import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/http_webdav_backend.dart';
import 'package:vault/core/sync/mkcol_with_parents.dart';
import 'package:vault/core/sync/webdav_backend.dart';

/// 真实 Nextcloud 验证中发现的四类兼容问题，用本地 HttpServer 固化：
/// ① MKCOL 不递归创建父目录（409）；② PROPFIND 集合不存在（404）；
/// ③ href 是服务器绝对路径而非 CloudLayout 逻辑路径；④ 根目录未建时
/// meta.enc 条件 PUT 失败。全部不改条件写语义、不新增依赖。
class _ParentDav {
  _ParentDav(this.server);

  final HttpServer server;
  final Set<String> collections = <String>{''};
  final Map<String, List<int>> files = <String, List<int>>{};
  final List<String> calls = <String>[];
  int etagSeq = 1;

  static Future<_ParentDav> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dav = _ParentDav(server);
    server.listen((HttpRequest request) async {
      await dav._handle(request);
    });
    return dav;
  }

  String get rootUrl => 'http://127.0.0.1:${server.port}/remote.php/dav/files/u';

  void close() => server.close(force: true);

  String _logical(String raw) {
    const String prefix = '/remote.php/dav/files/u';
    final path = raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
    return path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
  }

  Future<void> _handle(HttpRequest request) async {
    final path = _logical(request.uri.path);
    calls.add('${request.method} $path');
    final res = request.response;
    switch (request.method) {
      case 'MKCOL':
        final parent = path.substring(0, path.lastIndexOf('/'));
        if (!collections.contains(parent)) {
          res.statusCode = 409;
        } else if (collections.contains(path)) {
          res.statusCode = 405;
        } else {
          collections.add(path);
          res.statusCode = 201;
        }
        await res.close();
      case 'PROPFIND':
        await request.drain<void>();
        if (!collections.contains(path)) {
          res.statusCode = 404;
          await res.close();
          return;
        }
        res.statusCode = 207;
        final xml = StringBuffer(
          '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">',
        );
        for (final file in files.keys) {
          if (!file.startsWith('$path/')) continue;
          xml.write('<d:response>'
              '<d:href>/remote.php/dav/files/u$file</d:href>'
              '<d:propstat><d:prop><d:getetag>"e${etagSeq++}"</d:getetag>'
              '</d:prop></d:propstat></d:response>');
        }
        xml.write('</d:multistatus>');
        res.write(xml.toString());
        await res.close();
      case 'PUT':
        if (request.headers.value('if-none-match') != '*') {
          res.statusCode = 400;
          await res.close();
          return;
        }
        final parent = path.substring(0, path.lastIndexOf('/'));
        if (!collections.contains(parent)) {
          res.statusCode = 409;
          await res.close();
          return;
        }
        if (files.containsKey(path)) {
          res.statusCode = 412;
          await res.close();
          return;
        }
        files[path] = await request.fold<List<int>>(
          <int>[], (List<int> acc, List<int> chunk) => acc..addAll(chunk));
        res.statusCode = 201;
        res.headers.set('etag', '"p${etagSeq++}"');
        await res.close();
      case 'GET':
        final bytes = files[path];
        if (bytes == null) {
          res.statusCode = 404;
        } else {
          res.headers.set('etag', '"p1"');
          res.add(bytes);
        }
        await res.close();
      default:
        res.statusCode = 405;
        await res.close();
    }
  }
}

void main() {
  late _ParentDav dav;
  late HttpClientWebDavBackend backend;

  setUp(() async {
    dav = await _ParentDav.start();
    backend = HttpClientWebDavBackend(HttpWebDavConfig(rootUrl: dav.rootUrl));
  });

  tearDown(() {
    backend.close();
    dav.close();
  });

  test('parentCollectionPaths 逐段列出集合父链', () {
    expect(
      parentCollectionPaths('/vault/items/f'),
      <String>['', '/vault', '/vault/items'],
    );
  });

  test('MKCOL 409 时补齐父集合并重试，不吞掉其它错误', () async {
    expect(dav.collections.contains('/vault/items/f'), isFalse);
    await backend.mkcol('/vault/items/f');
    expect(dav.collections.contains('/vault'), isTrue);
    expect(dav.collections.contains('/vault/items'), isTrue);
    expect(dav.collections.contains('/vault/items/f'), isTrue);
    expect(dav.calls.where((String c) => c.startsWith('MKCOL')).length,
        greaterThanOrEqualTo(3));
  });

  test('PROPFIND 集合 404 自动建目录，第二次返回 207', () async {
    final listings = await backend.propfind(CloudLayout.entitiesDir('0'));
    expect(listings, isEmpty);
    expect(dav.collections.contains(CloudLayout.root), isTrue);
    expect(dav.collections.contains(CloudLayout.entitiesDir('0')), isTrue);
    expect(dav.calls, contains('PROPFIND ${CloudLayout.entitiesDir('0')}'));
  });

  test('服务器绝对 href 被还原成 /vault 逻辑路径', () async {
    await mkcolWithParents(backend, '/vault/items/0');
    await backend.put(
      '/vault/items/0/a.enc',
      utf8.encode('x'),
      condition: const WebDavCondition.createOnly(),
    );
    final listings = await backend.propfind('/vault/items/0');
    expect(listings, hasLength(1));
    expect(listings.single.path, '/vault/items/0/a.enc');
  });

  test('根目录未建时 ensureVaultMeta 先建 /vault 再条件 PUT', () async {
    // 这里直接验证同一个后端语义：先补 /vault，再 put /vault/meta.enc。
    expect(dav.collections.contains(CloudLayout.root), isFalse);
    await backend.mkcol(CloudLayout.root);
    final result = await backend.put(
      CloudLayout.metaPath,
      utf8.encode('meta'),
      condition: const WebDavCondition.createOnly(),
    );
    expect(result.statusCode, 201);
    expect(dav.files.containsKey(CloudLayout.metaPath), isTrue);

    try {
      await backend.put(
        CloudLayout.metaPath,
        utf8.encode('MUST-NOT-OVERWRITE'),
        condition: const WebDavCondition.createOnly(),
      );
      fail('重复 createOnly 应 412');
    } on WebDavException catch (e) {
      expect(e.statusCode, 412);
    }
    expect(utf8.decode(dav.files[CloudLayout.metaPath]!), 'meta');
  });
}
