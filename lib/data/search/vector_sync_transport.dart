/// 向量同步的**真实传输层**（docs/06 §7）。
///
/// 走真实 [WebDavBackend] 的 GET / 条件 PUT，路径由
/// `CloudLayout.vectorPath` 决定；封包是 [VectorEnvelope] 的 JSON。
/// 下载后必须过 [checkVectorEnvelope]：model_id / dim / dtype 不匹配
/// 一律丢弃并标记需重算，绝不把别的模型向量写进本地语义空间。
/// 不新增依赖；本地 HttpServer 即可完整验证传输。
library;

import 'dart:convert';

import '../../core/sync/cloud_layout.dart';
import '../../core/sync/webdav_backend.dart';
import 'vector_sync_policy.dart';

class VectorPullResult {
  const VectorPullResult({
    required this.envelope,
    required this.check,
    required this.hint,
  });

  /// 只有 accepted 时才非 null。
  final VectorEnvelope? envelope;
  final VectorCheckResult check;
  final String hint;

  bool get accepted => check.accepted;
  bool get needsRecompute => check.needsRecompute;
}

class VectorPushResult {
  const VectorPushResult({
    required this.ok,
    required this.etag,
    required this.hint,
  });

  final bool ok;
  final String? etag;
  final String hint;
}

class VectorSyncTransport {
  const VectorSyncTransport({
    required this.backend,
    required this.expected,
  });

  final WebDavBackend backend;
  final VectorExpectation expected;

  String pathFor(String hashedName) => CloudLayout.vectorPath(hashedName);

  /// 从 `/vault/vec/<name>` 拉封包并校验。坏 JSON / 规格不符
  /// 都返回 needsRecompute，不抛出、不写本地。
  Future<VectorPullResult> pull(String hashedName) async {
    final path = pathFor(hashedName);
    try {
      final got = await backend.get(path);
      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(got.bytes));
      } on Object {
        return VectorPullResult(
          envelope: null,
          check: checkVectorEnvelope(null, expected),
          hint: '$path 不是合法 JSON 封包，需重算',
        );
      }
      final envelope = VectorEnvelope.tryParse(decoded);
      final check = checkVectorEnvelope(envelope, expected);
      return VectorPullResult(
        envelope: check.accepted ? envelope : null,
        check: check,
        hint: check.accepted
            ? '已接受 ${envelope!.modelId} 向量封包'
            : '封包被丢弃：${check.reasons.join('；')}',
      );
    } on WebDavException catch (e) {
      return VectorPullResult(
        envelope: null,
        check: checkVectorEnvelope(null, expected),
        hint: '拉取 $path 失败（${e.statusCode}），需重算',
      );
    }
  }

  /// 条件上传。createOnly 用 `If-None-Match: *`，更新必须带 ETag；
  /// 绝不无条件 PUT。
  Future<VectorPushResult> push(
    String hashedName,
    VectorEnvelope envelope, {
    String? ifMatchEtag,
  }) async {
    final check = checkVectorEnvelope(envelope, expected);
    if (!check.accepted) {
      return VectorPushResult(
        ok: false,
        etag: null,
        hint: '拒绝上传：${check.reasons.join('；')}',
      );
    }
    final path = pathFor(hashedName);
    final condition = ifMatchEtag == null
        ? const WebDavCondition.createOnly()
        : WebDavCondition.ifMatch(ifMatchEtag);
    try {
      final result = await backend.put(
        path,
        utf8.encode(jsonEncode(envelope.toJson())),
        condition: condition,
      );
      return VectorPushResult(
        ok: true,
        etag: result.etag,
        hint: '已条件上传 $path',
      );
    } on WebDavException catch (e) {
      return VectorPushResult(
        ok: false,
        etag: null,
        hint: '上传 $path 失败（${e.statusCode}），保留本地待重试',
      );
    }
  }
}
