import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_duplicate.dart';

/// docs/05 §4 第 1 步 归档 URL 去重测试。
void main() {
  test('规范化：去跟踪参数/fragment/尾斜杠/默认端口、host 小写', () {
    expect(
      normalizeArchiveUrl(
        'https://Example.com:443/post/?utm_source=x&a=1#section',
      ),
      'https://example.com/post?a=1',
    );
    expect(normalizeArchiveUrl('http://x.com:80/a/'), 'http://x.com/a');
    expect(normalizeArchiveUrl('ftp://x.com/a'), isNull);
    expect(normalizeArchiveUrl('not-a-url'), isNull);
  });

  test('同 URL 已归档 → 提示更新快照；新 URL → 新建', () {
    final existing = <({String entryId, String url, String? finalUrl})>[
      (
        entryId: 'a1',
        url: 'https://example.com/post?utm_source=rss',
        finalUrl: 'https://example.com/post?from=app',
      ),
    ];
    final duplicate = planArchiveDuplicate(
      rawUrl: 'https://example.com/post/#x',
      existing: existing,
    );
    expect(duplicate.action, ArchiveDuplicateAction.askUpdate);
    expect(duplicate.existingEntryId, 'a1');
    expect(duplicate.reason, contains('更新快照'));
    expect(duplicate.toJson()['action'], 'askUpdate');

    final fresh = planArchiveDuplicate(
      rawUrl: 'https://example.com/other',
      existing: existing,
    );
    expect(fresh.action, ArchiveDuplicateAction.create);
  });

  test('finalUrl 命中也算重复；非法 URL 不进入流水线', () {
    final plan = planArchiveDuplicate(
      rawUrl: 'javascript:alert(1)',
      existing: const <({String entryId, String url, String? finalUrl})>[],
    );
    expect(plan.action, ArchiveDuplicateAction.invalid);
    expect(plan.reason, contains('http/https'));

    final byFinal = planArchiveDuplicate(
      rawUrl: 'https://final.example/p',
      existing: <({String entryId, String url, String? finalUrl})>[
        (
          entryId: 'b',
          url: 'https://short.example/x',
          finalUrl: 'https://final.example/p?utm_medium=y',
        ),
      ],
    );
    expect(byFinal.action, ArchiveDuplicateAction.askUpdate);
  });
}
