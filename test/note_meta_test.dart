import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/entry/note_meta.dart';

/// docs/13 §3 笔记 meta 模型测试。
void main() {
  test('默认不置顶、字数 0；JSON 往返', () {
    const meta = NoteMeta(pinned: true, wordCount: 1240);
    final back = NoteMeta.fromJson(meta.toJsonString());
    expect(back.pinned, isTrue);
    expect(back.wordCount, 1240);
    expect(NoteMeta.fromJson(null).pinned, isFalse);
    expect(NoteMeta.fromJson('{坏 JSON').wordCount, 0);
    expect(NoteMeta.fromJson('[]').pinned, isFalse);
  });

  test('字数统计：中文按字、英文按词、忽略 Markdown 标记', () {
    expect(countNoteWords('今天同步成功'), 6);
    expect(countNoteWords('hello WebDAV world'), 3);
    expect(countNoteWords('# **标题**\n正文'), 4);
  });

  test('保存时保留 pinned 只刷新字数；坏旧 meta 不丢正文', () {
    final saved = noteMetaForSave(
      '{"pinned":true,"word_count":5}',
      '新的正文内容',
    );
    expect(saved.pinned, isTrue);
    expect(saved.wordCount, 6);
    final fromNull = noteMetaForSave(null, 'abc 中文');
    expect(fromNull.pinned, isFalse);
    expect(fromNull.wordCount, 3);
  });

  test('负数字数按 0；copyWith 局部更新', () {
    expect(NoteMeta.fromJson(<String, Object?>{'word_count': -3}).wordCount, 0);
    expect(const NoteMeta().copyWith(pinned: true).pinned, isTrue);
  });
}
