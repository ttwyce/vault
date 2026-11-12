/// dart:io 客户端的异常分类（docs/20 §5 A3）。
///
/// 各 `http_*` 客户端原本重复写四段
/// `on TimeoutException / on SocketException / on HttpException / on Object`。
/// 这里只做**分类**，不决定业务结果：调用方仍按自己的能力返回各自的
/// 结果对象与 hint 文案，字符串逐字不变，重试策略也留在各客户端里。
///
/// 不含 `package:http`、不含网络请求，纯同步判定。
library;

import 'dart:async';
import 'dart:io';

enum NetworkFailureKind { timeout, unreachable, protocol, other }

class NetworkFailure {
  const NetworkFailure(this.kind, this.detail);

  final NetworkFailureKind kind;

  /// SocketException / HttpException 的 message；其余为空。
  /// **不新增日志**：这个字符串只用于拼调用方已有的用户可见 hint。
  final String detail;
}

NetworkFailure classifyNetworkFailure(Object error) {
  if (error is TimeoutException) {
    return const NetworkFailure(NetworkFailureKind.timeout, '');
  }
  if (error is SocketException) {
    return NetworkFailure(NetworkFailureKind.unreachable, error.message);
  }
  if (error is HttpException) {
    return NetworkFailure(NetworkFailureKind.protocol, error.message);
  }
  return const NetworkFailure(NetworkFailureKind.other, '');
}
