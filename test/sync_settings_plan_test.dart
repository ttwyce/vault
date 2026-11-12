import 'package:flutter_test/flutter_test.dart';

import 'package:vault/core/sync/sync_settings_plan.dart';
import 'package:vault/core/sync/webdav_backend.dart' show WebDavCapabilities;

/// docs/10 第 12 屏 / docs/04 §8.1 同步设置表单判定测试。
void main() {
  test('URL 规整：https、去尾斜杠；拒绝内嵌凭据/查询串/普通 http', () {
    expect(
      normalizeWebDavRoot('https://dav.example.com/vault/'),
      'https://dav.example.com/vault',
    );
    expect(
      normalizeWebDavRoot('http://127.0.0.1:8080/dav'),
      'http://127.0.0.1:8080/dav',
    );
    expect(normalizeWebDavRoot('http://dav.example.com/vault'), isNull);
    expect(normalizeWebDavRoot('https://u:p@dav.example.com/v'), isNull);
    expect(normalizeWebDavRoot('https://dav.example.com/v?x=1'), isNull);
    expect(normalizeWebDavRoot('ftp://dav.example.com'), isNull);
    expect(normalizeWebDavRoot('  '), isNull);
  });

  test('表单三道关卡：非法 / 等 A5 / 可探测', () {
    final draft = SyncSettingsDraft(
      rootUrl: 'https://dav.example.com/vault/',
      username: 'user',
      password: 'app-password',
    );
    final invalid = planSyncSettings(
      SyncSettingsDraft(
        rootUrl: 'ftp://x',
        username: '',
        password: '',
      ),
      a5Confirmed: true,
    );
    expect(invalid.gate, SyncSettingsGate.invalid);
    expect(invalid.errors, hasLength(3));
    expect(invalid.canProbe, isFalse);

    final waiting = planSyncSettings(draft, a5Confirmed: false);
    expect(waiting.gate, SyncSettingsGate.needsA5);
    expect(waiting.normalizedRootUrl, 'https://dav.example.com/vault');
    expect(waiting.hint, contains('A5'));
    expect(waiting.canProbe, isFalse);
    expect(waiting.toJson()['gate'], 'needsA5');

    final ready = planSyncSettings(draft, a5Confirmed: true);
    expect(ready.gate, SyncSettingsGate.readyToProbe);
    expect(ready.canProbe, isTrue);
  });

  test('能力探测文案按 DAV token / sync-collection 分支', () {
    final modern = describeCapabilities(const WebDavCapabilities(
      davTokens: <String>['1', '3', 'sync-collection'],
      syncCollection: true,
      conditionalPut: true,
      depthOnePropfind: true,
    ));
    expect(modern, contains('sync-collection'));
    expect(modern, contains('1 请求'));

    final legacy = describeCapabilities(const WebDavCapabilities(
      davTokens: <String>['1'],
      syncCollection: false,
      conditionalPut: false,
      depthOnePropfind: true,
    ));
    expect(legacy, contains('PROPFIND'));
    expect(legacy, contains('16 请求'));
  });
}
