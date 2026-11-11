import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_meta.dart';

/// kind=5 meta 的「解析即校验」测试。
void main() {
  const String url = 'https://www.Example.com:443/post/123?utm=x';

  ArchiveMeta sample() => ArchiveMeta(
        url: url,
        site: ArchiveMeta.siteOf(url),
        status: ArchiveStatus.full,
        finalUrl: url,
        title: 'RFC 6578',
        httpStatus: 200,
        lastCheckedAt: 1731052800000,
        policy: RecheckPolicy.monthly,
        snapshotBytes: 412000,
        excerpt: 'sync-collection 报告允许客户端…',
        highlights: const <ArchiveHighlight>[
          ArchiveHighlight(text: '增量', offset: 12, note: '重点'),
        ],
      );

  test('JSON 往返保真，且序列化确定性', () {
    final meta = sample();
    final decoded = ArchiveMeta.fromJson(jsonDecode(meta.toJsonString()));
    expect(decoded.url, url);
    expect(decoded.site, 'example.com');
    expect(decoded.status, ArchiveStatus.full);
    expect(decoded.snapshotBytes, 412000);
    expect(decoded.highlights.single.offset, 12);
    expect(decoded.toJsonString(), meta.toJsonString());
    // 键序无关：手工调换顺序不应影响解析结果。
    final shuffled = <String, Object?>{
      'archive_status': 'full',
      'url': url,
      'site': 'example.com',
    };
    expect(ArchiveMeta.fromJson(shuffled).status, ArchiveStatus.full);
  });

  test('site 聚合去掉 www 与端口，只接受 http/https', () {
    expect(ArchiveMeta.siteOf(url), 'example.com');
    expect(ArchiveMeta.siteOf('http://blog.example.org/a'), 'blog.example.org');
    expect(
      () => ArchiveMeta.siteOf('ftp://example.com/a'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ArchiveMeta.siteOf('not a url'),
      throwsA(isA<FormatException>()),
    );
  });

  test('非法枚举 / 字段类型 / 超长摘要一律在边界拒绝', () {
    Object? broken(Object? patch) => <String, Object?>{
          'url': 'https://example.com/a',
          'site': 'example.com',
          'archive_status': 'full',
          ...(patch as Map<String, Object?>),
        };

    expect(
      () => ArchiveMeta.fromJson(broken(<String, Object?>{'archive_status': 'wat'})),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ArchiveMeta.fromJson(broken(<String, Object?>{'recheck_policy': 'daily'})),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ArchiveMeta.fromJson(broken(<String, Object?>{'snapshot_bytes': '412000'})),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ArchiveMeta.fromJson(broken(<String, Object?>{'excerpt': 'x' * 201})),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ArchiveMeta.fromJson('not an object'),
      throwsA(isA<FormatException>()),
    );
  });

  test('空 meta 按「仅元数据」降级，不抛错', () {
    final meta = ArchiveMeta.fromMetaString(null, fallbackUrl: url);
    expect(meta.status, ArchiveStatus.metadata);
    expect(meta.site, 'example.com');
    expect(meta.hasText, isFalse);
  });

  test('状态语义：hasText / hasSnapshot / isDeadLink', () {
    expect(ArchiveStatus.text.hasText, isTrue);
    expect(ArchiveStatus.full.hasSnapshot, isTrue);
    expect(ArchiveStatus.metadata.hasText, isFalse);
    expect(ArchiveStatus.dead.isDeadLink, isTrue);
    expect(ArchiveStatus.blocked.hasText, isTrue,
        reason: '反爬页也可能已提取到正文层');
  });

  test('重检查策略驱动下次检查时间，never 不排任务', () {
    final meta = sample();
    expect(
      meta.nextCheckAt(),
      1731052800000 + const Duration(days: 30).inMilliseconds,
    );
    expect(
      meta.copyWith(policy: RecheckPolicy.weekly).nextCheckAt(),
      1731052800000 + const Duration(days: 7).inMilliseconds,
    );
    expect(meta.copyWith(policy: RecheckPolicy.never).nextCheckAt(), isNull);
    expect(
      meta.copyWith(clearLastCheckedAt: true).nextCheckAt(),
      isNull,
      reason: '还没检查过的条目不该排定时重检查，应先做首次抓取',
    );
  });

  test('copyWith 换 URL 时同步重算 site', () {
    final changed = sample().copyWith(url: 'https://github.com/a/b');
    expect(changed.site, 'github.com');
    expect(changed.url, 'https://github.com/a/b');
  });
}
