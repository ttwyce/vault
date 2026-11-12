import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/clipboard_archive_hint.dart';

/// docs/05 §3 剪贴板 URL 自动识别提示测试。
void main() {
  ClipboardHintDecision decide(
    String text, {
    String? lastPrompted,
    bool foreground = true,
    bool allowed = true,
  }) =>
      decideClipboardArchiveHint(
        text,
        lastPrompted: lastPrompted,
        appInForeground: foreground,
        userAllowedClipboard: allowed,
      );

  test('前台单 URL 弹提示，不自动抓取', () {
    final d = decide('看看这个 https://example.com/p');
    expect(d.action, ClipboardHintAction.askArchive);
    expect(d.shouldPrompt, isTrue);
    expect(d.urls, <String>['https://example.com/p']);
    expect(d.reason, contains('不自动抓取'));
  });

  test('多 URL 走批量不弹气泡；非 URL 不提示', () {
    final batch = decide('https://a.com/x https://b.com/y');
    expect(batch.action, ClipboardHintAction.openBatch);
    expect(batch.urls, hasLength(2));
    expect(decide('普通文字').shouldPrompt, isFalse);
  });

  test('后台 / 未授权 / 已提示过 / 空内容一律不打扰', () {
    expect(decide('https://a.com', foreground: false).shouldPrompt, isFalse);
    expect(decide('https://a.com', allowed: false).shouldPrompt, isFalse);
    expect(
      decide('https://a.com', lastPrompted: 'https://a.com').reason,
      contains('不重复打扰'),
    );
    expect(decide('   ').shouldPrompt, isFalse);
  });
}
