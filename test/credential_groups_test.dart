import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/credential_groups.dart';
import 'package:vault/data/vault/credential_models.dart';

/// docs/09 §8 账号智能分组测试。
void main() {
  const now = 1731052800000;
  const day = 86400000;

  test('一个账号可同时落多个智能分组，且桶内不重复计数', () {
    final samples = samplesForGroups(
      <CredentialHealthSample>[
        const CredentialHealthSample(
          strength: 10,
          passwordFingerprint: 'shared',
          leaked: true,
          favorite: true,
          passwordUpdatedAt: null,
        ),
        const CredentialHealthSample(
          strength: 20,
          passwordFingerprint: 'shared',
          leaked: false,
          favorite: false,
          passwordUpdatedAt: now - 10 * day,
        ),
      ],
      <String>['a', 'b'],
      favoriteIds: const <String>{'a'},
      categoryById: const <String, String?>{'a': null, 'b': 'cat-1'},
    );
    final buckets = groupCredentials(samples, nowMs: now);
    Map<CredentialSmartGroup, Set<String>> byGroup() => <CredentialSmartGroup, Set<String>>{
          for (final bucket in buckets) bucket.group: bucket.ids,
        };
    final byG = byGroup();
    expect(byG[CredentialSmartGroup.favorite], <String>{'a'});
    expect(byG[CredentialSmartGroup.ungrouped], <String>{'a'});
    expect(byG[CredentialSmartGroup.leaked], <String>{'a'});
    expect(byG[CredentialSmartGroup.reused], <String>{'a', 'b'});
    expect(byG[CredentialSmartGroup.outdated], <String>{'a'},
        reason: '未填修改时间视为超期；b 只改了 10 天');
    expect(buckets.first.label, '收藏');
  });

  test('超期按 180 天精确判定，样本与 id 数量不符直接拒绝', () {
    final samples = samplesForGroups(
      <CredentialHealthSample>[
        CredentialHealthSample(
          strength: 10,
          passwordFingerprint: 'x',
          leaked: false,
          favorite: false,
          passwordUpdatedAt: now - 200 * day,
        ),
      ],
      <String>['old'],
    );
    expect(
      groupCredentials(samples, nowMs: now)[CredentialSmartGroup.outdated.index]
          .ids,
      <String>{'old'},
    );
    expect(
      () => samplesForGroups(
        <CredentialHealthSample>[
          const CredentialHealthSample(
            strength: 1,
            passwordFingerprint: 'x',
            leaked: false,
            favorite: false,
            passwordUpdatedAt: null,
          ),
        ],
        <String>[],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('两级分类树禁止三级', () {
    expect(isCategoryDepthValid(null, const <String, String?>{}), isTrue);
    expect(
      isCategoryDepthValid('root', const <String, String?>{'root': null}),
      isTrue,
      reason: '父是一级，自己是二级',
    );
    expect(
      isCategoryDepthValid('child', const <String, String?>{'child': 'root'}),
      isFalse,
      reason: '父已经是二级，自己会变成三级',
    );
  });
}
