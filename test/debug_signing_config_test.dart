import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 固定 debug 签名的回归：不允许回退到「每台机器现生成 ~/.android/debug.keystore」。
void main() {
  test('仓库内固定 debug keystore 与 Gradle / CI 配置一致', () {
    final keystore = File('android/app/vault-debug.keystore');
    expect(keystore.existsSync(), isTrue,
        reason: 'CI 每次全新 runner 需要同一把 debug key');
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('vault-debug.keystore'));
    expect(gradle, contains('keyAlias = "vault-debug"'));
    expect(gradle, contains('signingConfigs.getByName("vaultDebug")'));

    final workflow = File('.github/workflows/android-apk.yml').readAsStringSync();
    // 不 grep apksigner 的 --print-certs 文本：不同 build-tools 版本
    // 输出 SHA-1/SHA-256 格式不同，曾导致 CI 误判失败。
    expect(workflow, contains(r'"$APKSIGNER" verify "$APK"'));
    expect(workflow, contains('keytool -printcert -jarfile'));
    expect(workflow, contains(r'test "$APK_SHA1" = "$KEY_SHA1"'));

    final ignore = File('android/.gitignore').readAsStringSync();
    expect(ignore, contains('!app/vault-debug.keystore'),
        reason: '固定 debug keystore 必须能入库');
  });
}
