import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/platform/platform_capability_bridge.dart';

/// 平台能力桥：缺原生实现必须显式失败，不假装可用。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('相机扫码 / 语音 / 托盘热键缺平台实现时抛明确异常', () async {
    const channel = MethodChannel('vault/test/platform-missing');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'vault/test/platform-missing',
      (ByteData? _) async => null,
    );
    const bridge = PlatformCapabilityBridge(channel: channel);
    await expectLater(bridge.scanQr(),
        throwsA(isA<PlatformCapabilityUnavailable>()));
    await expectLater(bridge.transcribeVoice(),
        throwsA(isA<PlatformCapabilityUnavailable>()));
    await expectLater(bridge.registerTrayHotkey(),
        throwsA(isA<PlatformCapabilityUnavailable>()));
  });

  test('自动填充候选含密码/TOTP 时在本地拒绝，不发平台通道', () async {
    const bridge = PlatformCapabilityBridge(
      channel: MethodChannel('vault/test/platform-never'),
    );
    await expectLater(
      bridge.publishAutofillCandidates(<Map<String, Object?>>[
        <String, Object?>{'entry_id': 'e1', 'password': 'secret'},
      ]),
      throwsA(isA<FormatException>()),
    );
  });
}
