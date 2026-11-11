# CHANGELOG

记录结构性变更。日常文字修订不入表，只记「改了决策 / 加了模块 / 换了方向」。

---

## v0.54 · 2026-11-11

### M6：HIBP k-anonymity 本地判定层（已验证）

- 新增 `lib/data/vault/hibp_client.dart`：SHA1 → 前 5 位请求路径 +
  35 位后缀、响应行容错解析、7 天缓存新鲜度、本地后缀比对。
  **完整哈希与密码明文永远不出设备**，URL 只含前缀
- `CredentialRepository.applyHibpResponse()`：平台层把响应体交给这里，
  命中写 `breached=2`、未命中写 `1`；无法比对返回 null，
  绝不把「未知」误标成「安全」；健康报告随即反映真实结果
- 测试：`hibp_client_test.dart` 4 条（含 SHA1("password") 官方前缀
  5BAA6 / 只带前缀 / 缓存过期拒绝判定）、
  `credential_repository_test.dart` +1 条 → 全量 **606 → 611**

**边界**：真实 HTTPS 请求由平台层执行，本层不联网；剪贴板清除与账号
分组树仍缺。M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**611/611 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 49）、20（当前状态）、
CHANGELOG（本条）

---

## v0.53 · 2026-11-11

### M6：敏感字段加密通道统一（已验证）

- `CredentialRepository` 抽出 `_openField/_writeField`，把 TOTP Base32 密钥
  与 `custom_fields`（含 secret:true 项）也收进 K_item 字段级加密通道；
  三个字段各自绑定 `credential_field/<field>` + 账号 id
- `setTotpSecret` 先校验 Base32 再封密文；`customFields()` 解密往返；
  `listSummaries` 从解密后的密钥生成验证码，密钥本身绝不出仓库
- 测试：`credential_repository_test.dart` +1 条（TOTP/自定义字段密文落库、
  解密往返、加密密钥仍生成 RFC 6238 正确码、非法 Base32 拒绝）
  → 全量 **605 → 606**

**边界**：剪贴板 30 秒清除、HIBP 网络请求、账号分组树与字段模板仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**606/606 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 48）、20（当前状态）、
CHANGELOG（本条）

---

## v0.52 · 2026-11-11

### M6：credential 字段级加密落库（已验证）

- `WriteGateway.sealCredentialField/openCredentialField`：复用 K_item +
  `ItemEnvelope`，AAD 绑定 `credential_field/<field>` / 账号 id / rev，
  base64 后存进 TEXT 列；**密钥绝不出 gateway**
- 打开时除了 AEAD 头部认证，还**对照数据库行**校验 entityId / field，
  堵住「把 A 账号整段密文原样复制到 B 账号」这类跨行重放
- `CredentialRepository` 注入 gateway：`setPassword` 只写密文、
  `samples()` 在内存解密算强度但报告只给统计；旧明文行兼容但不回写
- 密码页「生成强密码」现在真正以密文落库，不再只是展示；
  `passwordChangedAt` 同步更新
- 测试：`credential_repository_test.dart` +1 条（明文不落盘 / 跨行重放拒绝 /
  报告无明文）、`vault_page_test.dart` 1 条改为验证密文落库
  → 全量 **604 → 605**

**边界**：TOTP 密钥与 secret 自定义字段尚未用同一通道加密、剪贴板清除与
HIBP 网络请求仍缺；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**605/605 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 47）、20（当前状态）、
CHANGELOG（本条）

---

## v0.51 · 2026-11-11

### M6：密码生成器落地并接进新增弹窗（已验证）

- 新增 `lib/data/vault/password_generator.dart`：`Random.secure()` 密码学安全
  随机，长度/四类字符集/排除易混字符可配，保证每个启用类至少一位后
  Fisher-Yates 打乱；可注入随机源做确定性测试
- `VaultPage` 新增弹窗加「生成强密码」按钮与只读可复制结果。
  **明确不把生成明文写进本地库**：credential 的字段级加密通道尚未接通，
  页面提示用户自行复制保管
- 测试：`password_generator_test.dart` 4 条、`vault_page_test.dart` +1 条
  （验证生成后 credential.password 仍为 null）→ 全量 **599 → 604**

**边界**：字段级加密落库、剪贴板 30 秒清除、HIBP 网络请求仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**604/604 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 46）、20（当前状态）、
CHANGELOG（本条）

---

## v0.50 · 2026-11-11

### M6：RFC 6238 TOTP 落地并接进密码列表（已验证）

- 新增 `lib/data/vault/totp.dart`：Base32 解码自实现（容错小写/空格/填充）、
  HMAC-SHA1 用项目已有 `crypto` 包、动态截断、6/8 位输出、窗口剩余时间。
  **不新增依赖**，验证码只在内存生成，绝不写日志 / prompt
- 用 RFC 6238 附录 B 的 5 个 SHA1 官方向量钉住实现正确性
- `CredentialRepository.listSummaries()` 在仓库内部生成当前验证码，
  对外只输出 `totpCode`，**Base32 密钥绝不出仓库**；`VaultPage` 列表显示
  「TOTP 287082」徽章
- 测试：`totp_test.dart` 5 条 + `credential_repository_test.dart` +1 条
  → 全量 **593 → 599**

**边界**：不做剪贴板 30 秒清除 / 自动填充 / HIBP 真实网络请求；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**599/599 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 45）、20（当前状态）、
CHANGELOG（本条）

---

## v0.49 · 2026-11-11

### 关于与隐私页（docs/09 §10 上架材料，已验证）

- 新增 `AboutPage`：零后端 / 端到端加密 / 密码与 AI 绝对边界 /
  无遥测 / 字体 SIL OFL 1.1 与 Gemma-Qwen3 许可提示 /
  恢复码警告，六段声明在 App 内可读
- `SettingsHubPage` 加「关于与隐私」入口
- 测试：`about_page_test.dart` 2 条 → 全量 **591 → 593**
- 用 Dart 常量承载说明文本，**不新增 asset、不改 pubspec.yaml**

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**593/593 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
边界不变：M3 硬门槛未过，M4~M9 未完成。

**影响文档**：README（数字）、14（Day 44）、20（当前状态）、CHANGELOG（本条）

---

## v0.48 · 2026-11-11

### 设置中心「诊断与备份」入口（已验证）

- 新增 `DiagnosticsPage`：跑 `runReleaseAudit` 六项确定性自检并逐项展示，
  预览加密备份包 manifest、`/backup/` 路径与 7 天排期；明确标注
  「不替代真实服务器集成用例」
- `SettingsHubPage` 加入入口，M8/M9 判定层（release_audit / backup_models /
  embedding_manifest / agent_policy）终于有生产 UI 落点
- 测试：`diagnostics_page_test.dart` 2 条 → 全量 **589 → 591**

**边界**：真实 zip 打包、WebDAV 上传、明文导出仍留平台层；M3 硬门槛未过。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**591/591 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字）、14（Day 43）、20（当前状态）、CHANGELOG（本条）

---

## v0.47 · 2026-11-11

### 归档阅读器页面接线（已验证）

- 新增 `ArchiveReaderPage`（docs/05 §9）：用 `resolveReaderModes` 判定
  纯净 / 原貌 / 对比三模式可用性，不可点的模式给出可执行提示，
  底部显示「归档于 X · 原站状态」与 Wayback 回退提示
- `ArchivePage` 条目点击 → `Navigator` 进阅读器，接真实 `ArchiveMeta`
- 测试：`archive_reader_page_test.dart` 3 条（三模式可点、PDF 仅云端降级、
  死链状态条） → 全量 **586 → 589**

**边界**：PDF 渲染、并排 diff、按需下载仍属平台层，页面明确提示而不假装
能显示。M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**589/589 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字）、14（Day 42）、20（当前状态）、CHANGELOG（本条）

---

## v0.46 · 2026-11-11

### 归档 / 密码「新增」按钮接真实写入（已验证）

- `ArchivePage`「归档网址」：弹窗输入 URL → `ArchiveMeta.siteOf` 校验 →
  经 `WriteGateway` 建 kind=5 entry（只持久化 L1 元数据层，真实抓取留给
  平台层）→ 刷新列表；非法 scheme 明确提示且不落库
- `VaultPage`「新增」：改 `ConsumerStatefulWidget`，弹窗输入名称 →
  `WriteGateway` 建 kind=6 entry + credential 空行 → 真实列表与统计刷新
- 测试：`archive_page_test.dart` +1 条（合法 URL 落库 / 非法 URL 不落库）、
  `vault_page_test.dart` 2 条（空库无假账号 / 新增真实写表）
  → 全量 **583 → 586**

**边界**：只建元数据层，不做网页抓取 / 密码字段编辑 / TOTP / 剪贴板；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**586/586 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字）、14（Day 41）、20（当前状态）、CHANGELOG（本条）

---

## v0.45 · 2026-11-11

### 记录页 / 全库搜索页接 searchHybrid（已验证）

- `RecordsPage` 与 `SearchPage` 的搜索调用从旧 `repo.search` 切到
  `EntryRepository.searchHybrid`：时间意图、类型限定、停用词剥离、
  时间衰减重排与「默认排除 AI 日记」现在真正在 UI 生效
- 既有 10 条记录页/筛选测试保持全绿；新增 1 条 widget 测试验证
  「同步」搜索结果里不出现 kind=4 的 AI 日记 → 全量 **582 → 583**

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**583/583 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。边界不变：M3 硬门槛未过，M4~M9 未完成。

**影响文档**：README（数字）、14（Day 40）、20（当前状态）、CHANGELOG（本条）

---

## v0.44 · 2026-11-11

### 聊天页消息流真实落库（T25 / T26，已验证）

- 新增 `ConversationWriter`：消息 append-only（只 INSERT 不改写），
  草稿态会话在**第一条用户消息到达时**才与消息在同一事务里创建
  conversation（T26 不产生空记录）；重复追加只递增 messageCount
- `ConversationRepository.messages()` 按 (createdAt, hlc) 读取并解析 citations
- `ChatPage` 写死的假消息流（早上好 / 工具卡 / 引用卡）替换为真实消息
  FutureBuilder；当前对话条显示草稿 / 会话 id；发送按钮与回车都走
  `ConversationWriter.append`
- 测试：`conversation_writer_test.dart` 4 条（草稿落库、append-only 顺序、
  丢弃不落库、发送按钮真实写表） → 全量 **578 → 582**

**边界**：会话 / 消息目前不参与同步，写入口注释明确将来必须扩展
`WriteGateway` 会话分支而不是绕过它；无真实 AI 模型回复，消息只有用户侧。
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**582/582 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字）、14（Day 39）、20（当前状态）、CHANGELOG（本条）

---

## v0.43 · 2026-11-11

### 密码列表与归档搜索真实接线（已验证）

- `CredentialRepository.listSummaries()`：`credential.id` 关联 `entry` 取标题、
  只 select 非敏感列、跳过已删除条目；`VaultPage` 三个写死的假账号
  （GitHub / Cloudflare / 阿里云）改为真实列表 + TOTP/泄露徽章
- `ArchivePage` 新增「找哪个归档…」搜索框，按 title / site / excerpt / url
  过滤内存中的 meta（不额外触发 blob IO），与状态/站点筛选叠加生效
- 测试：`credential_repository_test.dart` +1 条真实列表、
  `archive_page_test.dart` +1 条搜索（既有 5 条夹具补 Scaffold 后保持全绿）
  → 全量 **576 → 578**

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**578/578 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。边界不变：M3 硬门槛未过，M4~M9 未完成。

**影响文档**：README（数字）、14（Day 38）、20（当前状态）、CHANGELOG（本条）

---

## v0.42 · 2026-11-11

### 会话抽屉 / 密码健康报告 UI 真实接线（已验证）

**改了什么**
- 新增 `ConversationDrawer`（docs/12 §3 / §5）：搜索框、今天/昨天/本周/更早
  与用户分组、当前会话便签黄底 + 左红条 + 多歪一点的高亮、新建对话
- `ChatPage` 两处 TODO 落地：左上三横杠用**独立路由**打开抽屉
  （不进 PageScaffold 布局树，主区零重排；路由自带 Material 祖先），
  右上「开启新对话」进 `ConversationDraftState` 草稿态（T26 首条消息前不落库）
- 新增 `CredentialRepository` + provider：按真实 `credential` 表列
  （`breached=2` 才算泄露、`passwordChangedAt` 算超期）算聚合统计，
  **只返回统计不返回任何明文**；`VaultPage` 的写死「42 个 · 安全评分 72」
  与假泄露横幅改为真实数据
- 测试：`chat_drawer_test.dart` 3 条（打开/关闭、草稿态不落库、真实会话选中）、
  `credential_repository_test.dart` 3 条 → 全量 **570 → 576**

**接线踩坑**：抽屉最初塞进 PageScaffold 的 child 布局树，导致
`Expanded > ListView` 高度约束被破坏（RenderFlex 溢出）与 TextField
缺 Material 祖先；最终改为独立路由 + 抽屉根包 Material，两个问题一起消失。

**边界**：抽屉不发真实消息、密码页不做 TOTP / 剪贴板 / HIBP 网络请求；
M3 硬门槛未过，M4~M9 均未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**576/576 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字 / 决策表）、09（§9）、14（Day 37）、
20（当前状态）、CHANGELOG（本条）

