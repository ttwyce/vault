/// 模型下载器 / 索引重建的**纯判定层**（docs/06 §5 / §6）。
///
/// 不下载、不写文件、不推理：只定义「源怎么排优先级、状态机怎么跳、
/// 磁盘够不够、断点续传 cursor 怎么续、校验失败怎么换源、重建任务怎么分批」。
/// 平台层按这里给出的 [DownloadAction] / [ReembedPlan] 执行真实操作。
library;

import 'embedding_manifest.dart' show EmbeddingModelSpec;

/// 下载状态（docs/06 §5.2）。
enum ModelState { idle, checking, downloading, verifying, ready, corrupt }

/// 源优先级：越靠前越优先，失败后依次降级。
enum ModelSource {
  modelScope,
  hfMirror,
  huggingFace,
  customMirror,
  userWebDav,
}

const List<ModelSource> kDefaultSourceOrder = <ModelSource>[
  ModelSource.modelScope,
  ModelSource.hfMirror,
  ModelSource.huggingFace,
  ModelSource.customMirror,
  ModelSource.userWebDav,
];

/// 每个源独立重试 3 次；全源失败才标记损坏。
const int kMaxAttemptsPerSource = 3;

class DownloadStatus {
  const DownloadStatus({
    required this.state,
    required this.sourceIndex,
    required this.attempt,
    required this.receivedBytes,
    required this.totalBytes,
    this.sha256Ok,
  });

  final ModelState state;
  final int sourceIndex;
  final int attempt;
  final int receivedBytes;
  final int totalBytes;
  final bool? sha256Ok;

  double get progress =>
      totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);
}

/// 磁盘检查：可用空间需 ≥ disk_bytes × 1.5。
bool hasEnoughDisk({
  required int freeBytes,
  required int modelBytes,
}) =>
    freeBytes >= (modelBytes * 1.5).ceil();

/// 断点续传：已有 .part 时从已收字节继续，绝不从头下。
int resumeOffset(int existingPartBytes, int totalBytes) =>
    existingPartBytes < 0 || existingPartBytes > totalBytes
        ? 0
        : existingPartBytes;

/// 状态机推进。返回新状态；非法跳转一律拒绝。
DownloadStatus advanceDownload(
  DownloadStatus status,
  DownloadEvent event, {
  required int totalBytes,
  required String expectedSha256,
  required String actualSha256,
  List<ModelSource> sources = kDefaultSourceOrder,
}) {
  switch (event) {
    case DownloadEvent.start:
      if (status.state != ModelState.idle &&
          status.state != ModelState.corrupt) {
        return status;
      }
      return DownloadStatus(
        state: ModelState.checking,
        sourceIndex: 0,
        attempt: 1,
        receivedBytes: 0,
        totalBytes: totalBytes,
      );
    case DownloadEvent.diskOk:
      if (status.state != ModelState.checking) return status;
      return _copy(status, state: ModelState.downloading);
    case DownloadEvent.progress:
      if (status.state != ModelState.downloading) return status;
      return status;
    case DownloadEvent.completed:
      if (status.state != ModelState.downloading) return status;
      return _copy(status, state: ModelState.verifying);
    case DownloadEvent.verified:
      if (status.state != ModelState.verifying) return status;
      final ok = _constantTimeEquals(expectedSha256, actualSha256);
      return DownloadStatus(
        state: ok ? ModelState.ready : ModelState.corrupt,
        sourceIndex: status.sourceIndex,
        attempt: status.attempt,
        receivedBytes: status.receivedBytes,
        totalBytes: status.totalBytes,
        sha256Ok: ok,
      );
    case DownloadEvent.failed:
      return _nextAttempt(status, sources.length, totalBytes);
  }
}

DownloadStatus _copy(DownloadStatus s, {required ModelState state}) =>
    DownloadStatus(
      state: state,
      sourceIndex: s.sourceIndex,
      attempt: s.attempt,
      receivedBytes: s.receivedBytes,
      totalBytes: s.totalBytes,
      sha256Ok: s.sha256Ok,
    );

