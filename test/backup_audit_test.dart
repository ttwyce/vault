import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/backup/backup_models.dart';
import 'package:vault/data/backup/security_audit.dart';

/// docs/03 §10 / docs/09 §11 导出备份与明文泄露扫描测试。
const int _now = 1731052800000;

void main() {
  group('加密备份包（docs/03 §10）', () {
    test('manifest 往返保真，坏 schema / 缺清单一律拒绝', () {
      final blobHash = 'a' * 64;
      final manifest = BackupManifest(
        schema: 1,
        vaultId: 'vault-a',
        createdAt: _now,
        entries: <String, String>{'e1': 'hash1'},
        blobs: <String, int>{blobHash: 412000},
        models: <String>['bge-small'],
      );
      final decoded = BackupManifest.fromJson(manifest.toJson());
      expect(decoded.vaultId, 'vault-a');
      expect(decoded.entries['e1'], 'hash1');
      expect(decoded.blobs[blobHash], 412000);
      expect(
        () => BackupManifest.fromJson(<String, Object?>{
              'schema': 0,
              'vault_id': 'x',
              'created_at': _now,
              'entries': <String, String>{},
              'blobs': <String, int>{},
              'models': <String>[],
            }),
        throwsA(isA<FormatException>()),
      );
    });

    test('/backup/ 与 /vault/ 严格分离，路径穿越被拒绝', () {
      expect(backupPath('2026-11-11.enc'), '/backup/2026-11-11.enc');
      expect(isBackupPath('/backup/x'), isTrue);
      expect(isBackupPath('/vault/items/0/x'), isFalse);
      expect(() => backupPath('../vault.db'),
          throwsA(isA<FormatException>()));
      expect(() => backupPath('a/b'), throwsA(isA<FormatException>()));
    });

    test('7 天自动备份：首次立即、之后 +7 天', () {
      expect(nextBackupAt(null, _now), _now);
      expect(nextBackupAt(_now, _now),
          _now + const Duration(days: 7).inMilliseconds);
    });

    test('明文导出必须二次确认 + 危险提示', () {
      var stage = PlaintextExportStage.idle;
      stage = advancePlaintextExport(stage,
          acknowledgedDanger: false, secondConfirmation: false);
      expect(stage, PlaintextExportStage.idle);
      stage = advancePlaintextExport(stage,
          acknowledgedDanger: true, secondConfirmation: false);
      expect(stage, PlaintextExportStage.warned);
      stage = advancePlaintextExport(stage,
          acknowledgedDanger: true, secondConfirmation: false);
      expect(stage, PlaintextExportStage.warned);
      stage = advancePlaintextExport(stage,
          acknowledgedDanger: true, secondConfirmation: true);
      expect(stage, PlaintextExportStage.confirmed);
      expect(
        advancePlaintextExport(stage,
            acknowledgedDanger: false, secondConfirmation: false),
        PlaintextExportStage.done,
      );
    });

    test('导入无冲突合并：同 hash 跳过、不同 hash 留冲突副本', () {
      expect(decideImport('h', null), ImportAction.insert);
      expect(decideImport('h', 'h'), ImportAction.skip);
      expect(decideImport('h2', 'h1'), ImportAction.conflictCopy);
    });
  });

  group('明文泄露扫描（docs/09 §11）', () {
    test('密码 / 日记 / prompt / 密钥 / TOTP 全部能定位到类别', () {
      final report = SecurityAuditReport(scanForPlaintextLeaks(
        const AuditInput(
          text: 'password=hunter2 日记正文 JBSWY3DPEHPK3PXP',
          secrets: <String>['hunter2'],
          diaryBodies: <String>['日记正文'],
          totpSecrets: <String>['JBSWY3DPEHPK3PXP'],
        ),
      ));
      expect(report.passed, isFalse);
      expect(
        report.findings.map((LeakFinding f) => f.kind).toSet(),
        <LeakKind>{
          LeakKind.password,
          LeakKind.diaryBody,
          LeakKind.totp,
        },
      );
    });

    test('干净日志通过审计，敏感字段名 / 明文 / 64 位 hex 被抓出', () {
      final clean = SecurityAuditReport(scanStructuredLog(
        <String, Object?>{
          'event': 'sync_ok',
          'count': 3,
          'detail': <String, Object?>{'pushed': 2},
        },
        knownSecrets: <String>['hunter2'],
      ));
      expect(clean.passed, isTrue);
      expect(clean.summary(), isEmpty);

      final dirty = SecurityAuditReport(scanStructuredLog(
        <String, Object?>{
          'password': 'hunter2',
          'nested': <String, Object?>{
            'totp_secret': 'JBSWY3DPEHPK3PXP',
            'raw': 'a' * 64,
          },
          'list': <Object?>['hunter2'],
        },
        knownSecrets: <String>['hunter2'],
      ));
      expect(dirty.passed, isFalse);
      expect(dirty.summary().length, greaterThanOrEqualTo(3));
      expect(dirty.summary().any((String s) => s.contains('keyMaterial')),
          isTrue);
    });
  });
}