---

## v0.41 · 2026-11-11

### 发布前确定性检查清单与会话仓库接线（已验证）

**改了什么**
- 新增 `lib/data/audit/release_audit.dart`：M9 发布前六项可复现检查
  A1 日志/prompt 明文零泄露、A2 密码/AI 日记不向量化、
  A3 模型 manifest 配置坑、A4 CredentialGuard 密码边界、
  A5 混合检索预处理烟测、A6 secret 自定义字段脱敏；
  `releaseAuditToJson()` 可直接写进 CI 产物 / sync_log
- 新增 `ConversationRepository` + provider：把真实 `conversation` 表接进
  docs/12 的分组逻辑，已删除会话不出现、用户分组优先
  （消除了会话判定层「只有测试用」的死代码）
- 测试：`release_audit_test.dart` 4 条、
  `conversation_repository_test.dart` 2 条 → 全量 **564 → 570**

**边界**：这只是确定性检查清单，**不冒充** 26 个真实集成用例与 5000 条
性能基线；M3 硬门槛未过，M4~M9 均未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**570/570 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字 / 决策表）、09（§11）、14（Day 36）、
20（当前状态）、CHANGELOG（本条）

---

## v0.40 · 2026-11-11

### M8/M9 预备层与 M5 判定层接线（已验证）

**改了什么**
- 新增 `lib/data/backup/backup_models.dart`（docs/03 §10）
  - 加密备份包 manifest（entry + blob + 模型清单）、`/backup/` 与 `/vault/`
    严格分离且拒绝路径穿越、7 天自动备份排期、明文导出二次确认状态机、
    导入「同 hash 跳过 / 不同 hash 留冲突副本」无冲突合并
- 新增 `lib/data/backup/security_audit.dart`（docs/09 §11 明文泄露扫描）
  - 文本扫描定位密码 / 日记正文 / prompt / 密钥 / TOTP 五类泄露
  - 结构化日志递归扫描：敏感字段名、已知明文、64 位 hex 材料；
    输出 `passed` 结论与可执行摘要
- **把 M5 判定层真正接进现有只读仓库**：`EntryRepository.searchHybrid()`
  - `preprocessSearchQuery` → CjkSegmenter → FTS → 结构化过滤 → 时间衰减重排
  - 默认排除 AI 日记（kind=4），可由调用方显式打开
  - 类型限定词 / 指代词从 FTS 短语剥离（否则「那篇日记 同步」匹配不到），
    剥离后剩余查询变短时短查询权重正确生效
- 测试：`backup_audit_test.dart` 7 条、真实 FTS 接线
  `hybrid_search_integration_test.dart` 4 条 → 全量 **553 → 564**

**边界**：备份真实 zip 打包、WebDAV `/backup/` 上传、真机性能基线、
26 个真实集成用例仍缺；M3 硬门槛未过，M4~M9 均未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**564/564 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字 / 决策表）、09（§11）、14（Day 35）、
20（当前状态）、CHANGELOG（本条）

---

## v0.39 · 2026-11-11

### M7 Agent 预备层：工具策略闸门与日总结判定（已验证）

按 docs/07 §3 / §4 / §5 / §6 落地不依赖模型 / 网络 / MCP 的部分。

**改了什么**
- 新增 `lib/data/agent/agent_policy.dart`
  - `AgentTool` 注册表抽象（为二期 MCP 预留）、`RiskLevel` / `PrivacyLevel`
  - `checkToolCall()`：**所有工具执行前统一过策略闸门**，确认卡片显示
    人话操作 + 完整内容预览 + 数据是否离开设备
  - docs/07 §4.3 五条密码绝对边界写成代码级 deny：明文进 prompt、
    密码走云端、密码同步第三方 MCP、L0-only 工具接云端、L2 未逐次授权
  - `AgentLoopLimits`：最多 6 轮、工具结果截断 2000 字
  - `routeModelForTask()`：密码 / 日记 / 日总结 / TOTP 强制端侧
- 新增 `lib/data/agent/daily_summary.dart`
  - 活动按「编辑 > 剪藏 > 浏览」加权聚合、时间线升序去重
  - 滚动摘要层级：周读 7 日 / 月读 4 周 / 年读 12 月
  - `validateCitations()` 剔除不存在 / 重复引用，绝不展示假引用
  - `AiDiaryRules`：kind=4 物理隔离、默认排除检索、不向量化、不可编辑、
    长度 150~300 字
- 测试：`agent_policy_test.dart` 10 条、`daily_summary_test.dart` 10 条
  → 全量 **533 → 553**

**边界**：纯判定层，不调模型、不联网、不接 MCP、不生成真实日记；
定时任务 / 端侧推理 / UI 抽屉仍缺。M3 硬门槛未过，M4~M7 均未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**553/553 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字 / 决策表）、09（§9）、14（Day 34）、
20（当前状态）、CHANGELOG（本条）

---

## v0.38 · 2026-11-11

### M6 / M7 预备层：密码判定与会话抽屉判定（已验证）

按 docs/11 §4 / docs/09 §8 / docs/12 §5 继续落地不依赖真实模型 / 平台通道 /
新依赖的纯逻辑。

**改了什么**
- 新增 `lib/data/vault/credential_models.dart`
  - `CustomFields` 结构（≤20 个、id 唯一、解析即校验），`redactedLabels()`
    只返回字段名不返回值
  - `estimatePasswordStrength()` 本地 0~4 估算，常见弱模式直接 0
  - `computeCredentialHealth()` 重复 / 弱 / 泄露 / 超 180 天 / 收藏统计；
    **报告里没有任何明文或指纹**
  - `hibpPrefix()` / `hibpHit()` k-anonymity：只发 SHA1 前 5 位、后缀本地比对
  - `CredentialGuard`：工具返回值敏感字段整体脱敏、prompt 明文扫描、
    备注默认 L0（云端需逐次授权）—— docs/11 §4.4 的代码级拦截
- 新增 `lib/data/chat/conversation_models.dart`
  - `groupConversations()`：用户分组优先且不再出现在日期分组里，
    今天 / 昨天 / 本周 / 更早四组
  - `ConversationDraftState`：T26 草稿态不发第一条消息不落库、切走直接丢弃、
    重复提交幂等
  - `orderMessages()`：T25 append-only 按 (createdAt, hlc, id) 稳定排序且不可变
  - `deriveConversationTitle()`：首条消息前 20 字兜底
- 测试：`credential_models_test.dart` 9 条、`conversation_models_test.dart` 8 条
  → 全量 **516 → 533**

**边界**：纯判定层。密码字段级加密落库、TOTP 生成、剪贴板 30s 清除、
HIBP 真实网络请求、会话 UI 抽屉、AI 工具循环都未实现（需平台通道 / 网络 /
真机）。M3 硬门槛未过，M4~M7 均未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**533/533 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字 / 决策表）、09（§8 / §9）、14（Day 33）、
20（当前状态）、CHANGELOG（本条）

---

## v0.37 · 2026-11-11

### M5 预备层：混合检索判定与向量模型 manifest（已验证）

M4 归档预备层两批完成后，按 docs/06 继续落地 M5 中不需要真实推理运行时 /
模型文件 / 新依赖的部分。

**改了什么**
- 新增 `lib/data/search/hybrid_search.dart` 纯判定层
  - `preprocessSearchQuery()`：引号精确短语、时间意图（今天/最近/上个月/去年）、
    类型限定（日记/想法/笔记/归档）、中文停用词只在 FTS 侧去掉、
    短查询降权向量并提升 FTS
  - `reciprocalRankFusion()`：RRF k=60，两路召回按名次融合；结构化过滤在
    融合前剔除、非法 rank 跳过、只返回 top N
  - `rerankScore()`：时间衰减 `1+0.3·exp(-days/180)` + 置顶加权
  - `planChunks()`：note/diary 512 token、bookmark 400 token / 20 块封顶 /
    overlap；**credential 永不向量化**（代码级硬约束）
- 新增 `lib/data/search/embedding_manifest.dart`
  - 四套默认模型 spec（BGE Small / E5 / EmbeddingGemma / Qwen3），解析即校验
    id 唯一、内置恰好一个、sha256、pooling、prompt 占位符、MRL 维度
  - `auditModelConfig()` 钉死 docs/06 §3.2 两个坑：Gemma query/doc 前缀必须
    不同；Qwen3 必须 last-token pooling
  - `isCompatibleWith()` 落实红线 3：不同模型 / 不同维度的向量绝不混用
- 测试：`hybrid_search_test.dart` 11 条、`embedding_manifest_test.dart` 7 条
  → 全量 **498 → 516**

**边界**：纯判定层，不加载 ONNX/GGUF、不做真实 KNN、不下载模型、
不建 FTS 索引；这些仍需 M5 接入层与真机。M3 硬门槛未过，M4 / M5 均未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**516/516 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字 / 决策表）、09（§7）、14（Day 32）、
20（当前状态）、CHANGELOG（本条）

---

## v0.36 · 2026-11-11

### M4 预备层第二批：阅读器判定与归档派生表写入口（已验证）

**改了什么**
- 新增 `lib/data/archive/archive_reader.dart` 纯判定层
  - `resolveReaderModes()`：纯净 / 原貌 / 对比三模式按 L1 正文、PDF 是否
    本地、是否有上一版正文分别判定；不可用时给出可执行提示
  - `fallbackReaderMode()` 在没有正文层时仍回退到 `clean`（渲染「仅元数据」
    空状态），不落到同样不可用的 compare 模式
  - `readerStatusLine()` 区分原站存活 / 已失效 / 访问受限
  - `mergeHighlights()` 重叠与相邻高亮合并；`canAskAiAboutSelection()`
    2 字起、2000 字上限
- `WriteGateway` 新增 M4 派生表写入口（本地表、不写 oplog，仍走唯一写入口）
  - `recordArchiveBlob()` 严格校验 sha256、`local=0` 默认仅云端
  - `markArchiveBlobLocal()` 只把 `local` 置 1，不改内容寻址 hash
  - `recordLinkCheck()` 记录检查结果与 simhash；**同 entry 同时间戳重放时
    只补非空字段**（此前 `insertOnConflictUpdate` 会用 `Value(null)` 抹掉
    已有的 final_url / simhash 证据 —— 真实 bug，已修）
  - `enqueueArchiveJob()` 排可中断续跑任务；`purgeTrashEntry()` 已覆盖
    blob_ref / link_check 清理
- 测试：`archive_reader_test.dart` 7 条、`archive_write_test.dart` 6 条
  → 全量 **485 → 498**

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**498/498 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
边界不变：仍是 M4 纯逻辑 / UI 预备层，真实抓取 / WebView / PDF 未做；
M3 硬门槛未过，不宣称 M4 完成。

**影响文档**：README（数字 / 决策表）、09（§6）、14（Day 31）、
20（当前状态）、CHANGELOG（本条）

---

## v0.35 · 2026-11-11

### M4 预备层：归档 meta 模型、策略引擎与总览页接线（已验证）

用户要求「继续开发下一阶段」，在 M3 真实服务商验收仍需外部条件的边界内，
先落地 docs/05 / docs/11 §3 / docs/13 §3 里**不需要 WebView / 网络 / 真机 /
新依赖**的归档判定层与 UI 数据层。

**改了什么**
- 新增 `lib/data/archive/archive_meta.dart`：kind=5 `entry.meta` 的唯一交换格式
  - 7 个 `ArchiveStatus` / 3 个 `RecheckPolicy` / 5 种 `LinkCheckResult` /
    `ArchiveBlobKind`；解析即校验（非法枚举、字段类型、超长摘要一律拒绝）
  - `siteOf()` 去掉 www / 端口、只接受 http/https；`toJsonString()` 用
    Canonical 保证确定性；`nextCheckAt()` 驱动 weekly/monthly/never
  - 空 meta 降级为「仅元数据」，坏 meta 不阻断整页
- 新增 `lib/data/archive/archive_policy.dart` 纯判定层
  - `decideArchivePolicy()`：L1 正文永远保存；超 80% 配额时 full 降级 text；
    反爬 / 付费墙 / 死链 / 超时各自给出明确状态
  - `classifyHttpStatus()`：404/410→dead、403/451→restricted、
    超时/DNS 重试 2 次后才 unreachable；`shouldTryWayback()`
  - `hasContentChanged()`：simhash 汉明距离 ≤3 不算实质变更
  - `planBlobCacheEviction()` LRU 只释放本地空间、不删云端；
    `planSnapshotDowngrade()` 按最老快照降到 80% 配额线
  - `groupBySite()` / `filterArchives()` / `summarizeStorage()` 供总览页
- 新增 `ArchiveRepository` + provider：只读 `entry(kind=5)`，坏 meta 隔离跳过
- **重写 `ArchivePage`**：从写死 3 条假数据改为 `ConsumerStatefulWidget`
  + `FutureBuilder`，状态筛选 / 站点聚合 / 存储面板全接真实数据；
  `FutureBuilder.future` 缓存到 state，避免点筛选时重新 loading 闪屏
