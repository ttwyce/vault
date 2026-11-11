import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/hlc.dart';
import 'package:vault/data/taxonomy/taxonomy_lww.dart';

String _hlc(int millis, String node) =>
    Hlc(millis: millis, counter: 0, node: node).encode();

void main() {
  test('本地无版本时应用远端', () {
    expect(
      resolveTaxonomyLww(
        localRev: null,
        localHlc: null,
        remoteRev: 1,
        remoteHlc: _hlc(1, 'devB'),
      ),
      TaxonomyLwwAction.applyRemote,
    );
  });

  test('rev 更大者胜，HLC 不参与', () {
    expect(
      resolveTaxonomyLww(
        localRev: 2,
        localHlc: _hlc(9999, 'devA'),
        remoteRev: 3,
        remoteHlc: _hlc(1, 'devB'),
      ),
      TaxonomyLwwAction.applyRemote,
    );
    expect(
      resolveTaxonomyLww(
        localRev: 4,
        localHlc: _hlc(1, 'devA'),
        remoteRev: 3,
        remoteHlc: _hlc(9999, 'devB'),
      ),
      TaxonomyLwwAction.keepLocal,
    );
  });

  test('T22：同 rev 的两设备并发修改，HLC 更大者胜', () {
    expect(
      resolveTaxonomyLww(
        localRev: 2,
        localHlc: _hlc(1000, 'devA'),
        remoteRev: 2,
        remoteHlc: _hlc(2000, 'devB'),
      ),
      TaxonomyLwwAction.applyRemote,
    );
    expect(
      resolveTaxonomyLww(
        localRev: 2,
        localHlc: _hlc(3000, 'devA'),
        remoteRev: 2,
        remoteHlc: _hlc(2000, 'devB'),
      ),
      TaxonomyLwwAction.keepLocal,
    );
  });

  test('同 rev 且 HLC 损坏 / 相等时保守保留本地', () {
    for (final pair in <List<String?>>[
      <String?>[null, _hlc(1, 'devB')],
      <String?>[_hlc(1, 'devA'), 'not-an-hlc'],
      <String?>[_hlc(1, 'devA'), _hlc(1, 'devA')],
    ]) {
      expect(
        resolveTaxonomyLww(
          localRev: 2,
          localHlc: pair[0],
          remoteRev: 2,
          remoteHlc: pair[1]!,
        ),
        TaxonomyLwwAction.keepLocal,
        reason: '无法建立因果序时绝不覆盖本地',
      );
    }
  });
}
