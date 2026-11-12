import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/archive/content_change_policy.dart';
import 'package:vault/data/archive/content_change_service.dart';
import 'package:vault/data/archive/http_archive_fetcher.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/db/vault_database.dart' show LinkCheckRow;
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

/// docs/05 §6.2：真实重抓 + simhash 变更 + 旧版 history 端到端。
class _PageServer {
  _PageServer(this.server);
  final HttpServer server;
  String body = '旧正文';
  String get url => 'http://127.0.0.1:${server.port}/p';

  static Future<_PageServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _PageServer(server);
    server.listen((HttpRequest request) async {
      request.response.headers.set('Content-Type', 'text/html; charset=utf-8');
      request.response.add(utf8.encode('<article><p>${site.body}</p></article>'));
      await request.response.close();
    });
    return site;
  }

  void close() => server.close(force: true);
}

void main() {
  late TestApp app;
  late _PageServer site;
  late HttpArchiveFetcher fetcher;

  setUp(() async {
    app = await TestApp.create();
    site = await _PageServer.start();
    fetcher = HttpArchiveFetcher(connectTimeout: const Duration(seconds: 2));
  });
  tearDown(() async {
    fetcher.close();
    site.close();
    await app.dispose();
  });

  test('首次生成指纹；内容改写后更新正文、落 history 与 changed 证据',
      () async {
    final meta = ArchiveMeta(
      url: site.url,
      site: '127.0.0.1',
      status: ArchiveStatus.text,
      watchChanges: true,
    );
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'arch-change',
      kind: EntryKind.bookmark,
      title: '关注变更的归档',
      body: '旧正文',
      meta: meta.toJsonString(),
    ));
    final service = ContentChangeService(
      db: app.db,
      gateway: app.gateway,
      fetcher: fetcher,
    );

    site.body = '第一段旧正文内容，讲的是 WebDAV 限流与退避策略，'
        '还有本地队列积压量对降频的影响，篇幅足够长以便指纹稳定。';
    final first = await service.checkAndApply(
      entryId: 'arch-change',
      nowMs: 1731052800000,
    );
    expect(first.ok, isTrue);
    expect(first.plan!.action, ContentChangeAction.firstSnapshot);
    expect(first.simhash, isNotNull);

    site.body = '完全不同的新主题 ALPHA BETA GAMMA DELTA EPSILON 001 002 003 '
        '004 005 006 007 008 009 010 011 012 013 014 015 016 017 018 019 020 '
        'kubernetes postgresql rust tokio grpc protobuf observability tracing '
        'vector index quantization embedding cosine transformer attention';
    final second = await service.checkAndApply(
      entryId: 'arch-change',
      nowMs: 1731052860000,
    );
    expect(second.ok, isTrue);
    expect(second.plan!.action, ContentChangeAction.promptChange);
    expect(second.plan!.keepPreviousAsHistory, isTrue);

    final row = await app.repo.getRow('arch-change');
    expect(row!.body, contains('ALPHA BETA GAMMA'));
    final written = ArchiveMeta.fromJson(jsonDecode(row.meta!));
    expect(written.changed, isTrue);
    expect(written.excerpt, contains('ALPHA BETA'));
    final history = await app.db.select(app.db.entryHistory).get();
    expect(history, isNotEmpty, reason: '更新应把旧版写进 entry_history');
    final checks = await app.db.select(app.db.linkChecks).get();
    expect(checks, hasLength(2));
    expect(checks.any((LinkCheckRow c) => c.result == 'changed'), isTrue);
  });

  test('正文未实质变化时只落 ok 证据，不制造新版本', () async {
    final meta = ArchiveMeta(
      url: site.url,
      site: '127.0.0.1',
      status: ArchiveStatus.text,
    );
    await app.gateway.writeEntry(EntryWrite.create(
      id: 'arch-stable',
      kind: EntryKind.bookmark,
      title: '稳定归档',
      body: '稳定正文',
      meta: meta.toJsonString(),
    ));
    final service = ContentChangeService(
      db: app.db,
      gateway: app.gateway,
      fetcher: fetcher,
    );
    site.body = '稳定正文内容 A B C D E F G H I J K L M N O P Q R S T';
    await service.checkAndApply(
      entryId: 'arch-stable',
      nowMs: 1731052800000,
    );
    final before = await app.repo.getRow('arch-stable');
    site.body = '稳定正文内容 A B C D E F G H I J K L M N O P Q R S T！';
    final second = await service.checkAndApply(
      entryId: 'arch-stable',
      nowMs: 1731052860000,
    );
    expect(second.plan!.action, ContentChangeAction.unchanged);
    final after = await app.repo.getRow('arch-stable');
    expect(after!.rev, before!.rev);
  });
}
