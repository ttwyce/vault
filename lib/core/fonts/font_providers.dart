import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'font_service.dart';

/// 字体服务。必须在 `ProviderScope` 里 override 成 `main()` 中 boot 好的实例：
///
/// ```dart
/// final fonts = await FontService.boot();
/// runApp(ProviderScope(
///   overrides: [fontServiceProvider.overrideWithValue(fonts)],
///   child: const VaultApp(),
/// ));
/// ```
///
/// 这样做而不是在 provider 内部 `await`，是为了让首帧就用上正确字体 ——
/// 否则会先渲染系统字体再切换，用户能看到明显的闪动。
final Provider<FontService> fontServiceProvider = Provider<FontService>(
  (Ref ref) => throw UnimplementedError(
    'fontServiceProvider 需要在 main() 中 override，见 docs/15 §5',
  ),
);
