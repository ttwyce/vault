import 'package:flutter/foundation.dart';

import 'font_role.dart';

/// 字体的来源。三者加载路径完全不同，不能混着处理。
enum FontSource {
  /// 随包内置：在 pubspec 的 `flutter.fonts` 里声明，引擎启动即可用。
  /// 零加载成本，可以带多字重。
  bundled,

  /// 系统字体：不指定 family，交给平台。零体积、零内存。
  system,

  /// 用户导入：运行时用 `FontLoader` 注册，家族名由文件哈希生成。
  imported,
}

/// 一个可选的字体。
///
/// 注意 `family` 可以为 null —— 表示"用平台默认字体"。这是「系统原生」
/// 预设的实现方式，也是所有内置字体加载失败时的兜底。
@immutable
class FontFace {
  const FontFace({
    required this.id,
    required this.displayName,
    required this.roles,
    required this.source,
    this.family,
    this.fallback = const <String>[],
    this.assetPath,
    this.filePath,
    this.bytes = 0,
    this.license = '',
    this.note = '',
    this.originName,
    this.importedAt,
  });

  /// 稳定标识。内置为 `bundled:<slug>`，系统为 `system:<role>`，
  /// 导入为 `imported:<sha256 前 12 位>`。持久化只存 id，不存路径。
  final String id;

  final String displayName;

  /// 适用的角色。一个字体可以同时适配多个角色（如霞鹜文楷）。
  final Set<FontRole> roles;

  final FontSource source;

  /// Flutter 字体家族名。null = 平台默认字体。
  final String? family;

  /// 缺字时的回退链。中文/西文混排几乎必然缺字，这个列表必须非空。
  final List<String> fallback;

  /// 内置字体在 assets 里的路径（仅 bundled 有值）。
  final String? assetPath;

  /// 导入字体在磁盘上的绝对路径（仅 imported 有值，运行时填充）。
  final String? filePath;

  /// 文件体积，用于在 UI 上显示与配额提示。
  final int bytes;

  final String license;

  /// 风格说明，显示在字体卡片上。
  final String note;

  /// 导入时的原始文件名，重命名后仍可追溯。
  final String? originName;

  final DateTime? importedAt;

  bool get isSystem => source == FontSource.system;
  bool get isImported => source == FontSource.imported;
  bool get isBundled => source == FontSource.bundled;

  bool supports(FontRole role) => roles.contains(role);

  /// 人类可读的体积。
  String get sizeLabel {
    if (bytes <= 0) return '系统字体';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  FontFace copyWith({
    String? displayName,
    String? filePath,
    String? originName,
  }) {
    return FontFace(
      id: id,
      displayName: displayName ?? this.displayName,
      roles: roles,
      source: source,
      family: family,
      fallback: fallback,
      assetPath: assetPath,
      filePath: filePath ?? this.filePath,
      bytes: bytes,
      license: license,
      note: note,
      originName: originName ?? this.originName,
      importedAt: importedAt,
    );
  }

  /// 只序列化持久化需要的字段。`filePath` 不入库 ——
  /// 应用沙盒路径在 iOS 升级后会变，必须每次启动重新拼接。
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'displayName': displayName,
        'roles': roles.map((FontRole r) => r.name).toList(),
        'source': source.name,
        'family': family,
        'fallback': fallback,
        'fileName': filePath?.split(RegExp(r'[\\/]')).last,
        'bytes': bytes,
        'license': license,
        'note': note,
        'originName': originName,
        'importedAt': importedAt?.toIso8601String(),
      };

  static FontFace? fromJson(Map<String, Object?> json, String? resolvedDir) {
    final id = json['id'] as String?;
    final name = json['displayName'] as String?;
    if (id == null || name == null) return null;

    final roles = <FontRole>{};
    for (final raw in (json['roles'] as List<Object?>? ?? const <Object?>[])) {
      final role = FontRoleMeta.fromId(raw as String? ?? '');
      if (role != null) roles.add(role);
    }

    final source = FontSource.values.firstWhere(
      (FontSource s) => s.name == json['source'],
      orElse: () => FontSource.imported,
    );

    final fileName = json['fileName'] as String?;
    final importedAt = json['importedAt'] as String?;

    return FontFace(
      id: id,
      displayName: name,
      roles: roles,
      source: source,
      family: json['family'] as String?,
      fallback: (json['fallback'] as List<Object?>? ?? const <Object?>[])
          .map((Object? e) => e as String)
          .toList(),
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      license: json['license'] as String? ?? '',
      note: json['note'] as String? ?? '',
      originName: json['originName'] as String?,
      filePath: (resolvedDir != null && fileName != null)
          ? '$resolvedDir/$fileName'
          : null,
      importedAt: importedAt == null ? null : DateTime.tryParse(importedAt),
    );
  }
}