- 测试：`archive_meta_test.dart` 7 条、`archive_policy_test.dart` 15 条、
  `archive_page_test.dart` 5 条（真实 TestApp + kind=5 数据，含坏 meta 隔离）
  → 全量 **458 → 485**

**关键边界**
- 这是 **M4 的纯逻辑 / UI 预备层**，不是 M4 完成：真实抓取、readability
  注入、PDF 生成、Wayback API、原生分享入口都未实现（需 WebView / 平台通道）
- M3 硬门槛仍未过（A5 / 26 个真实集成用例），按文档规则不宣称 M4 完成

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**485/485 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字 / 决策表 / 目录）、09（§6）、14（Day 30）、
20（当前状态）、CHANGELOG（本条）

---

## v0.34 · 2026-11-11

### 响应体大小上限硬化（已验证）

docs/README「关键预算」写「单条目正文 ≤ 1 MB / blob ≤ 20 MB」，但 HTTP 层
此前会把任意大小的响应全读进内存：损坏或被篡改的云端文件可直接撑爆峰值
内存预算，且半个载荷会被当成「损坏条目」去解密。

**改了什么**
- `HttpWebDavConfig.maxResponseBytes`（默认 1 MB，blob 按需下载可显式调大）
- `_bytes()` 先按 `Content-Length` 快速拒绝，chunked 响应边读边累计，
  超限抛 `WebDavException(507 → E_QUOTA)`，**绝不静默截断或返回半个载荷**
- 超限分支刻意不 `drain()`：`HttpClientResponse` 是单订阅流，drain 后再
  `await for` 会抛 `StateError` 把真正的 E_QUOTA 掩盖掉（实现时踩过）
- `test/http_webdav_backend_test.dart` +1 条：64 B 上限下 2 KB 载荷 →
  E_QUOTA，调大到 4 KB 后完整读回 → 全量 **457 → 458**

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**458/458 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
真实 HTTP 后端**仍未接生产路径、M0 A5 未过**，M3 硬门槛不变。

**影响文档**：README（数字 / 决策表）、09（§5）、14（Day 29）、CHANGELOG（本条）

---

## v0.33 · 2026-11-11

### 真实认证断言与 T15 强杀重启确定性覆盖（已验证）

**改了什么**
- `test/http_webdav_backend_test.dart` +1 条：真实 TCP 校验 Basic 认证头
  内容（`alice:secret` 的 base64），并断言 401 → `E_AUTH`（不可重试）
- `test/db_sync_workspace_test.dart` +1 条 T15：用系统临时目录的
  **落盘 SQLCipher 库**模拟「写入中途失败 → 关闭句柄 → 同文件重开」，
  断言失败事务无半写、已提交数据仍在、`applied=0` 的 oplog 仍是待推、
  被强杀的那次写入不留幽灵行 → 全量 **455 → 457**
  - 测试用 `SqlitePragmas(journalMode: 'DELETE')` 避开 WAL 残留文件在
    后台 isolate 重开时的环境限制
  - `VaultDatabaseOpener.close()` 会 `destroy()` 密钥；生产重启重新派生，
    测试里先复制一份 `DatabaseKey.bytes` 再重开（夹具问题，非产品 bug）

**关键边界**：T15 只覆盖「本地事务原子 + 重启续跑」的确定性部分；
真实强杀进程、跨设备最终一致仍需真机 / 26 个真实集成用例。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**457/457 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
真实 HTTP 后端**仍未接生产路径、M0 A5 未过**，M3 硬门槛不变。

**影响文档**：README（数字 / 决策表）、09（§5 / §12）、14（Day 28）、
CHANGELOG（本条）

---

## v0.32 · 2026-11-11

### 统一调度接入退避重试驱动（已验证）

`RetryScheduler`（v0.22）此前只被自己的单测覆盖，`SyncCoordinator` 仍然
「正文跑一次就结束」：E_NET / E_RATE 进入 BACKOFF 后整轮就停，没有任何
东西真正等一会儿再跑。本轮把两者接通。

**改了什么**
- `SyncCoordinator` 新增可选 `retryScheduler`（默认 `RetryScheduler()`），
  正文阶段改为 `load → run → commit` 的重试闭环
- **每次重试都重新装配 `SyncWorkspace`**：上一轮可能已经把 `sync_state` /
  `syncToken` 落库，复用旧对象会重复发同一批请求
- 只有 BACKOFF 才重试；超过总尝试次数仍 BACKOFF 则按「正文不完整」跳过
  taxonomy / 清理阶段（保守闸门不变）
- `test/sync_coordinator_test.dart`：现有用例注入假 `sleep`（原来真睡
  1s→2s→4s 累计 17 秒），新增 1 条
  「E_NET 退避 → 重试成功 → 仍继续 taxonomy 与清理」的贯通测试
  → 全量 **454 → 455**

**关键决策**：生产默认 `Future.delayed`，测试注入零等待；不排队触发、
不无限重试（总尝试次数封顶），与 D24 / D38 一致。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**455/455 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
真实 HTTP 后端**仍未接生产路径、M0 A5 未过**，M3 硬门槛不变。

**影响文档**：README（数字 / 决策表）、09（§5）、14（Day 27）、CHANGELOG（本条）

---

## v0.31 · 2026-11-11

### GET ETag 兜底与重定向防护（已验证）

**改了什么**
- `get()` 与 `put()` 对称：GET 成功但响应无 ETag 时用 HEAD 回读，
  绝不把空条件交给 `SyncEngine` 写进 `syncState`
- `request.followRedirects = false`：条件写被 3xx 重定向到登录页时，
  自动跟随会把 `If-Match` 丢掉却返回 200 —— 静默丢数据
- `_send` 把 3xx 统一映射成 `WebDavException(401 → E_AUTH)`，
  由状态机停止同步并禁用自动重试（docs/04 §7）
- `test/http_webdav_backend_test.dart` +2 条真实 TCP 场景：
  GET 无 ETag → HEAD 回读；302 登录页 → E_AUTH
  → 全量 **452 → 454**

**关键决策**：宁可让会话过期显式失败，也不能把「重定向后的 200」
当成条件写成功。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**454/454 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
真实 HTTP 后端**仍未接生产路径、M0 A5 未过**，M3 硬门槛不变。

**影响文档**：README（数字 / 决策表）、09（§5）、14（Day 26）、CHANGELOG（本条）

---

## v0.30 · 2026-11-11

### 并发限流与真实运行时装配门面（已验证）

**改了什么**
- `HttpWebDavConfig.maxConcurrentRequests`（默认 3）落到
  `HttpClient.maxConnectionsPerHost`：docs/04 §10「全局最多 3 个在途 HTTP
  请求」不再只是文档承诺。用 SDK 连接池上限比手写信号量更可靠，
  因为它覆盖「发请求 + 读响应体」整个生命周期
- `test/http_webdav_backend_test.dart` +1 条：8 个并发 GET、服务器统计
  同时在途数，断言峰值 ≤ 配置值
- 新增 `lib/app/session/vault_sync_runtime.dart`：`VaultSyncRuntime.create()`
  把真实 `VaultDatabase` + `WriteGateway` + `DbSyncWorkspaceStore` +
  `DbEntitySyncPort` + `SyncEngine` + `EntitySyncEngine` +
  `SyncCoordinator` + `HttpClientWebDavBackend` 接成一条完整链路，
  `sync()` 一行跑完「正文 → taxonomy → 本地清理 → 云端墓碑 TTL」
- `test/vault_sync_runtime_test.dart` 2 条：真实内存加密库 + 本地
  HttpServer，断言设备水位真实 PUT、sync_log 落库、清理阶段执行；
  `dispose()` 关闭 HTTP 客户端
  → 全量 **449 → 452**

**关键边界**
- `VaultSyncRuntime` **刻意不接 App 启动装配**：构造它需要 WebDAV 地址
  与凭据，而 M0 A5（坚果云 / Nextcloud 真实行为）尚未确认。
  这里只提供「配置就绪后一行调用」的落点
- 仍是本地最小 WebDAV 服务验证，**A5 未过、26 个真实集成用例未通过、
  M3 硬门槛不变、不进 M4**

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**452/452 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。

**影响文档**：README（数字 / 决策表）、09（§5）、14（Day 25）、
20（真实接入边界）、CHANGELOG（本条）

---

## v0.29 · 2026-11-11

### PUT 成功但服务器不给 ETag 时的兜底（已验证）

部分 WebDAV 实现成功 `PUT` 不在响应头返回 ETag。`HttpClientWebDavBackend.put()`
此前直接返回空字符串，`SyncEngine` 把它写进 `syncState` 后下一轮会按
`createOnly()` 重试已存在文件，陷入 412 死循环 —— 这是真实服务商上最容易
遇到的兼容性坑之一。

**改了什么**
- `put()` 在响应 ETag 为空时用一次 `HEAD` 回读真实 ETag；HEAD 不支持或
  仍拿不到 ETag 时抛 `WebDavException(409 → E_PATH)` 交下一轮重新发现，
  **绝不静默返回空条件**
- `test/http_webdav_backend_test.dart` +2 条真实 TCP 场景：无响应 ETag 时
  HEAD 兜底且下一轮 `If-Match` 成功；服务器完全不实现 HEAD 时抛 E_PATH
  → 全量 **447 → 449**

**关键决策**：宁可多一次 HEAD 或让本轮重试，也不能把空 ETag 写进
`syncState` —— 后者会把「条件写」悄悄降级成「无条件写」。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**449/449 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
真实 HTTP 后端**仍未接生产路径、M0 A5 未过**，M3 硬门槛不变。

**影响文档**：README（数字 / 决策表）、09（§5）、14（Day 24）、CHANGELOG（本条）

---

## v0.28 · 2026-11-11

### 真实 HTTP 后端超时错误码修正（已验证）

审查 `HttpClientWebDavBackend._send()` 时发现 `.timeout()` 抛出的
`TimeoutException` 没有被捕获：会一路漏到 `SyncEngine` 的顶层 `catch`，
被当成 `E_CORRUPT`（文件损坏）直接 FAILED，而不是 `E_NET`（网络不可用，
可退避）。用户会看到完全错误的提示且不会重试。

- `_send` 新增 `on TimeoutException` → `WebDavException(statusCode: 504)`，
  `syncErrorCodeForStatus(>=500)` 映射到 `SyncErrorCode.net`
- `test/http_webdav_backend_test.dart` +1 条：服务器故意延迟 + 80ms 客户端
  超时，断言错误码是 `net` → 全量 **446 → 447**

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**447/447 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
真实 HTTP 后端**仍未接生产路径、M0 A5 未过**，M3 硬门槛不变。

**影响文档**：README（数字）、09（§5）、14（Day 23）、CHANGELOG（本条）

---

## v0.27 · 2026-11-11

### 真实 HTTP WebDAV 后端（dart:io，无新增依赖，本地集成验证）

此前 `WebDavBackend` 只有内存 fake。本轮用 Dart SDK 自带的
`dart:io HttpClient` 实现真实 HTTP 客户端，并用
`HttpServer.bind(127.0.0.1, 0)` 起最小 WebDAV 服务做**真实 TCP 集成测试**，
不需要外部服务器、不新增任何 Dart 依赖、不动 `pubspec.yaml`。

**改了什么**
- 新增 `lib/core/sync/http_webdav_backend.dart`：`HttpClientWebDavBackend`
  - OPTIONS / PROPFIND / REPORT / GET / PUT / DELETE / MKCOL 全覆盖
  - `WebDavCondition` 原样转成 `If-Match` / `If-None-Match: *`；
    4xx/5xx 与 SocketException / HttpException 统一映射 `WebDavException`
  - Basic 认证、可配连接超时、ETag 从响应头读
  - 207 Multi-Status 用轻量正则按 `<response>` 块解析，兼容
    `d:` / 无前缀 / 绝对 URL href；`status=404` 的块收敛成 `etag=null`
  - `reportSyncCollection` 返回 changed / deleted / `sync-token`
- 新增 `test/http_webdav_backend_test.dart` 7 条：OPTIONS 能力头、
  条件 PUT/GET/DELETE + 412 + 404、PROPFIND 207 解析、REPORT 增量/删除/token、
  MKCOL + 网络错误、XML 兼容性、以及
  **`SyncEngine` 通过真实 HTTP 后端跑完一轮 L1 静默同步**（设备水位真实 PUT）
  → 全量 **439 → 446**

**关键边界（必须守住）**
- 这是**抽象层的真实网络实现**，只针对本地最小 WebDAV 服务验证；
  **不等于 M0 A5 通过** —— 坚果云 / Nextcloud 的 RFC 6578、ETag 引号、
  Depth、URL 编码差异都还没实测
- **未接入生产路径**：App 启动装配仍不构造 `HttpClientWebDavBackend`，
  需要用户确认 M0 A5 结论与 WebDAV 账号配置后才接线
- 26 个真实集成用例仍未通过，**M3 硬门槛不变，不进 M4**
- XML 解析刻意不引第三方包：各家服务器命名空间前缀差异大，
  按标签局部名匹配反而更 tolerant；若将来要解析复杂属性再评估

**验证**
| 项 | 结果 |
|---|---|
| `flutter analyze` | 通过：No issues found |
| `flutter test --reporter compact --concurrency=1` | **446/446 passed** |
| `flutter build` | 未执行 |

