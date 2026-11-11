import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/device_watermark.dart';
import 'package:vault/core/sync/hlc.dart';
import 'package:vault/core/sync/http_webdav_backend.dart';
import 'package:vault/core/sync/sync_state_machine.dart';
import 'package:vault/core/sync/sync_engine.dart';
import 'package:vault/core/sync/sync_payloads.dart';
import 'package:vault/data/write/entry_snapshot.dart';
import 'package:vault/core/sync/webdav_backend.dart';

/// 用 `HttpServer.bind(127.0.0.1, 0)` 起一个最小 WebDAV 服务，
/// 验证真实 HTTP 路径：条件写、ETag、PROPFIND 207 解析、
/// REPORT 增量 / 删除、GET 404、OPTIONS 头、MKCOL。
/// 不依赖外部服务器，也不需要新增 Dart 依赖。
class _DavServer {
  _DavServer(this.server);

  final HttpServer server;
  final Map<String, _Entry> files = <String, _Entry>{};
  final List<String> calls = <String>[];
  int _etag = 100;

  /// 模拟「PUT 成功但不返回 ETag」的服务商行为。
  bool noPutEtag = false;

  /// 模拟「GET 成功但不返回 ETag」的服务商行为。
  bool noGetEtag = false;

  String? lastAuthorization;
  bool requireAuth = false;

  static Future<_DavServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dav = _DavServer(server);
    server.listen((HttpRequest request) async {
      await dav._handle(request);
    });
    return dav;
  }

  String get rootUrl => 'http://127.0.0.1:${server.port}';

  Future<void> close() async => server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    lastAuthorization = request.headers.value(HttpHeaders.authorizationHeader);
    if (requireAuth && lastAuthorization == null) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }
    calls.add('${request.method} $path');
    final response = request.response;
    response.headers.set('DAV', '1, 3, sync-collection');

    switch (request.method) {
      case 'OPTIONS':
        response.headers.set('Allow', 'OPTIONS, PROPFIND, REPORT, GET, PUT, DELETE, MKCOL');
        response.headers.set('ETag', '"root"');
        await response.close();
        return;

      case 'HEAD':
        final entry = files[path];
        if (entry == null) {
          response.statusCode = HttpStatus.notFound;
        } else {
          response.headers.set('ETag', entry.etag);
        }
        await response.close();
        return;

      case 'MKCOL':
        response.statusCode = HttpStatus.created;
        await response.close();
        return;

      case 'GET':
        final entry = files[path];
        if (entry == null) {
          response.statusCode = HttpStatus.notFound;
          await response.close();
          return;
        }
        if (!noGetEtag) response.headers.set('ETag', entry.etag);
        response.add(entry.bytes);
        await response.close();
        return;

      case 'PUT':
        final condition = request.headers.value('if-match') ??
            request.headers.value('if-none-match');
        if (condition == null) {
          response.statusCode = HttpStatus.badRequest;
          await response.close();
          return;
        }
        final current = files[path];
        if (condition == '*' && current != null) {
          response.statusCode = HttpStatus.preconditionFailed;
          await response.close();
          return;
        }
        if (condition != '*' &&
            (current == null || current.etag != condition)) {
          response.statusCode = HttpStatus.preconditionFailed;
          await response.close();
          return;
        }
        final bytes = await request.fold<List<int>>(
          <int>[],
          (List<int> previous, List<int> chunk) =>
              <int>[...previous, ...chunk],
        );
        final etag = '"e${_etag++}"';
        files[path] = _Entry(bytes, etag);
        response.statusCode =
            current == null ? HttpStatus.created : HttpStatus.noContent;
        if (!noPutEtag) response.headers.set('ETag', etag);
        await response.close();
        return;

      case 'DELETE':
        final ifMatch = request.headers.value('if-match');
        final current = files[path];
        if (ifMatch == null ||
            current == null ||
            (ifMatch != '*' && current.etag != ifMatch)) {
          response.statusCode = HttpStatus.preconditionFailed;
          await response.close();
          return;
        }
        files.remove(path);
        response.statusCode = HttpStatus.noContent;
        await response.close();
        return;

      case 'PROPFIND':
        await request.drain<void>();
        response.statusCode = 207;
        response.headers.contentType = ContentType('application', 'xml');
        final buffer = StringBuffer(
          '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">',
        );
        for (final entry in files.entries) {
          if (!entry.key.startsWith('$path/') && entry.key != path) continue;
          buffer.write('<d:response><d:href>${Uri.encodeComponent(entry.key)}</d:href>'
              '<d:propstat><d:prop><d:getetag>${entry.value.etag}</d:getetag>'
              '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>'
              '</d:response>');
        }
        buffer.write('</d:multistatus>');
        response.write(buffer.toString());
        await response.close();
        return;

      case 'REPORT':
        await request.drain<void>();
        response.statusCode = 207;
        response.headers.contentType = ContentType('application', 'xml');
        final buffer = StringBuffer(
          '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">',
        );
        for (final entry in files.entries) {
          buffer.write('<d:response><d:href>${Uri.encodeComponent(entry.key)}</d:href>'
              '<d:propstat><d:prop><d:getetag>${entry.value.etag}</d:getetag>'
              '</d:prop></d:propstat></d:response>');
        }
        // 一个明确的 404 删除项，验证按 response 块判定而非整份 XML。
        buffer.write('<d:response><d:href>/vault/items/0/gone.enc</d:href>'
            '<d:status>HTTP/1.1 404 Not Found</d:status></d:response>');
        buffer.write('<d:sync-token>token-next</d:sync-token>');
        buffer.write('</d:multistatus>');
        response.write(buffer.toString());
        await response.close();
        return;

      default:
        response.statusCode = HttpStatus.methodNotAllowed;
        await response.close();
    }
  }
}

