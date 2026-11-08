import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/session/vault_session.dart';
import 'app/session/vault_storage.dart';
import 'core/crypto/vault_meta.dart';
import 'core/fonts/font_providers.dart';
import 'core/fonts/font_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 字体必须在 runApp 之前就绪：字体是首帧的视觉基础，
  // 晚一步就会看到「系统字体闪一下再变手写体」（见 docs/15 §5）。
  final fonts = await FontService.boot();

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

  runApp(
    ProviderScope(
      overrides: [
        fontServiceProvider.overrideWithValue(fonts),
        vaultBootstrapProvider.overrideWithValue(
          VaultBootstrap(
            storage: storage,
            deviceId: deviceId,
            meta: meta,
            bootError: bootError,
          ),
        ),
      ],
      child: const VaultApp(),
    ),
  );
}
