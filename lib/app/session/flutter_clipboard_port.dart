import 'package:flutter/services.dart';

import '../../data/vault/sensitive_clipboard.dart';

/// Flutter 平台剪贴板适配（唯一需要 MethodChannel 的地方）。
class FlutterClipboardPort implements ClipboardPort {
  const FlutterClipboardPort();

  @override
  Future<void> write(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<String?> read() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
