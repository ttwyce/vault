import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/credential_models.dart';
import 'package:vault/data/vault/credential_template.dart';

/// docs/09 §8 字段模板与增删排序测试。
void main() {
  CredentialField field(String id, {bool secret = false, int sort = 0}) =>
      CredentialField(
        id: id,
        label: '字段$id',
        value: '值$id',
        type: CustomFieldType.text,
        secret: secret,
        sort: sort,
      );

  test('三套预置模板可实例化，secret 标记保留、sort 连续', () {
    expect(kDefaultFieldTemplates, hasLength(3));
    for (final template in kDefaultFieldTemplates) {
      final fields = template.instantiate();
      expect(fields.fields.length, template.items.length);
      expect(fields.fields.map((CredentialField f) => f.sort).toList(),
          List<int>.generate(template.items.length, (int i) => i));
      expect(
        fields.fields.where((CredentialField f) => f.secret).length,
        template.items.where((FieldTemplateItem i) => i.secret).length,
      );
    }
    expect(templateById('dev')!.label, '开发平台');
    expect(templateById('missing'), isNull);
  });

  test('add 自动续 sort、拒绝重复 id 与超过 20 个', () {
    var fields = const CustomFields(<CredentialField>[]);
    fields = fields.add(field('a'));
    fields = fields.add(field('b'));
    expect(fields.fields.map((CredentialField f) => f.sort).toList(),
        <int>[0, 1]);
    expect(() => fields.add(field('a')), throwsA(isA<FormatException>()));

    var many = const CustomFields(<CredentialField>[]);
    for (var i = 0; i < CustomFields.maxFields; i++) {
      many = many.add(field('f$i'));
    }
    expect(() => many.add(field('overflow')),
        throwsA(isA<FormatException>()));
  });

  test('remove 与 reorder 重排 sort，越界 clamp', () {
    var fields = const CustomFields(<CredentialField>[])
        .add(field('a'))
        .add(field('b'))
        .add(field('c'));
    fields = fields.reorder('a', 99);
    expect(fields.fields.map((CredentialField f) => f.id).toList(),
        <String>['b', 'c', 'a']);
    expect(fields.fields.map((CredentialField f) => f.sort).toList(),
        <int>[0, 1, 2]);

    fields = fields.remove('c');
    expect(fields.fields.map((CredentialField f) => f.id).toList(),
        <String>['b', 'a']);
    expect(() => fields.reorder('missing', 0),
        throwsA(isA<FormatException>()));
  });

  test('secret 字段掩码只给标签与类型，绝不返回 value', () {
    final fields = CustomFields(<CredentialField>[
      field('s', secret: true),
      field('n'),
    ]);
    final masked = fields.maskedLabels();
    expect(masked, hasLength(1));
    expect(masked.single, contains('字段s'));
    expect(masked.single, contains('••••'));
    expect(masked.single, isNot(contains('值s')));
  });
}
