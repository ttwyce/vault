import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/http_model_downloader.dart';

/// 纯 Dart：真实本地 HttpServer + 临时目录，不走 TestWidgetsFlutterBinding。
void main() {
  test('HttpModelDownloader 按自定义源真实下载并校验 sha256', () async {
    final bytes =
        Uint8List.fromList(List<int>.generate(512, (int i) => i % 251));
    final expectedHash = sha256.convert(bytes).toString();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((HttpRequest request) async {
      request.response.headers.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    });
    final root = await Directory.systemTemp.createTemp('vault-model-src-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final downloader = HttpModelDownloader(modelsRoot: root);
    final outcome = await downloader.download(
      modelId: 'custom-model',
      expectedSha256: expectedHash,
      modelBytes: bytes.length,
      sourceUrls: <String>['http://127.0.0.1:${server.port}/model.gguf'],
    );
    downloader.close();
    expect(outcome.ready, isTrue, reason: outcome.hint);
    final file = File('${root.path}/custom-model/custom-model.gguf');
    expect(await file.exists(), isTrue);
    expect(await file.length(), bytes.length);
  });
}
