import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/http_archive_fetcher.dart';

/// docs/05 §5：真实 GET + 纯 Dart 正文抽取用本地 HttpServer 验证。
class _PageServer {
  _PageServer(this.server);
  final HttpServer server;
  int status = 200;
  String html = '';
  String get url => 'http://127.0.0.1:${server.port}/p';

  static Future<_PageServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _PageServer(server);
    server.listen((HttpRequest request) async {
      request.response.statusCode = site.status;
      request.response.headers.set('Content-Type', 'text/html; charset=utf-8');
      request.response.add(utf8.encode(site.html));
      await request.response.close();
    });
    return site;
  }

  void close() => server.close(force: true);
}

void main() {
  late _PageServer site;
  late HttpArchiveFetcher fetcher;

  setUp(() async {
    site = await _PageServer.start();
    fetcher = HttpArchiveFetcher(connectTimeout: const Duration(seconds: 2));
  });
  tearDown(() {
    fetcher.close();
    site.close();
  });

  test('抽取 title / article 正文 / 标题换行，去掉 script 与样式',
      () async {
    site.html = '<html><head><title>测试 &amp; 页面</title>'
        '<style>隐藏样式</style><script>alert(1)</script></head>'
        '<body><nav>导航噪声</nav><article><h2>小节</h2>'
        '<p>第一段正文。</p><p>第二段 &lt;正文&gt;。</p></article></body></html>';
    final result = await fetcher.fetch(Uri.parse(site.url));
    expect(result.ok, isTrue);
    expect(result.title, '测试 & 页面');
    expect(result.body, contains('## 小节'));
    expect(result.body, contains('第一段正文。'));
    expect(result.body, contains('第二段 <正文>。'));
    expect(result.body, isNot(contains('alert(1)')));
    expect(result.body, isNot(contains('隐藏样式')));
  });

  test('没有 article 时退化到 body；正文为空不写空条目', () async {
    site.html = '<html><body><p>只有一段正文</p></body></html>';
    final ok = await fetcher.fetch(Uri.parse(site.url));
    expect(ok.ok, isTrue);
    expect(ok.body, '只有一段正文');

    site.html = '<html><body><script>x</script></body></html>';
    final empty = await fetcher.fetch(Uri.parse(site.url));
    expect(empty.ok, isFalse);
    expect(empty.body, isNull);
  });

  test('404 / 非法 scheme / 断连都不写正文', () async {
    site.status = 404;
    final notFound = await fetcher.fetch(Uri.parse(site.url));
    expect(notFound.ok, isFalse);
    expect(notFound.hint, contains('404'));
    final invalid = await fetcher.fetch(Uri.parse('ftp://example.com/x'));
    expect(invalid.ok, isFalse);

    final url = site.url;
    site.close();
    final down = await fetcher.fetch(Uri.parse(url));
    expect(down.ok, isFalse);
    expect(down.body, isNull);
  });
}
