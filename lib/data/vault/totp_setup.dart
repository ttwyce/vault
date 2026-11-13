/// TOTP 绑定 / otpauth URI 解析（docs/09 §8）。
///
/// 不新增依赖：相机扫码需要平台通道，本层先支持粘贴 `otpauth://` 链接
/// 与手动输入 Base32 密钥（等价于扫码得到的内容），并校验格式/参数。
/// 真实密钥写入由 CredentialRepository.setTotpSecret 字段级加密完成。
library;

import 'dart:core';

class TotpSetupResult {
  const TotpSetupResult({required this.secret, required this.label});

  final String secret;
  final String label;
}

/// 解析 `otpauth://totp/<label>?secret=<base32>&issuer=<issuer>`。
/// 坏 scheme / 缺 secret / 非法参数一律返回 null，不抛异常到 UI。
TotpSetupResult? parseOtpauthUri(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'otpauth' || uri.host != 'totp') return null;
  final secret = (uri.queryParameters['secret'] ?? '').toUpperCase();
  if (secret.isEmpty) return null;
  if (!RegExp(r'^[A-Z2-7]+=*$').hasMatch(secret)) return null;
  final path = Uri.decodeComponent(uri.path.replaceAll(RegExp(r'^/+'), ''));
  final issuer = uri.queryParameters['issuer'] ?? '';
  final label = path.isEmpty ? (issuer.isEmpty ? 'TOTP' : issuer) : path;
  return TotpSetupResult(secret: secret, label: label);
}

/// 清掉用户从验证器复制来的空格 / 连字符，再做 Base32 字母表校验。
String? normalizeTotpSecret(String raw) {
  final cleaned = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s\-=]+'), '');
  if (cleaned.isEmpty || !RegExp(r'^[A-Z2-7]+$').hasMatch(cleaned)) return null;
  return cleaned;
}
