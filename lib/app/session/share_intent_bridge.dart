import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../data/archive/share_intent_parser.dart';
import '../../data/db/tables/entry_tables.dart';
import '../../data/write/write_gateway.dart';
import 'vault_session.dart';

const String kShareIntentChannel = 'vault/share';
const MethodChannel _channel = MethodChannel(kShareIntentChannel);

/// 系统剪藏分享桥（docs/08 §4）。
///
/// Android ACTION_SEND 由 MainActivity 接收并在 Flutter 引擎就绪后经
/// `MethodChannel` 推送；iOS Share Extension 需独立 target，当前通过
/// 同一通道接口预留。真实抓取仍由主 App 队列消费，这里只接收不联网。
class ShareIntentBridge {
  const ShareIntentBridge({this.channel = _channel});

  final MethodChannel channel;

  Future<ShareIntentPlan?> consumeInitial() async {
    final raw = await _invoke<String>('consumeInitial');
    if (raw == null) return null;
    return planShareIntent(raw);
  }

  Stream<ShareIntentPlan> get stream {
    return const EventChannel('$kShareIntentChannel/events')
        .receiveBroadcastStream()
        .map((Object? event) => planShareIntent(event.toString()))
        .asBroadcastStream();
  }

  Future<T?> _invoke<T>(String method) async {
    try {
      return await channel.invokeMethod<T>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// 把分享计划真实排进 job_queue；纯文本落想法条目，URL 落归档任务。
class ShareIntentConsumer {
  const ShareIntentConsumer({required this.enqueue, required this.writeNote});

  final Future<int> Function({
    required String type,
    String? payload,
    int nextRunAt,
  }) enqueue;

  /// 写一条想法（经 WriteGateway）。
  final Future<void> Function(String text) writeNote;

  Future<int> consume(ShareIntentPlan plan) async {
    if (plan.kind == ShareIntentKind.empty) return 0;
    if (plan.kind == ShareIntentKind.quickNote) {
      await writeNote(plan.text);
      return 1;
    }
    var count = 0;
    for (final item in shareQueueItems(plan)) {
      await enqueue(
        type: 'share_${item['type']}',
        payload: jsonEncode(item),
        nextRunAt: 0,
      );
      count++;
    }
    return count;
  }
}


/// 解锁后一次性消费系统分享：provider 缓存初始文本，避免多次 runApp 重复落库。
final FutureProvider<ShareIntentPlan?> initialShareIntentProvider =
    FutureProvider<ShareIntentPlan?>((Ref ref) async =>
        const ShareIntentBridge().consumeInitial());

final Provider<ShareIntentConsumer> shareIntentConsumerProvider =
    Provider<ShareIntentConsumer>((Ref ref) {
  return ShareIntentConsumer(
    enqueue: ({required String type, String? payload, int nextRunAt = 0}) =>
        ref.read(writeGatewayProvider).enqueueArchiveJob(
              type: type,
              payload: payload,
              nextRunAt: nextRunAt,
            ),
    writeNote: (String text) async {
      await ref.read(writeGatewayProvider).writeEntry(EntryWrite.create(
            kind: EntryKind.thought,
            body: text,
          ));
    },
  );
});

/// VaultApp 在解锁态 watch 它：只触发一次冷启动消费。
final FutureProvider<int> consumeInitialShareAfterUnlockProvider =
    FutureProvider<int>((Ref ref) => consumeInitialShareIntent(ref));

/// 会话解锁后调用：把冷启动分享落进真实队列 / 想法。
Future<int> consumeInitialShareIntent(Ref ref) async {
  final session = ref.read(vaultSessionProvider);
  if (!session.isUnlocked) return 0;
  final plan = await ref.read(initialShareIntentProvider.future);
  if (plan == null) return 0;
  return ref.read(shareIntentConsumerProvider).consume(plan);
}
