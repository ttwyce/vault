/// 字体在界面里承担的三种角色。
///
/// 分成三个角色而不是「一个全局字体」，是因为手绘风的核心是
/// **两套声音**：正文用书写体，元数据（时间、字数、标签、秒数）用等宽体。
/// 一套字体同时干这两件事，层级就塌了（见 docs/10 §4）。
enum FontRole {
  /// 界面控件 + 笔记正文 + 列表。用量最大，决定整体气质。
  ui,

  /// 页面标题、品牌字标、卡片大标题。可以比 ui 更"有个性"。
  display,

  /// 时间戳、字数、标签、TOTP 秒数、代码块。必须是等宽。
  mono,
}

extension FontRoleMeta on FontRole {
  String get id => name;

  String get label => switch (this) {
        FontRole.ui => '界面与正文',
        FontRole.display => '标题与展示',
        FontRole.mono => '数字与等宽',
      };

  String get hint => switch (this) {
        FontRole.ui => '列表、按钮、笔记正文都走这套。换它，整个 App 的气质就变了。',
        FontRole.display => '只用在页面标题和卡片大标题上，可以比正文更夸张。',
        FontRole.mono => '时间、字数、标签、密码与 TOTP。等宽能让数字列自动对齐。',
      };

  /// 预览样张：三种角色各给一句能暴露字形特征的话。
  String get sample => switch (this) {
        FontRole.ui => '把链接、一段文字丢进来 —— AI 替你整理好。',
        FontRole.display => '拾遗 · WebDAV 增量同步',
        FontRole.mono => '14:02 · 4,182 字 · #webdav · 004 821',
      };

  static FontRole? fromId(String id) {
    for (final role in FontRole.values) {
      if (role.name == id) return role;
    }
    return null;
  }
}
