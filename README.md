# Vault

端侧优先的个人知识库：笔记 / 想法 / 日记 / 网页归档 / 密码，统一进一个端到端加密的本地库，用自己的 WebDAV 同步，不依赖自建后端。

> 当前阶段：**M2 已完成；M3 同步编排已补齐但硬门槛未过；M4~M9 仅完成纯逻辑 / UI 预备层**。
> 详见 [docs/README.md](docs/README.md)（文档地图 + 决策表 D1~D110）与 [CHANGELOG](docs/CHANGELOG.md)。

## 特性

- **本地优先 + 端到端加密**：SQLCipher 本地库、`ItemEnvelope` 字段级加密、HLC 排序、WriteGateway 唯一写入口
- **内容**：笔记 / 想法 / 分类标签、月历日记（补写、天气心情、AI 日记可溯源）、网页归档、密码库（TOTP / 密码健康 / 字段模板）
- **检索**：FTS5 + 混合检索 + RRF 重排 + 置顶加权；端侧向量检索为可选预备层
- **同步**：WebDAV 增量同步、冲突副本、限速退避、L2 删除列表；真实服务器环境仍待验证
- **AI**：18 个 Agent 工具、分级授权与二次确认、L0/L1/L2 数据分级，secret 字段绝不进 prompt
- **手绘草图 UI**：亮 / 暗双主题、桌面三栏与快捷键预备层

## 开发环境

- Flutter `3.47.9 stable` / Dart `3.13.7`（见 `.metadata`）
- 依赖：`flutter pub get --enforce-lockfile`（`pubspec.lock` 已锁定版本与 sha256）

```bash
flutter analyze
flutter test --reporter compact --concurrency=1
```

本地开发若使用镜像源，需设置 `PUB_HOSTED_URL`；CI 会在构建前把 `pubspec.lock` 中的镜像 host 临时替换为官方源（不提交该改动）。

## Android 自动构建

GitHub Actions [android-apk.yml](.github/workflows/android-apk.yml) 在 push `master`、打 `v*` tag 或手动触发时执行：

1. Flutter / Java 17 环境 → `flutter pub get --enforce-lockfile`
2. `flutter analyze` + `flutter test --reporter compact --concurrency=1`
3. `flutter build apk --debug` → 上传 `app-debug.apk` 为 workflow artifact（保留 14 天）

产物在仓库 **Actions → Android APK → 最近一次运行 → Artifacts** 下载。当前为 debug 签名，尚未配置发布签名与商店分发。

## 文档

| 入口 | 内容 |
|---|---|
| [docs/README.md](docs/README.md) | 文档地图、当前进度、决策表 D1~D110 |
| [docs/20-交接文档.md](docs/20-交接文档.md) | 交接状态、硬规则、未完成项 |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | 逐版变更（v0.19 起） |
| [docs/09-里程碑、验收与风险.md](docs/09-里程碑、验收与风险.md) | 里程碑与 26 个同步回归用例 |
| [docs/14-开发日志.md](docs/14-开发日志.md) | 每批开发日志 |

## 已知边界

- **M3 硬门槛未过**：26 个同步用例的真实 WebDAV 环境未跑完，`VaultSyncRuntime` 未接入 App 启动
- 真实 WebView 抓取、PDF 生成、系统自动填充、生物识别、托盘 / 全局热键注册等原生能力仍待平台层实现
- 诊断页会把外部门禁（性能基线 / 原生能力 / 安全审计 / 同步回归）显式显示为未通过，不伪装完成

## 许可

暂未指定，代码仅供当前项目使用。
