/// 嵌入模型的**真实下载器**（docs/06 §5）。
///
/// 用 Dart SDK `dart:io` GET 模型文件：支持 `.part` 断点续传
/// （`Range: bytes=<offset>-`）、流式进度、完成后 sha256 校验；
/// 校验失败删 `.part` 并换下一个源，每个源独立重试，全源失败才
/// 标记损坏。状态推进复用 [advanceDownload]，不新增依赖；
/// 真机 / 外网验收可跳过，用本地 HttpServer + 临时目录即可完整验证。
library;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;

import 'model_downloader.dart';

class ModelDownloadOutcome {
  const ModelDownloadOutcome({
    required this.status,
    required this.hint,
    required this.filePath,
  });

  final DownloadStatus status;
  final String hint;
  final String? filePath;

  bool get ready => status.state == ModelState.ready;
}

class HttpModelDownloader {
  HttpModelDownloader({
    required this.modelsRoot,
    HttpClient? client,
    this.connectTimeout = const Duration(seconds: 10),
    this.readTimeout = const Duration(seconds: 60),
    this.freeBytes,
  }) : _client = client ?? HttpClient();

  final Directory modelsRoot;
  final HttpClient _client;
  final Duration connectTimeout;
  final Duration readTimeout;

  /// 磁盘可用空间（测试可注入）；默认给足，避免假失败。
  final int Function()? freeBytes;

  void close({bool force = true}) => _client.close(force: force);

  Future<ModelDownloadOutcome> download({
    required String modelId,
    required String expectedSha256,
    required int modelBytes,
    required List<String> sourceUrls,
    void Function(DownloadStatus status)? onStatus,
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = Directory('${modelsRoot.path}/$modelId');
    final part = File('${dir.path}/$modelId.part');
    final finalFile = File('${dir.path}/$modelId.gguf');

    // 状态机的源数必须与真实 URL 数一致，否则换源边界错。
    final sources = List<ModelSource>.generate(
      sourceUrls.isEmpty ? 1 : sourceUrls.length,
      (int i) => kDefaultSourceOrder[i % kDefaultSourceOrder.length],
    );
    var status = advanceDownload(
      const DownloadStatus(
        state: ModelState.idle,
        sourceIndex: 0,
        attempt: 1,
        receivedBytes: 0,
        totalBytes: 0,
      ),
      DownloadEvent.start,
      totalBytes: modelBytes,
      expectedSha256: expectedSha256,
      actualSha256: '',
      sources: sources,
    );
    onStatus?.call(status);

    final free = freeBytes?.call() ?? (modelBytes * 2);
    if (!hasEnoughDisk(freeBytes: free, modelBytes: modelBytes)) {
      final noSpace = DownloadStatus(
        state: ModelState.corrupt,
        sourceIndex: 0,
        attempt: 1,
        receivedBytes: 0,
        totalBytes: modelBytes,
      );
      onStatus?.call(noSpace);
      return ModelDownloadOutcome(
        status: noSpace,
        hint: '磁盘空间不足（需 ≥ ${(modelBytes * 1.5).ceil()} 字节）',
        filePath: null,
      );
    }
    status = advanceDownload(
      status,
      DownloadEvent.diskOk,
      totalBytes: modelBytes,
      expectedSha256: expectedSha256,
      actualSha256: '',
      sources: sources,
    );
    onStatus?.call(status);

    while (status.state == ModelState.downloading) {
      if (status.sourceIndex >= sourceUrls.length) {
        status = DownloadStatus(
          state: ModelState.corrupt,
          sourceIndex: status.sourceIndex,
          attempt: status.attempt,
          receivedBytes: 0,
          totalBytes: modelBytes,
        );
        break;
      }
      final url = sourceUrls[status.sourceIndex];
      final ok = await _tryOne(
        url: url,
        dir: dir,
        part: part,
        expectedSha256: expectedSha256,
        modelBytes: modelBytes,
        keepPart: true,
        onProgress: onProgress,
      );
      if (ok == null) {
        // 网络失败：.part 同源重试保留，换源时由状态机清 0 后删除。
        final next = advanceDownload(
          status,
          DownloadEvent.failed,
          totalBytes: modelBytes,
          expectedSha256: expectedSha256,
          actualSha256: '',
          sources: sources,
        );
        if (next.sourceIndex != status.sourceIndex && await part.exists()) {
          await part.delete();
        }
        status = next;
        onStatus?.call(status);
        continue;
      }
      if (!ok) {
        // sha256 校验失败：删 .part，换下一个尝试 / 源。
        if (await part.exists()) await part.delete();
        status = advanceDownload(
          status,
          DownloadEvent.failed,
          totalBytes: modelBytes,
          expectedSha256: expectedSha256,
          actualSha256: '',
          sources: sources,
        );
        onStatus?.call(status);
        continue;
      }
      // 完整下载 + 校验通过 → verifying → ready。
      status = advanceDownload(
        status,
        DownloadEvent.completed,
        totalBytes: modelBytes,
        expectedSha256: expectedSha256,
        actualSha256: '',
        sources: sources,
      );
      status = advanceDownload(
        status,
        DownloadEvent.verified,
        totalBytes: modelBytes,
        expectedSha256: expectedSha256,
        actualSha256: expectedSha256,
        sources: sources,
      );
      onStatus?.call(status);
      if (await finalFile.exists()) await finalFile.delete();
      await part.rename(finalFile.path);
    }

    return ModelDownloadOutcome(
      status: status,
      hint: status.state == ModelState.ready
          ? '模型校验通过，已就绪'
          : '全源失败或校验不通过，模型标记损坏',
      filePath: status.state == ModelState.ready ? finalFile.path : null,
    );
  }

  /// 返回 null = 网络失败；false = 校验失败；true = 完整且 sha256 通过。
  Future<bool?> _tryOne({
    required String url,
    required Directory dir,
    required File part,
    required String expectedSha256,
    required int modelBytes,
    required bool keepPart,
    void Function(int received, int total)? onProgress,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    final offset = resumeOffset(
      await part.exists() ? await part.length() : 0,
      modelBytes,
    );
    try {
      final request = await _client.getUrl(uri).timeout(connectTimeout);
      if (offset > 0) request.headers.set('range', 'bytes=$offset-');
      final response = await request.close().timeout(connectTimeout);
      if (response.statusCode != 200 && response.statusCode != 206) {
        await response.drain<void>();
        return null;
      }
      // 服务器忽略了 Range（返回 200 而非 206）时必须从头覆盖，
      // 否则 append 会把全量内容接到旧 .part 后面导致 sha256 失败。
      final resumed = offset > 0 && response.statusCode == 206;
      final sink = part.openWrite(
        mode: resumed ? FileMode.append : FileMode.write,
      );
      var received = resumed ? offset : 0;
      try {
        await for (final chunk in response.timeout(readTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, modelBytes);
        }
      } finally {
        await sink.close();
      }
      if (!keepPart) return null;
      final bytes = await part.readAsBytes();
      final actual = sha256.convert(bytes).toString();
      return _constantTimeEqualsPublic(expectedSha256, actual);
    } on Object {
      // 四类失败对下载器是同一个结果：本源不可用，换下一个源。
      // 网络异常分类由 http_* 客户端共用（见 data/network_failure.dart）；
      // 这里不需要区分类型，也不吞掉非网络异常之外的错误细节。
      return null;
    }
  }
}

/// 与状态机内部同口径的常量时间比较（避免校验值比较走短路）。
bool _constantTimeEqualsPublic(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