`pubspec.yaml` / `pubspec.lock` 未改动、未新增依赖。

**影响文档**：README（数字 / 决策表 / 下一步）、09（§2 A5 / §5）、
14（Day 22）、20（真实接入边界）、CHANGELOG（本条）

---

## v0.26 · 2026-11-11

### T23：远端删除分类与本地路径对称（已验证）

`WriteGateway._deleteCategory()`（本地）删除分类时会把子分类提升为一级并
各自写 oplog，但 `_applyCategorySnapshot()`（远端 taxonomy 通道）被删除时
只清 `entry_category` 关联，**没有提升子分类** —— 会留下 `parent_id` 指向
已删分类的孤儿，两级树重建时它们会「神秘消失」，正是 docs/09 T23 要防的。

**改了什么**
- `_applyCategorySnapshot` 在删除分支末尾把该分类下所有子分类的
  `parent_id` 置空，与本地路径对称；条目关联清除、FTS 重建保持不变
- `test/entity_sync_engine_test.dart` +1 条 T23：远端删除信封落库后
  条目数不变、关联清空、子分类成为活的一级分类 → 全量 **438 → 439**
- 测试里先把本地 outbox 标记已推，避免本地 `create` 信封按同一
  `hashedName` PUT 到同一 path 覆盖测试预置的删除文件（夹具冲突，非产品 bug）

**关键决策**：删除分类绝不删条目，子分类只能提升不能级联删除；
本地 / 远端两条写入路径必须对称，否则跨设备结果不一致。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**439/439 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
**M3 硬门槛不变**：26 个真实集成用例未通过，不进 M4。

**影响文档**：README（数字 / 决策表）、09（§5 / §12 T23）、14（Day 21）、
CHANGELOG（本条）

---

## v0.25 · 2026-11-11

### T21：两设备同名标签在独立通道自动合并（已验证）

docs/09 T21 要求「两设备各建同名标签 → 自动合并为一个，关联不丢」。
M2 的组织页合并向导只覆盖**本地**同名标签；taxonomy 独立通道拉取远端
标签时 `_applyTagSnapshot` 直接 `insertOnConflictUpdate`，会留下两个同名
活标签、条目关联各挂一边。

**改了什么**
- `_applyTagSnapshot` 在远端 tag 非删除且本地存在「同名不同 id」的活标签时，
  在同一事务内按 `usage_count` 大者保留（`taxonomyNameKey` 大小写不敏感），
  用 `INSERT OR IGNORE` 把关联改指到保留方、软删另一方、重算计数、
  重建受影响条目的 FTS
- **保留本地 id 时跳过远端 id 的插入**，否则刚软删的远端标签会被
  `insertOnConflictUpdate` 复活成活标签 —— 这是实现时最容易漏的一步
- `test/entity_sync_engine_test.dart` +1 条 T21 场景 → 全量 **437 → 438**

**关键决策**：合并判定复用本地 `_mergeTags` 的「usage 大者」规则，
不新增另一套；并列时按 id 字典序做确定性 tie-break。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**438/438 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
**M3 硬门槛不变**：26 个真实集成用例未通过，不进 M4。

**影响文档**：README（数字 / 决策表）、09（§5 / §12 T21）、14（Day 20）、
CHANGELOG（本条）

---

## v0.24 · 2026-11-11

### 首批同步 50 条分批与分片游标边界（已验证）

- `DbSyncWorkspaceStore.load()` / `run()` 默认待推 oplog 上限由 500 改为
  **50**（`pendingBatchSize`），与 docs/04 §8.2「首次同步每批 50 条」、
  §10「PUSH 预留 60 请求」对齐。`EntitySyncPort.pendingBatchSize` 同步。
  以前 500 会稳定撞满 200 的请求预算，日志里全是「预算不足」，虽不丢数据
  但每轮白跑；现在超出的 oplog 保持 `applied=0`，下一轮按 seq 升序自然续跑，
  **不需要额外分批游标**。
- `test/db_sync_workspace_test.dart` +1 条：60 条待推 → 只装 50 条、标记已推后
  下轮恰好剩下 10 条 → 全量 **436 → 437**
- **明确不做（留给真实接入层）**：16 分片扫描的跨轮游标。分片游标需要保存
  每个分片的结果才能推断删除，只记「起点」仍要重扫 16 个；当前状态机在
  预算不足时走 `discoverBudgetExceeded → PUSH`，本就是「本轮放弃 L2、
  下轮重来」，内存 fake 下强行持久化反而会污染跨轮状态。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**437/437 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。
**M3 硬门槛不变**：26 个真实集成用例未通过，不进 M4。

**影响文档**：README（数字 / 决策表）、09（§5）、14（Day 19）、CHANGELOG（本条）

---

## v0.23 · 2026-11-11

### 修复 taxonomy 同 rev 并发更新被静默丢弃（T22，已验证）

在 v0.22 之后再做一轮代码审查，发现 `WriteGateway.applyRemoteTaxonomySnapshots()`
与 `applyEntityPull()` 判定远端 taxonomy 快照时只比较 `rev`：
`latest.rev >= snapshot.rev` 就直接 `continue`。两台设备从同一 base
各自改一次分类 / 标签都会得到 `rev = base + 1`，此时**后到的那一方会被
静默丢掉**，既不写 oplog 也不报错 —— 正是 docs/09 T22 要求避免的情况。

**改了什么**
- 新增 `lib/data/taxonomy/taxonomy_lww.dart`：`resolveTaxonomyLww()` 纯函数
  - 本地无版本 → 应用远端；`rev` 不同 → 大者胜
  - `rev` 相同 → 用 HLC 做因果序 tie-break，HLC 更大者胜
  - HLC 解析失败 / 完全相等 → 保守保留本地，绝不覆盖
- `applyRemoteTaxonomySnapshots()` / `applyEntityPull()` 两处判定统一换成
  该函数，不再各自写 `latest.rev >= snapshot.rev`
- `test/taxonomy_lww_test.dart` 4 条 + `test/entity_sync_engine_test.dart`
  1 条落库层 T22 场景 → 全量 **431 → 436**

**关键决策**：taxonomy 的 `rev` 是**本地单调递增**，不是跨设备全局版本；
跨设备并发必须靠 HLC 判定（docs/03 §5）。同 rev 且无法建立因果序时
保留本地比覆盖更安全。

**验证**
| 项 | 结果 |
|---|---|
| `flutter analyze` | 通过：No issues found |
| `flutter test --reporter compact --concurrency=1` | **436/436 passed** |
| `flutter build` | 未执行 |

`pubspec.yaml` / `pubspec.lock` 未改动、未新增依赖、未执行构建。
**M3 硬门槛不变**：26 个真实集成用例未通过，不进 M4。

**影响文档**：README（数字 / 决策表）、09（§5）、14（Day 18）、CHANGELOG（本条）

---

## v0.22 · 2026-11-11

### 自主代码审查：P0 数据一致性 + 6 项编排缺口 + M2 遗留 UI（已验证）

用户授权「能做的都做」并允许开子代理 / 团队并行。主控按文件边界串行落地，
并行只用于只读审查（避免写冲突），共修 8 类缺口。仍不新增依赖、不改
`pubspec.yaml`、不接真实 HTTP、不执行构建。

**改了什么**
- **P0 `WriteGateway.purgeTrashEntry()`**：30 天物理清理此前只删 5 张表，
  漏掉 `credential` / `entry_vec` / `blob_ref` / `link_check` / `activity`，
  会留下指向不存在条目的孤儿行；`diary_index` 两列现在只把命中的列置空，
  不误删同一天的另一篇（用户 / AI）日记索引
- **P1 sync-collection token**：`REPORT` 返回的 `delta.syncToken` 写进
  `syncState['sync/token']`，随 `_replaceSyncState()` 原子落库；下一轮
  `load()` 读回它，不再每轮拿旧 token 请求全量变更表
- **P1 水位 schema 闸门**：`DeviceWatermark.isSchemaTooNew()` 此前从未被调用；
  现在 L1 就拒绝高版本设备，不发 OPTIONS / REPORT（docs/04 §7 / T18）
- **P1 E_PATH / MKCOL**：`_RunContext.collectionRequest()` 与
  `putWithMkcol()` 对目录类请求 / PUT 的 404/409 自动 MKCOL 重建再重试一次；
  **GET 条目文件 404 不误建目录**（那是正常的 diff 结果），重试仍是条件写
- **P1 能力探测缓存**：`WebDavCapabilities.isCacheExpired()` 落地，结果存
  `sync/capabilities` + `sync/capabilities_checked_at`，24 小时内不发 OPTIONS
- **P1 退避重试驱动**：新增 `RetryScheduler`（可注入 `sleep` 的纯 Dart
  调度器，生产接 `Future.delayed`），只有 BACKOFF 才重试，E_NET 1s→5min、
  E_RATE 30s→10min，超过总尝试次数即停；`SyncRunResult.retryCode` 显式
  记录可重试错误码，不靠解析文案猜
- **P2 分类拖拽排序**（M2 遗留，docs/09 §4）：新增
  `lib/data/taxonomy/category_reorder.dart` 纯函数
  （`sortedSiblings` / `reorderCategorySiblings`），组织页改用 Flutter 3.41+
  的 `onReorderItem` 扁平渲染两级树，**跨父级 / 跨层级拖动一律拒绝**，
  同级排序逐条走 `WriteGateway.writeCategory`；`category.sortOrder` 字段
  终于有了 UI
- **测试**：`test/sync_engine_test.dart` +6（token / 水位 schema / MKCOL×2 /
  缓存×2）、`test/retry_scheduler_test.dart` 5 条、
  `test/entity_sync_engine_test.dart` +1（10 张关联表无孤儿行）、
  `test/category_reorder_test.dart` 5 条、
  `test/organize_write_test.dart` +1（拖拽落库 + category oplog）
  → 全量 **413 → 431**

**关键决策**
- **孤儿行比「多删一点」更危险**：物理清理必须覆盖所有引用该 entry 的
  派生表，否则下次同步 / 重建索引会把它们当成还活着的引用
- **能力缓存与增量游标都走 `sync_state` 内部键**：不新增表、不跑 codegen，
  随同步结果原子落库
- **MKCOL 只对集合目录类请求启用**：GET 文件 404 是正常的 diff 结果，
  盲目建目录会掩盖真实删除
- **退避错误码显式化**：状态机只在 FAILED 保留 error，BACKOFF 的错误码
  必须由 `retryCode` 字段传给调度器
- **拖拽不改归属**：跨父级 / 跨层级落点忽略，改层级是独立操作

**验证**
| 项 | 结果 |
|---|---|
| `flutter analyze` | 通过：No issues found |
| `flutter test --reporter compact --concurrency=1` | **431/431 passed**（413 + 新增 18） |
| `flutter build` / 打包 / 编译 | **未执行** |

**工作方式**：用户明确授权开子代理 / 团队并行后，并行只用于只读代码审查；
**写文件仍由主控串行**（历史上有并行把用户机器卡死、以及文件写冲突的教训）。
验证命令带 `NO_PROXY=127.0.0.1,localhost,::1`；`pubspec.yaml` /
`pubspec.lock` 未改动、未新增依赖。**M3 硬门槛不变**：26 个真实集成用例
仍未通过，不进 M4。

**影响文档**：09（§4 / §5）、README（进度 / 数字 / 决策表 / 工作方式）、
14（Day 17）、20（硬规则与收尾状态）、CHANGELOG（本条）

---

## v0.21 · 2026-11-11

### 修复 L2 删除列表未被消费（已验证）

代码审查发现一个真实的同步缺口：`SyncEngine` 的 `_pull()` 只 GET
`diff.added + diff.modified`，`diff.deleted` 从未被消费。也就是说
`sync-collection` 明确给出的删除列表、或 16 分片完整扫描推断出的
「远端 item 文件消失」，除了被记进 `SyncRunResult.diff` 之外没有任何效果；
本地会一直保留那条条目。墓碑缺失 / 已被 90 天 TTL 清掉时，这类删除
永远同步不过来。

**改了什么**
- `lib/core/sync/sync_engine.dart` 新增 `_applyDeletedItemFiles()`，
  在 `_applyTombstones()` 之后消费 `ctx.diff.deleted`：
  - 只处理 `/vault/items/` 路径；其它命名空间的陈旧 `sync_state`
    记录一律清除但不碰本地实体
  - 复用 `decideTombstone()`：`localRev > baseRev` 说明本地有未推编辑，
    **编辑胜** —— 复活并写新 rev、生成 upsert 推回云端，绝不因文件消失
    吞掉用户内容
  - 本地未变 → 规则 7 软删进回收站（`deleted=true` + `deletedAt`）；
    本地已删 → 幂等，只清状态
  - 无论哪种判定，都从 `sync_state` 移除该 path → ETag，避免下一轮
    反复把它当成远端删除
- 新增 `tombstoneHandledEntryIds`：同一轮里墓碑是比「文件不见」更强的
  信号，已由墓碑处理过的 entry 不再被删除列表二次 bump rev / 软删
