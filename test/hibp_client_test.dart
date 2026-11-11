import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/hibp_client.dart';

/// HIBP k-anonymity 判定层测试：完整哈希绝不出设备。
void main() {
  const now = 1731052800000;

  test('SHA1 切成前 5 位 + 35 位后缀，URL 只带前缀', () {
    final request = HibpChecker().requestFor('password');
    expect(request.prefix, '5BAA6',
        reason: 'SHA1("password") 的官方前 5 位');
    expect(request.path, '/range/5BAA6');
    expect(request.path, isNot(contains(request.suffix)));
    expect(HibpRequest.endpoint, contains('pwnedpasswords.com'));
  });

  test('响应行容错解析，非法行跳过', () {
    final parsed = HibpChecker().parseResponse(
      '0018A45C4D1DEF81644B54AB00000000000:2\r\n'
      'wrong\n'
      '  00000000000000000000000000000000000:10  \n',
    );
    expect(parsed, hasLength(2));
    expect(parsed.first, hasLength(35));
  });

  test('本地比对命中 / 未命中；未取回或过期时拒绝判定', () {
    final checker = HibpChecker();
    final request = checker.requestFor('password');
    expect(
      () => checker.isBreached(request, now),
      throwsA(isA<FormatException>()),
    );

    checker.store(request.prefix, <String>{request.suffix}, now);
    expect(checker.isFresh(request.prefix, now), isTrue);
    expect(checker.isBreached(request, now), isTrue);
    final other = HibpRequest(
      prefix: request.prefix,
      suffix: 'F' * 35,
    );
    expect(checker.isBreached(other, now), isFalse);

    final expired = now + HibpChecker.sevenDaysMs + 1;
    expect(checker.isFresh(request.prefix, expired), isFalse);
    expect(
      () => checker.isBreached(request, expired),
      throwsA(isA<FormatException>()),
    );
    checker.clear();
    expect(checker.cacheSize, 0);
  });

  test('同一前缀不同后缀互不干扰，且缓存按前缀隔离', () {
    final checker = HibpChecker();
    final leaked = checker.requestFor('password');
    checker.store(leaked.prefix, <String>{leaked.suffix}, now);
    expect(checker.cacheSize, 1);
    final suffixOnly = leaked.suffix;
    expect(suffixOnly.length, 35);
    expect(leaked.prefix.length, 5);
  });
}
