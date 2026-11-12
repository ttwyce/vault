/// 检索结果卡里的归档状态徽章（docs/06 §8.1）。
///
/// 不读库：把 `ArchiveStatus` 映射成「原站存活 / 已失效 / 有快照 /
/// 反爬 / 付费墙 / 仅元数据」的用户可见文案与草图色调。
library;

import '../../core/widgets/sketch_controls.dart' show SketchTone;
import 'archive_meta.dart' show ArchiveMeta, ArchiveStatus;

class ArchiveStatusBadge {
  const ArchiveStatusBadge({
    required this.label,
    required this.tone,
  });

  final String label;
  final SketchTone tone;
}

ArchiveStatusBadge planArchiveStatusBadge(ArchiveMeta meta) {
  if (meta.status == ArchiveStatus.dead) {
    return const ArchiveStatusBadge(
      label: '原站已失效',
      tone: SketchTone.primary,
    );
  }
  if (meta.status == ArchiveStatus.blocked) {
    return const ArchiveStatusBadge(label: '反爬', tone: SketchTone.blue);
  }
  if (meta.status == ArchiveStatus.paywalled) {
    return const ArchiveStatusBadge(label: '付费墙', tone: SketchTone.blue);
  }
  if (meta.status == ArchiveStatus.metadata) {
    return const ArchiveStatusBadge(
      label: '仅元数据',
      tone: SketchTone.plain,
    );
  }
  if (meta.hasSnapshot) {
    return const ArchiveStatusBadge(
      label: '有快照',
      tone: SketchTone.plain,
    );
  }
  return const ArchiveStatusBadge(
    label: '原站存活',
    tone: SketchTone.plain,
  );
}
