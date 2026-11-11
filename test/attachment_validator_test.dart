import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:vault/data/vault/attachment_validator.dart';

/// docs/09 §8 图片附件判定层测试。
void main() {
  Uint8List bytes(List<int> head, [int tail = 32]) => Uint8List.fromList(
        <int>[...head, ...List<int>.filled(tail, 0)],
      );

  test('按文件头识别 PNG / JPEG / WebP / GIF，不信任扩展名', () {
    expect(
      detectAttachmentKind(bytes(const <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ])),
      AttachmentKind.png,
    );
    expect(
      detectAttachmentKind(bytes(const <int>[0xFF, 0xD8, 0xFF, 0xE0])),
      AttachmentKind.jpeg,
    );
    expect(
      detectAttachmentKind(Uint8List.fromList(const <int>[
        0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0,
        0x57, 0x45, 0x42, 0x50, 0, 0, 0, 0,
      ])),
      AttachmentKind.webp,
    );
    expect(
      detectAttachmentKind(bytes(const <int>[
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61,
      ])),
      AttachmentKind.gif,
    );
    expect(detectAttachmentKind(bytes(const <int>[1, 2, 3])), isNull);
  });

  test('空 / 超大 / 非法格式一律拒绝，且给出可执行原因', () {
    expect(validateAttachment(Uint8List(0)).accepted, isFalse);
    final tooBig = validateAttachment(
      Uint8List(kMaxAttachmentBytes + 1),
    );
    expect(tooBig.accepted, isFalse);
    expect(tooBig.reason, contains('5MB'));
    final bad = validateAttachment(bytes(const <int>[1, 2, 3, 4]));
    expect(bad.accepted, isFalse);
    expect(bad.reason, contains('文件头'));
  });

  test('文件名规范化去掉路径与可疑字符，按真实格式换扩展名', () {
    expect(
      attachmentFileName('../../photo with space.PNG', AttachmentKind.png),
      'photo_with_space.png',
    );
    expect(
      attachmentFileName('C:\\tmp\\scan.jpeg', AttachmentKind.jpeg),
      'scan.jpg',
    );
    expect(attachmentFileName('', AttachmentKind.gif), 'attachment.gif');
  });

  test('planAttachment 输出 blob_ref 计划；非法输入返回 null', () {
    final plan = planAttachment(
      'cred-1',
      'notes/截图.PNG',
      bytes(const <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ]),
    );
    expect(plan, isNotNull);
    expect(plan!.fileName, '截图.png'.replaceAll('截图', '_'));
    expect(plan.mime, 'image/png');
    expect(plan.toJson()['entry_id'], 'cred-1');
    expect(
      planAttachment('cred-1', 'x.txt', bytes(const <int>[1, 2, 3])),
      isNull,
    );
  });
}
