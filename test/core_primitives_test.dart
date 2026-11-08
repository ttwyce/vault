import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/canonical.dart';
import 'package:vault/core/identity/uuid_v7.dart';
import 'package:vault/core/sync/hlc.dart';

void main() {
  group('UUIDv7', () {
    test('格式合法、版本位为 7、变体位为 10', () {
      final gen = UuidV7(now: () => 1731052800000);
      final id = gen.next();
      expect(UuidV7.isValid(id), isTrue, reason: id);
      expect(id.substring(14, 15), '7');
      expect(<String>['8', '9', 'a', 'b'], contains(id.substring(19, 20)));
    });

    test('能取回创建时间', () {
      const millis = 1731052800123;
      final id = UuidV7(now: () => millis).next();
      expect(UuidV7.timestampOf(id), millis);
    });

    test('同一毫秒内单调递增', () {
      final gen = UuidV7(now: () => 1731052800000);
      final ids = List<String>.generate(500, (_) => gen.next());
      final sorted = List<String>.of(ids)..sort();
      // id 序 = 创建序：这是列表按 id 排序不会错乱的前提
      expect(ids, sorted);
      expect(ids.toSet().length, 500, reason: '不能重复');
    });

    test('跨毫秒仍然单调', () {
      var now = 1731052800000;
      final gen = UuidV7(now: () => now);
      final first = gen.next();
      now += 1;
      final second = gen.next();
      expect(first.compareTo(second) < 0, isTrue);
    });

    test('计数器溢出时借下一毫秒，绝不回退', () {
      final gen = UuidV7(now: () => 1731052800000);
      final ids = List<String>.generate(5000, (_) => gen.next());
      final sorted = List<String>.of(ids)..sort();
      expect(ids, sorted);
      // 借用毫秒后时间戳最多领先 1ms（5000 条 < 4096*2，用不到 2ms）
      final last = UuidV7.timestampOf(ids.last)!;
      expect(last - 1731052800000, lessThanOrEqualTo(2));
    });

    test('非法字符串被拒绝', () {
      expect(UuidV7.isValid('not-a-uuid'), isFalse);
      expect(UuidV7.isValid('018f2a3b-4c5d-4e6f-8a9b-0c1d2e3f4a5b'), isFalse);
      expect(UuidV7.timestampOf('bad'), isNull);
    });
  });

  group('HLC', () {
    test('编码固定宽度，字符串序 = 时间序', () {
      const a = Hlc(millis: 1731052800000, counter: 3, node: 'devA');
      const b = Hlc(millis: 1731052800001, counter: 0, node: 'devA');
      final millisHex = 1731052800000.toRadixString(16).padLeft(16, '0');
      expect(a.encode(), '$millisHex:0003:devA');
      // 总长度必须恒定，否则字符串比较就不等于时间比较
      expect(a.encode().length, b.encode().length);
      expect(a.encode().compareTo(b.encode()) < 0, isTrue);
      expect(a < b, isTrue);
    });

    test('编解码往返', () {
      const hlc = Hlc(millis: 1731052800123, counter: 42, node: 'win-01');
      final parsed = Hlc.tryParse(hlc.encode());
      expect(parsed, hlc);
      expect(Hlc.tryParse('garbage'), isNull);
      expect(Hlc.tryParse('0001:0002'), isNull);
      expect(Hlc.tryParse('0001:0002:'), isNull);
    });

    test('同一毫秒内连续 tick 递增', () {
      final clock = HlcClock(node: 'devA', now: () => 1731052800000);
      final a = clock.tick();
      final b = clock.tick();
      final c = clock.tick();
      expect(a < b, isTrue);
      expect(b < c, isTrue);
      expect(c.counter, 2);
    });

    test('物理时钟前进时计数器归零', () {
      var now = 1731052800000;
      final clock = HlcClock(node: 'devA', now: () => now);
      clock.tick();
      clock.tick();
      now += 5000;
      expect(clock.tick().counter, 0);
    });

    test('observe 之后本地时钟严格大于远端', () {
      final local = HlcClock(node: 'devA', now: () => 1731052800000);
      local.tick();

      // 远端时钟比本地快 10 分钟（典型的 Windows 时钟漂移）
      final remote = Hlc(millis: 1731053400000, counter: 7, node: 'devB');
      final merged = local.observe(remote);

      expect(merged > remote, isTrue);
      expect(merged.node, 'devA');
      // 之后本地事件必须继续大于合并结果
      expect(local.tick() > merged, isTrue);
    });

    test('observe 不会让时钟倒退', () {
      final local = HlcClock(node: 'devA', now: () => 1731052800000);
      final own = local.tick();
      // 远端时钟明显更旧（设备离线很久后回来）
      final stale = Hlc(millis: 1700000000000, counter: 99, node: 'devB');
      final after = local.observe(stale);
      expect(after >= own, isTrue);
    });

    test('restore 只能前进', () {
      final clock = HlcClock(node: 'devA', now: () => 1731052800000);
      clock.tick();
      final older = Hlc(millis: 1700000000000, counter: 0, node: 'devA');
      clock.restore(older);
      expect(clock.last!.millis, 1731052800000, reason: '不能被旧值拉回去');

      final newer = Hlc(millis: 1731052900000, counter: 0, node: 'devA');
      clock.restore(newer);
      expect(clock.last, newer);
      expect(clock.tick() > newer, isTrue);
    });

    test('计数器溢出借毫秒', () {
      final clock = HlcClock(node: 'devA', now: () => 1731052800000);
      clock.restore(const Hlc(
        millis: 1731052800000,
        counter: Hlc.counterMax,
        node: 'devA',
      ));
      final next = clock.tick();
      expect(next.millis, 1731052800001);
      expect(next.counter, 0);
    });
  });

  group('Canonical JSON', () {
    test('键序无关', () {
      final a = Canonical.json(<String, Object?>{'b': 1, 'a': 2, 'c': 3});
      final b = Canonical.json(<String, Object?>{'c': 3, 'a': 2, 'b': 1});
      expect(a, b);
      expect(a, '{"a":2,"b":1,"c":3}');
    });

    test('嵌套对象也排序，数组保持顺序', () {
      final value = <String, Object?>{
        'z': <String, Object?>{'y': 1, 'x': 2},
        'a': <Object?>[3, 1, 2],
      };
      expect(Canonical.json(value), '{"a":[3,1,2],"z":{"x":2,"y":1}}');
    });

    test('整数值的 double 与 int 等价', () {
      expect(
        Canonical.json(<String, Object?>{'n': 1}),
        Canonical.json(<String, Object?>{'n': 1.0}),
      );
    });

    test('内容哈希对字段顺序不敏感', () {
      final h1 = Canonical.contentHash(<String, Object?>{
        'kind': 1,
        'title': '笔记',
        'body': '正文',
      });
      final h2 = Canonical.contentHash(<String, Object?>{
        'body': '正文',
        'title': '笔记',
        'kind': 1,
      });
      expect(h1, h2);
      expect(h1.length, 64);
    });

    test('内容变了哈希必须变', () {
      final base = <String, Object?>{'title': 'A', 'body': 'B'};
      final changed = <String, Object?>{'title': 'A', 'body': 'B '};
      expect(Canonical.contentHash(base), isNot(Canonical.contentHash(changed)));
    });

    test('中文与转义字符稳定', () {
      final hash = Canonical.contentHash(<String, Object?>{
        'title': '带"引号"和\n换行',
      });
      // 同一份输入重复计算必须一致（不依赖 locale / 平台）
      expect(hash, Canonical.contentHash(<String, Object?>{'title': '带"引号"和\n换行'}));
    });

    test('NaN / Infinity 直接报错，不静默产出脏哈希', () {
      expect(() => Canonical.json(double.nan), throwsArgumentError);
      expect(() => Canonical.json(double.infinity), throwsArgumentError);
    });
  });
}
