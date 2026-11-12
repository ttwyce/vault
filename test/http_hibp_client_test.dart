import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/hibp_client.dart';
import 'package:vault/data/vault/http_hibp_client.dart';

/// docs/11 §4.4：真实 HIBP GET 用本地 HttpServer 验证，跳过真机/外网。
class _RangeServer {
  _RangeServer(this.server);
  final HttpServer server;
  String body = '';
  int status = 200;
  final List<String> paths = <String>[];

  static Future<_RangeServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _RangeServer(server);
    server.listen((HttpRequest request) async {
      site.paths.add(request.uri.path);
      request.response.statusCode = site.status;
      request.response.write(site.body);
      await request.response.close();
    });
    return site;
  }

  String get baseUrl => 'http://127.0.0.1:${server.port}';
  void close() => server.close(force: true);
}

void main() {
  late _RangeServer site;
  late HttpHibpClient client;

  setUp(() async {
    site = await _RangeServer.start();
    client = HttpHibpClient(
      baseUrl: site.baseUrl,
      connectTimeout: const Duration(seconds: 2),
    );
  });
  tearDown(() {
    client.close();
    site.close();
  });

  test('只把前 5 位前缀放进 URL，完整哈希绝不出设备', () async {
    final checker = HibpChecker();
    final request = checker.requestFor('password123!');
    site.body = '${request.suffix}:12345\r\n';
    final result = await client.fetchRange(request);
    expect(result.body, isNotNull);
    expect(site.paths.single, '/range/${request.prefix}');
    expect(site.paths.single, isNot(contains(request.suffix)));
    checker.store(request.prefix, checker.parseResponse(result.body!), 1);
    expect(checker.isBreached(request, 1), isTrue);
  });

  test('响应无命中 → 未泄露', () async {
    final checker = HibpChecker();
    final request = checker.requestFor('some-other-password');
    site.body = '00000000000000000000000000000000000:1\r\n';
    final result = await client.fetchRange(request);
    checker.store(request.prefix, checker.parseResponse(result.body!), 1);
    expect(checker.isBreached(request, 1), isFalse);
  });

  test('HTTP 500 / 非法前缀 / 断连都不返回可用 body', () async {
    final suffix = 'F' * 35;
    final request = HibpRequest(prefix: 'ABCDE', suffix: suffix);
    site.status = 500;
    expect((await client.fetchRange(request)).body, isNull);
    expect(
      (await client.fetchRange(
        HibpRequest(prefix: 'bad', suffix: suffix),
      )).body,
      isNull,
    );
    final base = site.baseUrl;
    site.close();
    client.close();
    client = HttpHibpClient(
      baseUrl: base,
      connectTimeout: const Duration(milliseconds: 200),
    );
    final down = await client.fetchRange(request);
    expect(down.body, isNull);
    expect(down.hint, contains('未知'));
  });
}
