/// App 启动装配：把已写好的真实链路聚合起来交给页面（docs/20 §5 A1）。
///
/// 这一层**不实现任何新能力**：不碰数据库结构、不实例化 VaultSyncRuntime、
/// 不持久化 WebDAV 凭据、不把 API Key 写进 settings.json。
/// 默认状态全部为 null，测试里没有 ProviderScope override 时页面保持
/// 原来的「未装配」诚实降级，而不是抛异常。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/agent/llm_chat_service.dart';
import '../../data/archive/http_archive_fetcher.dart';
import '../../data/archive/http_link_checker.dart';
import '../../data/archive/http_wayback_client.dart';
import '../../data/backup/backup_models.dart';
import '../../data/backup/markdown_exporter.dart';
import '../../data/backup/markdown_importer.dart';
import '../../data/backup/security_audit.dart';
import '../../data/db/vault_database.dart';
import '../../data/search/http_model_downloader.dart';
import '../../data/vault/credential_repository.dart';
import '../../data/vault/http_hibp_client.dart';
import '../../data/write/write_gateway.dart';

/// main() 在 runApp 前算好的启动装配参数，只通过 override 注入一次。
class AppRuntimeBootstrap {
  const AppRuntimeBootstrap({
    this.modelsRoot,
    this.exportRoot,
    this.blobBaseUrl,
    this.checkerFactory,
    this.waybackClientFactory,
    this.fetcherFactory,
    this.hibpClientFactory,
    this.llmRuntime,
  });

  final Directory? modelsRoot;
  final Directory? exportRoot;
  final String? blobBaseUrl;
  final HttpLinkChecker Function()? checkerFactory;
  final HttpWaybackClient Function()? waybackClientFactory;
  final HttpArchiveFetcher Function()? fetcherFactory;
  final HttpHibpClient Function()? hibpClientFactory;
  final LlmRuntime? llmRuntime;
}

/// 页面能拿到的全部运行期装配。不可变，替换 LLM 运行期时整份重建。
class AppRuntime {
  const AppRuntime({
    this.modelsRoot,
    this.exportRoot,
    this.blobBaseUrl,
    this.checkerFactory,
    this.waybackClientFactory,
    this.fetcherFactory,
    this.hibpClientFactory,
    this.llmRuntime,
  });

  static const AppRuntime empty = AppRuntime();

  final Directory? modelsRoot;
  final Directory? exportRoot;

  /// WebDAV blob 根地址。A5 / 真实账号未确认前保持 null：
  /// 阅读器只在拿到地址时才提供下载按钮，不接一个必然 404 的地址。
  final String? blobBaseUrl;

  final HttpLinkChecker Function()? checkerFactory;
  final HttpWaybackClient Function()? waybackClientFactory;
  final HttpArchiveFetcher Function()? fetcherFactory;
  final HttpHibpClient Function()? hibpClientFactory;

  /// 只有用户显式保存过云端 Key 才非空；未配置时 ChatPage 只写用户消息。
  final LlmRuntime? llmRuntime;

  AppRuntime withLlmRuntime(LlmRuntime? runtime) => AppRuntime(
        modelsRoot: modelsRoot,
        exportRoot: exportRoot,
        blobBaseUrl: blobBaseUrl,
        checkerFactory: checkerFactory,
        waybackClientFactory: waybackClientFactory,
        fetcherFactory: fetcherFactory,
        hibpClientFactory: hibpClientFactory,
        llmRuntime: runtime,
      );

  /// 真实下载器需要 models 目录；没装配时返回 null，页面保持「未装配」提示。
  HttpModelDownloader? createModelDownloader() {
    final root = modelsRoot;
    if (root == null) return null;
    return HttpModelDownloader(modelsRoot: root);
  }

  /// 给 ModelsPage 的工厂：目录没装配时是 null，构造时绝不假装能下载。
  HttpModelDownloader Function()? get modelDownloaderFactory {
    final root = modelsRoot;
    if (root == null) return null;
    return () => HttpModelDownloader(modelsRoot: root);
  }

  /// 明文导出：页面已推进两道确认，这里固定用 done 阶段调用真实导出器。
  ///
  /// knownSecrets 必须来自真实凭据仓库，不能传空集合 —— 否则等于绕过
  /// 「密码明文不导出」的代码级扫描。
  ///
  /// **不传 diaryBodies**：那个输入是给「日志 / prompt 里夹带日记正文」的
  /// 扫描用的；明文 Markdown 导出的正文里本来就包含日记，传进去会让
  /// 扫描必然自命中、整次导出被拒绝。AI 日记同理不进这个扫描。
  Future<MarkdownExportResult> exportPlaintext({
    required VaultDatabase db,
    required WriteGateway gateway,
  }) async {
    final root = exportRoot;
    if (root == null) {
      return const MarkdownExportResult(
        ok: false,
        stage: PlaintextExportStage.idle,
        writtenFiles: <String>[],
        hint: '未装配导出目录',
        leaks: <LeakFinding>[],
      );
    }
    final secrets = await CredentialRepository(db, gateway).knownSecretValues();
    return MarkdownExporter(db: db, root: root).export(
      stage: PlaintextExportStage.done,
      knownSecrets: secrets,
    );
  }

  /// 导入必须走 WriteGateway，保证 oplog / FTS / HLC 同事务（§1 规则 4）。
  Future<MarkdownImportResult> importMarkdown({
    required VaultDatabase db,
    required WriteGateway gateway,
  }) {
    final root = exportRoot;
    if (root == null) {
      return Future<MarkdownImportResult>.value(const MarkdownImportResult(
        inserted: <String>[],
        skipped: <String>[],
        conflictCopies: <String>[],
        failed: <String>[],
        hints: <String>['未装配导入目录'],
      ));
    }
    return MarkdownImporter(db: db, gateway: gateway, root: root)
        .importFolder();
  }
}

/// 默认是空装配：测试里裸 ProviderContainer 也能安全读。
final Provider<AppRuntimeBootstrap> appRuntimeBootstrapProvider =
    Provider<AppRuntimeBootstrap>((Ref ref) => const AppRuntimeBootstrap());

final NotifierProvider<AppRuntimeNotifier, AppRuntime> appRuntimeProvider =
    NotifierProvider<AppRuntimeNotifier, AppRuntime>(AppRuntimeNotifier.new);

class AppRuntimeNotifier extends Notifier<AppRuntime> {
  @override
  AppRuntime build() {
    final boot = ref.watch(appRuntimeBootstrapProvider);
    return AppRuntime(
      modelsRoot: boot.modelsRoot,
      exportRoot: boot.exportRoot,
      blobBaseUrl: boot.blobBaseUrl,
      checkerFactory: boot.checkerFactory,
      waybackClientFactory: boot.waybackClientFactory,
      fetcherFactory: boot.fetcherFactory,
      hibpClientFactory: boot.hibpClientFactory,
      llmRuntime: boot.llmRuntime,
    );
  }

  /// 用户在「云端模型」页保存 / 清除 Key 后立即生效：
  /// AppShell watch 这个 provider 会重建 ChatPage，无需重启。
  void setLlmRuntime(LlmRuntime? runtime) {
    final previous = state.llmRuntime;
    state = state.withLlmRuntime(runtime);
    if (!identical(previous, runtime)) {
      previous?.client.close();
    }
  }
}
