import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/site_feed.dart';
import 'package:vault/data/taxonomy/tag_cluster.dart';

/// RSS/整站计划 + 标签聚类建议。
void main() {
  test('parseFeedUrls 兼容 RSS link 与 Atom href，去重', () {
    const xml = '''<rss><channel>
      <item><link>https://a.example.com/1</link></item>
      <item><link><![CDATA[https://a.example.com/2]]></link></item>
      <entry><link href="https://a.example.com/1"/></entry>
      <item><link>/relative</link></item>
    </channel></rss>''';
    expect(parseFeedUrls(xml), <String>[
      'https://a.example.com/1',
      'https://a.example.com/2',
    ]);
  });

  test('HttpSiteFeed 从本地服务器真实读取并生成整站排队计划', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((HttpRequest request) async {
      request.response.headers.contentType = ContentType('application','xml');
      request.response.write(
          '<feed><entry><link href="https://blog.example.com/p1"/></entry>'
          '<entry><link href="https://blog.example.com/p2"/></entry></feed>');
      await request.response.close();
    });
    final feed = HttpSiteFeed();
    addTearDown(feed.close);
    final result = await feed.fetch(
        Uri.parse('http://127.0.0.1:${server.port}/feed.xml'));
    expect(result.ok, isTrue);
    expect(result.urls, hasLength(2));
    final plan = planSiteArchive(
      feedUrl: 'https://blog.example.com/feed.xml',
      urls: result.urls,
      maxItems: 1,
    );
    expect(plan.site, 'blog.example.com');
    expect(plan.queueItems(), hasLength(1));
    expect(plan.queueItems().single['type'], 'site_archive');
    expect(jsonEncode(plan.queueItems()), contains('blog.example.com'));
  });

  test('标签聚类给出共现对与相似名分组，不写库', () {
    final suggestion = planTagClusters(
      entries: <List<String>>[
        <String>['t1', 't2'],
        <String>['t1', 't2'],
        <String>['t2', 't3'],
      ],
      names: <String, String>{
        't1': 'WebDAV',
        't2': 'web dav',
        't3': '同步',
      },
    );
    expect(suggestion.cooccurrences.first.count, 2);
    expect(suggestion.groups, hasLength(1));
    expect(suggestion.groups.single, <String>['t1', 't2']);
    expect(suggestion.hint, contains('1 组相似标签'));
  });
}
