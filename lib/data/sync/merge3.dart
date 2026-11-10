/// 三方合并（docs/04 §5.2 / §5.3）。
///
/// `base` / `local` / `remote` 都是 `EntrySnapshot` ——
/// 它在写入层就预留了「同步与合并的唯一交换格式」，
/// 这里不再另造一套结构，避免两份模型慢慢漂移。
///
/// 输出只是**应该写回什么**，不写库、不写 oplog。
/// 落库仍由 `WriteGateway` 负责，保证合并结果也会进 oplog。
library;

import 'dart:convert';
import 'dart:math' as math;

import '../../core/crypto/canonical.dart';
import '../../core/sync/conflict_matrix.dart';
import '../../core/sync/hlc.dart';
import '../db/tables/entry_tables.dart';
import '../write/entry_snapshot.dart';
import 'line_diff.dart';

/// 按 kind 选合并策略（docs/04 §5.3）。
///
/// 未知 kind 一律 LWW：将来新增类型时，保守地整体替换，
/// 也好过拿一套不懂语义的文本合并去改它。
enum MergeStrategy { text, lastWriteWins, metaFields, credential }

MergeStrategy strategyForKind(int kind) {
  final type = EntryKind.fromCode(kind);
  return switch (type) {
    EntryKind.note || EntryKind.thought || EntryKind.diary =>
      MergeStrategy.text,
    EntryKind.aiDiary => MergeStrategy.lastWriteWins,
    EntryKind.bookmark => MergeStrategy.metaFields,
    EntryKind.credential => MergeStrategy.credential,
    null => MergeStrategy.lastWriteWins,
  };
}

class MergeContext {
  const MergeContext({
    required this.nextHlc,
    required this.nowMs,
    required this.localLabel,
    required this.remoteLabel,
    required this.conflictCopyId,
    this.conflictCopyHlc,
  });

  /// 合并结果的新 HLC（调用方 `clock.observe(remoteHlc).encode()`）。
  final String nextHlc;
  final int nowMs;

  /// 形如「设备 A，11-08 13:20」，写进冲突标记。
  final String localLabel;
  final String remoteLabel;

  /// 冲突副本的新 UUIDv7。由调用方生成，保持这里纯函数。
  final String conflictCopyId;
  final String? conflictCopyHlc;
}

class MergeResult {
  const MergeResult({
    required this.merged,
    required this.isConflict,
    required this.reason,
    this.conflictCopy,
  });

  /// 写回本地的快照。
  final EntrySnapshot merged;

  /// 是否需要给用户横幅提示。
  final bool isConflict;

  /// 需要**另插一条**的另一版本（新 id）。两条都保留 = 零丢失。
  final EntrySnapshot? conflictCopy;
  final String reason;
}

/// 三方合并入口。[base] 为 null 表示首次同步就撞车，不做合并。
MergeResult merge3({
  required EntrySnapshot? base,
  required EntrySnapshot local,
  required EntrySnapshot remote,
  required MergeContext context,
}) {
  if (local.id != remote.id || (base != null && base.id != local.id)) {
    throw ArgumentError('三方合并要求三份快照的 id 一致');
  }

  // 重算而不是信任 content_hash 字段：云端文件可能被外部工具改过，
  // 只改内容不改 hash 的情况必须也能被识别成「变了」。
  final localHash = _hash(local);
  final remoteHash = _hash(remote);
  final baseHash = base == null ? null : _hash(base);

  // 三路短路（docs/04 §5.2）
  if (baseHash != null && localHash == baseHash) {
    return _adopt(remote, '只有远端变了：直接采用远端');
  }
  if (baseHash != null && remoteHash == baseHash) {
    return _adopt(local, '只有本地变了：直接保留本地');
  }
  if (localHash == remoteHash) {
    return _adopt(local, '两侧内容巧合相同');
  }

  // 没有 base 就没有共同祖先，任何"合并"都是猜的。
  if (base == null) {
    return _withCopy(
      winner: local,
      loser: remote,
      loserLabel: context.remoteLabel,
      context: context,
      reason: '没有 base（首次同步就撞车）：不合并，远端另存冲突副本',
    );
  }

  final localWins = _localIsLater(local, remote);
  final strategy = strategyForKind(local.kind);

  switch (strategy) {
    case MergeStrategy.lastWriteWins:
      return _adopt(
        localWins ? local : remote,
        'AI 日记 / 未知类型：LWW 整体替换，不做合并',
      );

    case MergeStrategy.credential:
      // 密码字段合并无意义且危险：绝不尝试，只做 LWW + 保留旧值副本。
      return _withCopy(
        winner: localWins ? local : remote,
        loser: localWins ? remote : local,
        loserLabel: localWins ? context.remoteLabel : context.localLabel,
        context: context,
        reason: '密码条目冲突：LWW + 旧值副本，绝不合并密码字段',
      );

    case MergeStrategy.metaFields:
      return MergeResult(
        merged: _buildMerged(
          local: local,
          remote: remote,
          title: _mergeTitle(base, local, remote, localWins),
          // 归档正文是派生的，按 LWW 取一侧即可
          body: (localWins ? local.body : remote.body) ?? '',
          meta: mergeMetaFields(
            baseMeta: base.meta,
            localMeta: local.meta,
            remoteMeta: remote.meta,
            localWins: localWins,
          ),
          context: context,
        ),
        isConflict: false,
        reason: '书签：正文 LWW + meta 字段级合并',
      );

    case MergeStrategy.text:
      return _mergeText(base, local, remote, localWins, context);
  }
}

