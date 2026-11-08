import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/theme/sketch_typography.dart';
import 'package:vault/core/fonts/font_catalog.dart';
import 'package:vault/core/fonts/font_face.dart';
import 'package:vault/core/fonts/font_role.dart';
import 'package:vault/core/fonts/font_state.dart';
import 'package:vault/core/fonts/font_validation.dart';

Uint8List _header(List<int> head, {int pad = 2048}) {
  final bytes = Uint8List(pad);
  for (var i = 0; i < head.length; i++) {
    bytes[i] = head[i];
  }
  return bytes;
}

void main() {
  group('文件头识别', () {
    test('TrueType / OpenType / TTC / WOFF / WOFF2', () {
      expect(FontValidation.sniff(_header(<int>[0x00, 0x01, 0x00, 0x00])),
          FontFormat.trueType);
      expect(FontValidation.sniff(_header(<int>[0x74, 0x72, 0x75, 0x65])),
          FontFormat.trueType); // 'true'
      expect(FontValidation.sniff(_header(<int>[0x74, 0x74, 0x63, 0x66])),
          FontFormat.collection); // 'ttcf'
      expect(FontValidation.sniff(_header(<int>[0x4F, 0x54, 0x54, 0x4F])),
          FontFormat.openType); // 'OTTO'
      expect(FontValidation.sniff(_header(<int>[0x77, 0x4F, 0x46, 0x46])),
          FontFormat.woff); // 'wOFF'
      expect(FontValidation.sniff(_header(<int>[0x77, 0x4F, 0x46, 0x32])),
          FontFormat.woff2); // 'wOF2'
      expect(FontValidation.sniff(_header(<int>[0x3C, 0x21, 0x44, 0x4F])),
          FontFormat.unknown); // '<!DO'
    });

    test('WOFF2 被拒绝并给出可执行的建议', () {
      final msg = FontValidation.validate(
        _header(<int>[0x77, 0x4F, 0x46, 0x32]),
        'X.woff2',
      );
      expect(msg, isNotNull);
      expect(msg, contains('fonttools'));
    });

    test('过小与过大的文件被拒绝', () {
      expect(FontValidation.validate(Uint8List(10), 'tiny.ttf'), isNotNull);
      final big = Uint8List(FontValidation.maxBytes + 1)
        ..[0] = 0x00
        ..[1] = 0x01;
      expect(FontValidation.validate(big, 'huge.ttf'), contains('40 MB'));
    });

    test('合法 TTF 通过', () {
      expect(
        FontValidation.validate(_header(<int>[0x00, 0x01, 0x00, 0x00]), 'ok.ttf'),
        isNull,
      );
    });
  });

  group('字体状态', () {
    test('默认状态是手写预设，三个角色都解析到内置字体', () {
      final state = FontState.defaults();
      expect(state.presetId, 'handwritten');
      expect(state.faceFor(FontRole.ui).family, FontCatalog.wenKaiFamily);
      expect(state.faceFor(FontRole.display).family, FontCatalog.caveatFamily);
      expect(state.faceFor(FontRole.mono).family, FontCatalog.monoFamily);
    });

    test('改单个角色后与预设一致时自动归位', () {
      final state = FontState.defaults().withRoleFont(
        FontRole.mono,
        FontCatalog.systemMono.id,
      );
      expect(state.presetId, FontState.customId);

      // 改回 JetBrains Mono，应重新识别为「手写默认」
      final back = state.withRoleFont(
        FontRole.mono,
        'bundled:jetbrains-mono',
      );
      expect(back.presetId, 'handwritten');
    });

    test('字体 id 找不到时退回系统字体而不是抛异常', () {
      final broken = FontState(
        presetId: FontState.customId,
        roles: const <FontRole, String>{
          FontRole.ui: 'imported:gone',
          FontRole.display: 'bundled:caveat',
          FontRole.mono: 'bundled:jetbrains-mono',
        },
        imported: const <FontFace>[],
      );
      expect(broken.faceFor(FontRole.ui).isSystem, isTrue);
    });

    test('JSON 往返保留导入字体与角色映射', () {
      final state = FontState(
        presetId: FontState.customId,
        roles: const <FontRole, String>{
          FontRole.ui: 'imported:abcdef123456',
          FontRole.display: 'bundled:caveat',
          FontRole.mono: 'system:mono',
        },
        imported: <FontFace>[
          FontFace(
            id: 'imported:abcdef123456',
            displayName: '我的字体',
            family: 'imp_abcdef123456',
            roles: const <FontRole>{FontRole.ui, FontRole.mono},
            source: FontSource.imported,
            filePath: '/data/fonts/files/abcdef123456.ttf',
            bytes: 4096,
            originName: 'MyFont-Regular.ttf',
          ),
        ],
      );

      final restored = FontState.fromJson(state.toJson(), '/data/fonts/files');
      expect(restored.roles[FontRole.ui], 'imported:abcdef123456');
      expect(restored.imported.single.displayName, '我的字体');
      // 路径必须由目录 + 文件名重新拼出，不能信序列化里的绝对路径
      expect(restored.imported.single.filePath,
          '/data/fonts/files/abcdef123456.ttf');
      expect(restored.isCustom, isTrue);
    });

    test('配置残缺时用默认预设补齐，不整份丢弃', () {
      final restored = FontState.fromJson(<String, Object?>{
        'presetId': 'custom',
        'roles': <String, Object?>{'ui': 'bundled:wenkai-lite'},
        'imported': <Object?>[],
      }, null);
      expect(restored.roles.length, FontRole.values.length);
      expect(restored.roles[FontRole.display], 'bundled:caveat');
    });

    test('每个角色至少有一个内置选项', () {
      final state = FontState.defaults();
      for (final role in FontRole.values) {
        expect(state.optionsFor(role), isNotEmpty, reason: role.name);
      }
    });
  });

  group('排版解析', () {
    test('手写预设生成三条不同的字体栈', () {
      final type = SketchTypography.resolve(FontState.defaults());
      expect(type.ui.family, FontCatalog.wenKaiFamily);
      expect(type.display.family, FontCatalog.caveatFamily);
      expect(type.mono.family, FontCatalog.monoFamily);
      expect(type.ui, isNot(type.display));
    });

    test('系统预设的字体栈不带家族名', () {
      final type = SketchTypography.resolve(
        FontState.defaults().withPreset(FontPresets.native),
      );
      expect(type.ui.isSystem, isTrue);
      expect(type.display.isSystem, isTrue);
    });

    test('元数据样式一定走等宽栈', () {
      final type = SketchTypography.resolve(FontState.defaults());
      expect(type.monoStyle(size: 10).fontFamily, FontCatalog.monoFamily);
    });
  });

  group('内置字体资源', () {
    testWidgets('三套字体都真的在包里，且文件头合法', (WidgetTester tester) async {
      // flutter_test 会构建 asset bundle，fonts 声明的文件可通过 rootBundle 读到。
      // 这条用例的价值：pubspec 里家族名写错、文件漏提交、下到半截的损坏文件，
      // 都能在这里立刻暴露，不用等真机。
      for (final face in FontCatalog.bundled) {
        expect(face.assetPath, isNotNull, reason: face.displayName);
        final data = await rootBundle.load(face.assetPath!);
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        expect(bytes.length, face.bytes, reason: '${face.displayName} 体积变了，需同步 catalog');
        expect(FontValidation.sniff(bytes).isSupported, isTrue,
            reason: '${face.displayName} 文件头不合法');
      }
    });
  });
}
