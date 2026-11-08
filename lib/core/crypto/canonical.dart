import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 确定性序列化与内容哈希。
///
/// 为什么需要「确定性」：`content_hash` 要在**不同设备、不同 Dart 版本、
/// 不同 Map 插入顺序**下算出同一个值。直接用 `jsonEncode(map)` 不行 ——
/// Dart 的 Map 迭代顺序取决于构造方式，两台设备拼出来的 JSON 字符串
/// 可能一个字符都不差但顺序不同，哈希就对不上，同步会误判成"内容变了"。
///
/// 规则（只有三条，必须严格遵守）：
/// 1. **对象键按字典序升序**，且不含任何空白
/// 2. **数组保持原顺序**（顺序是语义的一部分）
/// 3. **数值统一**：整数值一律写成整数形式（`1` 而不是 `1.0`），
///    否则 `1.0` 和 `1` 会算出两个哈希
abstract final class Canonical {
  const Canonical._();

  static String json(Object? value) {
    final buffer = StringBuffer();
    _write(buffer, value);
    return buffer.toString();
  }

  static void _write(StringBuffer out, Object? value) {
    if (value == null) {
      out.write('null');
      return;
    }
    if (value is bool) {
      out.write(value ? 'true' : 'false');
      return;
    }
    if (value is num) {
      out.write(_number(value));
      return;
    }
    if (value is String) {
      // jsonEncode 已处理转义（引号、反斜杠、控制字符、非 BMP）
      out.write(jsonEncode(value));
      return;
    }
    if (value is List) {
      out.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.write(',');
        _write(out, value[i]);
      }
      out.write(']');
      return;
    }
    if (value is Map) {
      final entries = <MapEntry<String, Object?>>[
        for (final entry in value.entries)
          MapEntry<String, Object?>(entry.key.toString(), entry.value),
      ]..sort((MapEntry<String, Object?> a, MapEntry<String, Object?> b) =>
          a.key.compareTo(b.key));
      out.write('{');
      for (var i = 0; i < entries.length; i++) {
        if (i > 0) out.write(',');
        out.write(jsonEncode(entries[i].key));
        out.write(':');
        _write(out, entries[i].value);
      }
      out.write('}');
      return;
    }
    // 兜底：不认识的类型用 toString，但这类值不应该出现在被哈希的字段里
    out.write(jsonEncode(value.toString()));
  }

  static String _number(num value) {
    if (value is int) return value.toString();
    if (value is double) {
      if (value.isNaN || value.isInfinite) {
        throw ArgumentError('canonical JSON 不支持 NaN / Infinity');
      }
      // 整数值的 double 退化成整数形式，保证 1.0 == 1
      if (value == value.roundToDouble() && value.abs() < 1e15) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    return value.toString();
  }

  /// 字段集合 → sha256 十六进制。字段的插入顺序不影响结果。
  static String contentHash(Map<String, Object?> fields) {
    return sha256.convert(utf8.encode(json(fields))).toString();
  }
}
