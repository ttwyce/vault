/// 发布前硬化的「明文泄露扫描」纯逻辑（docs/09 §11 / §12）。
///
/// 不读真实日志、不碰文件系统：把一段文本 / 一个结构化 payload 交给它，
/// 判断有没有可能把密码、日记正文、prompt 上下文、密钥材料带出去。
/// 用代码级扫描替代人工 review，每次发版前可确定性回归。
library;

import '../vault/credential_models.dart' show CredentialGuard;

/// 泄露类别。
enum LeakKind { password, diaryBody, promptContext, keyMaterial, totp }

class LeakFinding {
  const LeakFinding(this.kind, this.detail);

  final LeakKind kind;
  final String detail;
}

/// 审计输入：已知敏感值集合 + 可选的结构化日志。
class AuditInput {
  const AuditInput({
    required this.text,
    this.secrets = const <String>[],
    this.diaryBodies = const <String>[],
    this.promptSamples = const <String>[],
    this.keyFingerprints = const <String>[],
    this.totpSecrets = const <String>[],
  });

  final String text;
  final Iterable<String> secrets;
  final Iterable<String> diaryBodies;
  final Iterable<String> promptSamples;
  final Iterable<String> keyFingerprints;
  final Iterable<String> totpSecrets;
}

List<LeakFinding> scanForPlaintextLeaks(AuditInput input) {
  final findings = <LeakFinding>[];

  void check(Iterable<String> values, LeakKind kind, String label) {
    for (final value in values) {
      if (value.trim().isEmpty) continue;
      if (input.text.contains(value)) {
        findings.add(LeakFinding(kind, '$label 出现在待输出文本中'));
      }
    }
  }

  check(input.secrets, LeakKind.password, '密码明文');
  check(input.totpSecrets, LeakKind.totp, 'TOTP 密钥');
  check(input.diaryBodies, LeakKind.diaryBody, '日记正文');
  check(input.promptSamples, LeakKind.promptContext, 'prompt 上下文');
  check(input.keyFingerprints, LeakKind.keyMaterial, '密钥材料');
  return List<LeakFinding>.unmodifiable(findings);
}

/// 结构化日志扫描：递归检查所有字符串值，命中敏感键或明文即报告。
List<LeakFinding> scanStructuredLog(
  Map<String, Object?> payload, {
  Iterable<String> knownSecrets = const <String>[],
}) {
  final findings = <LeakFinding>[];
  void walk(Object? value, String path) {
    if (value is String) {
      if (CredentialGuard.containsSecret(value, knownSecrets)) {
        findings.add(LeakFinding(LeakKind.password, '$path 夹带已知明文'));
      }
      // 32 字节 hex 密钥 / 64 字节 sha256 指纹都不该出现在日志里。
      if (RegExp(r'\b[0-9a-fA-F]{64}\b').hasMatch(value)) {
        findings.add(
            LeakFinding(LeakKind.keyMaterial, '$path 含 64 位十六进制材料'));
      }
      return;
    }
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (CredentialGuard.redact(<String, Object?>{key: entry.value})[key] ==
            '[已隐藏]') {
          findings.add(
              LeakFinding(LeakKind.password, '$path.$key 是敏感字段名'));
        }
        walk(entry.value, '$path.$key');
      }
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        walk(item, path);
      }
    }
  }

  walk(payload, 'root');
  return List<LeakFinding>.unmodifiable(findings);
}

/// 安全审计结论。
class SecurityAuditReport {
  const SecurityAuditReport(this.findings);

  final List<LeakFinding> findings;

  bool get passed => findings.isEmpty;

  List<String> summary() => <String>[
        for (final finding in findings) '${finding.kind.name}: ${finding.detail}',
      ];
}