DownloadStatus _nextAttempt(
  DownloadStatus s,
  int sourceCount,
  int totalBytes,
) {
  final nextAttempt = s.attempt + 1;
  final sameSource = nextAttempt <= kMaxAttemptsPerSource;
  final nextSourceIndex = s.sourceIndex + 1;
  if (!sameSource && nextSourceIndex >= sourceCount) {
    // 全源失败 → 损坏，不静默重试。
    return DownloadStatus(
      state: ModelState.corrupt,
      sourceIndex: s.sourceIndex,
      attempt: s.attempt,
      receivedBytes: 0,
      totalBytes: totalBytes,
    );
  }
  return DownloadStatus(
    state: ModelState.downloading,
    sourceIndex: sameSource ? s.sourceIndex : nextSourceIndex,
    attempt: sameSource ? nextAttempt : 1,
    // 换源后 .part 作废；同源重试保留断点。
    receivedBytes: sameSource ? s.receivedBytes : 0,
    totalBytes: totalBytes,
  );
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

enum DownloadEvent {
  start,
  diskOk,
  progress,
  completed,
  verified,
  failed,
}

/// 备份排除状态（docs/06 §5.3）：三端都必须排除 models/。
class BackupExclusion {
  const BackupExclusion({
    required this.androidDataExtraction,
    required this.androidFullBackup,
    required this.iosIsExcludedFromBackup,
    required this.windowsOutsideOneDrive,
  });

  final bool androidDataExtraction;
  final bool androidFullBackup;
  final bool iosIsExcludedFromBackup;
  final bool windowsOutsideOneDrive;

  bool get allConfigured =>
      androidDataExtraction &&
      androidFullBackup &&
      iosIsExcludedFromBackup &&
      windowsOutsideOneDrive;
}

// ---------------------------------------------------------------------------
// 索引重建（docs/06 §6）
// ---------------------------------------------------------------------------

enum ReembedScope { all, single }

/// 触发场景 → 范围，并决定是否先删旧模型向量。
ReembedPlan planReembed({
  required ReembedTrigger trigger,
  required String activeModelId,
  String? newModelId,
  int totalEntries = 0,
  int cursor = 0,
  int batchSize = 20,
}) {
  final switching = trigger == ReembedTrigger.modelSwitch;
  final scope = switch (trigger) {
    ReembedTrigger.firstDownload ||
    ReembedTrigger.modelSwitch ||
    ReembedTrigger.modelRedownload =>
        ReembedScope.all,
    ReembedTrigger.entryWrite ||
    ReembedTrigger.entryEdit ||
    ReembedTrigger.remotePull =>
        ReembedScope.single,
  };
  final targetModelId = newModelId ?? activeModelId;
  return ReembedPlan(
    scope: scope,
    deleteOtherModelVectors: switching,
    modelId: targetModelId,
    cursor: scope == ReembedScope.single ? 0 : cursor,
    batchSize: batchSize,
    totalEntries: scope == ReembedScope.single ? 1 : totalEntries,
  );
}

enum ReembedTrigger {
  firstDownload,
  modelSwitch,
  entryWrite,
  entryEdit,
  remotePull,
  modelRedownload,
}

class ReembedPlan {
  const ReembedPlan({
    required this.scope,
    required this.deleteOtherModelVectors,
    required this.modelId,
    required this.cursor,
    required this.batchSize,
    required this.totalEntries,
  });

  final ReembedScope scope;
  final bool deleteOtherModelVectors;
  final String modelId;
  final int cursor;
  final int batchSize;
  final int totalEntries;

  /// 本批的 [from, to)，可中断；每批完成后把 to 写回 cursor。
  (int, int)? nextBatch() {
    if (cursor >= totalEntries) return null;
    final end = (cursor + batchSize).clamp(0, totalEntries);
    return (cursor, end);
  }

  double get progress => totalEntries <= 0 ? 1.0 : cursor / totalEntries;

  ReembedPlan advance(int processed) => ReembedPlan(
        scope: scope,
        deleteOtherModelVectors: false,
        modelId: modelId,
        cursor: (cursor + processed).clamp(0, totalEntries),
        batchSize: batchSize,
        totalEntries: totalEntries,
      );
}

/// 下载中 / 构建中时检索降级为纯 FTS（docs/06 §6.3）。
///
/// 保留旧签名给「模型是否就绪」的快速判断；更精确的降级计划见
/// [planSearchDegradation]。
bool useVectorSearch(ModelState state) => state == ModelState.ready;

/// 索引构建进度（已构建 / 总数）。
class IndexBuildState {
  const IndexBuildState({
    required this.builtEntries,
    required this.totalEntries,
  });

  final int builtEntries;
  final int totalEntries;

  bool get isComplete => totalEntries <= 0 || builtEntries >= totalEntries;

  double get progress =>
      totalEntries <= 0 ? 1.0 : (builtEntries / totalEntries).clamp(0.0, 1.0);

}

/// 检索降级计划（docs/06 §6.3 四行表）。
class SearchDegradationPlan {
  const SearchDegradationPlan({
    required this.ftsEnabled,
    required this.vectorEnabled,
    required this.partialVectorOnly,
    required this.uiHint,
  });

  final bool ftsEnabled;
  final bool vectorEnabled;
  final bool partialVectorOnly;
  final String uiHint;
}

/// 任何情况下 FTS 都可用，只是向量质量不同：
/// - 无模型 / 下载中 / 校验中 → 纯 FTS（下载中静默）
/// - 索引构建中 → FTS + 已构建部分的向量，顶部细进度条
/// - 索引完成 / ready → 完整混合检索，无提示
SearchDegradationPlan planSearchDegradation({
  required ModelState modelState,
  IndexBuildState? indexState,
  bool modelDownloaded = true,
}) {
  if (!modelDownloaded) {
    return const SearchDegradationPlan(
      ftsEnabled: true,
      vectorEnabled: false,
      partialVectorOnly: false,
      uiHint: '下载模型可启用语义搜索',
    );
  }
  if (modelState == ModelState.downloading ||
      modelState == ModelState.checking ||
      modelState == ModelState.verifying) {
    return const SearchDegradationPlan(
      ftsEnabled: true,
      vectorEnabled: false,
      partialVectorOnly: false,
      uiHint: '',
    );
  }
  if (modelState == ModelState.corrupt ||
      modelState == ModelState.idle) {
    return const SearchDegradationPlan(
      ftsEnabled: true,
      vectorEnabled: false,
      partialVectorOnly: false,
      uiHint: '下载模型可启用语义搜索',
    );
  }
  final build = indexState;
  if (build != null && !build.isComplete) {
    return SearchDegradationPlan(
      ftsEnabled: true,
      vectorEnabled: true,
      partialVectorOnly: true,
      uiHint: '索引构建中 ${(build.progress * 100).floor()}%，'
          '仅已构建部分参与语义检索',
    );
  }
  return const SearchDegradationPlan(
    ftsEnabled: true,
    vectorEnabled: true,
    partialVectorOnly: false,
    uiHint: '',
  );
}

/// 模型 manifest 的 disk_bytes 用于磁盘检查；顺手校验 spec 自身合法。
int requiredDiskBytes(EmbeddingModelSpec spec) => (spec.diskBytes * 1.5).ceil();