- `test/sync_engine_test.dart` 新增 4 条：规则 7 软删、编辑胜复活、
  墓碑优先不重复处理、非 items 命名空间只清状态
- `test/db_sync_workspace_test.dart` 新增 1 条端到端：软删真的落进
  `trash` 表、FTS 移除、delete oplog `applied=1`、陈旧 ETag 清除

**关键决策**
- **墓碑优先，文件消失是弱信号**：两条路径都指向同一条删除时，
  只按墓碑判定一次
- **编辑胜判据复用 `localRev > baseRev`**，与 docs/04 §5.1 #8/#9 一致，
  不新增一套「谁更新」的规则
- **完整扫描才推断删除**这条红线不变：部分分片扫描的 `diff.deleted`
  本来就是空的（D26），本轮不改变 L2 发现逻辑

**验证**
| 项 | 结果 |
|---|---|
| `flutter analyze` | 通过：No issues found |
| `flutter test --reporter compact --concurrency=1` | **413/413 passed**（408 + 编排 4 + DB 1） |
| `flutter build` / 打包 / 编译 | **未执行** |

**工作方式**：全程主控串行，未开并行子代理；验证命令带
`NO_PROXY=127.0.0.1,localhost,::1`；`pubspec.yaml` / `pubspec.lock`
未改动、未新增依赖。**M3 硬门槛不变**：26 个真实集成用例仍未通过，不进 M4。

**影响文档**：09（§5）、README（进度 / 数字 / 决策表）、14（Day 16）、
20（收尾状态）、CHANGELOG（本条）

---

## v0.20 · 2026-11-11

### M3 统一调度：正文 → taxonomy → 本地清理 → 云端墓碑 TTL（已验证）

远端仓库由 `ttwyce/bbbjjj` 改名为 `ttwyce/vault`（私有），本地目录、
package 名、远端名三者一致；`75b6c8b` 已推送。本轮把前一批三个互不感知的
入口串成一次顶层同步，并补齐 90 天墓碑文件的云端 DELETE 编排。
仍不新增依赖、不改 `pubspec.yaml`、不接真实 HTTP、不执行构建。

**改了什么**
- 新增 `lib/core/sync/sync_coordinator.dart`：
  - `SyncCoordinator` 按「正文 `SyncEngine` → taxonomy `EntitySyncEngine`
    → 本地 30 天清理 → 云端 90 天墓碑 DELETE」串行执行，一把总单飞锁
    保证同一时刻只有一轮顶层同步，锁忙直接跳过
  - **保守闸门**：正文失败 / 退避 / 预算不足 / 水位未发布，或 taxonomy
    通道失败 / 跳过 / 预算不足时，一律跳过清理阶段 —— 清理不可逆
  - 云端 DELETE 只针对 `planTombstoneRetention()` 判定的 90 天过期墓碑，
    且必须用 `sync_state` 里已确认的 ETag 做 `If-Match`；无 ETag、
    412、503、预算不足都留到下一轮，不做无条件删除
  - `SyncRunReport` 汇总三条链路结果，`completed` 只表示同步链路完整；
    清理阶段「部分完成」不推翻已成功的同步
- 修改 `lib/core/sync/entity_sync_engine.dart`：
  `EntitySyncRunResult` 新增 `budgetExceeded` / `isComplete`，
  让调度器能区分「完整跑完」与「预算不足的半轮」
- 修改 `lib/data/sync/db_entity_sync_port.dart`：实现
  `TrashPurgeRunner` / `TombstoneLister`，从 `sync_state` 列出云端墓碑；
  时间信息缺失的记录 `deletedAt=0`（视为未过期），绝不按「看不见就算老」
- 新增 `test/sync_coordinator_test.dart`（7 条）：顺序、五类正文不完整、
  三类 taxonomy 不完整、缺 ETag、DELETE 失败、总单飞锁、清理预算不足

**关键决策**
- **清理不可逆，所以前置链路不完整就不清理**：本地物理删除与云端墓碑
  DELETE 都不能在「可能还有未同步状态」时执行
- **90 天 TTL 只删云端墓碑文件**：本地 `sync_state` 里已确认的墓碑记录
  仍保留，供 30 天清理闸门继续使用，两套依据互不删除
- **每个 DELETE 都带 `If-Match`**：接口层不存在无条件删除的调用形态

**验证**
| 项 | 结果 |
|---|---|
| `flutter analyze` | 通过：No issues found |
| `flutter test --reporter compact --concurrency=1` | **408/408 passed**（401 + 新增 7） |
| `flutter build` / 打包 / 编译 | **未执行** |

**工作方式**：全程主控串行，未开并行子代理；验证命令带
`NO_PROXY=127.0.0.1,localhost,::1`；`pubspec.yaml` / `pubspec.lock`
未改动、未新增依赖。**M3 硬门槛不变**：26 个真实集成用例仍未通过，不进 M4；
本轮新增的仍是确定性单测与内存 fake。

**影响文档**：09（§5）、README（进度 / 数字 / 目录 / 决策表）、
14（Day 15）、20（下一步）、CHANGELOG（本条）

---

## v0.19 · 2026-11-11

### M3 第三批收尾：#14 数据库集成测试 + #15 taxonomy 通道 / 保留策略（已验证）

按 [20 交接文档](20-交接文档.md) §5 的顺序完成 #14 / #15 / #16：
先给 `DbSyncWorkspaceStore` / `applySyncRun()` 补专用数据库集成测试，
再实现 taxonomy 独立同步通道与 30 天清理墓碑联动，最后同步文档。
仍不新增依赖、不改 `pubspec.yaml`、不接真实 HTTP、不执行构建。

**改了什么**
- 新增 `test/db_sync_workspace_test.dart`（12 条）：
  - `load()` 装配 `syncState` / `deviceEtags` / `localWatermarks` /
    `pendingOps`（`rawPayload` 就是 oplog 信封字节）/ `baseRevs` /
    `baseSnapshots`，坏 oplog 隔离不阻断整轮
  - 用 fake `WebDavBackend` 跑一次 `DbSyncWorkspaceStore.run()`，断言
    entry / FTS / oplog `applied=1` / `sync_state` / `sync_log` /
    `device_watermark` 一起落地
  - 损坏载荷写进 `sync_quarantine` 且原始字节完整、不覆盖本地；
    单飞锁跳过不写 `sync_log`
  - 坏 `content_hash` 与「事务中段索引写入故意失败」两种失败都整次回滚，
    断言 entity / oplog / sync_state / sync_log / 隔离区 / 水位无半写状态
  - 钉住 `recordEntityPushes()` / `applyRemoteTaxonomySnapshots()` 落库入口
- 新增 `lib/core/sync/entity_sync_engine.dart`：
  - `EntitySyncEngine` 把 category / tag / `entry_taxonomy` 的待推 oplog
    按 seq 顺序条件推送到 `CloudLayout.entityItemPath()`，成功后
    `WriteGateway.recordEntityPushes()` 落库
  - 16 分片 ETag diff 拉取；部分分片扫描不推断删除；坏载荷隔离；
    单飞锁忙跳过；所有 PUT 必须带 `If-Match` / `If-None-Match`
  - **不跑 `merge3`**：同 rev 或更旧的远端快照直接跳过
- 新增 `lib/data/sync/db_entity_sync_port.dart`：
  - `DbEntitySyncPort` 把通道接到 drift；`pending()` 只取 taxonomy 实体
  - `purgeExpiredTrash()` 逐条过保留策略闸门后物理清空
- 新增 `lib/core/sync/retention_policy.dart`：
  - 30 天本地清理必须同时满足「到期 / 仍为删除态 / 本条墓碑 ETag 已确认 /
    无未推 oplog」，否则等待下一次同步
  - 90 天墓碑 TTL 独立判定，只产出云端删除计划，不动本地回收站
- 修改 `lib/data/write/write_gateway.dart`：
  - `applyEntityPull()` 在一个事务里落实体 / oplog / 隔离区 /
    `sync_state` / `sync_log`，且**只替换 `/vault/entities/` 命名空间**
  - `quarantineOnly()` 处理「只有坏载荷」的独立事务
  - `purgeTrashEntry()` 是 30 天清理的唯一落库入口
- 新增 `test/entity_sync_engine_test.dart`（13 条）：条件写 / 路径隔离 /
  `applied=1` / 拉取不合并 / 隔离 / 部分分片保护 / 30 天闸门 /
  90 天与 30 天分离判定

**关键决策**
- **刚 PUT 的文件合入本轮 remote**：PROPFIND 与 PUT 之间没有原子性，
  否则服务器尚未列出新文件时会被 diff 误判为远端删除
- **entity 通道只维护自己的 `sync_state` 命名空间**：正文通道的
  `items/` / `tombstones/` / `devices/` 映射不被覆盖
- **30 天清理的闸门是「本条墓碑的 ETag 已确认」**，不是「任意墓碑存在」、
  更不是「到期时间到了」；条目恢复或有未推 oplog 一律不准删
- **墓碑 90 天 TTL 与本地 30 天清理互不删除对方的依据**
- **M3 硬门槛不变**：26 个真实集成用例仍未通过，不进 M4；
  内存后端 / 内存加密库不替代 Nextcloud + mod_dav、真机计时、强杀重启

**验证**
| 项 | 结果 |
|---|---|
| `flutter analyze` | 通过：No issues found |
| `flutter test --reporter compact --concurrency=1` | **401/401 passed**（376 + #14 12 + #15 13） |
| `flutter build` / 打包 / 编译 | **未执行**（硬规则：未允许绝不构建） |

**工作方式**：全程主控串行，未开并行子代理；验证命令带
`NO_PROXY=127.0.0.1,localhost,::1`；`pubspec.yaml` / `pubspec.lock` 未改动、
未新增依赖。本机安装 Flutter 3.47.9 stable / Dart 3.13.7 与 `.metadata`
一致，用 `PUB_HOSTED_URL=https://pub.flutter-io.cn` + `--enforce-lockfile`
按原锁文件取依赖，避免锁文件被改写。

**影响文档**：20（交接状态与下一步）、09（§5 第三批收尾状态）、
README（进度 / 数字 / 目录 / 下一步）、14（Day 14）、CHANGELOG（本条）

---

## v0.18 · 2026-11-11

### M3 第三批交接：加密载荷与 DB 工作区（部分落地 / 已验证）

按「写交接文档并推送」整理 M3 第三批中断状态：把 #13 真实加密 codec 与
#14 数据库工作区 / 事务落库代码提交，明确 #15 / #16 未完成；仍不新增依赖、
不改 `pubspec.yaml`、不接真实 HTTP、不执行构建。

**改了什么**
- 新增 `lib/core/sync/encrypted_sync_codec.dart`：
  - `K_name` HMAC 文件名、`K_item` entry / tombstone / taxonomy 信封、
    `K_meta` `/vault/meta.enc` 校验载荷；设备水位按设计保持明文
  - 解码交叉校验信封头、实体、id、rev 与 `content_hash`
- 修改 `lib/core/sync/sync_payloads.dart` / `sync_engine.dart`：
  - 引入 `AsyncSyncPayloadCodec` / `SyncPayloadCodecAdapter` /
    `SyncEntityPayloadCodec` / `SyncEnvelopeHeader`
  - `SyncPendingOp.rawPayload` 让 oplog 信封字节原样 PUT
  - `SyncRunResult` 记录 `quarantinePayloads` / `nextHlc` /
    `cloudAppliedEntryIds`，供 DB 侧安全标记 `applied=1`
- 新增 `lib/data/sync/sync_workspace_store.dart`：
  - 从 `sync_state` / `device_watermark` / `entries` / oplog 装配
    `SyncWorkspace`，并 `load → SyncEngine.run → applySyncRun`
- 修改 `lib/data/write/write_gateway.dart`：
  - `applySyncRun()` 在一个事务里落实体、历史、回收站、FTS、oplog、
    `sync_state`、`device_watermark`、`sync_log` 与隔离区
  - `sync_quarantine` 用原生 SQL 建表，避免 drift codegen /
    `schemaVersion` 升级
  - 预备 `recordEntityPushes()` / `applyRemoteTaxonomySnapshots()` 落库入口
- `CloudLayout` 新增 `/vault/entities/<shard>/` 独立命名空间；
  `SyncEntity` 新增 `sync_meta` / `tombstone`
- 新增 `test/encrypted_sync_codec_test.dart` 7 条；
  `test/sync_engine_test.dart` 改用 `SyncPayloadCodecAdapter`
- 新增 `docs/20-交接文档.md`，同步 README / 09 / 14 / CHANGELOG

**关键决策**
- **交接不等于第三批完成**：#14 代码已落地但专用数据库集成测试未补；
  taxonomy 独立通道与 30 天清理墓碑联动仍未做
- **中断半成品全部撤回**：短暂出现的 `entity_sync_engine.dart` /
  `retention_policy.dart` 与 `write_gateway.dart` 半编辑已删除 / 还原
- **oplog 信封字节原样上传**：避免为了同步再解一次密文、制造额外明文窗口
- **远端确认才标 `applied=1`**：`cloudAppliedEntryIds` 防止本地未推编辑被静默吃掉
- **M3 硬门槛不变**：26 个同步用例不全通过，不进 M4

