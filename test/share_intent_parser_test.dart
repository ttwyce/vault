import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/share_intent_parser.dart';

/// docs/08 §4 剪藏分享意图判定测试。
void main() {
  test('单 URL / 多 URL / 尾随标点 / 去重', () {
    expect(
      extractShareUrls('看看这个 https://example.com/a 吧'),
      <String>['https://example.com/a'],
    );
    expect(
      extractShareUrls('https://a.com/x。https://b.com/y，https://a.com/x'),
      <String>['https://a.com/x', 'https://b.com/y'],
    );
    expect(extractShareUrls('ftp://x/y 和 file:///tmp/a'), isEmpty);
  });

  test('有 URL → 归档队列；纯文本 → 想法；空白 → 忽略', () {
    final archive = planShareIntent(
      '这篇好 https://example.com/p 还有 https://other.com/q',
    );
    expect(archive.kind, ShareIntentKind.archiveUrls);
    expect(archive.reason, contains('只接收不抓取'));
    final queue = shareQueueItems(archive);
    expect(queue, hasLength(2));
    expect(queue.first['type'], 'archive');
    expect(queue.first['site'], 'example.com');

    final note = planShareIntent('  今天想到一个好点子  ');
    expect(note.kind, ShareIntentKind.quickNote);
    expect(shareQueueItems(note).single['text'], '今天想到一个好点子');

    expect(planShareIntent('   ').kind, ShareIntentKind.empty);
    expect(shareQueueItems(planShareIntent('   ')), isEmpty);
  });

  test('JSON 可导出，供平台层写入 App Group / UserDefaults 队列', () {
    final plan = planShareIntent('https://example.com/p');
    expect(plan.toJson()['kind'], 'archiveUrls');
    expect(shareQueueItems(plan).single['url'], 'https://example.com/p');
  });
}
