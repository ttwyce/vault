import 'dart:math';

/// UUIDv7 生成器。
///
/// 为什么不用 v4：条目的主键要**时间有序**。
/// 同步时按 id 排序等于按创建时间排序，PROPFIND 拿回来的文件列表天然有序，
/// 分片目录内的遍历、断点续传的游标都能直接用 id 做键。
/// v4 是纯随机，做不到这一点，只能额外加索引列。
///
/// 布局（RFC 9562）：
/// ```
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                           unix_ts_ms                          |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |          unix_ts_ms           |  ver  |       rand_a          |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |var|                        rand_b                             |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                            rand_b                             |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// ```
///
/// **同一毫秒内保证单调递增**：`rand_a` 当作 12 位计数器用。
/// 这是 v7 相对 v4 的第二个好处 —— 快速连续创建 1000 条笔记时，
/// id 顺序仍然等于创建顺序，列表不会出现"后建的排在前面"。
class UuidV7 {
  UuidV7({Random? random, int Function()? now})
      : _random = random ?? Random.secure(),
        _now = now ?? _defaultNow;

  final Random _random;
  final int Function() _now;

  int _lastMillis = 0;
  int _counter = 0;

  static int _defaultNow() => DateTime.now().millisecondsSinceEpoch;

  /// 12 位计数器上限。超过就借用下一毫秒（v7 的 rand_a 只有 12 位）。
  static const int _counterMax = 0xFFF;

  String next() {
    final now = _now();
    if (now > _lastMillis) {
      _lastMillis = now;
      // 起始值随机，避免不同设备同一毫秒内创建的条目在 id 上"撞队形"
      _counter = _random.nextInt(0x40);
    } else {
      _counter++;
      if (_counter > _counterMax) {
        // 计数器用尽：把时间戳推到下一毫秒。宁可让 id 比真实时间晚 1ms，
        // 也不能让同一毫秒出现乱序（会破坏"id 序 = 创建序"这个前提）。
        _lastMillis++;
        _counter = 0;
      }
    }
    return _compose(_lastMillis, _counter);
  }

  String _compose(int millis, int counter) {
    final bytes = List<int>.filled(16, 0);

    // 48 位毫秒时间戳（大端）
    bytes[0] = (millis >> 40) & 0xFF;
    bytes[1] = (millis >> 32) & 0xFF;
    bytes[2] = (millis >> 24) & 0xFF;
    bytes[3] = (millis >> 16) & 0xFF;
    bytes[4] = (millis >> 8) & 0xFF;
    bytes[5] = millis & 0xFF;

    // 版本 7（高 4 位）+ 计数器高 4 位
    bytes[6] = 0x70 | ((counter >> 8) & 0x0F);
    bytes[7] = counter & 0xFF;

    // 变体 10（高 2 位）+ 62 位随机
    for (var i = 8; i < 16; i++) {
      bytes[i] = _random.nextInt(256);
    }
    bytes[8] = 0x80 | (bytes[8] & 0x3F);

    return _format(bytes);
  }

  static String _format(List<int> b) {
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    final s = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) s.write('-');
      s.write(hex(b[i]));
    }
    return s.toString();
  }

  // ---------------------------------------------------------------------------
  // 校验与提取
  // ---------------------------------------------------------------------------

  static final RegExp _pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static bool isValid(String value) => _pattern.hasMatch(value);

  /// 从 id 里取回创建时间（UTC 毫秒）。同步时用于"远端条目比本地新"的快速判断。
  static int? timestampOf(String value) {
    if (!isValid(value)) return null;
    final hex = value.substring(0, 8) + value.substring(9, 13);
    return int.parse(hex, radix: 16);
  }
}
