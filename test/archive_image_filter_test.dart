import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/archive/archive_image_filter.dart';

/// docs/05 §4.1 归档图片过滤测试。
void main() {
  test('宽或高 ≥200 保留；双维都小丢弃', () {
    expect(
      planArchiveImage('<img src="a.png" width="320" height="100">').action,
      ArchiveImageAction.keepLocal,
    );
    expect(
      planArchiveImage("<img src='b.png' width='100' height='240'>").action,
      ArchiveImageAction.keepLocal,
    );
    final small = planArchiveImage(
      '<img src="c.png" width="80" height="80">',
    );
    expect(small.action, ArchiveImageAction.dropSmall);
    expect(small.reason, contains('80×80'));
  });

  test('未声明尺寸保守保留；无 src 丢弃', () {
    expect(
      planArchiveImage('<img src="d.png" alt="图">').action,
      ArchiveImageAction.keepLocal,
    );
    expect(
      planArchiveImage('<img alt="无地址">').action,
      ArchiveImageAction.dropSmall,
    );
  });

  test('下载失败保留原 URL 并标注；批量按 HTML 抽取', () {
    final failed = planArchiveImage(
      '<img src="https://x/big.png" width="600">',
      downloadFailed: true,
    );
    expect(failed.action, ArchiveImageAction.keepRemoteAnnotated);
    expect(failed.reason, contains('保留原 URL'));
    expect(failed.toJson()['action'], 'keepRemoteAnnotated');

    final plans = planArchiveImages(
      '<p><img src="a.png" width="300"></p>'
      '<img src="b.png" width="10" height="10">',
      failedSrcs: const <String>{'a.png'},
    );
    expect(plans, hasLength(2));
    expect(plans[0].action, ArchiveImageAction.keepRemoteAnnotated);
    expect(plans[1].action, ArchiveImageAction.dropSmall);
  });
}
