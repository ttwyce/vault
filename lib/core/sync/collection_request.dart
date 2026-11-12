/// 真实 WebDAV 后端的集合请求容错（docs/04 §10 / D37）。
///
/// 真实 Nextcloud 的分片集合首次不存在时返回 404，而同步编排器把分片
/// 404 判成扫描失败。这里在 PROPFIND / REPORT / OPTIONS 类集合请求失败时
/// 逐级补齐父目录再重试一次；GET 单个文件 404 绝不建目录（那是正常 diff）。
library;

import 'mkcol_with_parents.dart';
import 'webdav_backend.dart';

Future<T> collectionRequest<T>(
  WebDavBackend backend,
  String path,
  Future<T> Function() call,
) async {
  try {
    return await call();
  } on WebDavException catch (e) {
    if (e.statusCode != 404 && e.statusCode != 409) rethrow;
    await mkcolWithParents(backend, path);
    return await call();
  }
}
