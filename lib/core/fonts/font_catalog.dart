import 'package:flutter/foundation.dart';

import 'font_face.dart';
import 'font_role.dart';

/// 内置字体目录（随包，不下载、不联网）。
///
/// 选型原则（见 docs/15 §2）：
/// - 全部 SIL OFL 1.1，可商用、可随包分发、只需保留许可声明
/// - 中文只有一套 —— 每个中文字体都在 10MB 量级，多放一套包体就不可接受
/// - 西文展示体与等宽体都是小文件（< 0.5MB），可以放心内置
abstract final class FontCatalog {
  const FontCatalog._();

  // --- 家族名：与 pubspec.yaml 的 flutter.fonts 声明必须逐字一致 ---

  /// 霞鹜文楷 Lite（SIL OFL 1.1，13.3 MB）
  static const String wenKaiFamily = 'SketchWenKai';

  /// Caveat（SIL OFL 1.1，394 KB，可变字重，仅拉丁）
  static const String caveatFamily = 'SketchCaveat';

  /// JetBrains Mono（SIL OFL 1.1，264 KB）
  static const String monoFamily = 'SketchJetBrainsMono';

  /// 中文兜底链。系统手写/楷体优先，再退到无衬线，最后退到通用族。
  static const List<String> cjkFallback = <String>[
    'LXGW WenKai',
    'Kaiti SC',
    'STKaiti',
    'KaiTi',
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'sans-serif',
  ];

  static const List<String> latinFallback = <String>[
    'Segoe Print',
    'Bradley Hand',
    'Comic Sans MS',
    'Chalkboard SE',
    'cursive',
  ];

  // ---------------------------------------------------------------------------
  // 随包内置的三套字体
  // ---------------------------------------------------------------------------

  static const FontFace wenKai = FontFace(
    id: 'bundled:wenkai-lite',
    displayName: '霞鹜文楷 Lite',
    family: wenKaiFamily,
    fallback: cjkFallback,
    roles: <FontRole>{FontRole.ui, FontRole.display},
    source: FontSource.bundled,
    assetPath: 'assets/fonts/LXGWWenKaiLite-Regular.ttf',
    bytes: 13949472,
    license: 'SIL OFL 1.1',
    note: '楷体骨架，字重轻，长文阅读最舒服。手绘风的主字体。',
  );

  static const FontFace caveat = FontFace(
    id: 'bundled:caveat',
    displayName: 'Caveat',
    family: caveatFamily,
    fallback: <String>[wenKaiFamily, ...cjkFallback],
    roles: <FontRole>{FontRole.display},
    source: FontSource.bundled,
    assetPath: 'assets/fonts/Caveat-Variable.ttf',
    bytes: 403648,
    license: 'SIL OFL 1.1',
    note: '纯手写西文，只覆盖拉丁字母。中文会自动落回霞鹜文楷。',
  );

  static const FontFace mono = FontFace(
    id: 'bundled:jetbrains-mono',
    displayName: 'JetBrains Mono',
    family: monoFamily,
    fallback: <String>['Consolas', 'Menlo', 'DejaVu Sans Mono', 'monospace'],
    roles: <FontRole>{FontRole.mono},
    source: FontSource.bundled,
    assetPath: 'assets/fonts/JetBrainsMono-Regular.ttf',
    bytes: 270224,
    license: 'SIL OFL 1.1',
    note: '零宽斜杠与清晰区分的 0/O、1/l，密码与 TOTP 用它。',
  );

  static const List<FontFace> bundled = <FontFace>[wenKai, caveat, mono];

  // ---------------------------------------------------------------------------
  // 系统字体：family 为 null 即平台默认，零体积
  // ---------------------------------------------------------------------------

  static const FontFace systemUi = FontFace(
    id: 'system:ui',
    displayName: '系统默认',
    roles: <FontRole>{FontRole.ui},
    source: FontSource.system,
    note: '各端用自己的界面字体。不占体积、不占内存，但三端观感不一致。',
  );

