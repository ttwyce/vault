/// 跨链路端到端集成（docs/20 §5 A2）。
///
/// 一台本地 HttpServer 同时扮演 HTML 源站、WebDAV /vault/blobs/ 与 /backup/，
/// 两个 TestApp 内存库扮演 A / B 两台设备。串起 §3 表里已落地的真实链路：
/// L1 抓取 → L2 PDF 登记 → blob 条件上传 → 跨设备 Markdown 迁移 →
/// 按需下载 → 内容变更重抓 → 加密备份上传 / 还原校验。
///
/// **这不是新的产品模块**：没有新增判定层、meta 模型或 http_* 客户端。
/// 测试里两段胶水（put blobPath / 导出导入目录参数）对应当前产品缺口：
/// blob 上传器、restore 写回条目。都只在测试内出现，并显式断言其边界。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/crypto/vault_keys.dart';
import 'package:vault/core/sync/cloud_layout.dart';
import 'package:vault/core/sync/http_webdav_backend.dart';
import 'package:vault/core/sync/webdav_backend.dart';
import 'package:vault/data/archive/archive_meta.dart';
import 'package:vault/data/archive/content_change_policy.dart';
import 'package:vault/data/archive/content_change_service.dart';
import 'package:vault/data/archive/http_archive_fetcher.dart';
import 'package:vault/data/archive/http_blob_downloader.dart';
import 'package:vault/data/archive/pdf_snapshot_service.dart';
import 'package:vault/data/archive/simple_pdf.dart';
import 'package:vault/data/backup/backup_models.dart';
import 'package:vault/data/backup/encrypted_backup_service.dart';
import 'package:vault/data/backup/markdown_exporter.dart';
import 'package:vault/data/backup/markdown_importer.dart';
import 'package:vault/data/db/tables/entry_tables.dart';
import 'package:vault/data/vault/credential_repository.dart';
import 'package:vault/data/write/write_gateway.dart';

import 'support/test_harness.dart';

const String _firstHtml = '<html><head><title>旧标题</title></head>'
    '<body><article><h1>旧标题</h1>'
    '<p>这是第一版网页正文，内容足够长以便生成稳定的内容指纹，'
    '并且能在按需下载与重抓步骤里逐字核对。</p></article></body></html>';
const String _thirdHtml = '<html><head><title>新标题</title></head>'
    '<body><article><h1>新标题</h1>'
    '<p>完全不同的第二段叙述：向量检索采用混合排序，归档快照按内容寻址，'
    '密码字段永不进入模型上下文，日记补写按显式日期落库。</p>'
    '<p>这一版的措辞、标题、标签容器都与首版拉开距离，'
    '足以让 64 位指纹越过汉明距离阈值并触发旧版历史归档。</p>'
    '</article></body></html>';

/// 本地服务器：GET /page.html 返回可变 HTML；PUT/GET 任意路径按
/// If-None-Match: * 做条件写并维护 ETag（与真实 WebDavBackend 契约相同）。
class _PipelineServer {
  _PipelineServer(this.server);

  final HttpServer server;
  final Map<String, List<int>> objects = <String, List<int>>{};
  final Map<String, String> etags = <String, String>{};
  String html = _firstHtml;
  int seq = 1;

  static Future<_PipelineServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final site = _PipelineServer(server);
    server.listen((HttpRequest request) async {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/page.html') {
        request.response.headers.contentType = ContentType.html;
        request.response.write(site.html);
        await request.response.close();
        return;
      }
      if (request.method == 'PUT') {
        final createOnly = request.headers.value('if-none-match') == '*';
        if (createOnly && site.objects.containsKey(path)) {
          request.response.statusCode = 412;
          await request.response.close();
          return;
        }
        final bytes = await request.fold<List<int>>(
          <int>[], (List<int> acc, List<int> chunk) => acc..addAll(chunk));
        site.objects[path] = bytes;
        final tag = '"p${site.seq++}"';
        site.etags[path] = tag;
        request.response.headers.set('etag', tag);
        request.response.statusCode = 201;
        await request.response.close();
        return;
      }
      if (request.method == 'GET' || request.method == 'HEAD') {
        final bytes = site.objects[path];
        if (bytes == null) {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }
        request.response.headers.set('etag', site.etags[path]!);
        if (request.method == 'GET') request.response.add(bytes);
        await request.response.close();
        return;
      }
      request.response.statusCode = 405;
      await request.response.close();
    });
    return site;
  }

  String get rootUrl => 'http://127.0.0.1:${server.port}';
  String get pageUrl => '$rootUrl/page.html';
  void close() => server.close(force: true);
}

