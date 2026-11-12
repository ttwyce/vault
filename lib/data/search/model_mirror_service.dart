/// 用户 WebDAV 作为**模型镜像**的真实传输（docs/06 §5.4）。
///
/// 默认关闭：所有操作都必须 `userOptedIn`，否则不读写云端。
/// 上传走条件 PUT `/vault/models/<id>.gguf`（与 items 分离），
/// 下载走 GET 并做 sha256 校验，失败删文件不假装可用。
/// 不新增依赖；本地 HttpServer + 临时目录即可完整验证。
library;

import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;

import '../../core/sync/cloud_layout.dart';
import '../../core/sync/webdav_backend.dart';

class ModelMirrorResult {
  const ModelMirrorResult({
    required this.ok,
    required this.hint,
    required this.bytes,
    required this.etag,
  });

  final bool ok;
  final String hint;
  final int bytes;
  final String? etag;
}

class ModelMirrorService {
  const ModelMirrorService({
    required this.backend,
    required this.modelsRoot,
  });

  final WebDavBackend backend;
  final Directory modelsRoot;

  static String pathFor(String modelId) => CloudLayout.modelPath(modelId);

  Future<ModelMirrorResult> upload({
    required String modelId,
    required String expectedSha256,
    required bool userOptedIn,
    int quotaUsedBytes = 0,
    int quotaLimitBytes = 0,
    String? ifMatchEtag,
  }) async {
    if (!userOptedIn) {
      return const ModelMirrorResult(
        ok: false,
        hint: '模型镜像默认关闭，未勾选不上传',
        bytes: 0,
        etag: null,
      );
    }
    final path = pathFor(modelId);
    final file = File('${modelsRoot.path}/$modelId/$modelId.gguf');
    if (!await file.exists()) {
      return const ModelMirrorResult(
        ok: false,
        hint: '本地模型文件不存在，未上传',
        bytes: 0,
        etag: null,
      );
    }
    final bytes = await file.readAsBytes();
    if (quotaLimitBytes > 0 &&
        quotaUsedBytes + bytes.length > quotaLimitBytes) {
      return ModelMirrorResult(
        ok: false,
        hint: '超过云端配额（${quotaUsedBytes + bytes.length}/$quotaLimitBytes），未上传',
        bytes: bytes.length,
        etag: null,
      );
    }
    if (sha256.convert(bytes).toString() != expectedSha256) {
      return ModelMirrorResult(
        ok: false,
        hint: '本地模型 sha256 校验失败，拒绝上传损坏文件',
        bytes: bytes.length,
        etag: null,
      );
    }
    final condition = ifMatchEtag == null
        ? const WebDavCondition.createOnly()
        : WebDavCondition.ifMatch(ifMatchEtag);
    try {
      final result = await backend.put(path, bytes, condition: condition);
      return ModelMirrorResult(
        ok: true,
        hint: '已上传模型镜像 $path（${bytes.length} 字节，占配额）',
        bytes: bytes.length,
        etag: result.etag,
      );
    } on WebDavException catch (e) {
      return ModelMirrorResult(
        ok: false,
        hint: '上传失败（HTTP ${e.statusCode}），本地文件保留',
        bytes: bytes.length,
        etag: null,
      );
    }
  }

  Future<ModelMirrorResult> download({
    required String modelId,
    required String expectedSha256,
    required bool userOptedIn,
  }) async {
    if (!userOptedIn) {
      return const ModelMirrorResult(
        ok: false,
        hint: '模型镜像默认关闭，未勾选不拉取',
        bytes: 0,
        etag: null,
      );
    }
    final path = pathFor(modelId);
    try {
      final got = await backend.get(path);
      if (got.bytes.isEmpty) {
        return ModelMirrorResult(
          ok: false,
          hint: '云端模型为空，未写入本地',
          bytes: 0,
          etag: got.etag,
        );
      }
      if (sha256.convert(got.bytes).toString() != expectedSha256) {
        return ModelMirrorResult(
          ok: false,
          hint: '云端模型 sha256 校验失败，拒绝写入',
          bytes: got.bytes.length,
          etag: got.etag,
        );
      }
      final dir = Directory('${modelsRoot.path}/$modelId');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$modelId.gguf');
      await file.writeAsBytes(got.bytes);
      return ModelMirrorResult(
        ok: true,
        hint: '已从镜像拉取模型（${got.bytes.length} 字节）',
        bytes: got.bytes.length,
        etag: got.etag,
      );
    } on WebDavException catch (e) {
      return ModelMirrorResult(
        ok: false,
        hint: '拉取失败（HTTP ${e.statusCode}）',
        bytes: 0,
        etag: null,
      );
    }
  }
}