  static const FontFace systemDisplay = FontFace(
    id: 'system:display',
    displayName: '系统默认',
    roles: <FontRole>{FontRole.display},
    source: FontSource.system,
    note: '标题走系统字体的粗体，最清晰、最不容易出问题。',
  );

  static const FontFace systemMono = FontFace(
    id: 'system:mono',
    displayName: '系统等宽',
    family: 'monospace',
    fallback: <String>['Consolas', 'Menlo', 'Courier New', 'DejaVu Sans Mono'],
    roles: <FontRole>{FontRole.mono},
    source: FontSource.system,
    note: 'Android / iOS / Windows 各自的等宽族，字形差异较大。',
  );

  static const List<FontFace> system = <FontFace>[
    systemUi,
    systemDisplay,
    systemMono,
  ];

  /// 所有内置（非用户导入）字体，按角色过滤用。
  static const List<FontFace> builtIn = <FontFace>[
    wenKai,
    caveat,
    mono,
    systemUi,
    systemDisplay,
    systemMono,
  ];

  static FontFace? byId(String id) {
    for (final face in builtIn) {
      if (face.id == id) return face;
    }
    return null;
  }
}

/// 一套预设：把三个角色一次定好。
///
/// 用户不需要理解"角色"，点一个名字就得到完整的一套观感。
@immutable
class FontPreset {
  const FontPreset({
    required this.id,
    required this.name,
    required this.desc,
    required this.roles,
  });

  final String id;
  final String name;
  final String desc;

  /// 角色 → 字体 id
  final Map<FontRole, String> roles;

  String fontIdFor(FontRole role) => roles[role] ?? FontCatalog.systemUi.id;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'roles': roles.map((FontRole k, String v) => MapEntry<String, Object?>(k.name, v)),
      };
}

abstract final class FontPresets {
  const FontPresets._();

  /// 默认：手写感最强的一套。
  static const FontPreset handwritten = FontPreset(
    id: 'handwritten',
    name: '手写默认',
    desc: '霞鹜文楷 + Caveat + JetBrains Mono。设计稿就是这一套。',
    roles: <FontRole, String>{
      FontRole.ui: 'bundled:wenkai-lite',
      FontRole.display: 'bundled:caveat',
      FontRole.mono: 'bundled:jetbrains-mono',
    },
  );

  /// 省内存 / 三端不一致：全部系统字体。
  static const FontPreset native = FontPreset(
    id: 'native',
    name: '系统原生',
    desc: '全部用各端系统字体。零额外内存，但三端长得不一样。',
    roles: <FontRole, String>{
      FontRole.ui: 'system:ui',
      FontRole.display: 'system:display',
      FontRole.mono: 'system:mono',
    },
  );

  /// 阅读优先：标题也用文楷，中英混排不会一半手写一半印刷。
  static const FontPreset reading = FontPreset(
    id: 'reading',
    name: '阅读优先',
    desc: '标题与正文统一用文楷。中英混排最一致，适合长文。',
    roles: <FontRole, String>{
      FontRole.ui: 'bundled:wenkai-lite',
      FontRole.display: 'bundled:wenkai-lite',
      FontRole.mono: 'bundled:jetbrains-mono',
    },
  );

  /// 极客等宽：等宽体当正文，中文回退到文楷。
  static const FontPreset geek = FontPreset(
    id: 'geek',
    name: '极客等宽',
    desc: '正文也用等宽体。密度最高，但中文长文会比较累。',
    roles: <FontRole, String>{
      FontRole.ui: 'bundled:jetbrains-mono',
      FontRole.display: 'bundled:caveat',
      FontRole.mono: 'bundled:jetbrains-mono',
    },
  );

  static const List<FontPreset> all = <FontPreset>[
    handwritten,
    reading,
    native,
    geek,
  ];

  static const FontPreset fallback = handwritten;

  static FontPreset byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return fallback;
  }
}
