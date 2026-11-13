import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/fonts/font_providers.dart';
import 'settings/local_settings.dart';
import 'settings/local_settings_provider.dart';
import 'session/auto_lock_watcher.dart';
import 'session/llm_runtime_provider.dart';
import 'session/share_intent_bridge.dart';
import 'session/vault_session.dart';
import 'session/vault_gate.dart';
import 'theme/sketch_palette.dart';
import 'theme/sketch_theme.dart';
import 'theme/sketch_typography.dart';

class VaultApp extends ConsumerWidget {
  const VaultApp({super.key, this.initialSettings});

  /// main() 在 runApp 前从磁盘读出的本地偏好；空则从默认状态开始。
  final LocalSettings? initialSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fonts = ref.watch(fontServiceProvider);
    // 安全存储里的云端 Key 异步恢复；没保存过就什么都不做，
    // AppRuntime 保持 llmRuntime=null（聊天页继续诚实降级）。
    ref.watch(llmRuntimeBootstrapProvider);
    // 冷启动系统分享只在解锁后消费一次：provider 缓存结果，
    // 多次 build 不会重复落队列。
    if (ref.watch(vaultSessionProvider).isUnlocked) {
      ref.watch(consumeInitialShareAfterUnlockProvider);
    }
    final initial = initialSettings;
    if (initial != null &&
        ref.read(localSettingsProvider) == const LocalSettings() &&
        initial != const LocalSettings()) {
      // 只在首次 build 注入已加载的偏好，不覆盖用户后续切换。
      ref.read(localSettingsProvider.notifier).initialize(initial);
    }

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
          home: const AutoLockWatcher(child: VaultGate()),
        );
      },
    );
  }
}
