import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/bip39_english.dart';
import 'package:vault/core/crypto/recovery_code.dart';

void main() {
  // BIP-39 官方测试向量（256 bit / 24 词）。
  // 来源：https://github.com/trezor/python-mnemonic/blob/master/vectors.json
  // 已用独立 Python 实现（hashlib + 手工 11 位切分）复算确认。
  const vectors = <String, String>{
    '0000000000000000000000000000000000000000000000000000000000000000':
        'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon abandon abandon art',
    '7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f':
        'legal winner thank year wave sausage worth useful legal winner thank '
            'year wave sausage worth useful legal winner thank year wave '
            'sausage worth title',
    '8080808080808080808080808080808080808080808080808080808080808080':
        'letter advice cage absurd amount doctor acoustic avoid letter advice '
            'cage absurd amount doctor acoustic avoid letter advice cage '
            'absurd amount doctor acoustic bless',
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff':
        'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo '
            'zoo zoo zoo zoo zoo zoo vote',
  };

  group('BIP-39 词表不变式', () {
    test('2048 词、字典序、前 4 字母唯一', () {
      expect(bip39English.length, bip39WordCount);
      expect(bip39English.length, 2048);

      final sorted = List<String>.from(bip39English)..sort();
      expect(bip39English, equals(sorted), reason: '顺序即索引，必须字典序');

      final prefixes = <String>{};
      for (final word in bip39English) {
        expect(word.length >= 3, isTrue, reason: '过短的词无法用 4 字母前缀定位：$word');
        if (word.length >= 4) {
          expect(
            prefixes.add(word.substring(0, 4)),
            isTrue,
            reason: '前 4 字母冲突：$word —— 缩写匹配会失去唯一性',
          );
        }
      }
    });
  });

  group('官方向量', () {
    vectors.forEach((String hex, String expected) {
      test('${hex.substring(0, 8)}… 编码正确', () {
        final code = RecoveryCode.fromEntropy(entropyFromHex(hex));
        expect(code.words.join(' '), expected);
      });

      test('${hex.substring(0, 8)}… 能解回原熵', () {
        final code = RecoveryCode.parse(expected);
        expect(code.toEntropy().toHex(), hex);
      });
    });
  });

  group('校验和', () {
    test('抄错一个词会被立刻发现', () {
      final code = RecoveryCode.fromEntropy(entropyFromHex('00' * 32));
      final broken = List<String>.from(code.words);
      // 把最后一个词换成另一个合法词：词都在词表里，只有校验和不对
      broken[23] = 'zoo';
      expect(
        () => RecoveryCode.fromWords(broken).toEntropy(),
        throwsA(
          isA<RecoveryCodeException>().having(
            (RecoveryCodeException e) => e.reason,
            'reason',
            contains('校验和'),
          ),
        ),
      );
    });

    test('parse 阶段就校验，不用等 toEntropy', () {
      final code = RecoveryCode.fromEntropy(entropyFromHex('ab' * 32));
      final broken = List<String>.from(code.words)..[0] = 'zoo';
      expect(
        () => RecoveryCode.parse(broken.join(' ')),
        throwsA(isA<RecoveryCodeException>()),
      );
    });
  });

  group('输入容错', () {
    final canonical = RecoveryCode.fromEntropy(entropyFromHex('11' * 32)).words.join(' ');

    test('大小写不敏感', () {
      expect(RecoveryCode.parse(canonical.toUpperCase()).words, RecoveryCode.parse(canonical).words);
    });

    test('中文逗号、顿号、换行、制表符都当分隔符', () {
      final messy = canonical.replaceAll(' ', '，');
      expect(RecoveryCode.parse(messy).words.join(' '), canonical);

      final lines = RecoveryCode.parse(canonical).words.join('\n');
      expect(RecoveryCode.parse(lines).words.join(' '), canonical);

      final tabbed = RecoveryCode.parse(canonical).words.join('\t');
      expect(RecoveryCode.parse(tabbed).words.join(' '), canonical);
    });

    test('带序号前缀也能读（用户从编号列表复制）', () {
      final words = RecoveryCode.parse(canonical).words;
      final numbered = <String>[
        for (var i = 0; i < words.length; i++) '${i + 1}. ${words[i]}',
      ].join('\n');
      expect(RecoveryCode.parse(numbered).words.join(' '), canonical);

      final chineseNumbered = <String>[
        for (var i = 0; i < words.length; i++) '${i + 1}、${words[i]}',
      ].join(' ');
      expect(RecoveryCode.parse(chineseNumbered).words.join(' '), canonical);
    });

    test('4 字母缩写能唯一还原（24 个词全部缩写后仍可解析）', () {
      final canonical = RecoveryCode.generate(Random(33));
      final abbreviated = canonical.words
          .map((String w) => w.length <= 4 ? w : w.substring(0, 4))
          .join(' ');

      final parsed = RecoveryCode.parse(abbreviated);
      expect(parsed.words, canonical.words);
      expect(parsed.toEntropy().toHex(), canonical.toEntropy().toHex());
    });

    test('3 字母歧义前缀被拒绝并给出解释', () {
      // `sol` 不是词表里的词，但是 solar / soldier / solid / solution / solve 的公共前缀
      expect(
        () => RecoveryCode.parse(
          'sol sol sol sol sol sol sol sol sol sol sol sol '
          'sol sol sol sol sol sol sol sol sol sol sol zoo',
        ),
        throwsA(
          isA<RecoveryCodeException>().having(
            (RecoveryCodeException e) => e.reason,
            'reason',
            contains('少于 4 个字母'),
          ),
        ),
      );
    });

    test('词数不对时说明差多少', () {
      expect(
        () => RecoveryCode.parse('abandon abandon abandon'),
        throwsA(
          isA<RecoveryCodeException>().having(
            (RecoveryCodeException e) => e.reason,
            'reason',
            contains('当前读到 3 个'),
          ),
        ),
      );
    });

    test('不在词表里的词被指出是第几个', () {
      final words = RecoveryCode.parse(canonical).words;
      final broken = List<String>.from(words)..[7] = 'notaword';
      expect(
        () => RecoveryCode.parse(broken.join(' ')),
        throwsA(
          isA<RecoveryCodeException>().having(
            (RecoveryCodeException e) => e.reason,
            'reason',
            allOf(contains('第 8 个词'), contains('notaword')),
          ),
        ),
      );
    });
  });

  group('展示与抽查', () {
    test('grouped 分成 4 组、每组 6 词', () {
      final code = RecoveryCode.generate(Random(1));
      final groups = code.grouped;
      expect(groups.length, 4);
      for (final group in groups) {
        expect(group.split(' ').length, 6);
      }
      expect(groups.join(' ').split(' ').length, 24);
    });

    test('matches 支持完整词与 4 字母缩写', () {
      final code = RecoveryCode.fromEntropy(entropyFromHex('00' * 32));
      expect(code.matches(1, 'abandon'), isTrue);
      expect(code.matches(1, 'aban'), isTrue);
      expect(code.matches(1, 'ABANDON'), isTrue);
      expect(code.matches(24, 'art'), isTrue, reason: 'art 是完整词，3 字母也接受');
      expect(code.matches(1, 'ability'), isFalse);
    });

    test('matches 位置越界抛错', () {
      final code = RecoveryCode.generate(Random(2));
      expect(() => code.matches(0, 'abandon'), throwsA(isA<ArgumentError>()));
      expect(() => code.matches(25, 'abandon'), throwsA(isA<ArgumentError>()));
    });

    test('pickPositions 返回升序且不重复', () {
      for (var seed = 0; seed < 20; seed++) {
        final picked = RecoveryCode.pickPositions(3, Random(seed));
        expect(picked.length, 3);
        expect(picked, equals(List<int>.from(picked)..sort()), reason: '必须升序');
        expect(picked.toSet().length, 3, reason: '不能重复');
        expect(picked.every((int p) => p >= 1 && p <= 24), isTrue);
      }
    });

    test('pickPositions 数量越界抛错', () {
      expect(() => RecoveryCode.pickPositions(0, Random(1)), throwsA(isA<ArgumentError>()));
      expect(() => RecoveryCode.pickPositions(25, Random(1)), throwsA(isA<ArgumentError>()));
    });
  });

  group('熵长度', () {
    test('非 32 字节熵被拒绝', () {
      expect(
        () => RecoveryCode.fromEntropy(entropyFromHex('00' * 16)),
        throwsA(isA<RecoveryCodeException>()),
      );
    });

    test('生成的恢复码熵是 32 字节且随机', () {
      final a = RecoveryCode.generate(Random(30));
      final b = RecoveryCode.generate(Random(31));
      expect(a.toEntropy().length, 32);
      expect(a.words, isNot(equals(b.words)));
    });
  });
}
