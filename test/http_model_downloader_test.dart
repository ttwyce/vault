import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/http_model_downloader.dart';
import 'package:vault/data/search/model_downloader.dart';

/// docs/06 §5：真实模型下载用本地 HttpServer + 临时目录验证。
class _ModelServer {
  _ModelServer(this.server);
  final HttpServer server;
  late List<int> payload;
  bool supportRange = true;
  int status = 200;
  final List<String> ranges = <String>[];

  static Future<_ModelServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _ModelServer(server);
    site.payload = utf8.encode('model-weights-${'x' * 200}');
    server.listen((HttpRequest request) async {
      if (site.status != 200) {
        request.response.statusCode = site.status;
        await request.response.close();
        return;
      }
      final range = request.headers.value('range');
      site.ranges.add(range ?? '');
      if (range != null && site.supportRange) {
        final start = int.tryParse(
              range.replaceAll('bytes=', '').split('-').first.trim(),
            ) ??
            0;
        request.response.statusCode = 206;
        request.response.headers.set(
          'content-range',
          'bytes $start-${site.payload.length - 1}/${site.payload.length}',
        );
        request.response.add(site.payload.sublist(start));
      } else {
        request.response.add(site.payload);
      }
      await request.response.close();
    });
    return site;
  }

  String url(String path) => 'http://127.0.0.1:${server.port}$path';
  String get digest => sha256.convert(payload).toString();
  void close() => server.close(force: true);
}

void main() {
  late _ModelServer site;
  late Directory root;
  late HttpModelDownloader downloader;

  setUp(() async {
    site = await _ModelServer.start();
    root = await Directory.systemTemp.createTemp('vault-model-test-');
    downloader = HttpModelDownloader(
      modelsRoot: root,
      connectTimeout: const Duration(seconds: 2),
      readTimeout: const Duration(seconds: 2),
    );
  });
  tearDown(() {
    downloader.close();
    site.close();
    root.deleteSync(recursive: true);
  });

  test('真实 GET + sha256 校验通过 → ready 且正式文件落盘', () async {
    final outcome = await downloader.download(
      modelId: 'm-ok',
      expectedSha256: site.digest,
      modelBytes: site.payload.length,
      sourceUrls: <String>[site.url('/ok.gguf')],
    );
    expect(outcome.ready, isTrue);
    expect(outcome.status.state, ModelState.ready);
    final file = File(outcome.filePath!);
    expect(await file.exists(), isTrue);
    expect(await file.length(), site.payload.length);
    expect(await File('${root.path}/m-ok/m-ok.part').exists(), isFalse);
  });

  test('已有 .part 时发 Range: bytes=N- 断点续传', () async {
    final dir = Directory('${root.path}/m-resume')..createSync(recursive: true);
    final part = File('${dir.path}/m-resume.part');
    final half = site.payload.sublist(0, 40);
    part.writeAsBytesSync(half);
    final progress = <int>[];
    final outcome = await downloader.download(
      modelId: 'm-resume',
      expectedSha256: site.digest,
      modelBytes: site.payload.length,
      sourceUrls: <String>[site.url('/resume.gguf')],
      onProgress: (int received, int total) => progress.add(received),
    );
    expect(outcome.ready, isTrue);
    expect(site.ranges.any((String r) => r.startsWith('bytes=40-')), isTrue);
    expect(progress.isNotEmpty, isTrue);
    expect(await File(outcome.filePath!).readAsBytes(), site.payload);
  });

  test('服务器忽略 Range 返回 200 时从头覆盖，不会拼出坏文件', () async {
    site.supportRange = false;
    final dir = Directory('${root.path}/m-ignore')..createSync(recursive: true);
    File('${dir.path}/m-ignore.part').writeAsBytesSync(<int>[9, 9, 9]);
    final outcome = await downloader.download(
      modelId: 'm-ignore',
      expectedSha256: site.digest,
      modelBytes: site.payload.length,
      sourceUrls: <String>[site.url('/ignore.gguf')],
    );
    expect(outcome.ready, isTrue);
    expect(await File(outcome.filePath!).readAsBytes(), site.payload);
  });

  test('sha256 不符换下一个源；全源失败标记 corrupt', () async {
    final wrongFirst = await downloader.download(
      modelId: 'm-wrong',
      expectedSha256: '0' * 64,
      modelBytes: site.payload.length,
      sourceUrls: <String>[
        site.url('/a.gguf'),
        site.url('/b.gguf'),
        site.url('/c.gguf'),
        site.url('/d.gguf'),
      ],
    );
    expect(wrongFirst.ready, isFalse);
    expect(wrongFirst.status.state, ModelState.corrupt);
    expect(wrongFirst.filePath, isNull);

    site.status = 500;
    final allFail = await downloader.download(
      modelId: 'm-fail',
      expectedSha256: site.digest,
      modelBytes: site.payload.length,
      sourceUrls: <String>[site.url('/x.gguf')],
    );
    expect(allFail.status.state, ModelState.corrupt);
  });

  test('磁盘不足直接拒绝，不发任何请求', () async {
    final limited = HttpModelDownloader(
      modelsRoot: root,
      connectTimeout: const Duration(seconds: 2),
      freeBytes: () => 10,
    );
    final outcome = await limited.download(
      modelId: 'm-disk',
      expectedSha256: site.digest,
      modelBytes: site.payload.length,
      sourceUrls: <String>[site.url('/disk.gguf')],
    );
    expect(outcome.ready, isFalse);
    expect(outcome.hint, contains('磁盘空间不足'));
    expect(site.ranges, isEmpty);
    limited.close();
  });
}
