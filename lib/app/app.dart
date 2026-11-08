import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/fonts/font_providers.dart';
import 'session/vault_gate.dart';
import 'theme/sketch_palette.dart';
import 'theme/sketch_theme.dart';
import 'theme/sketch_typography.dart';

class VaultApp extends ConsumerWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fonts = ref.watch(fontServiceProvider);

    // 字体变化时重建 MaterialApp —— 主题里的 fontFamily 与 textTheme
    // 都来自 typography，改字体等于换主题。
    return ListenableBuilder(
      listenable: fonts,
      builder: (BuildContext context, Widget? _) {
        final typography = SketchTypography.resolve(fonts.state);
        return MaterialApp(
          title: '拾遗',
          debugShowCheckedModeBanner: false,
          theme: SketchTheme.build(
            palette: SketchPalette.light,
            brightness: Brightness.light,
            typography: typography,
          ),
          darkTheme: SketchTheme.build(
            palette: SketchPalette.dark,
            brightness: Brightness.dark,
            typography: typography,
          ),
          themeMode: ThemeMode.system,
          // 根路由闸门：由它决定显示解锁页、首次创建页还是主界面。
          // 所有页面自己都不判断「有没有解锁」（见 vault_gate.dart）。
          home: const VaultGate(),
        );
      },
    );
  }
}
