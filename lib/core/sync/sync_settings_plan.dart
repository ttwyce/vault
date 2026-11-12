/// 同步设置表单的**纯判定层**（docs/10 第 12 屏 / docs/04 §8.1）。
///
/// 不联网、不存凭据、不实例化 `VaultSyncRuntime`：只校验输入、
/// 推导能力探测策略提示，并明确「M0 A5 未过前不得启动」。
/// 真实 `flutter_secure_storage` / WebDAV 探测由平台层接。
library;

import 'webdav_backend.dart' show WebDavCapabilities, WebDavDiscoveryStrategy;

class SyncSettingsDraft {
  const SyncSettingsDraft({
    required this.rootUrl,
    required this.username,
    required this.password,
  });

  final String rootUrl;
  final String username;
  final String password;
}

enum SyncSettingsGate { invalid, needsA5, readyToProbe }

class SyncSettingsPlan {
  const SyncSettingsPlan({
    required this.gate,
    required this.normalizedRootUrl,
    required this.errors,
    required this.hint,
    required this.canProbe,
  });

  final SyncSettingsGate gate;
  final String normalizedRootUrl;
  final List<String> errors;
  final String hint;
  final bool canProbe;

  Map<String, Object?> toJson() => <String, Object?>{
        'gate': gate.name,
        'root_url': normalizedRootUrl,
        'errors': errors,
        'hint': hint,
        'can_probe': canProbe,
      };
}

/// 规整 URL：只接受 https（http 需显式 localhost 例外），去尾斜杠，
/// 禁止 query / fragment 与凭据内嵌。
String? normalizeWebDavRoot(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  final isHttps = uri.scheme == 'https';
  final isLocalHttp = uri.scheme == 'http' &&
      (uri.host == '127.0.0.1' ||
          uri.host == 'localhost' ||
          uri.host == '::1');
  if (!isHttps && !isLocalHttp) return null;
  if (uri.userInfo.isNotEmpty) return null;
  if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) return null;
  final path = uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  return uri.replace(path: path, query: null, fragment: null).toString();
}

/// 表单判定：先 URL 校验，再账号/密码，最后显式 A5 闸门。
SyncSettingsPlan planSyncSettings(
  SyncSettingsDraft draft, {
  required bool a5Confirmed,
}) {
  final errors = <String>[];
  final normalized = normalizeWebDavRoot(draft.rootUrl);
  if (normalized == null) {
    errors.add('WebDAV 地址必须是 https（本机可 http）且不含账号密码/查询串');
  }
  if (draft.username.trim().isEmpty) errors.add('账号不能为空');
  if (draft.password.isEmpty) errors.add('应用密码不能为空');
  if (errors.isNotEmpty) {
    return SyncSettingsPlan(
      gate: SyncSettingsGate.invalid,
      normalizedRootUrl: '',
      errors: List<String>.unmodifiable(errors),
      hint: '请修正表单后重试',
      canProbe: false,
    );
  }
  if (!a5Confirmed) {
    return SyncSettingsPlan(
      gate: SyncSettingsGate.needsA5,
      normalizedRootUrl: normalized!,
      errors: const <String>[],
      hint: 'M0 A5（坚果云 / Nextcloud 真实行为）未确认，'
          '仅保存配置草稿，不启动同步',
      canProbe: false,
    );
  }
  return SyncSettingsPlan(
    gate: SyncSettingsGate.readyToProbe,
    normalizedRootUrl: normalized!,
    errors: const <String>[],
    hint: '可执行 OPTIONS 能力探测（仍不自动启动同步）',
    canProbe: true,
  );
}

/// 能力探测结果 → 用户可读文案。
String describeCapabilities(WebDavCapabilities capabilities) {
  final strategy = capabilities.discoveryStrategy ==
          WebDavDiscoveryStrategy.syncCollection
      ? 'REPORT sync-collection 增量发现（1 请求）'
      : 'PROPFIND 全量发现（最多 16 请求）';
  return '服务端能力：${capabilities.davTokens.join(', ')}；$strategy';
}
