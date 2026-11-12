/// 真实 HTTP WebDAV 后端的集合创建（docs/04 §10 / D37）。
///
/// 坚果云 / Nextcloud 的 `MKCOL` 不会递归创建父目录：如果
/// `/vault/items/f` 的父级 `/vault/items` 不存在，会返回 409 Conflict。
/// 同步引擎在 404/409 时只重建**目标目录一次**（见 SyncEngine.putWithMkcol），
/// 所以后端在这里逐段补齐父集合，保证条件写重试拿到的是真正修复后的路径。
///
/// 幂等：目标已存在时 405/409 一律当成功；只对 GET 文件 404 不建目录。
library;

import 'webdav_backend.dart';

/// 输入形如 `/vault/items/f`；返回需要逐级创建的集合路径。
List<String> parentCollectionPaths(String path) {
  if (!path.startsWith('/')) {
    throw ArgumentError.value(path, 'path', 'WebDAV 路径必须以 / 开头');
  }
  final segments = path.split('/')
    ..removeWhere((String segment) => segment.isEmpty);
  final parents = <String>[''];
  for (var i = 1; i < segments.length; i++) {
    parents.add('/${segments.sublist(0, i).join('/')}');
  }
  return List<String>.unmodifiable(parents);
}

Future<void> mkcolWithParents(
  WebDavBackend backend,
  String path,
) async {
  for (final parent in parentCollectionPaths(path)) {
    try {
      await backend.mkcol(parent);
    } on WebDavException catch (e) {
      // 405 = 已存在；409 = 并发创建 / 父级已存在；都等同于集合已就绪。
      if (e.statusCode != 405 && e.statusCode != 409) rethrow;
    }
  }
  try {
    await backend.mkcol(path);
  } on WebDavException catch (e) {
    if (e.statusCode != 405 && e.statusCode != 409) rethrow;
  }
}
