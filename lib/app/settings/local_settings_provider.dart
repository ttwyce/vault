import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_settings.dart';

/// 可覆盖：测试注入临时目录的 [SettingsStore]。
final Provider<SettingsStore> settingsStoreProvider =
    Provider<SettingsStore>((Ref ref) {
  throw StateError(
    'SettingsStore 未装配：启动时需 overrideWithValue(await SettingsStore.open())',
  );
});

/// 当前本地设置。默认「AI 日记不参与检索」。
final NotifierProvider<LocalSettingsNotifier, LocalSettings>
    localSettingsProvider =
    NotifierProvider<LocalSettingsNotifier, LocalSettings>(
  LocalSettingsNotifier.new,
);

class LocalSettingsNotifier extends Notifier<LocalSettings> {
  @override
  LocalSettings build() => const LocalSettings();

  Future<void> setIncludeAiDiaryInSearch(bool value) async {
    final store = ref.read(settingsStoreProvider);
    final next = state.copyWith(includeAiDiaryInSearch: value);
    await store.save(next);
    state = next;
  }

  Future<void> reload() async {
    state = await ref.read(settingsStoreProvider).load();
  }

  /// main() 在 runApp 前注入已从磁盘读出的偏好。
  void initialize(LocalSettings loaded) {
    state = loaded;
  }
}
