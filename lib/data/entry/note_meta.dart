/// 笔记 / 想法 `entry.meta` 模型（docs/13 §3）。
///
/// 不写库：只定义 `pinned` / `word_count` 的解析、序列化与刷新规则。
/// 标签一律走 `entry_tag` 关联表，绝不塞进 meta（避免双写不一致）。
library;

import 'dart:convert';

class NoteMeta {
  const NoteMeta({
    this.pinned = false,
    this.wordCount = 0,
  });

  final bool pinned;
  final int wordCount;

  Map<String, Object?> toJson() => <String, Object?>{
        'pinned': pinned,
        'word_count': wordCount,
      };

  String toJsonString() => jsonEncode(toJson());

  /// 坏 JSON / 非对象返回默认值，不让一条旧数据把编辑器搞崩。
  factory NoteMeta.fromJson(Object? raw) {
    Object? decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } on Object {
        return const NoteMeta();
      }
    }
    if (decoded is! Map) return const NoteMeta();
    final map = Map<String, Object?>.from(decoded);
    final words = map['word_count'];
    return NoteMeta(
      pinned: map['pinned'] == true,
      wordCount: words is num && words >= 0 ? words.toInt() : 0,
    );
  }

  NoteMeta copyWith({bool? pinned, int? wordCount}) => NoteMeta(
        pinned: pinned ?? this.pinned,
        wordCount: wordCount ?? this.wordCount,
      );
}

/// 中文按字 / 英文按词，忽略 Markdown 标记（与日记字数同一口径）。
int countNoteWords(String body) {
  final cleaned = body.replaceAll(RegExp(r'[#*_>`\-]'), '');
  final cjk = RegExp(r'[\u4e00-\u9fff]').allMatches(cleaned).length;
  final words = RegExp(r'[A-Za-z0-9]+').allMatches(cleaned).length;
  return cjk + words;
}

/// 保存时保留 pinned，只刷新字数。
NoteMeta noteMetaForSave(String? existingRaw, String body) =>
    NoteMeta.fromJson(existingRaw).copyWith(wordCount: countNoteWords(body));
