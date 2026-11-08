import 'package:flutter/foundation.dart';

import 'font_catalog.dart';
import 'font_face.dart';
import 'font_role.dart';

/// 当前字体配置。
///
/// 这是**设备本地状态**，不进 WebDAV 同步 —— 字体文件体积大、许可各不相同，
/// 而且「我这台电脑用等宽、手机用文楷」是完全合理的需求（见 docs/15 §6）。
@immutable
class FontState {
  const FontState({
    required this.presetId,
    required this.roles,
    required this.imported,
  });

  /// 预设 id；用户单独改过某个角色后变成 [customId]。
  final String presetId;

  /// 角色 → 字体 id。三个角色必须都有值，缺了会退回系统字体。
  final Map<FontRole, String> roles;

  /// 用户导入的字体（含文件路径，启动时由 FontStore 重新拼出）。
  final List<FontFace> imported;

  static const String customId = 'custom';

  factory FontState.defaults() => FontState(
        presetId: FontPresets.fallback.id,
        roles: Map<FontRole, String>.unmodifiable(FontPresets.fallback.roles),
        imported: const <FontFace>[],
      );

  bool get isCustom => presetId == customId;

  FontPreset get preset => FontPresets.byId(presetId);

  /// 按 id 找字体：先查内置目录，再查导入列表。
  FontFace? faceById(String id) {
    final builtIn = FontCatalog.byId(id);
    if (builtIn != null) return builtIn;
    for (final face in imported) {
      if (face.id == id) return face;
    }
    return null;
  }

  /// 取某个角色实际生效的字体。找不到时退到系统默认，绝不抛异常 ——
  /// 用户删掉正在使用的字体后，界面必须还能正常打开。
  FontFace faceFor(FontRole role) {
    final id = roles[role];
    final face = id == null ? null : faceById(id);
    if (face != null) return face;
    return switch (role) {
      FontRole.ui => FontCatalog.systemUi,
      FontRole.display => FontCatalog.systemDisplay,
      FontRole.mono => FontCatalog.systemMono,
    };
  }

  /// 某个角色下所有可选的字体：内置的 + 导入的，按角色过滤。
  List<FontFace> optionsFor(FontRole role) => <FontFace>[
        ...FontCatalog.builtIn.where((FontFace f) => f.supports(role)),
        ...imported.where((FontFace f) => f.supports(role)),
      ];

  /// 需要运行时注册的字体（只有导入的）。
  Iterable<FontFace> get runtimeFaces =>
      imported.where((FontFace f) => f.family != null);

  FontState copyWith({
    String? presetId,
    Map<FontRole, String>? roles,
    List<FontFace>? imported,
  }) {
    return FontState(
      presetId: presetId ?? this.presetId,
      roles: roles ?? this.roles,
      imported: imported ?? this.imported,
    );
  }

  /// 切换单个角色。若结果与某个预设完全一致，自动归位到该预设 ——
  /// 避免 UI 上出现"配置和预设一样却标着自定义"的怪状态。
  FontState withRoleFont(FontRole role, String fontId) {
    final next = Map<FontRole, String>.from(roles)..[role] = fontId;
    String matched = customId;
    for (final p in FontPresets.all) {
      final same = FontRole.values.every((FontRole r) => p.roles[r] == next[r]);
      if (same) {
        matched = p.id;
        break;
      }
    }
    return copyWith(
      presetId: matched,
      roles: Map<FontRole, String>.unmodifiable(next),
    );
  }

  FontState withPreset(FontPreset preset) => copyWith(
        presetId: preset.id,
        roles: Map<FontRole, String>.unmodifiable(preset.roles),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 1,
        'presetId': presetId,
        'roles': roles.map(
          (FontRole k, String v) => MapEntry<String, Object?>(k.name, v),
        ),
        'imported': imported.map((FontFace f) => f.toJson()).toList(),
      };

  /// [filesDir] 用来把 `fileName` 还原成绝对路径。
  static FontState fromJson(Map<String, Object?> json, String? filesDir) {
    final rawRoles = json['roles'];
    final roles = <FontRole, String>{};
    if (rawRoles is Map) {
      for (final role in FontRole.values) {
        final value = rawRoles[role.name];
        if (value is String) roles[role] = value;
      }
    }

    final imported = <FontFace>[];
    final rawImported = json['imported'];
    if (rawImported is List) {
      for (final item in rawImported) {
        if (item is Map) {
          final face = FontFace.fromJson(
            item.cast<String, Object?>(),
            filesDir,
          );
          if (face != null) imported.add(face);
        }
      }
    }

    if (roles.length != FontRole.values.length) {
      // 配置残缺：用默认预设补齐缺失的角色，而不是整份丢弃。
      final base = FontPresets.fallback;
      for (final role in FontRole.values) {
        roles.putIfAbsent(role, () => base.roles[role]!);
      }
    }

    return FontState(
      presetId: json['presetId'] as String? ?? FontPresets.fallback.id,
      roles: Map<FontRole, String>.unmodifiable(roles),
      imported: List<FontFace>.unmodifiable(imported),
    );
  }
}
