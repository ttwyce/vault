/// RFC 6238 TOTP（docs/09 §8：与主流验证器一致）。
///
/// 纯 Dart：Base32 解码自实现，HMAC-SHA1 用项目已有的 `crypto` 包，
/// 不新增依赖、不碰网络、不读系统时间以外的数据。
/// 验证码只在内存里生成，绝不写日志或 prompt。
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Base32（RFC 4648，无填充、大小写不敏感、忽略空格）。
Uint8List decodeBase32(String secret) {
  const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final cleaned = secret
      .toUpperCase()
      .replaceAll(RegExp(r'[\s=]+'), '');
  if (cleaned.isEmpty) {
    throw const FormatException('TOTP 密钥为空');
  }
  final out = BytesBuilder();
  var buffer = 0;
  var bits = 0;
  for (final unit in cleaned.codeUnits) {
    final index = alphabet.indexOf(String.fromCharCode(unit));
    if (index < 0) {
      throw FormatException('TOTP 密钥含非法 Base32 字符：${String.fromCharCode(unit)}');
    }
    buffer = (buffer << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.addByte((buffer >> bits) & 0xFF);
    }
  }
  return out.takeBytes();
}

/// 生成某个 Unix 毫秒时刻的 TOTP。
String generateTotp({
  required String base32Secret,
  required int nowMs,
  int periodSeconds = 30,
  int digits = 6,
}) {
  if (periodSeconds <= 0 || digits <= 0 || digits > 10) {
    throw ArgumentError('TOTP 周期与位数不合法');
  }
  final key = decodeBase32(base32Secret);
  final counter = nowMs ~/ (periodSeconds * 1000);
  final message = Uint8List(8);
  var value = counter;
  for (var i = 7; i >= 0; i--) {
    message[i] = value & 0xFF;
    value >>= 8;
  }
  final hmac = Hmac(sha1, key).convert(message).bytes;
  final offset = hmac[hmac.length - 1] & 0x0F;
  final binary = ((hmac[offset] & 0x7F) << 24) |
      ((hmac[offset + 1] & 0xFF) << 16) |
      ((hmac[offset + 2] & 0xFF) << 8) |
      (hmac[offset + 3] & 0xFF);
  final modulus = _pow10(digits);
  return (binary % modulus).toString().padLeft(digits, '0');
}

/// 当前 30 秒窗口还剩多少毫秒。UI 用它画倒计时环。
int totpRemainingMs(int nowMs, {int periodSeconds = 30}) {
  final periodMs = periodSeconds * 1000;
  return periodMs - (nowMs % periodMs);
}

int _pow10(int n) {
  var result = 1;
  for (var i = 0; i < n; i++) {
    result *= 10;
  }
  return result;
}
