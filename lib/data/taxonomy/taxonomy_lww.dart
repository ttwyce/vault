import '../../core/sync/hlc.dart';

/// taxonomy 远端快照的 LWW 判定（docs/11 §2.4 / docs/09 T21~T22）。
///
/// 此前 `applyRemoteTaxonomySnapshots` / `applyEntityPull` 只比较 `rev`：
/// 两台设备从同一 base 各自改一次都会得到 `rev = base + 1`，此时
/// `latest.rev >= snapshot.rev` 会**静默丢掉其中一方**，且没有任何报错。
/// docs/09 T21 / T22 明确要求「同名合并 / 保留 HLC 较大者」。
///
/// 判定收敛成纯函数：
/// - 本地无版本 → 应用远端
/// - `rev` 不同 → 大者胜（明确的版本递进）
/// - `rev` 相同 → 用 HLC 做因果序 tie-break，HLC 更大者胜
/// - HLC 解析失败或完全相等 → 保守保留本地，绝不覆盖
enum TaxonomyLwwAction {
  /// 应用远端快照。
  applyRemote,

  /// 远端更旧 / 并列但无法判定 → 只更新 ETag，不动实体与 oplog。
  keepLocal,
}

TaxonomyLwwAction resolveTaxonomyLww({
  required int? localRev,
  required String? localHlc,
  required int remoteRev,
  required String remoteHlc,
}) {
  if (localRev == null) return TaxonomyLwwAction.applyRemote;
  if (remoteRev > localRev) return TaxonomyLwwAction.applyRemote;
  if (remoteRev < localRev) return TaxonomyLwwAction.keepLocal;

  // 同 rev：跨设备并发编辑。HLC 是唯一能给出因果序的依据。
  final local = localHlc == null ? null : Hlc.tryParse(localHlc);
  final remote = Hlc.tryParse(remoteHlc);
  if (local == null || remote == null) {
    return TaxonomyLwwAction.keepLocal;
  }
  return remote > local
      ? TaxonomyLwwAction.applyRemote
      : TaxonomyLwwAction.keepLocal;
}
