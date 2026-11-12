import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/http_link_checker.dart';
import 'package:vault/data/archive/archive_policy.dart';

/// docs/05 §6.1：真实 HEAD 链路用本地 HttpServer 验证，不需要真机 / 外网。
class _Site {
  _Site(this.server);
  final HttpServer server;
  int mode = 200; // 200 / 404 / 403 / 302
  String? redirectTo;
  final List<String> methods = <String>[];

  static Future<_Site> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _Site(server);
    server.listen((HttpRequest request) async {
      site.methods.add(request.method);
      if (request.uri.path == '/final') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }
      if (site.mode == 302 && site.redirectTo != null) {
        request.response.statusCode = 302;
        request.response.headers.set(HttpHeaders.locationHeader, site.redirectTo!);
      } else {
        request.response.statusCode = site.mode;
      }
      await request.response.close();
    });
    return site;
  }

  String url(String path) => 'http://127.0.0.1:${server.port}$path';
  void close() => server.close(force: true);
}

void main() {
  late _Site site;
  late HttpLinkChecker checker;

  setUp(() async {
    site = await _Site.start();
    checker = HttpLinkChecker(connectTimeout: const Duration(seconds: 2));
  });
  tearDown(() {
    checker.close();
    site.close();
  });

  test('HEAD 200 → 存活，且真的发了 HEAD 不是 GET', () async {
    final obs = await checker.check(site.url('/ok'));
    expect(obs.httpStatus, 200);
    expect(obs.retries, 0);
    expect(obs.finalUrl, isNull);
    expect(site.methods, <String>['HEAD']);
    expect(classifyHttpStatus(obs.httpStatus, retries: obs.retries).name, 'ok');
  });

  test('404 → dead，403 → restricted', () async {
    site.mode = 404;
    final dead = await checker.check(site.url('/gone'));
    expect(dead.httpStatus, 404);
    expect(classifyHttpStatus(404, retries: 0).name, 'dead');

    site.mode = 403;
    final restricted = await checker.check(site.url('/blocked'));
    expect(restricted.httpStatus, 403);
    expect(classifyHttpStatus(403, retries: 0).name, 'restricted');
  });

  test('302 跟随 Location 并记录最终 URL', () async {
    final target = site.url('/final');
    site.mode = 302;
    site.redirectTo = target;
    final obs = await checker.check(site.url('/start'));
    // 跟随到 /final 后返回 200。
    expect(obs.httpStatus, 200);
    expect(obs.finalUrl, isNotNull);
    expect(site.methods.length, greaterThan(1));
  });

  test('DNS/连接失败重试 2 次后 unreachable', () async {
    // 先取 URL 再关服务器，让连接失败。
    final down = site.url('/down');
    site.close();
    final obs = await checker.check(down);
    expect(obs.httpStatus, isNull);
    expect(obs.retries, 2);
    expect(obs.reason, contains('网络不可达'));
    expect(classifyHttpStatus(null, retries: 2).name, 'unreachable');
  });

  test('非法 URL 不发请求', () async {
    final obs = await checker.check('ftp://example.com/x');
    expect(obs.httpStatus, isNull);
    expect(obs.reason, contains('URL 非法'));
    expect(site.methods, isEmpty);
  });
}