**尚未完成**
- `DbSyncWorkspaceStore` / `applySyncRun()` 专用数据库集成测试与原子回滚断言
- taxonomy 独立同步通道、30 天回收站清理与墓碑联动、墓碑 90 天 TTL 分离判定
- 真实 WebDAV 客户端、M0 A5 结论、26 个集成用例与真机 / 计时 / 强杀重启 /
  大 blob / 5000 条性能验收

**验证**
| 项 | 结果 |
|---|---|
| `flutter analyze` | 通过：No issues found |
| `flutter test --reporter compact --concurrency=1` | 通过：**376/376 passed**（369 + 新增 7） |
| 定向 #13 测试 | 通过：`+28: All tests passed!` |
| `flutter build` | **未执行**（硬规则：未允许绝不构建） |

默认并发全量测试时 `kdf_perf_probe_test.dart` 因机器负载出现
`5662 ms > 5000 ms` 的性能抖动；单独复跑 `2610 ms` 通过，串行全量复跑全绿。

**工作方式**：全程主控串行，未开并行子代理；验证命令带
`NO_PROXY=127.0.0.1,localhost`；`pubspec.yaml` 未改动，未新增依赖。
临时测试日志提交前清理。按用户要求创建 GitHub 私有仓库
`ttwyce/bbbjjj` 并推送本次交接提交。

**影响文档**：20（新增交接文档）、09（§5 第三批交接状态）、README（进度 /
数字 / 目录 / 下一步）、14（Day 13）、CHANGELOG（本条）

---

## v0.17 · 2026-11-10

### M3 第二批：无依赖接入抽象与 SyncEngine 编排（已验证）

按用户选择的「继续无依赖编排」推进：仍不新增依赖、不改 `pubspec.yaml`、
不接真实 HTTP、不接数据库，但把第一批纯判定层串成一次可测试的同步运行。

**改了什么**
- 新增 `lib/core/sync/webdav_backend.dart`：
  - `WebDavBackend` 抽象接口：OPTIONS / PROPFIND / REPORT / GET / PUT / DELETE / MKCOL
  - `WebDavCondition` 只提供 `If-Match` 或 `If-None-Match: *`，
    接口层让「无条件 PUT」在编译期无法表达
  - OPTIONS 大小写不敏感能力探测：支持 `sync-collection` 走 1 请求增量，
    否则降级 16 分片 PROPFIND
  - HTTP 状态码 → `SyncErrorCode`、`WebDavPreconditionFailed`、
    `diffSyncCollection` 与 `diffAllShards`；只有 16 个分片全部扫完才推断删除
- 新增 `lib/core/sync/sync_payloads.dart`：
  - `SyncVaultMeta` / `SyncTombstone` / `SyncPendingOp` / `SyncWorkspace`
  - `SyncPayloadCodec` 把加密信封、JSON 与测试 codec 隔离在边界上；
    真实实现将来替换为 DEK 派生密钥的加密 codec
- 新增 `lib/core/sync/sync_engine.dart`：
  - 单飞锁、请求预算、状态机、L1 水位、L2 双路径发现、
    「墓碑 → meta → 条目」拉取、vault/schema 校验、损坏隔离、
    冲突矩阵 / `merge3` / 冲突副本、墓碑编辑胜、条件推送、
    412 重试、验证与设备水位发布串成一次 `run()`
  - 删除顺序固定为「先 PUT 墓碑，再 DELETE 条目文件」；
    连续第 4 次 412 生成冲突副本后继续校验；
    E_NET / E_RATE 退避，预算耗尽保存进度不做假完成
- 新增 `test/webdav_backend_test.dart`（8 条）与
  `test/sync_engine_test.dart`（21 条）：内存后端 + 纯 JSON codec，
  覆盖 T03/T04/T05/T06/T07/T09/T10/T11/T12/T14/T18/T19 的
  **可判定部分**、拉取顺序、条件写、删除顺序、预算、锁与水位发布
  → **340 → 369**

**关键决策**
- **先无依赖内存编排，再确认真实 WebDAV 依赖**：用户明确选择 fake-first；
  `pubspec.yaml` 与依赖保持不动，M0 A5 的客户端选型仍需单独确认
- **条件写做成类型而不是可空参数**：后端接口没有无条件 PUT/DELETE 的调用形态
- **payload / workspace / backend 三层隔离**：编排逻辑不依赖 drift、
  不依赖 HTTP 客户端、不依赖具体加密字节，后续逐层替换
- **编排测试不等于集成验收**：内存后端能证明顺序与零丢失规则，
  不能证明真实 Nextcloud / mod_dav、断网恢复、强杀重启、blob 进度或耗时
- 修掉 `sync_engine.dart` 的 `use_of_void_result`：DELETE 后端返回
  `Future<void>`，不能把 `request<void>` 结果当预算标记；改成
  `request<bool>` 包装，保留「墓碑已写、DELETE 下次续跑」语义

**尚未完成（M3 硬门槛仍未过）**
- 真实 WebDAV 客户端与 M0 A5 结论；新增/启用依赖前必须向用户确认
- DEK 加密 `SyncPayloadCodec`、`ItemEnvelope` 明文头与 AAD、云端 HMAC 文件名
- `sync_state` / `device_watermark` / `sync_log` / oplog / 回收站 / 历史的数据库事务集成
- taxonomy 实体同步、30 天回收站清理与墓碑联动、quarantine 落盘
- T01/T02/T15/T16/T19 的真机 / 大批量 / blob / 计时验收，
  T09/T10 的真实服务器断网与 412 验收，以及 09 §5 的 **26 个同步用例**
- 未通过 26 个集成用例前不进 M4

**验证**
| 项 | 结果 |
|---|---|
| `flutter analyze` | 通过：No issues found |
| `flutter test` | 通过：**369/369 passed**（基线 340 + 新增 29） |
| `flutter build` | **未执行**（硬规则：未允许绝不构建） |

**工作方式**：全程主控串行，未开并行子代理；所有验证命令带
`NO_PROXY=127.0.0.1,localhost`；未改动 `pubspec.yaml`，未新增依赖。
临时测试日志已清理。

**影响文档**：09（§5 M3 第二批状态）、README（进度 / 数字 / 决策 / 目录）、
14（Day 12）、CHANGELOG（本条）

---

## v0.16 · 2026-11-10

### M3 第一批：纯 Dart 同步核心（已验证）

按 `docs/04-同步引擎设计.md` 先落地**不依赖网络、不依赖数据库、不新增依赖**
的同步判定层，把最容易出错的状态转移、冲突矩阵与三方合并先变成确定性单测。

**改了什么**
- 新增 `lib/core/sync/`：
  - `sync_state_machine.dart`：13 个阶段、`docs/04 §4.2` 完整转移表、
    非法事件 `StateError`、10 个错误码的线格式
  - `sync_runtime.dart`：`SingleFlightLock`（锁忙直接跳过，不排队）、
    `RequestBudget(limit=200)`（不足不消耗）、`BackoffPolicy`
    （E_NET 1s→5min / E_RATE 30s→10min，不可重试错误直接抛）
  - `device_watermark.dart`：L1 明文水位解析、schema 兼容判定、
    未知设备 / HLC 前进 / ETag 心跳三类判据
  - `change_diff.dart`：L2 ETag diff、部分分片 `includeDeletes=false`
    安全开关、`sync-collection` 删除列表合入
  - `cloud_layout.dart`：`[0-9a-f]{32}.enc` 文件名、16 分片、
    meta/devices/items/tombstones/vec/blobs 路径与分段 URL 编码
  - `conflict_matrix.dart`：12 条冲突矩阵、#8/#9「编辑胜」、
    #12 隔离优先、墓碑 90 天 / 回收站 30 天、先写墓碑再删文件
- 新增 `lib/data/sync/`：
  - `line_diff.dart`：行级 LCS hunk、重叠分组、git 风格冲突标记、
    1200 行上限与 `LineDiffTooLarge`
  - `merge3.dart`：`EntrySnapshot` 三路短路、无 base 不合并、
    meta 字段级 LWW + `tags` 并集、按 kind 的文本 / LWW / 书签 /
    密码策略，合并结果 `rev=max+1`、新 HLC、重算 `content_hash`
- 新增 4 个测试文件、49 条用例：状态机/运行时 14、L1/L2/路径 12、
  冲突矩阵/墓碑 8、行级 diff/merge3 15 → **291 → 340**

**关键决策**
- **先纯函数，后 WebDAV**：状态机、探测、冲突与合并都不碰 IO，
  所以 T04/T05/T06/T07/T08/T11/T12/T13/T14/T17/T18/T20 中
  能用纯逻辑表达的部分可先钉死；真实 HTTP 行为留到接入层
- **锁忙跳过而不是排队**：前台、编辑 debounce、定时器会同时触发，
  排队会堆积几十次同步并打爆请求预算
- **部分分片扫描禁止推断删除**：没扫到的分片里文件"不见"不是删除，
  删除必须由完整扫描或 `sync-collection` 明确给出
- **坏数据优先级最高**：解密失败 / hash 不匹配先隔离，绝不参与合并或覆盖本地
- **删除不能吞掉未同步编辑**：`localRev > baseRev` 忽略远端墓碑；
  本地已删且远端确有内容变化、rev 更大时复活远端版本
- **密码条目永不字段合并**：LWW + 旧值副本，避免把两个密码拼成第三条脏数据
- **冲突副本是普通新条目**：新 id、rev=1、合法 content_hash，后续同步不再撞车
- 修掉 4 个新文件的 `library_directive_not_first`：库指令必须在所有 import 之前

**尚未完成（M3 硬门槛仍未过）**
- `WebDavBackend` / 能力探测 / 真实 PROPFIND、REPORT、GET、PUT、DELETE
- 拉取（墓碑 → meta → 条目）、推送 `If-Match`、412 重试计数、quarantine 落盘
- `sync_state` / `device_watermark` / `sync_log` 的数据库集成
- taxonomy 实体同步、30 天回收站清理与墓碑联动
- T01/T02/T03/T09/T10/T15/T16/T19 等需要真实服务器 / 真机 / 计时的用例；
  T10 本批只覆盖状态转移，不覆盖「连续 3 次 412」计数；T19 只覆盖静默判定，
  不覆盖「≤3 请求 / ≤800ms」
- 09 §5 的 **26 个同步用例**仍是 M3 硬门槛，未通过前不进 M4

**验证**
| 项 | 结果 |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ **340/340 passed**（基线 291 + 新增 49） |
| `flutter build` | ⏸ **未执行**（硬规则：未允许绝不构建） |

**工作方式**：全程主控串行，未开并行子代理；所有验证命令带
`NO_PROXY=127.0.0.1,localhost`；未改动 `pubspec.yaml`，未新增依赖。

**影响文档**：09（§5 M3 第一批状态）、README（进度 / 数字 / 目录）、
14（Day 11）、CHANGELOG（本条）

---

## v0.15 · 2026-11-10

### M2 收尾：taxonomy 写入、回收站/历史、筛选与工具栏（已验证）

**先还 Day 9 的账**

Day 9 的四个页面是「未验证提交」。这轮开局跑基线：`flutter test` 得到
`+246 -6`，6 条失败全部集中在两个地方：

- `records_page._refresh()` 写成 `setState(() => _results = _compute())`，
  箭头闭包返回 `Future`，被 Flutter 断言 `setState() callback argument
  returned a Future` 拦下 —— **首帧必崩**的产品 bug，不是测试写错。
- `widget_test.dart` 还是 M1 的裸 `ProviderScope`，页面接了真仓库后
  `vaultBootstrapProvider` 没有 override；`pumpAndSettle` 又因进度圈超时。
  改用 `TestApp` + `UncontrolledProviderScope(container:)` 与固定 pump。

修完 6 条并提交 `064210e`，基线 252 条全绿，才开始叠新代码。

**改了什么**
- `SyncEntity.entryTaxonomy` 成为独立同步实体；`WriteGateway` 新增
  `writeCategory` / `writeTag` / `setEntryTaxonomy` / `restoreVersion` /
  `readEntryPayload` / `readTaxonomySnapshot` 与 `_commitTaxonomy()`
- 新增 `lib/data/taxonomy/`：共享模型与硬规则、只读仓库（回收站 / 历史 /
  关联）、provider。历史版本 payload 是加密信封，统一走
  `gateway.readEntryPayload()` 解密，不把 `VaultKeys` 暴露成公开 provider
- 新增页面：`trash` / `history` / `search`（高亮 + `recordSearch` 埋点）/
  `quick` / `settings_hub`；`organize` 升级为可写（含同名标签合并向导）；
  `editor` 加分类单选 + 标签多选（≤8）选择器
- `AppShell` 接设置中心与全局「快速记录」悬浮按钮
- **补完 09 §4 明列的两项验收**：记录页「分类 OR（递归 CTE 含子级）/
  标签 AND」筛选；编辑器 Markdown 工具栏（H2 / 列表 / 任务 / 代码 /
  图片，插入逻辑抽成纯函数）
- 新增 39 条测试：taxonomy 15 / 回收站历史 4 / 组织页写 3 /
  编辑器 taxonomy 2 / Markdown 9 / 筛选 6 → **252 → 291**

