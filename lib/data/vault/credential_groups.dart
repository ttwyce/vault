/// 账号智能分组的纯判定层（docs/09 §8 账号分组）。
///
/// 不读写数据库：只把 `CredentialRepository` 已经算出的健康样本映射成
/// 智能分组，保证「一个账号可以同时属于多个智能分组」且不重复计数。
library;

import 'credential_models.dart';

enum CredentialSmartGroup { favorite, ungrouped, leaked, reused, outdated }

class CredentialGroupBucket {
  const CredentialGroupBucket(this.group, this.ids);

  final CredentialSmartGroup group;
  final Set<String> ids;

  String get label => switch (group) {
        CredentialSmartGroup.favorite => '收藏',
        CredentialSmartGroup.ungrouped => '未分组',
        CredentialSmartGroup.leaked => '已泄露',
        CredentialSmartGroup.reused => '重复密码',
        CredentialSmartGroup.outdated => '超期未改',
      };
}

/// 一条账号的分组输入。
class CredentialGroupSample {
  const CredentialGroupSample({
    required this.id,
    required this.favorite,
    required this.categoryId,
    required this.leaked,
    required this.passwordFingerprint,
    required this.changedAtMs,
  });

  final String id;
  final bool favorite;
  final String? categoryId;
  final bool leaked;
  final String passwordFingerprint;
  final int? changedAtMs;
}

/// 从健康样本构造分组输入（重复密码靠相同指纹判定）。
List<CredentialGroupSample> samplesForGroups(
  List<CredentialHealthSample> health,
  List<String> ids, {
  Set<String> favoriteIds = const <String>{},
  Map<String, String?> categoryById = const <String, String?>{},
}) {
  if (health.length != ids.length) {
    throw ArgumentError('健康样本与账号 id 数量不一致');
  }
  return <CredentialGroupSample>[
    for (var i = 0; i < health.length; i++)
      CredentialGroupSample(
        id: ids[i],
        favorite: favoriteIds.contains(ids[i]),
        categoryId: categoryById[ids[i]],
        leaked: health[i].leaked,
        passwordFingerprint: health[i].passwordFingerprint,
        changedAtMs: health[i].passwordUpdatedAt,
      ),
  ];
}

/// 智能分组：一个账号可落在多个桶里。
/// [nowMs] 用于按 [outdatedDays] 精确判定超期。
List<CredentialGroupBucket> groupCredentials(
  Iterable<CredentialGroupSample> samples, {
  required int nowMs,
  int outdatedDays = 180,
}) {
  final fingerprintCounts = <String, int>{};
  for (final sample in samples) {
    if (sample.passwordFingerprint.isEmpty) continue;
    fingerprintCounts[sample.passwordFingerprint] =
        (fingerprintCounts[sample.passwordFingerprint] ?? 0) + 1;
  }
  final thresholdMs = const Duration(days: 1).inMilliseconds * outdatedDays;
  final buckets = <CredentialSmartGroup, Set<String>>{
    for (final group in CredentialSmartGroup.values) group: <String>{},
  };
  for (final sample in samples) {
    if (sample.favorite) {
      buckets[CredentialSmartGroup.favorite]!.add(sample.id);
    }
    if (sample.categoryId == null || sample.categoryId!.isEmpty) {
      buckets[CredentialSmartGroup.ungrouped]!.add(sample.id);
    }
    if (sample.leaked) {
      buckets[CredentialSmartGroup.leaked]!.add(sample.id);
    }
    if ((fingerprintCounts[sample.passwordFingerprint] ?? 0) > 1) {
      buckets[CredentialSmartGroup.reused]!.add(sample.id);
    }
    if (sample.changedAtMs == null ||
        nowMs - sample.changedAtMs! > thresholdMs) {
      buckets[CredentialSmartGroup.outdated]!.add(sample.id);
    }
  }
  return <CredentialGroupBucket>[
    for (final group in CredentialSmartGroup.values)
      CredentialGroupBucket(group, Set<String>.unmodifiable(buckets[group]!)),
  ];
}

/// 两级分类树深度校验（docs/11 §2：禁止三级）。
bool isCategoryDepthValid(String? parentId, Map<String, String?> byId) {
  if (parentId == null) return true;
  final parentParent = byId[parentId];
  return parentParent == null;
}
