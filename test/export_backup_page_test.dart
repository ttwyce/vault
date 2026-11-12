import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/backup/encrypted_backup_service.dart';
import 'package:vault/features/settings/export_backup_page.dart';

/// docs/03 §10 导出/备份页测试。
void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ExportBackupPage()),
    ));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('明文导出必须两次确认才走到 done', (WidgetTester tester) async {
    await pumpPage(tester);
    expect(find.textContaining('当前阶段：idle'), findsOneWidget);

    // 未勾任何确认，推进无效。
    await tester.tap(find.text('推进确认流程'));
    await tester.pump();
    expect(find.textContaining('当前阶段：idle'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).at(0));
    await tester.pump();
    await tester.tap(find.text('推进确认流程'));
    await tester.pump();
    expect(find.textContaining('当前阶段：warned'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pump();
    await tester.tap(find.text('推进确认流程'));
    await tester.pump();
    expect(find.textContaining('当前阶段：confirmed'), findsOneWidget);
    await tester.tap(find.text('推进确认流程'));
    await tester.pump();
    expect(find.textContaining('当前阶段：done'), findsOneWidget);
    expect(find.textContaining('已允许平台层执行'), findsOneWidget);
  });

  testWidgets('导入合并判定与 /backup/ 隔离展示', (WidgetTester tester) async {
    await pumpPage(tester);
    expect(find.textContaining('/backup/vault.enc'), findsOneWidget);
    expect(find.textContaining('不算备份：false'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'h1');
    await tester.enterText(find.byType(TextField).at(1), 'h1');
    await tester.tap(find.text('判定'));
    await tester.pump();
    expect(find.textContaining('动作：skip'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'h2');
    await tester.tap(find.text('判定'));
    await tester.pump();
    expect(find.textContaining('动作：conflictCopy'), findsOneWidget);
  });

  testWidgets('上传加密备份按钮调用真实服务并显示结果',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExportBackupPage(
          backupServiceFactory: () => _FakeBackupService(),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('上传加密备份'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.textContaining('已加密上传到 /backup/'), findsWidgets);
  });
}

class _FakeBackupService implements BackupUploader {
  @override
  Future<BackupUploadResult> upload({
    required String fileName,
    required String vaultId,
    required int nowMs,
    String? ifMatchEtag,
  }) async =>
      const BackupUploadResult(
        ok: true,
        fileName: 'vault.enc',
        etag: '"e1"',
        bytes: 128,
        hint: '已加密上传到 /backup/vault.enc',
      );
}
