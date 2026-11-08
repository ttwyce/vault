/// 混合逻辑时钟（Hybrid Logical Clock）。
///
/// 为什么不用墙上时间：三台设备的时钟不可能一致，Windows 差几秒、
/// 手机飞行模式几天回来差十几分钟都正常。用 `updated_at` 判断"谁更新"
/// 会导致**较新的修改被较旧的覆盖**，这是同步丢数据的头号原因。
///
/// 为什么不用 Lamport 时钟：Lamport 只有偏序，没有时间感。
/// 用户问"这条笔记是什么时候改的"，我们得答得出人话。
///
/// HLC 同时保留两者：物理毫秒 + 逻辑计数器，且保证
/// **`a` 因果先于 `b` ⇒ `a.encode() < b.encode()`**（字符串比较即可）。
///
/// 编码（固定宽度，可直接字符串排序）：
/// ```
/// 0000018F2A3B4C5D : 0003 : devA
/// └── 16 位十六进制毫秒 ──┘ └计数器┘ └节点 id┘
/// ```
class Hlc implements Comparable<Hlc> {
  const Hlc({
    required this.millis,
    required this.counter,
    required this.node,
  });

  /// 物理时间（UTC 毫秒）。48 位足够用到公元 10889 年。
  final int millis;

  /// 同一毫秒内的逻辑序号，16 位。
  final int counter;

  /// 设备标识。长度不限，但**同一部署内必须一致**，否则比较结果没有意义。
  final String node;

  static const int counterMax = 0xFFFF;

  /// 固定的 16 位毫秒宽度。少了这个，字符串比较就不等于时间比较。
  static String _hex(int value, int width) =>
      value.toRadixString(16).padLeft(width, '0');

  String encode() => '${_hex(millis, 16)}:${_hex(counter, 4)}:$node';

  static Hlc? tryParse(String value) {
    final first = value.indexOf(':');
    if (first <= 0) return null;
    final second = value.indexOf(':', first + 1);
    if (second <= first) return null;
    final millis = int.tryParse(value.substring(0, first), radix: 16);
    final counter = int.tryParse(value.substring(first + 1, second), radix: 16);
    if (millis == null || counter == null) return null;
    final node = value.substring(second + 1);
    if (node.isEmpty) return null;
    return Hlc(millis: millis, counter: counter, node: node);
  }

  @override
  int compareTo(Hlc other) {
    if (millis != other.millis) return millis.compareTo(other.millis);
    if (counter != other.counter) return counter.compareTo(other.counter);
    return node.compareTo(other.node);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator >=(Hlc other) => compareTo(other) >= 0;
  bool operator <=(Hlc other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.node == node;

  @override
  int get hashCode => Object.hash(millis, counter, node);

  @override
  String toString() => encode();

  static Hlc max(Hlc a, Hlc b) => a >= b ? a : b;
}

/// HLC 的推进器。每台设备一个实例，**必须持久化 `last`** ——
/// 重启后如果从零开始，可能生成比历史上更小的时钟值，导致合并时被误判为旧版本。
class HlcClock {
  HlcClock({
    required this.node,
    required this.now,
    Hlc? last,
  }) {
    _last = last;
  }

  final String node;

  /// 物理时钟。测试里注入可控的假时钟，生产环境用 `DateTime.now`。
  final int Function() now;

  Hlc? _last;

  Hlc? get last => _last;

  /// 从磁盘恢复。设备换机或数据导入时必须调用，否则时钟会倒退。
  void restore(Hlc? persisted) {
    if (persisted == null) return;
    if (_last == null || persisted > _last!) _last = persisted;
  }

  /// 本地事件：创建、修改、删除都先取一次。
  Hlc tick() {
    final physical = now();
    final previous = _last;
    final Hlc next;
    if (previous == null || physical > previous.millis) {
      next = Hlc(millis: physical, counter: 0, node: node);
    } else {
      next = _bump(previous.millis, previous.counter + 1);
    }
    _last = next;
    return next;
  }

  /// 收到远端时钟：把本地推进到"比两边都大"。
  ///
  /// 这是 HLC 的核心 —— 只要每条变更都经过这一步，
  /// 因果顺序就永远不会被本地时钟漂移破坏。
  Hlc observe(Hlc remote) {
    final physical = now();
    final local = _last;
    final maxMillis = <int>[
      physical,
      if (local != null) local.millis,
      remote.millis,
    ].reduce((int a, int b) => a > b ? a : b);

    final Hlc next;
    if (maxMillis == (local?.millis ?? -1) && maxMillis == remote.millis) {
      // 三方同毫秒：取两个计数器里较大的再加一
      next = _bump(maxMillis, _maxInt(local!.counter, remote.counter) + 1);
    } else if (maxMillis == (local?.millis ?? -1)) {
      next = _bump(maxMillis, local!.counter + 1);
    } else if (maxMillis == remote.millis) {
      next = _bump(maxMillis, remote.counter + 1);
    } else {
      // 物理时钟领先双方：逻辑计数器归零
      next = Hlc(millis: maxMillis, counter: 0, node: node);
    }

    if (local == null || next > local) _last = next;
    return _last!;
  }

  Hlc _bump(int millis, int counter) {
    if (counter > Hlc.counterMax) {
      // 计数器溢出：借一毫秒。物理时间可能领先真实时间最多 65535ms，
      // 但绝不会让时钟倒退。
      return Hlc(millis: millis + 1, counter: 0, node: node);
    }
    return Hlc(millis: millis, counter: counter, node: node);
  }

  static int _maxInt(int a, int b) => a > b ? a : b;
}
