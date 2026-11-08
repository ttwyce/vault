import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/search/cjk_segmenter.dart';

void main() {
  group('归一化', () {
    test('全角转半角（中文输入法下的常态）', () {
      expect(CjkSegmenter.normalize('ＷｅｂＤＡＶ　同步'), 'webdav 同步');
    });

    test('英文小写 + 标点转空格', () {
      expect(
        CjkSegmenter.normalize('WebDAV，增量同步！RFC 6578？'),
        'webdav 增量同步 rfc 6578',
      );
    });

    test('保留英文词内的连字符与下划线', () {
      expect(
        CjkSegmenter.normalize('sync-collection 与 entry_fts'),
        'sync-collection 与 entry_fts',
      );
    });
  });

  group('索引侧切分', () {
    test('汉字两侧加空格，拉丁原样', () {
      expect(CjkSegmenter.indexText('WebDAV 增量同步'), 'webdav 增 量 同 步');
    });

    test('纯英文不变形', () {
      expect(
        CjkSegmenter.indexText('sync-collection'),
        'sync-collection',
      );
    });

    test('中英混排', () {
      expect(
        CjkSegmenter.indexText('把 example.com 收进来'),
        '把 example.com 收 进 来',
      );
    });

    test('日文假名与韩文也切', () {
      expect(CjkSegmenter.indexText('ひらがな'), 'ひ ら が な');
      expect(CjkSegmenter.indexText('한국어'), '한 국 어');
    });

    test('空串与纯标点', () {
      expect(CjkSegmenter.indexText(''), '');
      expect(CjkSegmenter.indexText('——！？'), '');
    });
  });

  group('查询侧构造', () {
    test('连续汉字包成短语（保证相邻有序）', () {
      expect(CjkSegmenter.matchQuery('同步'), '"同 步"');
      expect(CjkSegmenter.matchQuery('增量同步'), '"增 量 同 步"');
    });

    test('中文单字不包短语', () {
      expect(CjkSegmenter.matchQuery('马'), '"马"');
    });

    test('多个片段用空格（AND）连接', () {
      expect(CjkSegmenter.matchQuery('webdav 同步'), '"webdav" "同 步"');
    });

    test('中英混合不加分隔也能切开', () {
      expect(CjkSegmenter.matchQuery('WebDAV增量同步'), '"webdav" "增 量 同 步"');
    });

    test('没有可检索内容时返回空串', () {
      expect(CjkSegmenter.matchQuery(''), '');
      expect(CjkSegmenter.matchQuery('   '), '');
      expect(CjkSegmenter.matchQuery('——！？'), '');
    });

    test('双引号被转义，不会构造出非法 FTS 语法', () {
      // 输入里的引号会被归一化当作标点去掉，所以不可能逃出短语边界
      expect(CjkSegmenter.matchQuery('say "hi"'), '"say" "hi"');
    });
  });

  group('是否值得走 FTS', () {
    test('中文单字有意义', () {
      expect(CjkSegmenter.isSearchable('马'), isTrue);
    });

    test('英文单字母不值得', () {
      expect(CjkSegmenter.isSearchable('a'), isFalse);
    });

    test('空与纯标点不值得', () {
      expect(CjkSegmenter.isSearchable(''), isFalse);
      expect(CjkSegmenter.isSearchable('！？'), isFalse);
    });
  });
}
