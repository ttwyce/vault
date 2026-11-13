import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/agent/agent_loop.dart';
import 'package:vault/data/agent/mcp_http_transport.dart';

/// MCP loopback transport：真实 HTTP 调用与默认关闭。
void main() {
  test('非 loopback 地址直接拒绝', () async {
    final transport = McpHttpTransport(
      endpoint: Uri.parse('https://mcp.example.com/tools/call'),
    );
    final result = await transport.callTool(
      remoteName: 'echo',
      args: const <String, Object?>{'text': 'hi'},
    );
    expect(result.ok, isFalse);
    expect(result.hint, contains('loopback'));
  });

  test('loopback bridge 真实返回工具内容', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((HttpRequest request) async {
      final body = await utf8.decoder.bind(request).join();
      expect(jsonDecode(body)['tool'], 'echo');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{
        'content': '远程工具结果',
      }));
      await request.response.close();
    });
    final transport = McpHttpTransport(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/tools/call'),
    );
    final result = await transport.callTool(
      remoteName: 'echo',
      args: const <String, Object?>{'text': 'hi'},
    );
    expect(result.ok, isTrue);
    expect(result.content, '远程工具结果');
  });

  test('未配置 transport 的 McpToolAdapter 仍明确未连接', () async {
    const adapter = McpToolAdapter(
      remoteName: 'echo',
      description: '测试',
      schema: <String, Object?>{'type': 'object'},
    );
    final result = await adapter.execute(const <String, Object?>{});
    expect(result.isError, isTrue);
    expect(result.content, contains('尚未连接'));
  });
}
