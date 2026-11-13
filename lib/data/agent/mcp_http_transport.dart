/// MCP over loopback HTTP（docs/07 §3.3 二期）。
///
/// 移动端没有 shell / stdio，桌面端也不保证有 MCP 进程；这里提供
/// 显式配置的 HTTP transport：默认关闭，只有用户填了本地 MCP bridge
/// 地址才会发请求。远程工具仍走 [checkToolCall] 的 L2 / dangerous 闸门。
/// 不发云端、不自动发现服务。
library;

// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import 'agent_policy.dart';

class McpTransportResult {
  const McpTransportResult({
    required this.ok,
    required this.content,
    required this.hint,
  });

  final bool ok;
  final String content;
  final String hint;
}

class McpHttpTransport {
  McpHttpTransport({
    required this.endpoint,
    HttpClient? client,
  }) : _client = client;

  final Uri endpoint;
  final HttpClient? _client;

  /// 只允许 loopback；把 Key/URL 发给远端主机不是 MCP 本地桥的语义。
  bool get valid =>
      (endpoint.host == '127.0.0.1' ||
          endpoint.host == 'localhost' ||
          endpoint.host == '::1') &&
      (endpoint.scheme == 'http' || endpoint.scheme == 'https');

  Future<McpTransportResult> callTool({
    required String remoteName,
    required Map<String, Object?> args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!valid) {
      return const McpTransportResult(
        ok: false,
        content: '',
        hint: 'MCP 地址必须是本机 loopback',
      );
    }
    final client = _client ?? HttpClient();
    try {
      final request = await client.postUrl(endpoint).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(<String, Object?>{
        'tool': remoteName,
        'args': args,
      }));
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        return McpTransportResult(
          ok: false,
          content: '',
          hint: 'MCP bridge 返回 HTTP ${response.statusCode}',
        );
      }
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['content'] is! String) {
        return const McpTransportResult(
          ok: false,
          content: '',
          hint: 'MCP bridge 响应格式不合法',
        );
      }
      return McpTransportResult(
        ok: true,
        content: decoded['content'] as String,
        hint: 'MCP 工具已返回',
      );
    } on SocketException {
      return const McpTransportResult(
        ok: false,
        content: '',
        hint: 'MCP bridge 不可达',
      );
    } on Object {
      return const McpTransportResult(
        ok: false,
        content: '',
        hint: 'MCP 调用失败',
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}

/// 让 `McpToolAdapter` 可注入 transport 的小接口。
abstract class McpTransport {
  Future<McpTransportResult> callTool({
    required String remoteName,
    required Map<String, Object?> args,
  });
}

ToolResult mcpResultToToolResult(McpTransportResult result) => ToolResult(
      result.ok ? result.content : result.hint,
      isError: !result.ok,
    );
