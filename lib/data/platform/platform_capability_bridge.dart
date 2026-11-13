/// 平台能力 Dart 桥（docs/08 / M8）。
///
/// 这些接口不假装系统能力已实现：原生模块没注册时明确抛
/// [PlatformCapabilityUnavailable]，由 UI 显示「需平台实现」。
/// 任何返回的自动填充候选都**不含密码 / TOTP 明文**；填充时由原生层
/// 经系统认证再调用 `vault/vault` 的受限方法取密钥（本轮未开放）。
library;

import 'package:flutter/services.dart';

const String kPlatformCapabilityChannel = 'vault/platform';
const MethodChannel _channel = MethodChannel(kPlatformCapabilityChannel);

class PlatformCapabilityUnavailable implements Exception {
  const PlatformCapabilityUnavailable(this.capability);
  final String capability;

  @override
  String toString() =>
      '平台能力 $capability 尚未接入原生实现，请用应用内可用路径';
}

class QrScanResult {
  const QrScanResult({required this.value, required this.hint});
  final String value;
  final String hint;
}

class VoiceTranscriptionResult {
  const VoiceTranscriptionResult({required this.text, required this.hint});
  final String text;
  final String hint;
}

class PlatformCapabilityBridge {
  const PlatformCapabilityBridge({this.channel = _channel});

  final MethodChannel channel;

  Future<T> _invoke<T>(String capability, String method,
      [Map<String, Object?>? args]) async {
    try {
      final result = await channel.invokeMethod<T>(method, args);
      if (result == null) {
        throw PlatformCapabilityUnavailable(capability);
      }
      return result;
    } on MissingPluginException {
      throw PlatformCapabilityUnavailable(capability);
    } on PlatformException catch (e) {
      if (e.code == 'unavailable') {
        throw PlatformCapabilityUnavailable(capability);
      }
      rethrow;
    }
  }

  /// 相机扫码：返回 otpauth:// 或任意二维码文本；需要平台图像识别。
  Future<QrScanResult> scanQr() async {
    final value = await _invoke<String>('qr_scan', 'scanQr');
    return QrScanResult(value: value, hint: '已读取二维码');
  }

  /// 语音转日记：返回转写文本；需要平台录音/STT 权限与实现。
  Future<VoiceTranscriptionResult> transcribeVoice() async {
    final text = await _invoke<String>('voice', 'transcribeVoice');
    return VoiceTranscriptionResult(text: text, hint: '语音已转写');
  }

  /// Windows 托盘 / 全局热键注册：需要原生窗口实现。
  Future<bool> registerTrayHotkey() async =>
      await _invoke<bool>('tray_hotkey', 'registerTrayHotkey');

  /// 向系统 Autofill / Credential Provider 提供候选（不含密钥材料）。
  Future<bool> publishAutofillCandidates(
      List<Map<String, Object?>> candidates) async {
    for (final candidate in candidates) {
      if (candidate.containsKey('password') ||
          candidate.containsKey('totp_secret')) {
        throw const FormatException('自动填充候选不得包含密钥材料');
      }
    }
    return _invoke<bool>('autofill', 'publishAutofillCandidates',
        <String, Object?>{'candidates': candidates});
  }
}
