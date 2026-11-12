/// 页面侧装配适配器：把 AppRuntime 的既有能力适配成页面构造参数。
///
/// 没有新业务逻辑：目录 / Key / 工厂都由启动装配算好，这里只从 Provider
/// 取出来传给页面。runner 是懒执行的（按钮点击时才读 db / gateway），
/// 裸 ProviderContainer 的既有 widget 测试只要不点按钮就保持原行为。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_runtime.dart';
import 'vault_session.dart';
import '../../data/backup/markdown_exporter.dart';
import '../../data/backup/markdown_importer.dart';

/// 页面完成两道确认后调用：真实泄露扫描 + 真实写盘。
Future<MarkdownExportResult> appPlaintextExportRunner(WidgetRef ref) =>
    ref.read(appRuntimeProvider).exportPlaintext(
          db: ref.read(vaultDatabaseProvider),
          gateway: ref.read(writeGatewayProvider),
        );

/// 导入走 WriteGateway，不绕过唯一写入口。
Future<MarkdownImportResult> appMarkdownImportRunner(WidgetRef ref) =>
    ref.read(appRuntimeProvider).importMarkdown(
          db: ref.read(vaultDatabaseProvider),
          gateway: ref.read(writeGatewayProvider),
        );
