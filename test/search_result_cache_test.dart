import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/search_result_cache.dart';

/// docs/07 §7.2 检索结果 5 分钟缓存测试。
void main() {
  test('同一 query 5 分钟内命中，大小写与空白不敏感', () {
    final cache = SearchResultCache<String>();
    cache.write(' 同步 ', '结果A', 1000);
    expect(cache.read('同步', 1000), '结果A');
    expect(cache.read('同步', 1000 + 299000), '结果A');
    expect(cache.length, 1);
  });

  test('超过 5 分钟过期，跨 5 分钟桶不复用', () {
    final cache = SearchResultCache<String>();
    cache.write('同步', '结果A', 1000);
    expect(cache.read('同步', 1000 + 300001), isNull);
    expect(cache.length, 0);
  });

  test('不同 query 互不覆盖；超出容量 FIFO 淘汰；clear 清空', () {
    final cache = SearchResultCache<int>(maxEntries: 2);
    cache.write('甲', 1, 0);
    cache.write('乙', 2, 0);
    cache.write('丙', 3, 0);
    expect(cache.length, 2);
    expect(cache.read('甲', 0), isNull, reason: '最早一条被淘汰');
    expect(cache.read('乙', 0), 2);
    expect(cache.read('丙', 0), 3);
    cache.clear();
    expect(cache.length, 0);
  });
}
