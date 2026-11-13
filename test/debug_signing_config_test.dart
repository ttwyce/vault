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
    // 只要求 apksigner 验签通过并打印证书；不再对工具输出做
    // 版本相关的硬字符串匹配（曾连续两次误判 CI 失败）。
    expect(workflow, contains(r'"$APKSIGNER" verify --verbose --print-certs "$APK"'));
    expect(workflow, contains('vault-debug.keystore'));
    expect(workflow, contains('grep \'SHA1:\''));

    final ignore = File('android/.gitignore').readAsStringSync();
    expect(ignore, contains('!app/vault-debug.keystore'),
        reason: '固定 debug keystore 必须能入库');
  });
}
