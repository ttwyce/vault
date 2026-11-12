/// 日记 `entry.meta` 模型（docs/11 §1.3）。
///
/// 不碰数据库：`date` 是显式的 YYYY-MM-DD 本地日期，不从 createdAt 推；
/// 补写、跨时区、凌晨两点算前一天都靠这个字段。
library;

import 'dart:convert';

const Set<String> kDiaryMoods = <String>{'平静', '好', '一般', '糟'};

class DiaryMeta {
  const DiaryMeta({
    required this.date,
    this.weather,
    this.mood,
    this.location,
    this.wordCount = 0,
    this.backfilled = false,
  });

  /// YYYY-MM-DD，本地时区。
  final String date;
  final String? weather;
  final String? mood;
  final String? location;
  final int wordCount;
  final bool backfilled;

  String toJsonString() => jsonEncode(toJson());

  Map<String, Object?> toJson() => <String, Object?>{
        'date': date,
        if (weather != null) 'weather': weather,
        if (mood != null) 'mood': mood,
        if (location != null) 'location': location,
        'word_count': wordCount,
        'backfilled': backfilled,
      };

  factory DiaryMeta.fromJson(Object? raw) {
    if (raw is String) {
      return DiaryMeta.fromJson(jsonDecode(raw));
    }
    if (raw is! Map) throw const FormatException('日记 meta 不是对象');
    final date = raw['date'];
    if (date is! String || !_validDate(date)) {
      throw const FormatException('日记 meta.date 必须是 YYYY-MM-DD');
    }
    final mood = raw['mood'];
    if (mood != null && mood is! String) {
      throw const FormatException('mood 必须是字符串');
    }
    if (mood is String && !kDiaryMoods.contains(mood)) {
      throw const FormatException('mood 不在枚举内');
    }
    final wordCount = raw['word_count'];
    return DiaryMeta(
      date: date,
      weather: raw['weather'] as String?,
      mood: mood as String?,
      location: raw['location'] as String?,
      wordCount: wordCount is num ? wordCount.toInt() : 0,
      backfilled: raw['backfilled'] == true,
    );
  }

  DiaryMeta copyWith({
    String? date,
    String? weather,
    String? mood,
    String? location,
    int? wordCount,
    bool? backfilled,
  }) =>
      DiaryMeta(
        date: date ?? this.date,
        weather: weather ?? this.weather,
        mood: mood ?? this.mood,
        location: location ?? this.location,
        wordCount: wordCount ?? this.wordCount,
        backfilled: backfilled ?? this.backfilled,
      );
}

bool _validDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null &&
      parsed.year.toString().padLeft(4, '0') == value.substring(0, 4) &&
      parsed.month.toString().padLeft(2, '0') == value.substring(5, 7) &&
      parsed.day.toString().padLeft(2, '0') == value.substring(8, 10);
}

/// 日期键（与 [DiaryMeta.date] 同口径）。
String diaryKey(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';

/// 字数：中文按字，英文按词，忽略空白与 Markdown 标记符。
int countDiaryWords(String body) {
  final cleaned = body.replaceAll(RegExp(r'[#*_>`\-]'), '');
  final cjk = RegExp(r'[\u4e00-\u9fff]').allMatches(cleaned).length;
  final words = RegExp(r'[A-Za-z0-9]+').allMatches(cleaned).length;
  return cjk + words;
}

/// 补写判定：归属日期早于创建当天即 backfilled。
bool isBackfilled({
  required String date,
  required int createdAtMs,
}) {
  final created = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  return date.compareTo(diaryKey(created)) < 0;
}

/// 构造一条日记 meta（把补写与字数一次算好）。
DiaryMeta buildDiaryMeta({
  required String date,
  required String body,
  required int createdAtMs,
  String? weather,
  String? mood,
  String? location,
}) =>
    DiaryMeta(
      date: date,
      weather: weather,
      mood: mood,
      location: location,
      wordCount: countDiaryWords(body),
      backfilled: isBackfilled(date: date, createdAtMs: createdAtMs),
    );
