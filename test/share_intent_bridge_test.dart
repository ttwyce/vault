import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/session/share_intent_bridge.dart';
import 'package:vault/data/archive/share_intent_parser.dart';

/// 系统剪藏分享桥：解析 + 真实排队接口。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ShareIntentConsumer 把多 URL 排成归档队列，纯文本落成想法', () async {
    final queued = <Map<String, Object?>>[];
    final notes = <String>[];
    final consumer = ShareIntentConsumer(
      enqueue: ({required String type, String? payload, int nextRunAt = 0}) async {
        queued.add(<String, Object?>{
          'type': type,
          'payload': payload,
          'nextRunAt': nextRunAt,
        });
        return queued.length;
      },
      writeNote: (String text) async => notes.add(text),
    );

    final urls = planShareIntent(
        '看这两篇 https://a.example.com/x 和 https://b.example.com/y');
    expect(urls.kind, ShareIntentKind.archiveUrls);
    expect(await consumer.consume(urls), 2);
    expect(queued, hasLength(2));
    expect(queued.first['type'], 'share_archive');
    expect(notes, isEmpty);

    final note = planShareIntent('一句话想法');
    expect(await consumer.consume(note), 1);
    expect(notes, <String>['一句话想法']);
    expect(queued, hasLength(2));
    expect(await consumer.consume(planShareIntent('   ')), 0);
  });

  test('ShareIntentBridge.consumeInitial 缺平台实现时返回 null', () async {
    const channel = MethodChannel('vault/test/missing');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'vault/test/missing',
      (ByteData? _) async => null,
    );
    const bridge = ShareIntentBridge(channel: channel);
    expect(await bridge.consumeInitial(), isNull);
  });
}
