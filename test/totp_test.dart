import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/totp.dart';

/// RFC 6238 附录 B 的 SHA1 / 30s / 8 位官方向量（取前 6 位即主流验证器码）。
/// 密钥是 RFC 给的 ASCII 字符串 "12345678901234567890" 的 Base32。
void main() {
  const String secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

  String codeAt(int seconds) =>
      generateTotp(base32Secret: secret, nowMs: seconds * 1000, digits: 8);

  test('RFC 6238 SHA1 官方向量（8 位）', () {
    expect(codeAt(59), '94287082');
    expect(codeAt(1111111109), '07081804');
    expect(codeAt(1111111111), '14050471');
    expect(codeAt(1234567890), '89005924');
    expect(codeAt(2000000000), '69279037');
  });

  test('6 位码 = 8 位码的后 6 位，且始终补零', () {
    final eight = codeAt(59);
    final six = generateTotp(
      base32Secret: secret,
      nowMs: 59000,
      digits: 6,
    );
    expect(six, eight.substring(2));
    expect(six.length, 6);
  });

  test('Base32 容错：小写、空格、填充；非法字符拒绝', () {
    final lower = generateTotp(
      base32Secret: '${secret.toLowerCase()}====',
      nowMs: 59000,
      digits: 8,
    );
    expect(lower, '94287082');
    expect(() => decodeBase32('ABC1'), throwsA(isA<FormatException>()));
    expect(() => decodeBase32(''), throwsA(isA<FormatException>()));
  });

  test('30 秒窗口内验证码稳定，跨窗口变化', () {
    final a = codeAt(59);
    final sameWindow = generateTotp(
      base32Secret: secret,
      nowMs: 59999,
      digits: 8,
    );
    expect(sameWindow, a);
    expect(codeAt(60), isNot(a));
  });

  test('剩余时间只在 1..periodMs 之间', () {
    expect(totpRemainingMs(0), 30000);
    expect(totpRemainingMs(29000), 1000);
    expect(totpRemainingMs(30000), 30000);
  });
}