/// note / thought / diary 的行级三方合并。
MergeResult _mergeText(
  EntrySnapshot base,
  EntrySnapshot local,
  EntrySnapshot remote,
  bool localWins,
  MergeContext context,
) {
  final baseLines = _lines(base.body);
  late final List<TextHunk> localHunks;
  late final List<TextHunk> remoteHunks;
  try {
    localHunks = diffHunks(baseLines, _lines(local.body));
    remoteHunks = diffHunks(baseLines, _lines(remote.body));
  } on LineDiffTooLarge {
    // 行数过大时 DP 会吃内存。降级 LWW，但**必须留副本**，
    // 不能因为"算不动"就悄悄丢掉一边的编辑。
    return _withCopy(
      winner: localWins ? local : remote,
      loser: localWins ? remote : local,
      loserLabel: localWins ? context.remoteLabel : context.localLabel,
      context: context,
      reason: '正文行数超过 $kMaxDiffLines：降级 LWW 并保留另一版本副本',
    );
  }

  final mergedLines = mergeLineHunks(
    base: baseLines,
    local: localHunks,
    remote: remoteHunks,
    localLabel: context.localLabel,
    remoteLabel: context.remoteLabel,
  );

  final merged = _buildMerged(
    local: local,
    remote: remote,
    title: _mergeTitle(base, local, remote, localWins),
    body: mergedLines.text,
    meta: mergeMetaFields(
      baseMeta: base.meta,
      localMeta: local.meta,
      remoteMeta: remote.meta,
      localWins: localWins,
    ),
    context: context,
  );

  if (!mergedLines.hasConflict) {
    return MergeResult(
      merged: merged,
      isConflict: false,
      reason: '不同段落的编辑互不重叠，自动合并',
    );
  }

  return MergeResult(
    merged: merged,
    isConflict: true,
    conflictCopy: _copyFrom(remote, context, context.remoteLabel),
    reason: '同一段落被两边修改：正文带冲突标记，远端原样另存副本',
  );
}

// ---------------------------------------------------------------------------
// meta 字段级 LWW（docs/04 §5.2）
// ---------------------------------------------------------------------------

/// meta 是 JSON 字符串。字段级 LWW，特例 `tags` 取并集。
///
/// 用 `Canonical.json` 判等，而不是 `==`：Map 的键顺序不同时
/// `==` 会判成不等，制造根本不存在的字段冲突。
String? mergeMetaFields({
  required String? baseMeta,
  required String? localMeta,
  required String? remoteMeta,
  required bool localWins,
}) {
  final b = _decode(baseMeta);
  final l = _decode(localMeta);
  final r = _decode(remoteMeta);
  if (b == null && l == null && r == null) return null;

  final keys = <String>{
    ...?b?.keys,
    ...?l?.keys,
    ...?r?.keys,
  };
  final out = <String, Object?>{};
  for (final key in keys) {
    final bv = b?[key];
    final lv = l?[key];
    final rv = r?[key];
    if (key == 'tags') {
      final union = _unionTags(<Object?>[bv, lv, rv]);
      if (union != null) out[key] = union;
      continue;
    }
    final chosen = _fieldLww(bv, lv, rv, localWins);
    if (chosen != null) out[key] = chosen;
  }
  return Canonical.json(out);
}

