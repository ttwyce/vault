import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_policy.dart';
import 'package:vault/data/archive/simhash.dart';

/// docs/05 §6.2 simhash 纯计算测试。
void main() {
  test('相同文本指纹相同、格式 16 位大写十六进制', () {
    const text = 'WebDAV 增量同步的限流与退避策略，RFC 6578。';
    final a = computeSimhash(text);
    expect(a, computeSimhash(text));
    expect(a.length, 16);
    expect(RegExp(r'^[0-9A-F]{16}$').hasMatch(a), isTrue);
  });

  test('空文本给全 0 指纹', () {
    expect(computeSimhash('   '), '0' * 16);
    expect(computeSimhash(''), '0' * 16);
  });

  test('小改动汉明距离小（不触发变更），大改写触发变更', () {
    final base = computeSimhash(
      '今天大部分时间在跟 WebDAV 的限流较劲。下午想到一点：退避策略'
      '其实不该只看 HTTP 状态码，还该看本地队列积压量。',
    );
    final tiny = computeSimhash(
      '今天大部分时间在跟 WebDAV 的限流较劲。下午想到一点：退避策略'
      '其实不该只看 HTTP 状态码，还该看本地队列积压量！',
    );
    expect(hasContentChanged(base, tiny), isFalse,
        reason: '只加一个标点不应提示内容变更');

    final rewritten = computeSimhash(
      '密码库的自定义字段采用字段级加密，恢复码与 TOTP 密钥都不进入'
      '任何模型上下文，健康报告只返回聚合统计而不会泄露明文。',
    );
    expect(hasContentChanged(base, rewritten), isTrue);
    expect(hasContentChanged(base, null), isFalse);
    expect(hasContentChanged(null, rewritten), isFalse);
  });

  test('高位 bit 63 参与计算，不因有符号溢出崩', () {
    final a = computeSimhash('ffffffffffffffff');
    final b = computeSimhash('00000000000000ff');
    expect(a.length, 16);
    expect(b.length, 16);
    expect(a, isNot(b), reason: '不同文本指纹应不同');
  });
}