/// 统计同时在途请求数的延迟服务器。
class _ConcurrencyServer {
  _ConcurrencyServer(this.server);

  final HttpServer server;
  int inFlight = 0;
  int peak = 0;
  int total = 0;

  static Future<_ConcurrencyServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final self = _ConcurrencyServer(server);
    server.listen((HttpRequest request) async {
      self.inFlight++;
      self.total++;
      if (self.inFlight > self.peak) self.peak = self.inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      request.response.headers.set('ETag', '"x"');
      request.response.add(<int>[1]);
      await request.response.close();
      self.inFlight--;
    });
    return self;
  }

  String get rootUrl => 'http://127.0.0.1:${server.port}';

  Future<void> close() async => server.close(force: true);
}

/// 最小 JSON codec：本用例只走 L1 静默，不需要真实加密字节。
class _JsonCodec implements SyncPayloadCodec {
  @override
  String hashedName(String entryId) =>
      '${entryId.hashCode.toRadixString(16).padLeft(32, '0')}.enc';

  @override
  List<int> encodeEntry(EntrySnapshot snapshot) => _bytes(snapshot.toJson());

  @override
  EntrySnapshot decodeEntry(List<int> bytes) =>
      EntrySnapshot.fromJson(_object(bytes));

  @override
  List<int> encodeMeta(SyncVaultMeta meta) => _bytes(meta.toJson());

  @override
  SyncVaultMeta decodeMeta(List<int> bytes) =>
      SyncVaultMeta.fromJson(_object(bytes));

  @override
  List<int> encodeTombstone(SyncTombstone t) => _bytes(t.toJson());

  @override
  SyncTombstone decodeTombstone(List<int> bytes) =>
      SyncTombstone.fromJson(_object(bytes));

  @override
  List<int> encodeWatermark(DeviceWatermark w) => _bytes(w.toJson());

  @override
  DeviceWatermark decodeWatermark(List<int> bytes, {String? etag}) =>
      DeviceWatermark.fromJson(_object(bytes), etag: etag);

  List<int> _bytes(Object? value) => utf8.encode(jsonEncode(value));

  Map<String, Object?> _object(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    return Map<String, Object?>.from(decoded as Map);
  }
}

class _Entry {
  const _Entry(this.bytes, this.etag);

  final List<int> bytes;
  final String etag;
}