Object? _fieldLww(Object? b, Object? l, Object? r, bool localWins) {
  if (_same(l, r)) return l;
  if (_same(l, b)) return r;
  if (_same(r, b)) return l;
  return localWins ? l : r;
}

bool _same(Object? a, Object? b) => Canonical.json(a) == Canonical.json(b);

/// tags 取并集（不是 LWW），排序保证输出稳定。
Object? _unionTags(List<Object?> values) {
  final tags = <String>{};
  for (final value in values) {
    if (value is List) {
      for (final tag in value) {
        tags.add(tag.toString());
      }
    }
  }
  if (tags.isEmpty) return null;
  return tags.toList()..sort();
}

String? _mergeTitle(
  EntrySnapshot base,
  EntrySnapshot local,
  EntrySnapshot remote,
  bool localWins,
) {
  if (local.title == remote.title) return local.title;
  if (local.title == base.title) return remote.title;
  if (remote.title == base.title) return local.title;
  return localWins ? local.title : remote.title;
}

// ---------------------------------------------------------------------------
// 内部
// ---------------------------------------------------------------------------

MergeResult _adopt(EntrySnapshot snapshot, String reason) => MergeResult(
      merged: snapshot,
      isConflict: false,
      reason: reason,
    );

/// LWW / 无 base / 降级路径统一走这里：胜者写回，败者另存副本。
MergeResult _withCopy({
  required EntrySnapshot winner,
  required EntrySnapshot loser,
  required String loserLabel,
  required MergeContext context,
  required String reason,
}) {
  return MergeResult(
    merged: winner,
    isConflict: true,
    conflictCopy: _copyFrom(loser, context, loserLabel),
    reason: reason,
  );
}

EntrySnapshot _buildMerged({
  required EntrySnapshot local,
  required EntrySnapshot remote,
  required String? title,
  required String body,
  required String? meta,
  required MergeContext context,
}) {
  return EntrySnapshot(
    id: local.id,
    kind: local.kind,
    title: title,
    body: body,
    meta: meta,
    createdAt: local.createdAt,
    updatedAt: context.nowMs,
    hlc: context.nextHlc,
    // 合并是一次**新编辑**，rev 必须继续递增，不能倒退回去
    rev: math.max(local.rev, remote.rev) + 1,
    contentHash: EntrySnapshot.computeContentHash(
      kind: local.kind,
      title: title,
      body: body,
      meta: meta,
    ),
    deleted: false,
    deletedAt: null,
  );
}

EntrySnapshot _copyFrom(
  EntrySnapshot source,
  MergeContext context,
  String label,
) {
  final title = conflictCopyTitle(
    source.title ?? '无标题',
    label,
    _formatTimestamp(context.nowMs),
  );
  return EntrySnapshot(
    id: context.conflictCopyId,
    kind: source.kind,
    title: title,
    body: source.body,
    meta: source.meta,
    createdAt: context.nowMs,
    updatedAt: context.nowMs,
    hlc: context.conflictCopyHlc ?? context.nextHlc,
    rev: 1,
    contentHash: EntrySnapshot.computeContentHash(
      kind: source.kind,
      title: title,
      body: source.body,
      meta: source.meta,
    ),
  );
}

String _hash(EntrySnapshot snapshot) => EntrySnapshot.computeContentHash(
      kind: snapshot.kind,
      title: snapshot.title,
      body: snapshot.body,
      meta: snapshot.meta,
    );

/// 谁更"新"：先看 HLC（跨设备时钟可比），HLC 相同/非法时退到 rev。
/// 完全平手时本地优先 —— 别在用户刚编辑完时拿远端覆盖掉。
bool _localIsLater(EntrySnapshot local, EntrySnapshot remote) {
  final l = Hlc.tryParse(local.hlc);
  final r = Hlc.tryParse(remote.hlc);
  if (l != null && r != null && l != r) return l > r;
  if (local.rev != remote.rev) return local.rev > remote.rev;
  return true;
}

Map<String, Object?>? _decode(String? meta) {
  if (meta == null || meta.trim().isEmpty) return null;
  try {
    final value = jsonDecode(meta);
    return value is Map<String, Object?> ? value : null;
  } on FormatException {
    return null;
  }
}

List<String> _lines(String? text) => (text ?? '').split('\n');

String _formatTimestamp(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis).toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}';
}
