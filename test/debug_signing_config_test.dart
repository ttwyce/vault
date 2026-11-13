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
    expect(workflow, contains('verify --print-certs'));
    expect(workflow, contains('apk-signing.txt'));
    expect(workflow,
        contains('54:E9:99:07:67:A0:B1:CE:AE:FF:8A:F9:FE:9F:12:62:E4:E1:D1:07'));

    final ignore = File('android/.gitignore').readAsStringSync();
    expect(ignore, contains('!app/vault-debug.keystore'),
        reason: '固定 debug keystore 必须能入库');
  });
}