void main() {
  late _DavServer server;
  late HttpClientWebDavBackend backend;

  setUp(() async {
    server = await _DavServer.start();
    backend = HttpClientWebDavBackend(
      HttpWebDavConfig(rootUrl: server.rootUrl),
    );
  });

  tearDown(() async {
    backend.close();
    await server.close();
  });

  test('OPTIONS 头映射、Basic 认证与 DAV 能力探测', () async {
    final headers = await backend.options('/vault/');
    expect(headers['dav'], contains('sync-collection'));
    expect(headers['allow'], contains('PROPFIND'));
    expect(server.calls, contains('OPTIONS /vault/'));
  });

  test('条件 PUT / GET / DELETE 走真实 TCP，ETag 与 412 都正确', () async {
    const String path = '/vault/items/0/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.enc';
    final put = await backend.put(
      path,
      utf8.encode('加密载荷'),
      condition: const WebDavCondition.createOnly(),
    );
    expect(put.statusCode, HttpStatus.created);
    expect(put.etag, isNotEmpty);

    await expectLater(
      backend.put(path, utf8.encode('重复创建'),
          condition: const WebDavCondition.createOnly()),
      throwsA(isA<WebDavException>().having(
        (WebDavException e) => e.isPreconditionFailed,
        '412',
        isTrue,
      )),
    );

    final got = await backend.get(path);
    expect(utf8.decode(got.bytes), '加密载荷');
    expect(got.etag, put.etag);

    final updated = await backend.put(
      path,
      utf8.encode('第二版'),
      condition: WebDavCondition.ifMatch(put.etag),
    );
    expect(updated.statusCode, HttpStatus.noContent);
    expect(updated.etag, isNot(put.etag));

    await backend.delete(path, ifMatch: updated.etag);
    expect(server.files.containsKey(path), isFalse);
    await expectLater(
      backend.get(path),
      throwsA(isA<WebDavException>().having(
        (WebDavException e) => e.statusCode,
        '404',
        404,
      )),
    );
  });

  test('PROPFIND 207 解析出 ETag，路径归一化为 /vault/...', () async {
    const String dir = '/vault/items/0';
    await backend.put(
      '$dir/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.enc',
      utf8.encode('a'),
      condition: const WebDavCondition.createOnly(),
    );
    await backend.put(
      '$dir/cccccccccccccccccccccccccccccccc.enc',
      utf8.encode('b'),
      condition: const WebDavCondition.createOnly(),
    );

    final listings = await backend.propfind(dir);
    expect(listings, hasLength(2));
    expect(listings.every((WebDavListing l) => l.path.startsWith('$dir/')),
        isTrue);
    expect(listings.every((WebDavListing l) => l.etag != null), isTrue);
    expect(listings.every((WebDavListing l) => !l.isCollection), isTrue);
  });

  test('REPORT sync-collection 给出增量 / 删除 / 新 token', () async {
    await backend.put(
      '/vault/items/0/dddddddddddddddddddddddddddddddd.enc',
      utf8.encode('changed'),
      condition: const WebDavCondition.createOnly(),
    );
    final delta = await backend.reportSyncCollection(
      '/vault/',
      syncToken: 'token-prev',
    );

    expect(delta.syncToken, 'token-next');
    expect(delta.changed, hasLength(1));
    expect(delta.deleted, <String>{'/vault/items/0/gone.enc'});
    expect(delta.changed.values.first, isNotEmpty,
        reason: '有 ETag 的条目不能被误判成删除');
  });

  test('MKCOL 幂等 + 网络错误映射成 E_NET 可退避错误码', () async {
    await backend.mkcol('/vault/entities/0');
    expect(server.calls, contains('MKCOL /vault/entities/0'));

    final broken = HttpClientWebDavBackend(
      const HttpWebDavConfig(rootUrl: 'http://127.0.0.1:1'),
    );
    await expectLater(
      broken.options('/vault/'),
      throwsA(isA<WebDavException>()),
    );
    broken.close();
  });

  test('SyncEngine 通过真实 HTTP 后端跑完一轮同步（L1 静默发布水位）',
      () async {
    // 本地服务器补上设备目录 / 水位文件 / meta.enc。
    final codec = _JsonCodec();
    final metaPath = CloudLayout.metaPath;
    server.files[metaPath] = _Entry(
      codec.encodeMeta(const SyncVaultMeta(vaultId: 'vault-http', schema: 1)),
      '"meta-e1"',
    );
    final otherPath = CloudLayout.devicePath('devB');
    server.files[otherPath] = _Entry(
      codec.encodeWatermark(DeviceWatermark(
        deviceId: 'devB',
        maxHlc: Hlc(millis: 1000, counter: 0, node: 'devB'),
        lastSeen: 1000,
        schema: 1,
      )),
      '"dev-e1"',
    );
    final selfPath = CloudLayout.devicePath('devA');
    // 让 PUT 设备水位文件成功（createOnly）。
    final workspace = SyncWorkspace(
      selfDeviceId: 'devA',
      vaultId: 'vault-http',
      schema: 1,
      localWatermarks: <String, Hlc?>{
        'devB': Hlc(millis: 1000, counter: 0, node: 'devB'),
      },
      deviceEtags: <String, String>{'devB': '"dev-e1"'},
      syncState: <String, String?>{},
      entries: <String, EntrySnapshot>{},
      baseRevs: <String, int>{},
      baseSnapshots: <String, EntrySnapshot?>{},
      pendingOps: <SyncPendingOp>[],
      nowMs: 1731052800000,
      nextHlc: Hlc(millis: 1731052800000, counter: 0, node: 'devA').encode(),
      localLabel: 'A',
      remoteLabel: 'B',
      newConflictCopyId: () => 'copy-1',
    );

    final result = await SyncEngine(
      backend: backend,
      codec: SyncPayloadCodecAdapter(codec),
    ).run(workspace);

    expect(result.isFailed, isFalse);
    expect(result.isIdle, isTrue);
    expect(result.watermarkPublished, isTrue);
    expect(result.requestCount, lessThanOrEqualTo(3));
    expect(server.files.containsKey(selfPath), isTrue,
        reason: '设备水位必须通过真实 PUT 落到服务器');
  });

  test('连接超时映射成 E_NET（可退避），不是 E_CORRUPT', () async {
    // 服务器故意不响应，让客户端 connectTimeout 先到。
    final slowServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    slowServer.listen((HttpRequest request) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      // ignore: unawaited_futures
      request.response.close();
    });
    final slow = HttpClientWebDavBackend(
      HttpWebDavConfig(
        rootUrl: 'http://127.0.0.1:${slowServer.port}',
        connectTimeout: const Duration(milliseconds: 80),
      ),
    );
    try {
      await expectLater(
        slow.options('/vault/'),
        throwsA(
          isA<WebDavException>().having(
            (WebDavException e) => e.syncErrorCode,
            'errorCode',
            SyncErrorCode.net,
          ),
        ),
      );
    } finally {
      slow.close();
      await slowServer.close(force: true);
    }
  });

  test('PUT 无响应 ETag 时用 HEAD 回读，不退化成空条件', () async {
    server.noPutEtag = true;
    const String path = '/vault/items/0/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee.enc';
    final put = await backend.put(
      path,
      utf8.encode('载荷'),
      condition: const WebDavCondition.createOnly(),
    );
    expect(put.etag, isNotEmpty);
    expect(server.calls, contains('HEAD $path'));
    // 下一轮用它做 If-Match 必须成功。
    final next = await backend.put(
      path,
      utf8.encode('第二版'),
      condition: WebDavCondition.ifMatch(put.etag),
    );
    expect(next.statusCode, HttpStatus.noContent);
  });

  test('PUT 与 HEAD 都没有 ETag 时抛 E_PATH，不返回空条件', () async {
    server.noPutEtag = true;
    // 让 HEAD 也拿不到：直接清空该路径的 ETag 头通过覆写 response 较难，
    // 这里用独立服务器验证「服务器完全不实现 HEAD」的退化路径。
    final bare = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    bare.listen((HttpRequest request) async {
      if (request.method == 'PUT') {
        await request.drain<void>();
        request.response.statusCode = HttpStatus.created;
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
      }
    });
    final b = HttpClientWebDavBackend(
      HttpWebDavConfig(rootUrl: 'http://127.0.0.1:${bare.port}'),
    );
    try {
      await expectLater(
        b.put(
          '/vault/items/0/ffffffffffffffffffffffffffffffff.enc',
          utf8.encode('x'),
          condition: const WebDavCondition.createOnly(),
        ),
        throwsA(isA<WebDavException>().having(
          (WebDavException e) => e.syncErrorCode,
          'errorCode',
          SyncErrorCode.path,
        )),
      );
    } finally {
      b.close();
      await bare.close(force: true);
    }
  });

  test('docs/04 §10：并发 HTTP 请求不超过 maxConcurrentRequests', () async {
    final concurrent = _ConcurrencyServer.start();
    final serverHttp = await concurrent;
    final limited = HttpClientWebDavBackend(
      HttpWebDavConfig(
        rootUrl: serverHttp.rootUrl,
        maxConcurrentRequests: 2,
      ),
    );
    try {
      await Future.wait<void>(<Future<void>>[
        for (var i = 0; i < 8; i++)
          limited.get('/vault/items/0/file-$i.enc').then((_) {}),
      ]);
      expect(serverHttp.peak, lessThanOrEqualTo(2),
          reason: '连接池上限必须覆盖同时在途请求');
      expect(serverHttp.total, 8);
    } finally {
      limited.close();
      await serverHttp.close();
    }
  });

  test('GET 无响应 ETag 时用 HEAD 回读，不把空条件传给调用方', () async {
    const String path = '/vault/items/0/11111111111111111111111111111111.enc';
    await backend.put(path, utf8.encode('内容'),
        condition: const WebDavCondition.createOnly());
    server.noGetEtag = true;

    final got = await backend.get(path);
    expect(utf8.decode(got.bytes), '内容');
    expect(got.etag, isNotEmpty);
    expect(server.calls, contains('HEAD $path'));
  });

  test('302 登录页重定向不被当成写成功，映射为 E_AUTH', () async {
    final redirect = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    redirect.listen((HttpRequest r) async {
      await r.drain<void>();
      r.response.statusCode = HttpStatus.found;
      r.response.headers.set(HttpHeaders.locationHeader, '/login');
      await r.response.close();
    });
    final b = HttpClientWebDavBackend(
      HttpWebDavConfig(rootUrl: 'http://127.0.0.1:${redirect.port}'),
    );
    try {
      await expectLater(
        b.put(
          '/vault/items/0/22222222222222222222222222222222.enc',
          utf8.encode('载荷'),
          condition: const WebDavCondition.createOnly(),
        ),
        throwsA(isA<WebDavException>().having(
          (WebDavException e) => e.syncErrorCode,
          'errorCode',
          SyncErrorCode.auth,
        )),
      );
    } finally {
      b.close();
      await redirect.close(force: true);
    }
  });

  test('Basic 认证头真实发送，401 映射成 E_AUTH 并停止重试', () async {
    final auth = HttpClientWebDavBackend(
      HttpWebDavConfig(
        rootUrl: server.rootUrl,
        username: 'alice',
        password: 'secret',
      ),
    );
    try {
      await auth.options('/vault/');
      expect(server.lastAuthorization, isNotNull);
      expect(server.lastAuthorization, startsWith('Basic '));
      final decoded = utf8.decode(base64.decode(
        server.lastAuthorization!.substring('Basic '.length),
      ));
      expect(decoded, 'alice:secret');

      server.requireAuth = true;
      // 不带凭据的后端必须拿到 401 → E_AUTH（不可重试）。
      await expectLater(
        backend.get('/vault/items/0/nope.enc'),
        throwsA(isA<WebDavException>().having(
          (WebDavException e) => e.syncErrorCode,
          'errorCode',
          SyncErrorCode.auth,
        )),
      );
    } finally {
      auth.close();
    }
  });

  test('响应体超过上限时抛 E_QUOTA，绝不返回半个载荷', () async {
    const String path = '/vault/items/0/33333333333333333333333333333333.enc';
    // 测试服务器把 PUT 的 bytes 原样 GET 回来；放 2 KB 超过 64 B 上限。
    await backend.put(
      path,
      List<int>.filled(2048, 7),
      condition: const WebDavCondition.createOnly(),
    );
    final small = HttpClientWebDavBackend(
      HttpWebDavConfig(rootUrl: server.rootUrl, maxResponseBytes: 64),
    );
    try {
      await expectLater(
        small.get(path),
        throwsA(isA<WebDavException>().having(
          (WebDavException e) => e.syncErrorCode,
          'errorCode',
          SyncErrorCode.quota,
        )),
      );
      // 调大上限后同一载荷可读回完整字节。
      final large = HttpClientWebDavBackend(
        HttpWebDavConfig(rootUrl: server.rootUrl, maxResponseBytes: 4096),
      );
      try {
        final got = await large.get(path);
        expect(got.bytes, hasLength(2048));
      } finally {
        large.close();
      }
    } finally {
      small.close();
    }
  });

  test('parseMultiStatus 兼容无命名空间前缀与绝对 URL href', () {
    const String xml = '<?xml version="1.0"?><multistatus>'
        '<response><href>http://dav.example.com/vault/items/0/a.enc</href>'
        '<propstat><prop><getetag>"x1"</getetag></prop></propstat></response>'
        '<response><href>/vault/items/0/b.enc</href>'
        '<status>HTTP/1.1 404 Not Found</status></response>'
        '</multistatus>';
    final listings =
        HttpClientWebDavBackend.parseMultiStatus(xml, '/vault/items/0');
    expect(listings, hasLength(2));
    expect(listings.first.path, '/vault/items/0/a.enc');
    expect(listings.first.etag, '"x1"');
    expect(listings.last.etag, isNull, reason: '404 的 response 必须收敛成 null');
  });
}
