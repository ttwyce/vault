# 归档区

这里放的是**已废弃但保留留档**的内容。不要基于这些文件继续开发。

## design-v1/

| 文件 | 是什么 | 为什么废弃 |
|---|---|---|
| `vault-ai.html` | 第 1 版设计稿：暖色编辑风（米黄纸底 + 衬线 + 朱红） | 视觉方向被推翻 —— 用户反馈"烂大街的暖色风" |
| `vault-screens.html` | 第 1 版全页面（11 屏，同风格） | 同上 |
| `vault-ui.html` | 第 2 版设计稿：冷灰蓝简洁风（Inter + 天蓝 + 毛玻璃） | 视觉方向再次推翻 —— 太像通用 SaaS，与题材无关 |

**现行设计稿**：`design/vault-sketch.html`（手绘草图风，43 屏）

## theme-teal/

| 文件 | 是什么 | 为什么废弃 |
|---|---|---|
| `tokens.dart` | 青绿主题的设计令牌 | 对应第 1 版视觉，与最终手绘风完全不符 |
| `app_semantic_colors.dart` | 语义色 ThemeExtension | 同上 |
| `app_theme.dart` | ThemeData 装配 | 同上 |
| `context_ext.dart` | BuildContext 扩展 | 同上 |

**说明**：这四份代码本身质量没问题（结构可复用），但色值、圆角、字体、阴影全都要换。
手绘风的落地要点见 [../docs/10-UI设计方案.md](../docs/10-UI设计方案.md) §11：

- 非对称圆角 → `BorderRadius.only(tl: Radius.elliptical(18,26), ...)`
- 虚线边框 → 需自写 `CustomPainter` + `PathMetrics`
- 硬阴影 → `BoxShadow(offset: Offset(4,4), blurRadius: 0)`
- 手写字体 → 打包 LXGW WenKai 子集

建议等设计定稿后**重写**，而不是在这套基础上改。