**关键决策**
- **taxonomy 是独立同步实体**：分类 / 标签 / 关联变更都要产生可解密的
  加密 oplog。塞进 `entry.meta` 会让「正文没变」被合并器误判成正文更新
- **回滚不把 rev 倒回去**：用旧版本内容做一次新的 `EntryWrite.update`，
  产生新 rev；否则同步时会把它当成旧数据丢掉（测试断言 rev=3）
- **删除分类不删条目**：清关联让条目回「未分类」，子分类提升为一级并各自写 oplog
- **同名标签合并保留 usage 最大者**，关联用 `INSERT OR IGNORE` 改指，source 软删
- **分类 OR / 标签 AND**：选一级分类连带子级；`HAVING COUNT(DISTINCT) = n`
  保证多标签越选越窄，不是并集
- **编辑器正文与 taxonomy 分两次写**：不双写 meta；`setEntryTaxonomy`
  幂等，无变化不产生 oplog
- **bottom sheet 先返回动作、等 Future 完成再弹确认框**：`pop()` 与
  `showDialog` 挤在同一帧会抢 Navigator，确认框会整个消失
- **回收站不做「永久删除」按钮**：30 天到期清理由后台任务负责

**验证**
| 项 | 结果 |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ **291/291 passed** |
| `flutter build` | ⏸ **未执行**（硬规则：未允许绝不构建） |

**工作方式**：全程主控串行，未开并行子代理（Day 9 两次卡死用户机器）；
所有验证命令带 `NO_PROXY=127.0.0.1,localhost`。

**影响文档**：09（§4 M2 落地状态）、README（进度 / 数字）、14（Day 10）

---

## v0.14 · 2026-11-10

### M2 第一轮：条目系统四个页面（未验证提交）

**改了什么**
- 新增 `lib/data/entry/`：`entry_models`（EntrySummary/CategoryNode + 纯函数）、
  `entry_repository`（只读：列表/搜索/日记月视图/分类/标签）、provider
- 新增 `test/support/test_harness.dart`：页面测试共享环境
- 重写 `records_page.dart`：笔记/想法分段 + 搜索防抖 + 标签过滤 + 列表
- 重写 `diary_page.dart`：月历三态（用户日记/AI 日记/今天）+ 补写入口 + 当日列表
- 新增 `editor_page.dart`：新建/编辑 + 保存走 WriteGateway + 日记 meta.date 自动落
- 新增 `organize_page.dart`：分类两级树 + 标签云（本轮只读）
- 新增测试：records 4 条 / diary 4 条 / editor 4 条 / organize 4 条

**工作方式**
- 4 个子代理并行 → 用户机器两次卡死 → 改为**主控串行写完剩余三页**
- 按用户要求：**本版本未跑 analyze / test**，验证由用户决定时机

**关键决策**
- 编辑保存时把 `meta` 原样传回 —— 日记日期等扩展字段住在 meta 里，
  整体替换语义下不传回等于清空扩展字段
- 标题为空时写侧就规范化（正文首行兜底），与读侧 `displayTitle` 对称
- 日记月视图按 `meta.date` 分月，不用 `created_at`（补写需求）
- 列表一次取回标签用 `group_concat` + 单元分隔符，避免 N+1

**已知未验证风险**（等用户跑验证后回填）
- 4 个新文件未经编译，类型/import 错误可能存在于静态检查环节

**影响文档**：19（新增，并行契约）、README、14（Day 9）

---

## v0.13 · 2026-11-08

### 会话层与解锁 UI：M1 收尾

**改了什么**
- 新增 `lib/app/session/`：`vault_storage` / `vault_session` / `vault_gate`
- 新增 `lib/features/unlock/`：`unlock_page`（解锁 / 恢复码解锁）、
  `onboarding_page`（设主密码 → 24 词恢复码 → 抽 3 词验证）
- `main.dart` 在 `runApp` 前读 `meta.enc`，首帧就确定该显示哪一页
- `app.dart` 的 `home` 从 `AppShell` 换成 `VaultGate`
- 新增 3 个测试文件、34 条用例，总数 202 → 236
- **建立 git 仓库**并提交基线（183 文件），新增 `.gitattributes` 统一 LF

**关键决策**
- **`resolveGateScreen` 是纯函数**：路由判断抽出来单独测，
  不必搭 widget 环境。它也是全 App 唯一的"现在该显示什么"判断
- **未确认的恢复码优先于状态机**：创建成功后状态已是 `unlocked`，
  按状态走会直接进主界面，那 24 个词就永远看不到了
- **不伪造解锁进度**：Argon2id 没有进度回调，只显示不确定转圈 + 真实秒数。
  假进度条会在 1% 卡两秒，比没有更让人焦虑
- **`meta.enc` 先写 `.tmp` 再 rename**：它是解锁唯一入口，写一半断电等于永久锁死
- **`readMeta` 区分"不存在"与"读不懂"**：把损坏当成首次使用，会引导用户新建库，
  而老数据其实就在磁盘上
- **`failed` 状态不提供"重试"按钮**：重试没有意义，那是在骗用户

**P0 修复（子代理实测复现后补的）**
- 🔴 `createVault` 原本没有"本机已有 vault"守卫：它会生成新 DEK 并覆盖
  `meta.enc`，旧 DEK 的包裹结果消失 → **老数据永久打不开且不报错**。
  现在两道闸：状态守卫 + `writeMetaIfAbsent`（文件存在即拒绝覆盖）
- 创建失败时区分"meta 是否已落盘"：已落盘 → `locked`（可重试），
  未落盘 → `needsSetup`（可重来）。一律回 `needsSetup` 会引导用户覆盖刚写好的 meta
- `unlock` / `unlockWithRecoveryCode` 在缺 meta 时不再静默或推进 `failed`
- 🔴 首次创建期间状态也是 `unlocking`，闸门原本会误判成"解锁中"切到解锁页 ——
  用户刚设完密码界面会突然跳走。改成用 `meta == null` 区分两种 `unlocking`
- `copyWith` 新增 `clearHandles`：解锁四件套（db/opener/gateway/activity）
  原本无法置空，将来做"切换 vault"会留下指向已关闭数据库的 gateway

**子代理并行**
本轮首次用三个子代理并行（解锁页 / 首次创建页 / 会话测试），
各自只写一个文件、互不重叠。它们各自发现并处理的问题：
- 解锁页：`overrides: <Override>[...]` 在 riverpod 3 里没有这个导出类型
- 首次创建页：抽查恢复码时**主动把词表收起**（原本词表还在屏幕上，验证就是自欺）
- 会话测试：14 条用例，覆盖创建 → 重启解锁 → 锁定 → 再解锁全链路；
  并实测复现了上面的 P0（这是本轮子代理最值钱的产出）
- 首次创建页：自己又加了三处 `status == needsSetup` 闸门，防止在非创建态渲染出创建表单

**影响文档**：18（新增）、README（索引 / D20~D22 / 目录 / 进度）、09（M1 收尾）、14（Day 8）

---

## v0.12 · 2026-11-08

### 写入层与活动埋点：唯一写入口 + 条目加密信封 + 三档合并窗口

**改了什么**
- 新增 `lib/data/write/`：`write_gateway` / `item_envelope` / `entry_snapshot`
- 新增 `lib/data/activity/activity_logger.dart`
- `SecretWrapper` 泛化为通用 AEAD box：新增 `seal`/`open`（任意字节），
  `wrap`/`unwrap` 保留给 DEK；参数 `kek` 改名 `key`
- `EntryKind` 枚举落到 `entry_tables.dart`
- 新增 2 个测试文件、45 条用例，总数 157 → 202

**关键决策**
- **`WriteGateway` 是唯一写入口**：实体变更 + oplog + 历史 + 回收站 + FTS + HLC
  全部同一事务。绕过它就等于静默丢同步，且事后无法修复
- **条目加密信封 = 明文头 {entity,id,rev} + AAD = 头部字节本身**。
  原方案「AAD 需要 rev，但 rev 在密文里」是个死循环；明文头是唯一同时
  满足"防重放"与"接收端能解"的做法
- **oplog payload 与云端 item 文件字节完全一致**，推送可直接 PUT。
  因此**删掉 `VaultKeys.oplog()` 子密钥** —— 域分离靠 AAD，不靠换密钥
- **content_hash 只覆盖 {kind,title,body,meta}**，且 meta 先解码再哈希。
  含 rev/updated_at 会让"只是同步了一次"变成假冲突
- **内容未变不产生新版本、空操作不写 oplog**：否则自动保存与误触
  会把一堆无意义变更推给所有设备
- **活动埋点按 (kind, entry) 时间窗口合并**（浏览 30min / 编辑 5min / 搜索 60s），
  不记流水账。合并后的粒度恰好是日总结要的「读了 5 篇、写了 3 条」

**验证**
- 用"索引写入故意抛错"验证事务原子性：实体 / oplog / 历史三者必须全部回滚
- 把 A 的 payload 塞进 B 的行 → `readSnapshot` 抛错（信封头与行元数据交叉校验）
- 改信封头一个字节 → 认证失败（证明 AAD 真的绑在头部上）
- 记三种活动后断言 `oplog` 表仍为空（隐私边界是可测的）

**影响文档**：17（新增）、16（子密钥从 6 条改 5 条）、README（索引 / D17~D19 /
目录 / 进度）、09（M1 任务状态）、14（Day 7）

---

## v0.11 · 2026-11-08

### 密钥层：Argon2id + XChaCha 包裹 + BIP-39 恢复码

**改了什么**
- 新增 `lib/core/crypto/` 九个文件：`secret_bytes` / `argon2_params` / `kdf` /
  `secret_wrapper` / `vault_keys` / `bip39_english` / `recovery_code` /
  `vault_meta` / `vault_lock`
- `bip39_english.dart` 内置 2048 词表（生成文件，非手写）
- `DatabaseKey` 重构为委托 `SecretBytes`，去掉重复的零拷贝/比较/擦除实现
- 新增依赖 `cryptography` 2.9；**放弃 `sodium_libs`**（一个包覆盖 AEAD + Argon2 + HKDF）
- 新增 4 个测试文件、74 条用例，总数 83 → 157

**关键数据（实测，非推测）**
- Argon2id `m=64MB t=3 p=4` 在桌面 JIT 上 **2147 ms**，设计文档推测的是 0.6~1.2s
- 这是纯 Dart 实现的必然结果。保留 64MB（与 Bitwarden 默认一致），
  但解锁页必须有进度反馈、派生不阻塞首帧、提供生物识别跳过 —— 已记为 R19

**关键决策**
- **恢复码不跑 Argon2**：256 bit 真随机熵无可爆破空间，慢哈希收益为零而代价是灾难恢复变慢
- **AAD 绑定 `vault_id + purpose`**：防止 `wrapped_dek` 与 `recovery_wrapped_dek` 互换位置
- **`DEK_local` 改为从 DEK 派生**，不再单独包裹：恢复码只需恢复一个秘密（偏离 03 文档原设计）
- **创建时自检两条解锁路径**：防止产出「看起来成功但永远打不开」的 vault
- **`meta.enc` 序列化按 key 排序**：否则每次写出字节不同，制造无意义的 If-Match 冲突

**关键修正**
- 🔴 `SecretBytes.fingerprint` 第一版取密钥首尾各 4 字节，等于把 64 bit 真实密钥
  写进日志。改成 `sha256(key)` 前 4 字节 —— 测试断言"toString 不含 ababab" 直接
  暴露了这个设计问题，不是测试写错
- `RecoveryCode.parse` 内部已验校验和，不能用来构造"词还原正确但校验和错"的中间态

**影响文档**：16（新增）、02（§2 依赖表 + §13）、03（§2 密钥层级重写、§7 恢复码）、
09（M1 任务状态 + R19/R20）、README、14（Day 6）

---

## v0.10 · 2026-11-08

### 数据库层：22 张表 + 加密打开器 + 中文检索生产化

**改了什么**
- `lib/data/db/tables/` 8 个文件，按 13 号文档铺完 22 张表
- `lib/data/db/vault_database.dart`：drift `@DriftDatabase` + 手写 FTS5 虚拟表 + 检索 API
- `lib/data/db/database_opener.dart`：`VaultDatabaseOpener`，全项目唯一 open 入口
- `lib/data/db/database_key.dart`：`DatabaseKey`（32B，`PRAGMA key` 二进制字面量）+ `SqlitePragmas`
- `lib/data/search/cjk_segmenter.dart`：归一化 + 按字切分 + 短语查询构造
- 测试 40 条新增，总数 43 → 83

**关键修正（比功能本身更重要）**
- 🔴 **只查 `PRAGMA cipher_version` 发现不了"忘了加密"**。
  本项目全局用 SQLCipher，所以没设 key 的连接照样报出版本号，
  然后以明文建库 —— 不报错、测试全绿、密码明文落盘。
  真正的探针是 **`PRAGMA cipher_salt`**（无密钥上下文时返回空集），已实测确认。
  现在三道断言：`cipher_version` + `cipher_salt` + 落盘文件头非 `SQLite format 3\0`
- 🔴 `PRAGMA key = x'..'` 是语法错误，必须写成 `PRAGMA key = "x'..'"`（外层双引号）
- `drift` 自己导出了 `DatabaseOpener`，故改名 `VaultDatabaseOpener`；
  同因测试里要 `hide isNotNull`

