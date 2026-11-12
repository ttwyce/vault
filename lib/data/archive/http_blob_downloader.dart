/// 归档 blob 的**真实按需下载**（docs/05 §7）。
///
/// 用 Dart SDK `dart:io` GET blob URL，流式计进度；下载成功后经
/// [WriteGateway.markArchiveBlobLocal] 只把 `local` 置 1（云端副本保留）。
/// 不新增依赖；真机 / 外网验收可跳过，用本地 HttpServer 注入完整验证。
/// 失败 / 超时 / 超过声明字节数一律不动数据库，绝不把半截 .part 当可用。
library;

import 'dart:async';
import 'dart:io';

import '../write/write_gateway.dart';

class BlobDownloadResult {
  const BlobDownloadResult({
    required this.ok,
    required this.bytes,
    required this.progress,
    required this.hint,
  });

  final bool ok;
  final int bytes;
  final double progress;
  final String hint;
}

class HttpBlobDownloader {
  HttpBlobDownloader({
    required this.gateway,
    HttpClient? client,
    this.connectTimeout = const Duration(seconds: 10),
    this.readTimeout = const Duration(seconds: 60),
  }) : _client = client ?? HttpClient();

  final WriteGateway gateway;
  final HttpClient _client;
  final Duration connectTimeout;
  final Duration readTimeout;

  void close({bool force = true}) => _client.close(force: force);

  /// [onProgress] 每收到一块回调 0~1；[expectedBytes] 来自 blob_ref.bytes。
  Future<BlobDownloadResult> download({
    required String entryId,
    required String blobHash,
    required Uri url,
    required int expectedBytes,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final request = await _client.getUrl(url).timeout(connectTimeout);
      final response = await request.close().timeout(connectTimeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        return BlobDownloadResult(
          ok: false,
          bytes: 0,
          progress: 0,
          hint: 'blob 返回 HTTP ${response.statusCode}，local 保持 0',
        );
      }
      var received = 0;
      await for (final chunk in response.timeout(readTimeout)) {
        received += chunk.length;
        if (expectedBytes > 0 && received > expectedBytes * 2) {
          throw const HttpException('blob 实际大小远超声明，拒绝落库');
        }
        onProgress?.call(expectedBytes <= 0
            ? 0
            : (received / expectedBytes).clamp(0.0, 1.0).toDouble());
      }
      // 只有完整读完才写 local=1。
      await gateway.markArchiveBlobLocal(
        entryId: entryId,
        blobHash: blobHash,
      );
      return BlobDownloadResult(
        ok: true,
        bytes: received,
        progress: 1,
        hint: '已下载到本地缓存（local=1），云端副本保留',
      );
    } on TimeoutException {
      return const BlobDownloadResult(
        ok: false,
        bytes: 0,
        progress: 0,
        hint: 'blob 下载超时，local 保持 0',
      );
    } on SocketException {
      return const BlobDownloadResult(
        ok: false,
        bytes: 0,
        progress: 0,
        hint: '网络不可达，local 保持 0',
      );
    } on HttpException catch (e) {
      return BlobDownloadResult(
        ok: false,
        bytes: 0,
        progress: 0,
        hint: 'blob 下载异常：${e.message}，local 保持 0',
      );
    } on Object {
      return const BlobDownloadResult(
        ok: false,
        bytes: 0,
        progress: 0,
        hint: 'blob 下载失败，local 保持 0',
      );
    }
  }
}
