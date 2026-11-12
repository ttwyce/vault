/// 自动填充字段识别与条目匹配（docs/08 §3.1 / §3.2）。
///
/// 不接平台 channel、不解密：只按 hint / idEntry / inputType / webDomain
/// 判定字段类型，并按域名或 Android 包名匹配候选条目。
/// **候选数据里绝不带密码明文**（Extension 侧只能拿域名/用户名/标题）。
library;

enum AutofillFieldType { username, password, otp, unknown }

/// 字段判定：先看 hint/id 关键词，再看 inputType 数值特征。
AutofillFieldType detectAutofillField({
  required String hint,
  required String idEntry,
  required int inputType,
}) {
  final text = '${hint.toLowerCase()} ${idEntry.toLowerCase()}';
  if (RegExp(r'otp|totp|验证码|动态码|one.?time|2fa').hasMatch(text)) {
    return AutofillFieldType.otp;
  }
  if (RegExp(r'password|passwd|pwd|密码|passcode').hasMatch(text)) {
    return AutofillFieldType.password;
  }
  if (RegExp(r'user|email|account|login|账号|邮箱|用户名').hasMatch(text)) {
    return AutofillFieldType.username;
  }
  // Android InputType.TYPE_TEXT_VARIATION_PASSWORD = 0x80，
  // TYPE_NUMBER_VARIATION_PASSWORD = 0x10（在 number class 里）。
  if ((inputType & 0x80) != 0) return AutofillFieldType.password;
  return AutofillFieldType.unknown;
}

class AutofillCandidate {
  const AutofillCandidate({
    required this.entryId,
    required this.title,
    required this.username,
    required this.domains,
    this.androidPackage,
  });

  final String entryId;
  final String title;
  final String username;
  final List<String> domains;
  final String? androidPackage;

  /// 明确不含 password / totpSecret 字段。
  Map<String, Object?> toJson() => <String, Object?>{
        'entry_id': entryId,
        'title': title,
        'username': username,
        'domains': domains,
        'android_package': androidPackage,
      };
}

/// 域名规整：去协议/路径/www，小写。
String normalizeAutofillDomain(String raw) {
  var value = raw.trim().toLowerCase();
  value = value.replaceFirst(RegExp(r'^[a-z]+://'), '');
  value = value.split('/').first;
  if (value.startsWith('www.')) value = value.substring(4);
  return value;
}

/// 按 webDomain 或 Android 包名匹配候选；匹配不上返回空（不猜）。
List<AutofillCandidate> matchAutofillCandidates({
  required Iterable<AutofillCandidate> candidates,
  String? webDomain,
  String? androidPackage,
}) {
  final domain = webDomain == null ? null : normalizeAutofillDomain(webDomain);
  return List<AutofillCandidate>.unmodifiable(<AutofillCandidate>[
    for (final candidate in candidates)
      if ((domain != null &&
              candidate.domains
                  .map(normalizeAutofillDomain)
                  .contains(domain)) ||
          (androidPackage != null &&
              candidate.androidPackage == androidPackage))
        candidate,
  ]);
}
