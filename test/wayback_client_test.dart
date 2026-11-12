import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/wayback_client.dart';

/// docs/05 §6.1 / §6.3 Wayback 判定测试。
void main() {
  test('可用性 API 地址构造', () {
    expect(
      waybackAvailabilityUrl('https://example.com/p'),
      contains('archive.org/wayback/available'),
    );
    expect(
      waybackAvailabilityUrl('https://example.com/p'),
      contains('example.com'),
    );
  });

  test('时间戳格式化：合法 / 非法', () {
    expect(formatWaybackTimestamp('20190312093015'), '2019-03-12');
    expect(formatWaybackTimestamp('2019'), isNull);
    expect(formatWaybackTimestamp(null), isNull);
    expect(formatWaybackTimestamp('abcd1234'), isNull);
  });

  test('有 closest 快照：返回年份提示与存档 URL；无 url 用时间戳兜底', () {
    final response = <String, Object?>{
      'archived_snapshots': <String, Object?>{
        'closest': <String, Object?>{
          'available': true,
          'url': 'https://web.archive.org/web/20190312093015/https://x/p',
          'timestamp': '20190312093015',
        },
      },
    };
    final result = parseWaybackAvailability(response, 'https://x/p');
    expect(result.available, isTrue);
    expect(result.hint, contains('2019-03-12'));
    expect(result.toJson()['archive_url'], contains('web.archive.org'));

    final fallback = parseWaybackAvailability(<String, Object?>{
      'archived_snapshots': <String, Object?>{
        'closest': <String, Object?>{
          'available': true,
          'timestamp': '20190312093015',
        },
      },
    }, 'https://x/p');
    expect(fallback.available, isTrue);
    expect(fallback.archiveUrl, contains('https://x/p'));
  });

  test('无快照 / 坏 JSON / 缺字段一律不算有存档', () {
    expect(
      parseWaybackAvailability(<String, Object?>{}, 'https://x').available,
      isFalse,
    );
    expect(
      parseWaybackAvailability('{坏 JSON', 'https://x').hint,
      contains('无法解析'),
    );
    expect(
      parseWaybackAvailability(null, 'https://x').hint,
      contains('没有响应'),
    );
    final missing = parseWaybackAvailability(<String, Object?>{
      'archived_snapshots': <String, Object?>{
        'closest': <String, Object?>{'available': true},
      },
    }, 'https://x');
    expect(missing.available, isFalse);
  });

  test('自动提交存档默认关闭，必须逐次勾选', () {
    expect(shouldSubmitToWayback(userOptedIn: false), isFalse);
    expect(shouldSubmitToWayback(userOptedIn: true), isTrue);
  });
}