**为什么值得单独记一笔**
加密失败是**唯一一种无声失效**：不报错、测试通过、用户不知情。
所以它从"实现细节"升级为 README 的第 4 条工程红线。

**影响文档**：03（§1.1 三条硬规则）、06（§1.3 已同步）、README（红线 4 / 目录结构 / 进度）、14（Day 5）

---

## v0.9 · 2026-11-08

### 数据库加密定案：SQLCipher（一行配置）+ 中文检索方案纠正

**改了什么**
- `pubspec.yaml` 加 `hooks.user_defines.sqlite3.source: sqlcipher`，改用 SQLCipher 预编译产物
- `sqlite3` 提升为直接依赖
- 新增 `test/sqlcipher_probe_test.dart`（6 条用例）：cipher_version / 错误密钥拒绝 / FTS5 / 中文检索 / trigram 对比 / WAL
- 06 §1.3 中文分词**整节重写**（原结论错误）
- 03 §1.1 新增「第 1 层已定案」+ 打开数据库的三条硬规则
- 02 §11.2 重写，A1 假设标记为已通过

**为什么**
- 原判断「`sqlcipher_flutter_libs` EOL ⇒ 必须自建构建」是错的。
  `sqlite3` 3.9 的 native-assets 钩子把 SQLCipher 做成内置选项，
  三端预编译产物齐备，成本从 5+ 人日降到 0.5 人日
- 应用层字段加密 + 明文索引（方案 B）有一个不可修补的洞：
  `entry_fts` / `entry_history` / `trash` / `activity` 都含明文，
  拿到 db 文件即可还原全部内容。字段级 AEAD 仍要做，但那是**同步层**的事

**实测数据**
- `PRAGMA cipher_version` = `4.20.0 community`
- 错误密钥 → `hmac check failed`，符合预期
- FTS5 + WAL 正常

**纠正的错误结论**
- 原文：「`unicode61` 对中文按字切分，召回率高但精度低」
- 实际：`unicode61` 把**连续汉字当成一个 token**，`MATCH '同步'` 对「增量同步」返回 0 条，
  是**完全搜不到**，不是精度低
- 新方案：应用层按字切分（`增 量 同 步`）+ **短语查询**（`MATCH '"同 步"'`）；
  `trigram` 因要求 ≥3 字符被否决（中文 2 字词占多数）

**影响文档**：02（§8 A1 / §11.2）、03（§1.1）、06（§1.3 重写）、09（A1 已完成 / 执行顺序）、14（Day 4）

---

## v0.8 · 2026-11-08

### 同步前置原语：UUIDv7 / HLC / Canonical JSON

**改了什么**
- `lib/core/identity/uuid_v7.dart`：单调 UUIDv7（同毫秒 12 位计数器，溢出借毫秒）
- `lib/core/sync/hlc.dart`：`Hlc` + `HlcClock`（tick / observe / restore）
- `lib/core/crypto/canonical.dart`：确定性 JSON + `contentHash`
- 新增 `test/core_primitives_test.dart` 22 条用例

**为什么先做这三个**
20 张表全都要用 `id` / `hlc` / `content_hash`。它们的错误不会在建表时暴露，
而是在同步合并阶段才爆发 —— 那时排查成本高一个数量级。先把它们测透再铺表。

**关键约束**
- HLC 编码必须**固定宽度**，否则字符串比较 ≠ 时间比较，所有"取最新"的查询都会错
- `HlcClock.restore()` **只能前进**：重启后从零开始会生成比历史更小的时钟值
- `Canonical` 必须让 `1` 与 `1.0` 等价，否则同一条内容在不同设备算出不同哈希

**影响文档**：14（Day 3）

---

## v0.7 · 2026-11-08

### 字体子系统（三角色排版 + 内置 3 套 + 用户导入）

**改了什么**
- 新增 `lib/core/fonts/` 九件套：`font_role` / `font_face` / `font_catalog` /
  `font_validation` / `font_runtime` / `font_state` / `font_store` / `font_service` / `font_providers`
- 新增 `SketchTypography`（`ThemeExtension`）：三个角色各一条 `FontStack`，
  生成 `TextTheme` 并提供 `monoStyle()`
- `SketchTheme` 由「静态双主题」改为 `build(palette, brightness, typography)`，
  字体不再写死
- 内置三套 SIL OFL 字体随包：霞鹜文楷 Lite 13.3 MB / Caveat 394 KB / JetBrains Mono 264 KB
- 四套预设：手写默认 / 阅读优先 / 系统原生 / 极客等宽；改单角色后与预设一致会自动归位
- 用户导入 TTF/OTF/TTC：文件头校验、sha256 内容寻址、40 MB 上限、
  家族名 `imp_<hash12>`（`FontLoader` 不可卸载，必须保证不重名）
- 新增设置页 `lib/features/settings/fonts_page.dart`；入口由 `AppActions`
  注入到 `PageScaffold` 右上角（避免 `core/widgets` 反向依赖 `features`）
- 新增 4 枚自制图标：`settings` / `type` / `upload` / `close`
- 测试 15 条全绿（字体校验 / 状态 / 排版解析 13 条 + 外壳渲染 2 条）

**为什么**
- 手绘风的产品身份几乎全由字体承担，Android 上没有可用的手写中文字体
- 用户有权换成自己买的字体，不能等发版
- 字体必须在 `runApp` 之前就绪，否则首帧会闪一下系统字体

**关键决策**
- **字体分三个角色**（正文 / 标题 / 等宽），不是一个全局字体 ——
  手绘风的核心是「两套声音」，元数据必须等宽才能对齐
- **中文只内置一套**：任何覆盖 GB2312 的中文字体都 10 MB 量级，多放一套包体不可接受
- **字体不参与同步**：体积大、许可复杂，且「桌面用等宽、手机用文楷」本身合理
- **持久化用 JSON 而非数据库**：必须在 DB 打开前可读
- **绝对路径不入库**：iOS 沙盒路径会变，只存文件名，启动时重新拼

**顺带修掉**
- 🟡 `flutter test` 在本环境失败的真正原因找到了：环境里有 `http_proxy=127.0.0.1:51096`，
  `flutter_tester` 的本地 WebSocket 被代理拦截（`Invalid WebSocket upgrade request`）。
  设 `NO_PROXY=127.0.0.1,localhost` 后测试正常 —— **不是沙箱限制，之前的判断是错的**
- `file_picker` 已到 13.3.2，API 与常见教程的 8.x 完全不同（无 `.platform`、无 `allowMultiple`）

**影响文档**：15（新增）、02（§1 表格 + §12）、10（§4 重写）、README（索引 / D13 / 目录结构）、14

---

## v0.6 · 2026-11-08

### 工程初始化 + M1 骨架落地

**改了什么**
- 创建 Flutter 工程（`package: vault` / `com.shiyi.vault` / android + ios + windows）
- 依赖实测解析：`flutter_riverpod 3.5.0`（Riverpod 3）、`go_router 18.1.3`、`drift 2.35.3`、`sqlite3 3.9.0`
- 落地主题层与组件库：`SketchPalette` / `SketchMetrics` / `SketchTheme` / `SketchFrame` / `SketchButton` / `SketchTag` / `PageScaffold`
- 自制图标 + 极简 SVG path 解析器（只支持 M/L/C/Z）
- 五分区外壳（桌面 rail / 移动底栏）+ 五个页面骨架
- `flutter analyze` 通过

**关键发现（已写入 02 §11）**
- 🔴 `sqlcipher_flutter_libs`（0.7.0+eol）与 `sqlite3_flutter_libs`（0.6.0+eol）**均已停止维护**，
  因为 `sqlite3` 3.9 改用 Dart Native Assets 自带原生库 → 两个包已移除
- 🔴 **SQLCipher 整库加密方案需重新选型**（原 A1 假设失效）：
  候选为「native assets 自编译 SQLCipher」/「应用层字段加密 + 明文索引」/「依赖系统盘加密」，
  建议先验 A 方案，B 作退路；期间 DB 打开逻辑收敛到单一 `DatabaseOpener`
- 🟡 本沙箱内 `flutter test` 无法建立本地 WebSocket（400），测试需在普通终端跑；`flutter analyze` 正常

**影响文档**：02（§11 新增）、14（新增）、README（目录结构）

---

## v0.5 · 2026-11-08

### 里程碑重排：纳入全部新增功能

**改了什么**
- 09 号文档从 M0~M8（190 人日）重排为 **M0~M9（247 人日）**
- 新增六个任务块：手绘主题组件库（M1）、分类与标签 + 日记月历（M2）、taxonomy 同步（M3）、归档总览（M4）、账号分组 + 自定义字段（M6）、会话与抽屉（M7）
- 新增 M9「发布前硬化」阶段（回归 / 性能 / 安全审计 / 三端联调）
- 同步回归用例从 20 条扩到 **26 条**（新增 T21~T26）
- 风险从 12 条扩到 17 条（新增 R13~R17：字体包体、虚线掉帧、会话膨胀、标签同名冲突、手绘风削弱安全感）
- 新增 §15「手绘风 vs 安全感」处理方案：密码模块用同色板但更克制的变体
- MVP 重新定义为 M0~M3 = 94 人日 ≈ 4.5 个月

**为什么**
- 原计划未包含功能补齐（40 人日）与会话/主题（16 人日），实际工作量被低估 30%

**影响文档**：09（重写）、README（索引数字）

---

## v0.4 · 2026-11-08

### 首页从「今天」改为「聊天」，引入对话抽屉

**改了什么**
- 首页标题「今天」→「聊天」，底部导航与桌面侧栏同步改名
- 新增左上三横杠 → 左侧抽屉（搜索 / 按日期分组 / 新建对话 / 当前会话高亮）
- 新增右上「＋ 开启新对话」，进入空白会话（草稿态，不落库）
- 主区新增「当前对话条」

**为什么**
- 引入抽屉后「今天」与抽屉首个分组标题重名，产生"今天 → 今天"的语义重复
- 页面本质已变为「会话列表 + 当前会话」，是聊天产品骨架
- 「今天」降级为抽屉内的分组标题，时间感保留

**影响文档**：12（新增）、10（页面清单）、README（决策表）

---

## v0.3 · 2026-11-08

### 视觉方向第 3 次改版：手绘草图风

**改了什么**
- 废弃前两版（暖色编辑风、冷灰蓝简洁风）
- 确定「手绘草图」：不规则圆角 + 虚线描边 + 零模糊硬阴影 + 整体倾斜 + 纸纹
- 色板改为：纸白 `#FDFBF7` / 墨 `#2D2D2D` / 马克笔红 `#FF4D4D` / 圆珠笔蓝 `#2D5DA1` / 便签黄 `#FFF9C4`
- 字体改为手写体栈（Segoe Print + 楷体），并确定跨端需打包 LXGW WenKai
- 全部图标改为自制 SVG（无图标库痕迹）
- 桌面侧栏与移动底栏统一为悬浮便签条，五项：聊天 / 记录 / 日记 / 归档 / 密码

**为什么**
- 前两版都是"通用 SaaS 长相"，与"个人档案馆"的题材无关
- 手绘风天然避开 2024–26 年 AI 产品的通用视觉（Inter + 渐变 + 玻璃）

**影响文档**：10（重写）、11（视觉约束）、README

---

## v0.2 · 2026-11-08

### 功能补齐

**新增**
- **日记页面**：月历总览 + 详情 + 补写；`meta.date` 与 `created_at` 分离；新增 `diary_index`
- **笔记分类与标签**：分类=两级树（最多 1 个），标签=扁平云（最多 8 个）；新增 `category` / `tag` 及关联表
- **归档网站页面**：状态筛选 + 站点聚合 + 存储配额；新增 `link_check`
- **账号分组 / 自定义字段 / 备注**：分组两级树 + 组内字段模板；`custom_fields` 支持 `secret` 标记

**关键决策**
- 分类与标签严格分工，不允许都做成多选（否则用户陷入整理瘫痪）
- 账号 `secret: true` 字段与密码同级加密，AI 永远读不到
- 分类/标签作为**独立同步实体**走 `taxonomy/` 通道，同名自动合并

**影响文档**：11（新增）、13（新增）、04（同步新增实体）

---

## v0.1 · 2026-11-08

### 初始方案

**确定**
- 三端（Android / iOS / Windows）+ 无后端 + WebDAV 同步 + 端侧 AI
- 统一 `entry` 数据模型，`kind` 区分笔记/想法/日记/书签/密码
- 同步引擎：三级探测（设备水位 → 分片 PROPFIND / sync-collection → 按需拉取）
- 冲突处理：六层保障，核心规则「删除永不覆盖未同步的编辑」
- 网页归档：三层模型（正文 / PDF 快照 / 原始 HTML）
- 检索：FTS5 + 向量 + RRF 融合
- AI：双模型路由，密码与日记强制走端侧（L0）

**关键数字**
- 20 个同步测试用例（M3 硬门槛）
- 190 人日 ≈ 单人全职 9~10 个月
- MVP（M0~M3 + 正文层归档）= 75 人日 ≈ 4 个月

**影响文档**：01~09
