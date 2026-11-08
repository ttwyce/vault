import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/fonts/font_providers.dart';
import 'core/fonts/font_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 字体必须在 runApp 之前就绪：字体是首帧的视觉基础，
  // 晚一步就会看到「系统字体闪一下再变手写体」（见 docs/15 §5）。
  final fonts = await FontService.boot();

  runApp(
    ProviderScope(
      overrides: [fontServiceProvider.overrideWithValue(fonts)],      child: const VaultApp(),
    ),
  );
}
