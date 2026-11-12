import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/session/app_runtime.dart';
import 'app/session/vault_session.dart';
import 'app/settings/local_settings.dart';
import 'app/settings/local_settings_provider.dart';
import 'app/session/vault_storage.dart';
import 'core/crypto/vault_meta.dart';
import 'core/fonts/font_providers.dart';
import 'core/fonts/font_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 字体必须在 runApp 之前就绪：字体是首帧的视觉基础，
  // 晚一步就会看到「系统字体闪一下再变手写体」（见 docs/15 §5）。
  final fonts = await FontService.boot();

  // 纯本地偏好（AI 日记是否参与检索）也在首帧前装配好：
  // 与字体同理，避免设置页首次点击开关时才发现 store 没就绪。
  final settingsStore = await SettingsStore.open();
  final settings = await settingsStore.load();

  // vault 元数据也在 runApp 之前读。
  //
  // 这样首帧就能确定该显示「解锁」还是「首次创建」，不会先闪一下 loading
  // 再跳转。`meta.enc` 只有几百字节，读它比一帧还快。
  final storage = VaultStorage();
  final deviceId = await storage.loadOrCreateDeviceId();

  VaultMeta? meta;
  String? bootError;
  try {
    meta = await storage.readMeta();
  } on VaultMetaException catch (error) {
    // 读不懂 ≠ 不存在。绝不能把它当成「首次使用」去新建一个 vault ——
    // 那等于把老数据丢在一边，而用户会以为自己的东西没了。
    bootError = error.message;
  } on Object catch (error) {
    bootError = describeFailure(error);
  }

  // 装配层接线（docs/20 §5 A1）：只算本地目录，不读 / 不存任何凭据，
  // 不实例化 VaultSyncRuntime。Key 由 LlmConfigService 在 App 里从
  // 系统安全区异步恢复；Directory 只是路径对象，此时不写盘。
  final support = await getApplicationSupportDirectory();
  final runtimeBoot = AppRuntimeBootstrap(
    modelsRoot: Directory('${support.path}/models'),
    exportRoot: Directory('${support.path}/exports'),
  );

  runApp(
    ProviderScope(
      overrides: [
        fontServiceProvider.overrideWithValue(fonts),
        settingsStoreProvider.overrideWithValue(settingsStore),
        appRuntimeBootstrapProvider.overrideWithValue(runtimeBoot),
        vaultBootstrapProvider.overrideWithValue(
          VaultBootstrap(
            storage: storage,
            deviceId: deviceId,
            meta: meta,
            bootError: bootError,
          ),
        ),
      ],
      child: VaultApp(initialSettings: settings),
    ),
  );
}
