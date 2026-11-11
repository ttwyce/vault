/// 密码/条目图片附件的**纯判定层**（docs/09 §8 / docs/13 §4）。
///
/// 不读文件系统、不写 blob：只按文件头字节识别格式、按 5MB 上限守卫、
/// 给出文件名规范化与 blob_ref 写入计划。真实加密与写库由平台层执行。
library;

import 'dart:typed_data';

enum AttachmentKind { png, jpeg, webp, gif }

class AttachmentSpec {
  const AttachmentSpec({
    required this.kind,
    required this.mime,
    required this.extension,
  });

  final AttachmentKind kind;
  final String mime;
  final String extension;

  static const Map<AttachmentKind, AttachmentSpec> specs =
      <AttachmentKind, AttachmentSpec>{
    AttachmentKind.png: AttachmentSpec(
        kind: AttachmentKind.png, mime: 'image/png', extension: 'png'),
    AttachmentKind.jpeg: AttachmentSpec(
        kind: AttachmentKind.jpeg, mime: 'image/jpeg', extension: 'jpg'),
    AttachmentKind.webp: AttachmentSpec(
        kind: AttachmentKind.webp, mime: 'image/webp', extension: 'webp'),
    AttachmentKind.gif: AttachmentSpec(
        kind: AttachmentKind.gif, mime: 'image/gif', extension: 'gif'),
  };
}

/// docs/09 §8：图片附件 ≤ 5MB。
const int kMaxAttachmentBytes = 5 * 1024 * 1024;

class AttachmentCheck {
  const AttachmentCheck({
    required this.accepted,
    required this.reason,
    this.kind,
  });

  final bool accepted;
  final String reason;
  final AttachmentKind? kind;

  Map<String, Object?> toJson() => <String, Object?>{
        'accepted': accepted,
        'reason': reason,
        'kind': kind?.name,
      };
}

/// 根据文件头识别格式；不信任扩展名（扩展名可由用户随便改）。
AttachmentKind? detectAttachmentKind(Uint8List bytes) {
  if (bytes.length >= 8 &&
      _equals(bytes.sublist(0, 8), const <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ])) {
    return AttachmentKind.png;
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return AttachmentKind.jpeg;
  }
  if (bytes.length >= 12) {
    final riff = _equals(bytes.sublist(0, 4), const <int>[0x52, 0x49, 0x46, 0x46]);
    final webp = _equals(bytes.sublist(8, 12), const <int>[0x57, 0x45, 0x42, 0x50]);
    if (riff && webp) return AttachmentKind.webp;
  }
  if (bytes.length >= 6) {
    final gif = _equals(bytes.sublist(0, 6), const <int>[
      0x47, 0x49, 0x46, 0x38, 0x37, 0x61,
    ]) || _equals(bytes.sublist(0, 6), const <int>[
      0x47, 0x49, 0x46, 0x38, 0x39, 0x61,
    ]);
    if (gif) return AttachmentKind.gif;
  }
  return null;
}

bool _equals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 完整校验：空 / 格式不认识 / 超过 5MB 一律拒绝，并给出可执行建议。
AttachmentCheck validateAttachment(Uint8List bytes) {
  if (bytes.isEmpty) {
    return const AttachmentCheck(
      accepted: false,
      reason: '文件为空',
    );
  }
  if (bytes.length > kMaxAttachmentBytes) {
    return const AttachmentCheck(
      accepted: false,
      reason: '图片超过 5MB，请先压缩或改用归档链接',
    );
  }
  final kind = detectAttachmentKind(bytes);
  if (kind == null) {
    return const AttachmentCheck(
      accepted: false,
      reason: '只接受 PNG / JPEG / WebP / GIF，且必须按文件头识别',
    );
  }
  return AttachmentCheck(accepted: true, reason: '通过', kind: kind);
}

/// 文件名规范化：去掉路径与可疑字符，保留识别出的真实扩展名。
String attachmentFileName(String original, AttachmentKind kind) {
  final base = original
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '');
  final safe = base.isEmpty ? 'attachment' : base;
  return '$safe.${AttachmentSpec.specs[kind]!.extension}';
}

/// blob_ref 写入计划（明文结构；真实密文与 sha256 由平台层算）。
class AttachmentPlan {
  const AttachmentPlan({
    required this.entryId,
    required this.fileName,
    required this.bytes,
    required this.kind,
    required this.mime,
  });

  final String entryId;
  final String fileName;
  final int bytes;
  final AttachmentKind kind;
  final String mime;

  Map<String, Object?> toJson() => <String, Object?>{
        'entry_id': entryId,
        'file_name': fileName,
        'bytes': bytes,
        'kind': kind.name,
        'mime': mime,
      };
}

AttachmentPlan? planAttachment(
  String entryId,
  String originalName,
  Uint8List bytes,
) {
  final check = validateAttachment(bytes);
  final kind = check.kind;
  if (!check.accepted || kind == null) return null;
  final spec = AttachmentSpec.specs[kind]!;
  return AttachmentPlan(
    entryId: entryId,
    fileName: attachmentFileName(originalName, kind),
    bytes: bytes.length,
    kind: kind,
    mime: spec.mime,
  );
}
