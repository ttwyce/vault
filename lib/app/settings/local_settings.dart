import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 纯本地设置（不参与同步、不加密、不含敏感值）。
class LocalSettings {
  const LocalSettings({this.includeAiDiaryInSearch = false});

  /// docs/07 §6.1：AI 日记默认排除检索，用户可显式打开。
  final bool includeAiDiaryInSearch;

  LocalSettings copyWith({bool? includeAiDiaryInSearch}) => LocalSettings(
        includeAiDiaryInSearch:
            includeAiDiaryInSearch ?? this.includeAiDiaryInSearch,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'include_ai_diary_in_search': includeAiDiaryInSearch,
      };

  factory LocalSettings.fromJson(Object? raw) {
    if (raw is! Map) return const LocalSettings();
    return LocalSettings(
      includeAiDiaryInSearch:
          raw['include_ai_diary_in_search'] == true,
    );
  }
}

/// `<appSupport>/settings.json`。
///
/// 与 `FontStore` 同样的理由：纯本地偏好不进数据库、必须在解锁前可读。
/// 目录可注入，测试用临时目录，不碰真实文件系统路径。
class SettingsStore {
  SettingsStore(this.root);

  /// 生产环境用应用支持目录；测试可注入临时目录。
  static Future<SettingsStore> open() async {
    final base = await getApplicationSupportDirectory();
    return SettingsStore(base);
  }

  final Directory root;

  File get _indexFile => File(p.join(root.path, 'settings.json'));

  Future<LocalSettings> load() async {
    try {
      if (!await _indexFile.exists()) return const LocalSettings();
      final raw = await _indexFile.readAsString();
      if (raw.trim().isEmpty) return const LocalSettings();
      return LocalSettings.fromJson(jsonDecode(raw));
    } on Object {
      // 坏文件退回默认，绝不让设置页崩。
      return const LocalSettings();
    }
  }

  Future<void> save(LocalSettings settings) async {
    if (!await root.exists()) await root.create(recursive: true);
    final tmp = File('${_indexFile.path}.tmp');
    await tmp.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await tmp.rename(_indexFile.path);
  }
}
