import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vault/app/settings/local_settings.dart';
import 'package:vault/app/settings/local_settings_provider.dart';

/// docs/07 §6.1 AI 日记检索开关测试。
void main() {
  test('默认关闭；JSON 往返保留；坏 JSON 退回默认', () async {
    const defaults = LocalSettings();
    expect(defaults.includeAiDiaryInSearch, isFalse);
    const on = LocalSettings(includeAiDiaryInSearch: true);
    expect(LocalSettings.fromJson(on.toJson()).includeAiDiaryInSearch, isTrue);
    expect(LocalSettings.fromJson('bad').includeAiDiaryInSearch, isFalse);

    final dir = await Directory.systemTemp.createTemp('vault-settings-test');
    addTearDown(() => dir.delete(recursive: true));
    final store = SettingsStore(dir);
    expect((await store.load()).includeAiDiaryInSearch, isFalse);
    await store.save(on);
    expect((await store.load()).includeAiDiaryInSearch, isTrue);
  });

  test('Notifier 切换会写入 store 并更新状态', () async {
    final dir = await Directory.systemTemp.createTemp('vault-settings-notifier');
    addTearDown(() => dir.delete(recursive: true));
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore(dir)),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(localSettingsProvider).includeAiDiaryInSearch,
        isFalse);
    await container
        .read(localSettingsProvider.notifier)
        .setIncludeAiDiaryInSearch(true);
    expect(container.read(localSettingsProvider).includeAiDiaryInSearch,
        isTrue);
    expect((await SettingsStore(dir).load()).includeAiDiaryInSearch, isTrue);
  });
}
