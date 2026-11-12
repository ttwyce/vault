import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/http_wayback_client.dart';

/// docs/05 §6.1：真实 Wayback GET 用本地 HttpServer 验证，跳过真机/外网。
class _WaybackServer {
  _WaybackServer(this.server);
  final HttpServer server;
  String? body;
  int status = 200;
  final List<String> queryUrls = <String>[];
  final List<String> savePaths = <String>[];

  static Future<_WaybackServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _WaybackServer(server);
    server.listen((HttpRequest request) async {
      if (request.method == 'POST') {
        site.savePaths.add(request.uri.path);
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }
      site.queryUrls.add(request.uri.queryParameters['url'] ?? '');
      request.response.statusCode = site.status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(site.body ?? '{}');
      await request.response.close();
    });
    return site;
  }

  String get baseUrl => 'http://127.0.0.1:${server.port}';
  void close() => server.close(force: true);
}

void main() {
  late _WaybackServer site;
  late HttpWaybackClient client;

  setUp(() async {
    site = await _WaybackServer.start();
    client = HttpWaybackClient(
      baseUrl: site.baseUrl,
      connectTimeout: const Duration(seconds: 2),
    );
  });
  tearDown(() {
    client.close();
    site.close();
  });

  test('有 closest 快照 → 返回可用 URL 与日期提示，且 URL 正确编码', () async {
    site.body = jsonEncode(<String, Object?>{
      'archived_snapshots': <String, Object?>{
        'closest': <String, Object?>{
          'available': true,
          'timestamp': '20190312093015',
          'url': 'https://web.archive.org/web/20190312093015/https://example.com/p',
        },
      },
    });
    final result = await client.findSnapshot('https://example.com/p?q=1');
    expect(result.available, isTrue);
    expect(result.hint, contains('2019-03-12'));
    expect(result.archiveUrl, contains('web.archive.org'));
    expect(site.queryUrls.single, 'https://example.com/p?q=1');
  });

  test('无快照 → 建议手动提交', () async {
    site.body = jsonEncode(<String, Object?>{'archived_snapshots': <String, Object?>{}});
    final result = await client.findSnapshot('https://example.com/p');
    expect(result.available, isFalse);
    expect(result.hint, contains('手动提交'));
  });

  test('HTTP 500 / 坏 JSON 不假装可用', () async {
    site.status = 500;
    final serverError = await client.findSnapshot('https://example.com/p');
    expect(serverError.available, isFalse);
    expect(serverError.hint, contains('HTTP 500'));

    site.status = 200;
    site.body = '{坏 JSON';
    final bad = await client.findSnapshot('https://example.com/p');
    expect(bad.available, isFalse);
    expect(bad.hint, contains('手动提交'));
  });

  test('连接失败 → 网络不可达提示', () async {
    final base = site.baseUrl;
    site.close();
    client.close();
    client = HttpWaybackClient(
      baseUrl: base,
      connectTimeout: const Duration(milliseconds: 200),
    );
    final result = await client.findSnapshot('https://example.com/p');
    expect(result.available, isFalse);
    expect(result.hint, contains('网络不可达'));
  });

  test('Save Page Now 需用户显式勾选才真实 POST URL', () async {
    final withoutOptIn = await client.submitSave(
      targetUrl: 'https://example.com/p',
      userOptedIn: false,
    );
    expect(withoutOptIn, contains('未勾选'));
    expect(site.savePaths, isEmpty);

    final submitted = await client.submitSave(
      targetUrl: 'https://example.com/p',
      userOptedIn: true,
    );
    expect(submitted, contains('已提交'));
    expect(site.savePaths, hasLength(1));
    expect(site.savePaths.single, contains('example.com/p'));
  });
}