void main() {
  late TestApp deviceA;
  late TestApp deviceB;
  late _PipelineServer site;
  late HttpClientWebDavBackend backend;
  late Directory transferRoot;

  setUp(() async {
    deviceA = await TestApp.create(seed: 31);
    deviceB = await TestApp.create(seed: 32);
    site = await _PipelineServer.start();
    backend = HttpClientWebDavBackend(HttpWebDavConfig(rootUrl: site.rootUrl));
    transferRoot = await Directory.systemTemp.createTemp('vault-pipeline-');
  });

  tearDown(() async {
    backend.close();
    site.close();
    if (await transferRoot.exists()) {
      await transferRoot.delete(recursive: true);
    }
    await deviceA.dispose();
    await deviceB.dispose();
  });

  test('L1 → L2 PDF → blob → 跨设备下载 → 变更重抓 → 加密备份闭环',
      () async {
    // ① L1 真实抓取：GET 本地 HTML，抽取正文，经 WriteGateway 落条目 + oplog。
    final fetcher = HttpArchiveFetcher();
    final fetched = await fetcher.fetch(Uri.parse(site.pageUrl));
    fetcher.close();
    expect(fetched.ok, isTrue, reason: fetched.hint);
    expect(fetched.body, isNotNull);

    final meta = ArchiveMeta(
      url: site.pageUrl,
      site: ArchiveMeta.siteOf(site.pageUrl),
      status: ArchiveStatus.text,
      title: fetched.title,
      httpStatus: fetched.statusCode,
      excerpt: '第一版网页正文',
    );
    final written = await deviceA.gateway.writeEntry(EntryWrite.create(
      id: 'entry-archive-1',
      kind: EntryKind.bookmark,
      title: fetched.title,
      body: fetched.body,
      meta: meta.toJsonString(),
    ));
    expect(written.changed, isTrue);
    final rowAfterFetch = await (deviceA.db.select(deviceA.db.entries)
          ..where((t) => t.id.equals('entry-archive-1')))
        .getSingle();
    expect(rowAfterFetch.kind, EntryKind.bookmark.code);
    expect(rowAfterFetch.body, fetched.body);
    expect(await deviceA.db.select(deviceA.db.oplogs).get(), isNotEmpty,
        reason: '实体写入必须同事务追加 oplog');

    // ② L2 PDF：真实生成字节并经网关登记 blob_ref(kind=2, local=1)。
    final pdf = await PdfSnapshotService(
      db: deviceA.db,
      gateway: deviceA.gateway,
    ).generate(entryId: 'entry-archive-1');
    expect(pdf.ok, isTrue, reason: pdf.hint);
    expect(pdf.blobHash, isNotNull);
    final blobRow = await deviceA.db.select(deviceA.db.blobRefs).getSingle();
    expect(blobRow.kind, 2);
    expect(blobRow.local, 1);
    expect(blobRow.blobHash, pdf.blobHash);
    final updatedMetaRaw = await (deviceA.db.select(deviceA.db.entries)
          ..where((t) => t.id.equals('entry-archive-1')))
        .getSingle()
        .then((r) => r.meta);
    expect(
      ArchiveMeta.fromJson(jsonDecode(updatedMetaRaw!)).status,
      ArchiveStatus.full,
    );

    // ③ blob 上传：PdfSnapshotResult 不带字节（当前产品缺口），
    // 测试内重算后用 CloudLayout.blobPath + 条件 PUT 作胶水。
    final pdfBytes = buildSimplePdf(rowAfterFetch.body!).bytes;
    expect(sha256.convert(pdfBytes).toString(), pdf.blobHash,
        reason: '登记 hash 必须与实际上传字节一致（内容寻址）');
    final blobPath = CloudLayout.blobPath(pdf.blobHash!);
    final uploaded = await backend.put(
      blobPath,
      pdfBytes,
      condition: const WebDavCondition.createOnly(),
    );
    expect(uploaded.etag, isNotEmpty);
    expect(site.objects[blobPath], pdfBytes);

    // ④ 另一台设备：blob_ref 不参与 oplog 同步（WriteGateway 明确约定），
    // 所以用真实明文导出 / 导入把条目迁到 B 库，再登记 local=0 引用。
    final exported = await MarkdownExporter(
      db: deviceA.db,
      root: transferRoot,
    ).export(
      stage: PlaintextExportStage.done,
      knownSecrets: await _knownSecrets(deviceA),
    );
    expect(exported.ok, isTrue, reason: exported.hint);
    final imported = await MarkdownImporter(
      db: deviceB.db,
      gateway: deviceB.gateway,
      root: transferRoot,
    ).importFolder();
    expect(imported.inserted, <String>['entry-archive-1']);
    expect(imported.failed, isEmpty);
    final copied = await (deviceB.db.select(deviceB.db.entries)
          ..where((t) => t.id.equals('entry-archive-1')))
        .getSingle();
    expect(copied.body, fetched.body);
    expect(await deviceB.db.select(deviceB.db.blobRefs).get(), isEmpty,
        reason: 'blob_ref 是本地派生表，导入不会凭空造出引用');
    await deviceB.gateway.recordArchiveBlob(
      entryId: 'entry-archive-1',
      blobHash: pdf.blobHash!,
      kind: 2,
      bytes: pdfBytes.length,
      local: false,
    );
    final beforeDownload = await deviceB.db.select(deviceB.db.blobRefs).getSingle();
    expect(beforeDownload.local, 0);

    // ⑤ 按需下载：真实 GET /vault/blobs/... 读完整字节才置 local=1。
    // 当前下载器只统计字节、不落盘（产品缺口显式断言，不假装落盘）。
    final downloader = HttpBlobDownloader(gateway: deviceB.gateway);
    final downloaded = await downloader.download(
      entryId: 'entry-archive-1',
      blobHash: pdf.blobHash!,
      url: Uri.parse('${site.rootUrl}$blobPath'),
      expectedBytes: pdfBytes.length,
    );
    downloader.close();
    expect(downloaded.ok, isTrue, reason: downloaded.hint);
    expect(downloaded.bytes, pdfBytes.length);
    final afterDownload = await deviceB.db.select(deviceB.db.blobRefs).getSingle();
    expect(afterDownload.local, 1);

    // ⑥ 内容变更重抓：先建立「上一版指纹」，再换一版差异明显的 HTML。
    // planContentChange 遇到 previousSimhash=null 是 firstSnapshot，
    // 不写 history；这是既有策略的语义，不是缺陷。
    final changeFetcher = HttpArchiveFetcher();
    final changeService = ContentChangeService(
      db: deviceA.db,
      gateway: deviceA.gateway,
      fetcher: changeFetcher,
    );
    final first = await changeService.checkAndApply(
      entryId: 'entry-archive-1',
      nowMs: 1731052800000,
    );
    expect(first.ok, isTrue, reason: first.hint);
    site.html = _thirdHtml;
    final changed = await changeService.checkAndApply(
      entryId: 'entry-archive-1',
      nowMs: 1731052800500,
    );
    changeFetcher.close();
    expect(changed.ok, isTrue, reason: changed.hint);
    expect(changed.simhash, isNotNull);
    expect(changed.plan!.action, ContentChangeAction.promptChange,
        reason: changed.hint);
    final changedRow = await (deviceA.db.select(deviceA.db.entries)
          ..where((t) => t.id.equals('entry-archive-1')))
        .getSingle();
    expect(changedRow.body, contains('混合排序'));
    expect(await deviceA.db.select(deviceA.db.entryHistory).get(), isNotEmpty,
        reason: '变更必须保留旧版可对比');
    final checks = await deviceA.db.select(deviceA.db.linkChecks).get();
    expect(checks.length, 2);
    expect(checks.any((r) => r.simhash == changed.simhash), isTrue);

    // ⑦ 加密备份：真实打包 + /backup/ 条件 PUT + 还原解密校验 manifest。
    final service = EncryptedBackupService(
      db: deviceA.db,
      backend: backend,
      keys: deviceA.keys,
    );
    final upload = await service.upload(
      fileName: 'pipeline.enc',
      vaultId: 'vault-pipeline',
      nowMs: 1731052900000,
    );
    expect(upload.ok, isTrue, reason: upload.hint);
    expect(isBackupPath(backupPath('pipeline.enc')), isTrue);
    expect(site.objects[backupPath('pipeline.enc')], isNotNull);

    final restored = await service.restore('pipeline.enc');
    expect(restored.ok, isTrue, reason: restored.hint);
    expect(restored.manifest!.vaultId, 'vault-pipeline');
    expect(restored.manifest!.entries.keys, contains('entry-archive-1'));
    expect(restored.manifest!.blobs, containsPair(pdf.blobHash, pdfBytes.length),
        reason: 'manifest 必须登记真实 blob 大小');
    expect(await deviceB.db.select(deviceB.db.entryHistory).get(), isEmpty,
        reason: 'restore 目前只校验 manifest，不写回条目（当前产品边界）');

    // 错密钥 / 篡改都必须明确失败，不能静默当成空备份。
    final wrongKeys = VaultKeys.generate();
    final other = EncryptedBackupService(
      db: deviceA.db,
      backend: backend,
      keys: wrongKeys,
    );
    expect((await other.restore('pipeline.enc')).ok, isFalse);
    wrongKeys.destroy();
  });
}

Future<Set<String>> _knownSecrets(TestApp app) =>
    CredentialRepository(app.db, app.gateway).knownSecretValues();
