import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/credential_meta.dart';

/// docs/13 §3 kind=6 meta 测试。
void main() {
  test('默认无分类、无 TOTP；JSON 往返', () {
    expect(const CredentialMeta().toJson(), <String, Object?>{
      'has_totp': false,
    });
    const meta = CredentialMeta(categoryHint: '工作', hasTotp: true);
    final back = CredentialMeta.fromJson(meta.toJsonString());
    expect(back.categoryHint, '工作');
    expect(back.hasTotp, isTrue);
  });

  test('坏 JSON / 非对象 / 空分类回默认', () {
    expect(CredentialMeta.fromJson('{坏').hasTotp, isFalse);
    expect(CredentialMeta.fromJson(<Object?>[]).categoryHint, isNull);
    expect(
      CredentialMeta.fromJson(<String, Object?>{
        'category_hint': '  ',
        'has_totp': 'true',
      }).categoryHint,
      isNull,
    );
  });

  test('copyWith 支持清空 categoryHint', () {
    const meta = CredentialMeta(categoryHint: '金融', hasTotp: false);
    expect(meta.copyWith(hasTotp: true).hasTotp, isTrue);
    expect(meta.copyWith(clearCategoryHint: true).categoryHint, isNull);
  });
}
