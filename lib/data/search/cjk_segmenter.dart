/// 中日韩文本的索引切分。
///
/// 存在的唯一原因：**FTS5 的 `unicode61` 不会切分中文**。
/// 它把连续汉字串当成一个 token，所以 `MATCH '同步'` 对「增量同步」返回 0 条。
/// 不是精度低，是完全搜不到。（实测见 `test/sqlcipher_probe_test.dart`）
///
/// 做法：索引侧把每个汉字前后加空格，查询侧做同样的切分并用**短语查询**。
/// 两侧必须用同一个函数，不对称就一定搜不到。
///
/// 为什么不用 trigram 分词器：它要求子串 ≥ 3 个字符，
/// 而中文里两字词占绝大多数（「同步」「笔记」「密码」），直接失效。
///
/// 为什么不用 jieba 之类的分词库：Dart 生态没有维护良好的实现，
/// 而且我们只需要"能召回"，精度由混合检索里的向量一路补。
abstract final class CjkSegmenter {
  const CjkSegmenter._();

  /// 汉字与扩展 A 区。日文假名与韩文谚文也按字切分（同样是 unicode61 的盲区）。
  static bool _isCjk(int rune) =>
      (rune >= 0x4E00 && rune <= 0x9FFF) || // CJK 统一表意
      (rune >= 0x3400 && rune <= 0x4DBF) || // 扩展 A
      (rune >= 0xF900 && rune <= 0xFAFF) || // 兼容表意
      (rune >= 0x3040 && rune <= 0x30FF) || // 平假名 / 片假名
      (rune >= 0xAC00 && rune <= 0xD7AF); // 谚文

  /// 需要被当成分隔符的标点（保留 `-` 和 `_`，它们在英文词里是有效字符）。
  static final RegExp _punctuation =
      RegExp(r'''[，。！？；：、（）【】「」『』《》〈〉…—～·"'“”‘’!?;:,()\[\]{}<>/\\|+=*&^%$#@`~]+''');

  static final RegExp _whitespace = RegExp(r'\s+');

  /// 归一化：全角转半角、英文小写、标点转空格、压缩空白。
  ///
  /// 不做这一步会出现「ＷｅｂＤＡＶ」搜不到「webdav」这类问题，
  /// 而中文输入法下全角字符是常态。
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      // 全角 ASCII（！ 到 ～）转半角
      if (rune >= 0xFF01 && rune <= 0xFF5E) {
        buffer.writeCharCode(rune - 0xFEE0);
      } else if (rune == 0x3000) {
        // 全角空格
        buffer.write(' ');
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer
        .toString()
        .toLowerCase()
        .replaceAll(_punctuation, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
  }

  /// 索引侧：把文本转成 FTS5 友好的形态。
  ///
  /// ```dart
  /// indexText('WebDAV 增量同步') // → 'webdav 增 量 同 步'
  /// ```
  static String indexText(String input) {
    final normalized = normalize(input);
    final buffer = StringBuffer();
    for (final rune in normalized.runes) {
      if (_isCjk(rune)) {
        buffer.write(' ');
        buffer.writeCharCode(rune);
        buffer.write(' ');
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().replaceAll(_whitespace, ' ').trim();
  }

  /// 查询侧：把用户输入转成 FTS5 的 MATCH 表达式。
  ///
  /// 规则：
  /// - 连续的汉字 → 一个**短语**（`"增 量 同 步"`），保证相邻且有序
  /// - 连续的拉丁字母/数字 → 一个词
  /// - 多个片段之间用 AND 连接
  ///
  /// 为什么必须是短语：不加引号的话 `同 步` 会变成两个独立 token 的 OR，
  /// 「步同」和跨词的「同步删除」都会误命中。
  ///
  /// 返回空字符串表示"没有可检索的内容"，调用方应跳过 FTS 直接走其它路径。
  static String matchQuery(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) return '';

    final terms = <String>[];
    final cjk = StringBuffer();
    final latin = StringBuffer();

    void flushCjk() {
      if (cjk.isEmpty) return;
      final chars = cjk.toString().split('');
      // 单字不必包成短语，直接当 token 更快
      terms.add(chars.length == 1 ? '"${chars.first}"' : '"${chars.join(' ')}"');
      cjk.clear();
    }

    void flushLatin() {
      if (latin.isEmpty) return;
      terms.add('"${latin.toString()}"');
      latin.clear();
    }

    for (final rune in normalized.runes) {
      if (_isCjk(rune)) {
        flushLatin();
        cjk.writeCharCode(rune);
      } else if (rune == 0x20) {
        flushCjk();
        flushLatin();
      } else {
        flushCjk();
        latin.writeCharCode(rune);
      }
    }
    flushCjk();
    flushLatin();

    return terms.join(' ');
  }

  /// 判断一个查询是否"值得走 FTS"。
  ///
  /// 纯标点、纯空白、单个 ASCII 字符都会让 FTS 返回大量噪声，
  /// 不如直接交给结构化过滤或向量检索。
  static bool isSearchable(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) return false;
    // 单字符：中文单字有意义（「马」），英文单字母没有
    if (normalized.length == 1 && !_isCjk(normalized.runes.first)) return false;
    return true;
  }
}
