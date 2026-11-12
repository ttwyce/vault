# CHANGELOG

记录结构性变更。日常文字修订不入表，只记「改了决策 / 加了模块 / 换了方向」。

---

## v1.59 · 2026-11-12

### M4：死链重检查按 recheck_policy 定间隔（已验证）

- `decideLinkCheck` 新增 `policy` 参数：weekly 7 天 / monthly 30 天 /
  never 永不自动重检查；`LinkCheckService.run` 透传该策略，
  默认 monthly 保持原有编排不变
- 修掉过去「所有条目固定 30 天」与 `ArchiveMeta.recheck_policy`
  口径不一致的问题；理由文案写明实际天数 / never
- 测试：`link_check_service_test.dart` +1 条（10 天 weekly 到期、
  monthly 未到期；31 天 monthly 到期；never 365 天仍跳过）
  → 全量 **908 → 909**

**边界**：真实 HEAD 请求 / 批量任务读 meta 传 policy 仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**909/909 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 154）、20（当前状态）、
CHANGELOG（本条）

---

## v1.58 · 2026-11-12

### M2：编辑器分类/标签建议接线（已验证）

- `EditorPage` 按 `suggestTaxonomy` 在分类行下方展示
  「建议（点采纳，不自动写入）」chip；输入标题/正文时随 `setState`
  刷新建议，采纳才合并到分类/标签选择（标签上限 8 生效）
- 原有 `taxonomy_suggestions.dart` 判定层接上真实编辑器 UI，
  编辑器 9 条回归全绿
- 测试：`editor_page_test.dart` +1 条（建议可见、采纳后标签出现）
  → 全量 **907 → 908**

**边界**：真实 AI 建议 / 右侧面板 / 保存后触发仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**908/908 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§2）、14（Day 153）、20（当前状态）、
CHANGELOG（本条）

---

## v1.57 · 2026-11-12

### 决策表收口：D93~D110（已验证）

- README 决策表从 D92 补到 **D110**，把 v1.40~v1.56 的架构决策
  逐条固化（Autofill 零明文、后台自动锁定、改密码二次确认、
  E_RATE 半速、8s debounce、日总结强校验、add_tags、AI 数据清理、
  分块聚合、向量同步开关、schema 双向、AI 日记排期、U1/U7、
  剪贴板提示、A2 余弦退路、Agent 降级、M3 硬门槛持续生效）
- 同步核对：当前全量 **907/907**；M3 硬门槛仍锁住 App 启动；
  `pubspec.yaml` / `pubspec.lock` 未改动

**边界**：剩余项全部需要真实 WebDAV / 真机 / 新依赖 / 平台 channel；
不宣称 M4~M9 完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**907/907 passed**；未执行构建。

**影响文档**：README（决策表）、14（Day 152）、20（当前状态）、
CHANGELOG（本条）

---

## v1.56 · 2026-11-12

### M7：Agent 超时 / 失败降级提示（C6，已验证）

- 新增 `agent_fallback_hint.dart`（docs/07 §11 C6）：超时 / 网络 /
  模型异常 / 预算耗尽四类失败 + 6 轮上限 / 拒绝 / 待确认三态，
  统一给出「检索仍可用、AI 回答不可用」的诚实文案；
  预算耗尽不可重试，正常完成不谎称降级
- `DiagnosticsPage` 展示规则
- 测试：`agent_fallback_hint_test.dart` 3 条 → 全量 **904 → 907**

**边界**：真实 `runAgentLoop` 失败原因注入 / UI 横幅仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**907/907 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 151）、20（当前状态）、
CHANGELOG（本条）

---

## v1.55 · 2026-11-12

### M5：A2 退路之 Dart 内暴力余弦 KNN（已验证）

- 新增 `vector_knn.dart`（docs/02 §8 A2）：sqlite_vector 不可用时的
  int8 量化向量暴力余弦检索；维度不匹配 / 零向量跳过、topK 降序、
  同分按 entryId 稳定、minScore 过滤，不引入任何新依赖
- `DiagnosticsPage` 展示退路规则
- 测试：`vector_knn_test.dart` 4 条 → 全量 **900 → 904**

**边界**：真实 `entry_vec` 读取 / 量化推理 / 5 万条计时仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**904/904 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§7）、14（Day 150）、20（当前状态）、
CHANGELOG（本条）

---

## v1.54 · 2026-11-12

### UI：底部导航 375px 适配判定（U7，已验证）

- 新增 `bottom_nav_fit.dart`（docs/10 §12 U7）：按可用宽度 / 5 个 Tab
  算每项宽度，375px 时每项 75px 不缩写不横向滚动；更窄时单字缩写、
  `maxLines: 1` + 省略号，并给建议字号
- `AppShell` 底部导航接判定层；`widget_test.dart` 移动/桌面 2 条回归全绿
- 测试：`bottom_nav_fit_test.dart` 3 条 → 全量 **897 → 900**

**边界**：真机 375px 横向滚动仍需人工验收；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**900/900 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§2）、14（Day 149）、20（当前状态）、
CHANGELOG（本条）

---

## v1.53 · 2026-11-12

### M4：剪贴板 URL 自动识别提示（已验证）

- 新增 `clipboard_archive_hint.dart`（docs/05 §3）：前台且用户授权时
  单个 URL 才弹「是否归档」、多个走批量入口、非 URL 不提示；
  后台 / 未授权 / 空内容 / 与上次已提示文本相同一律不打扰，
  且提示只接收不自动抓取
- `DiagnosticsPage` 展示规则
- 测试：`clipboard_archive_hint_test.dart` 3 条 → 全量 **894 → 897**

**边界**：真实系统剪贴板监听 / 托盘气泡 / 快捷磁贴仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**897/897 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 148）、20（当前状态）、
CHANGELOG（本条）

---

## v1.52 · 2026-11-12

### M2/UI：相邻卡片圆角配方轮换（U1，已验证）

- 新增 `sketch_card_variant.dart`（docs/10 §2 ① / §12 U1）：
  4 套配方按索引轮换、与上一张相同时顺延，保证任意相邻卡片不重复
- `ArchivePage` 列表从 `url.hashCode % 4` 改为整套轮换
  （倾斜方向也跟 variant 走），归档页 9 条回归全绿
- 测试：`sketch_card_variant_test.dart` 3 条 → 全量 **891 → 894**

**边界**：其余页面仍用各自 variant 策略，后续逐个替换；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**894/894 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§2）、14（Day 147）、20（当前状态）、
CHANGELOG（本条）

---

## v1.51 · 2026-11-12

### M7：AI 日记 23:50 排期判定（已验证）

- 新增 `ai_diary_schedule.dart`（docs/11 §1.4 / docs/07 §5.2）：
  23:50 定时窗口、当天已生成不重复、Windows 托盘 / Android / iOS
  三端文案明确前台补偿不承诺后台自动、支持次日补算前一天
- `DiagnosticsPage` 展示规则
- 测试：`ai_diary_schedule_test.dart` 3 条 → 全量 **888 → 891**

**边界**：真实定时器 / 托盘常驻 / kind=4 落库仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**891/891 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 146）、20（当前状态）、
CHANGELOG（本条）

---

## v1.50 · 2026-11-12

### M3 预备：meta.schema 双向判定（已验证）

- 新增 `schema_upgrade_policy.dart`（docs/03 §9）：云端 schema
  高于本地直接拒绝并提示升级；一致正常同步；云端更低时只有
  **所有已知设备都已升级**才允许同步后写回新 schema，
  缺版本信息视为未升级（保守不写回，避免把旧设备锁在门外）
- `DiagnosticsPage` 展示规则
- 测试：`schema_upgrade_policy_test.dart` 3 条 → 全量 **885 → 888**

**边界**：真实 `meta.enc` 写回 / 设备版本上报仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**888/888 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§3）、14（Day 145）、20（当前状态）、
CHANGELOG（本条）

---

## v1.49 · 2026-11-12

### M5：向量同步开关判定层（已验证）

- 新增 `vector_sync_settings.dart`（docs/06 §7）：默认关闭、JSON 往返与
  坏值回默认；关闭需二次确认且**不删云端封包 / 不清本地 entry_vec**，
  明确「换设备需全量重算」；开启强调 model_id / dim 校验与加密上传
- `DiagnosticsPage` 展示规则
- 测试：`vector_sync_settings_test.dart` 3 条 → 全量 **882 → 885**

**边界**：真实设置页开关 / `/vault/vec/` 上传下载仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**885/885 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§7）、14（Day 144）、20（当前状态）、
CHANGELOG（本条）

---

## v1.48 · 2026-11-12

### M5：分块命中聚合到 entry 粒度（已验证）

- `aggregateChunkHits()`（docs/06 §2.1）：同一 entry 的多个 chunk
  只保留最佳名次，fts / vector 两路在 RRF 前先聚合；
  避免长文因分块多被重复累加、把短笔记挤出 top3
- 原有 `reciprocalRankFusion` 全部用例回归通过
- 测试：`hybrid_search_test.dart` +1 条 → 全量 **881 → 882**

**边界**：真实 `entry_vec_chunk` 表 / 向量召回仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**882/882 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§7）、14（Day 143）、20（当前状态）、
CHANGELOG（本条）

---

## v1.47 · 2026-11-12

### M7：清除所有 AI 数据计划（已验证）

- 新增 `ai_data_clearance.dart`（docs/07 §7.3）：列出 5 个数据域
  （对话 / AI 日记 / 检索缓存 / 搜索词 / API Key）与有序执行步骤；
  必须逐次二次确认，未确认只给清单；
  `keepUserNotes=false` 一律拒绝，用户手写笔记和日记永不删除
- `DiagnosticsPage` 展示规则
- 测试：`ai_data_clearance_test.dart` 3 条 → 全量 **878 → 881**

**边界**：真实删除 / `flutter_secure_storage` Key 清除 / 偏好重置
仍属平台层；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**881/881 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 142）、20（当前状态）、
CHANGELOG（本条）

---

## v1.46 · 2026-11-12

### M7：补齐 `add_tags` 工具（已验证）

- `AgentToolRegistry` 从 17 增至 18 个工具：新增 `add_tags`
  （docs/07 §3.1，confirm / L1），批量给条目追加标签；
  标签名先解析成 id（同名复用、缺失才新建），保留原分类、
  自动去重、单条上限 8 由 `WriteGateway` 把关，单条失败不影响其它条目
- 未确认时只给内容预览不落库；`agent_loop_test` / `agent_policy_test`
  15 条回归全绿
- 测试：`agent_tools_test.dart` 更新注册表断言 + 1 条专用用例；
  `diagnostics_page_test.dart` 去掉写死的「17 个工具」断言
  → 全量 **877 → 878**

**边界**：`web_search` / `fetch_page`（dangerous + BYOK 外部 API）
仍不实现；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**878/878 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 141）、20（当前状态）、
CHANGELOG（本条）

---

## v1.45 · 2026-11-12

### M7：日总结模型输出解析（已验证）

- `parseDailySummary()`（docs/07 §5.2）：解析端侧模型输出的
  headline/timeline/open_threads/citations/date/granularity；
  坏 JSON / 缺 headline / 坏日期 / 非法层级一律拒绝，
  时间线归一化、假引用剔除与去重复用既有判定；默认 day
- `DiagnosticsPage` 展示规则
- 测试：`daily_summary_parse_test.dart` 3 条 → 全量 **874 → 877**

**边界**：真实模型调用 / kind=4 落库仍属平台层；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**877/877 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 140）、20（当前状态）、
CHANGELOG（本条）

---

## v1.44 · 2026-11-12

### M3 预备：写入后 8 秒 debounce 同步触发（已验证）

- 新增 `sync_kick_policy.dart`（docs/04 §12）：多次写入合并窗口、
  最后一次写入静默满 8s 才 kick；未解锁 / 后台 / 已有同步进行中
  推迟到前台补偿；时间戳倒退保守不触发；给出剩余等待
- `DiagnosticsPage` 展示规则
- 测试：`sync_kick_policy_test.dart` 3 条 → 全量 **871 → 874**

**边界**：真实 `SyncScheduler.kick()` / 定时器 / 写入口联动
仍待平台接线且需 A5；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**874/874 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§3）、14（Day 139）、20（当前状态）、
CHANGELOG（本条）

---

## v1.43 · 2026-11-12

### M3 预备：限流后请求预算减半（已验证）

- 新增 `rate_limit_budget.dart`（docs/04 §7 E_RATE / §10）：
  E_RATE 每轮减半且下限 1、E_NET/E_CONFLICT/无错误保持、
  超基线回落 200、致命错误预算归零不再发请求；
  连续成功 2 轮恢复基线，避免永久半速
- `DiagnosticsPage` 展示规则
- 测试：`rate_limit_budget_test.dart` 4 条 → 全量 **867 → 871**

**边界**：协调器 / `RequestBudget` 注入下一轮预算仍待平台接线；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**871/871 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§3）、14（Day 138）、20（当前状态）、
CHANGELOG（本条）

---

## v1.42 · 2026-11-12

### M8：改主密码 / 重置恢复码判定层（已验证）

- 新增 `passphrase_change_policy.dart`（docs/18 §9 / docs/16 §5）：
  当前密码非空、新密码 ≥8 字且非弱模式、两次一致、不与旧相同；
  允许时提示「重新包裹同一把 DEK，条目密文不变」并需二次确认；
  重置恢复码必须二次确认、旧码立即失效
- `DiagnosticsPage` 展示规则
- 测试：`passphrase_change_policy_test.dart` 3 条 → 全量 **864 → 867**

**边界**：真实 `VaultLock.changePassphrase` / `regenerateRecoveryCode`
设置页入口与 `meta.enc` 写回仍缺；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**867/867 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§10）、14（Day 137）、20（当前状态）、
CHANGELOG（本条）

---

## v1.41 · 2026-11-12

### M8：后台自动锁定（已验证）

- 新增 `auto_lock_policy.dart`（docs/18 §9）：按进入后台 / 回到前台
  时间戳判定，默认 5 分钟、未达阈值给剩余宽限、时间戳倒退保守不锁、
  阈值可配置
- 新增 `AutoLockWatcher` 并接在 `VaultGate` 外层：paused/hidden 记时刻，
  resumed 达阈值才调 `VaultSession.lock()`，不改闸门状态机；
  注入时钟与锁定动作便于测试
- 测试：`auto_lock_policy_test.dart` 3 条、`auto_lock_watcher_test.dart` 1 条；
  `about_page_test.dart` / `vault_gate_test.dart` 15 条回归全绿
  → 全量 **860 → 864**

**边界**：真实后台计时与系统生命周期在三端的行为需真机验证；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**864/864 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§10）、14（Day 136）、20（当前状态）、
CHANGELOG（本条）

---

## v1.40 · 2026-11-12

### M6/M8：Autofill 字段识别与条目匹配判定层（已验证）

- 新增 `autofill_policy.dart`（docs/08 §3.1 / §3.2）：按 hint/id/inputType
  识别 username / password / otp / unknown；域名规整与 Android 包名匹配；
  候选 JSON 明确只含域名/用户名/标题，**绝不带密码或 TOTP 明文**
- `DiagnosticsPage` 展示规则
- 测试：`autofill_policy_test.dart` 4 条 → 全量 **856 → 860**

**边界**：真实 Android AutofillService / iOS Credential Provider Extension /
共享 Keychain 一次性 token 仍属平台层；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**860/860 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8 / §10）、14（Day 135）、20（当前状态）、
CHANGELOG（本条）

---

## v1.39 · 2026-11-12

### 决策表收口：D79~D92（已验证）

- README 决策表从 D78 补到 **D92**，把 v1.16~v1.38 的架构决策逐条固化
  （模型页诚实状态、前台补偿队列、版本对比降级、同步设置 A5 闸门、
  U3/U8、显式日记日期、行内标签上限、命中来源、AI 隐私闸门、
  相关推荐不凑数、检索缓存、归档去重、抓取流水线逐层降级）
- 同步核对：当前全量 **856/856**；M3 硬门槛仍锁住 App 启动；
  `pubspec.yaml` / `pubspec.lock` 未改动

**边界**：剩余项全部需要真实 WebDAV / 真机 / 新依赖 / 平台 channel；
不宣称 M4~M9 完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**856/856 passed**；未执行构建。

**影响文档**：README（决策表）、14（Day 134）、20（当前状态）、
CHANGELOG（本条）

---

## v1.38 · 2026-11-12

### M4：按需下载与本地 blob 缓存策略（已验证）

- 新增 `archive_cache_policy.dart`（docs/05 §7）：默认 500MB 上限、
  L1 正文自动下载带骨架屏 / L2 PDF 必须点「查看原貌」/ 已本地不请求；
  超上限复用 `planBlobCacheEviction` 按 LRU 清理，动作明确
  **只置 local=0，不删云端**
- `DiagnosticsPage` 展示规则
- 测试：`archive_cache_policy_test.dart` 3 条 → 全量 **853 → 856**

**边界**：真实 blob 下载 / 进度条 / `local` 落库仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**856/856 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 133）、20（当前状态）、
CHANGELOG（本条）

---

## v1.37 · 2026-11-12

### M4：PDF 分页与三级降级（已验证）

- 新增 `pdf_pagination.dart`（docs/05 §8）：A4 595×842pt 按内容高度
  向上取整页数、每页 canvas 平移量、0/负高度返回 0 页、超 200 页截断；
  「平台原生 → 简易 Markdown PDF → 只保留 L1+L3 标记 text」三级降级
- `DiagnosticsPage` 展示规则
- 测试：`pdf_pagination_test.dart` 3 条 → 全量 **850 → 853**

**边界**：真实平台 PDF 渲染 / `pdf`+`printing` 包接线仍属平台层且需新依赖；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**853/853 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 132）、20（当前状态）、
CHANGELOG（本条）

---

## v1.36 · 2026-11-12

### M4：内容变更检测成本控制（已验证）

- 新增 `content_change_policy.dart`（docs/05 §6.2）：只对「用户手动标记」
  或「30 天内访问过」的条目排每月重抓；首次快照不提示变更、
  复用 `hasContentChanged` 汉明距离 > 3 才提示且保留旧正文为 history、
  坏指纹不当变更、阈值可调
- `DiagnosticsPage` 展示规则
- 测试：`content_change_policy_test.dart` 4 条 → 全量 **846 → 850**

**边界**：真实 simhash 计算 / 抓取 / history 落库仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**850/850 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 131）、20（当前状态）、
CHANGELOG（本条）

---

## v1.35 · 2026-11-12

### M4：Wayback availability 判定层（已验证）

- 新增 `wayback_client.dart`（docs/05 §6.1 / §6.3）：availability API
  地址构造、closest 快照解析、时间戳转日期、缺 url 时用时间戳兜底构造
  存档链接；无快照 / 坏 JSON / 缺字段一律明确「建议手动提交」，
  绝不把解析失败当成有存档；自动提交存档默认关闭、必须逐次勾选
- `DiagnosticsPage` 展示规则
- 测试：`wayback_client_test.dart` 5 条 → 全量 **841 → 846**

**边界**：真实 GET 请求 / 打开外链 / Save Page Now 仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**846/846 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 130）、20（当前状态）、
CHANGELOG（本条）

---

## v1.34 · 2026-11-12

### M4：归档全局配置与配额守卫（已验证）

- 新增 `archive_settings.dart`（docs/05 §5.2 / §5.3 / §5.4）：
  L1 正文常开不可关、完整快照 4 种排期、30 天/1 年/永久保留、
  全部设备/按需下载、默认 80% 配额、JSON 往返与坏值回默认；
  三端文案明确前台补偿，不承诺后台自动
- `planQuotaGuard`：降级最老快照后仍超配额则只存 L1 并提示用户
- `DiagnosticsPage` 展示规则
- 测试：`archive_settings_test.dart` 4 条 → 全量 **837 → 841**

**边界**：配置持久化 / 真实定时器 / 云端剩余空间读取仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**841/841 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 129）、20（当前状态）、
CHANGELOG（本条）

---

## v1.33 · 2026-11-12

### M4：归档正文图片过滤（已验证）

- 新增 `archive_image_filter.dart`（docs/05 §4.1）：按 `<img>` 的
  width/height 判宽或高 ≥200 保留、双维都小丢弃、未声明尺寸保守保留、
  下载失败保留原 URL 并标注；支持从一段 HTML 批量抽取
- `DiagnosticsPage` 展示规则
- 测试：`archive_image_filter_test.dart` 3 条 → 全量 **834 → 837**

**边界**：真实图片下载 / 本地引用改写 / 懒加载滚动仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**837/837 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 128）、20（当前状态）、
CHANGELOG（本条）

---

## v1.32 · 2026-11-12

### M4：归档内容闸门（反爬 / 付费墙，已验证）

- 新增 `archive_content_gate.dart`（docs/05 §4.1）：从标题/正文/HTML 类名
  与特征词判定 blocked（反爬/JS 验证）、paywalled（付费墙）、ok；
  正文不足 120 字按加载失败处理，一律「只存元数据」有可测依据
- `DiagnosticsPage` 展示规则
- 测试：`archive_content_gate_test.dart` 3 条 → 全量 **831 → 834**

**边界**：真实 WebView 加载 / readability 注入 / HTML 全文解析仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**834/834 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 127）、20（当前状态）、
CHANGELOG（本条）

---

## v1.31 · 2026-11-12

### M4：归档 URL 去重（已验证）

- 新增 `archive_duplicate.dart`（docs/05 §4 第 1 步）：URL 规范化
  （host 小写、去跟踪参数/fragment/尾斜杠/默认端口）、与已有
  url/finalUrl 比对，输出「新建 / 已归档问是否更新快照 / 非法」
- `ArchivePage` 新增前先去重：重复弹「已归档过」并可选择打开已有条目，
  **不静默插入第二条**；真实重抓/更新快照未接入前不假装能更新
- 测试：`archive_duplicate_test.dart` 3 条、`archive_page_test.dart` +1 条
  → 全量 **827 → 831**

**边界**：真实 HEAD/GET 去重、快照历史版本落库仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**831/831 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 126）、20（当前状态）、
CHANGELOG（本条）

---

## v1.30 · 2026-11-12

### M5/M7：检索结果 5 分钟缓存（已验证）

- 新增 `search_result_cache.dart`（docs/07 §7.2）：查询词归一化做 key、
  storedAt 独立判 TTL、FIFO 容量淘汰；修正「5 分钟分桶」与「5 分钟 TTL」
  窗口错位导致的边界提前失效
- `SearchPage` 接缓存：相同 query 5 分钟内复用结果且不重复 FTS / 搜索埋点，
  避免打字机式刷屏
- 测试：`search_result_cache_test.dart` 3 条、`search_page_test.dart` +1 条
  → 全量 **823 → 827**

**边界**：缓存不持久化，进程重启后失效；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**827/827 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§7）、14（Day 125）、20（当前状态）、
CHANGELOG（本条）

---

## v1.29 · 2026-11-12

### M7：当前对话条模型状态对齐（已验证）

- `ChatPage` 的「当前对话」条改为显示 `resolveModelStatus` 产出的
  真实 subtitle，不再写死「端侧模型」；与顶部状态、空状态引导口径一致
  （docs/07 §10.1 / C5）
- 测试：`model_status_test.dart` +1 条（未就绪可见、旧写死标签消失）
  → 全量 **822 → 823**

**边界**：真实模型名 / 云端厂商名注入仍待平台层；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**823/823 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 124）、20（当前状态）、
CHANGELOG（本条）

---

## v1.28 · 2026-11-12

### M7：条目详情相关推荐判定层（已验证）

- 新增 `related_entries.dart`（docs/07 §10.2）：标签 Jaccard
  + 标题中文 bigram Dice 打分，输出 top3；分数为 0 不凑数、
  排除自身、密码（kind=6）与 AI 日记（kind=4）永不推荐
- `DiagnosticsPage` 展示规则
- 测试：`related_entries_test.dart` 3 条 → 全量 **819 → 822**

**边界**：真实候选读取 / 详情页推荐卡片 / 语义向量召回仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**822/822 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 123）、20（当前状态）、
CHANGELOG（本条）

---

## v1.27 · 2026-11-12

### M7：搜索空结果「问 AI」入口接线（已验证）

- `SearchPage` 空结果区按 `modelAvailabilityProvider` 与
  `planAiEntry(searchUpgrade)` 判定：模型未就绪显示「去模型管理页」引导，
  就绪才出现「问 AI（逐次授权）」并弹含发送字数的隐私提示（C4）；
  默认状态不谎称可问答
- 测试：`search_page_test.dart` +1 条 → 全量 **818 → 819**

**边界**：真实问答 transport / 授权后发送仍缺；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**819/819 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 122）、20（当前状态）、
CHANGELOG（本条）

---

## v1.26 · 2026-11-12

### M7：AI 入口与隐私提示判定层（C4，已验证）

- 新增 `ai_entry_points.dart`（docs/07 §10.2 / C4）：助手 Tab /
  搜索升级 / 阅读器划词 / 相关推荐四入口的可见性与隐私级别；
  L0 数据（密码/日记/备注）永远禁止进入 prompt、模型未就绪与缺上下文
  给明确引导、云端入口必弹逐次授权并显示发送字数
- `DiagnosticsPage` 展示规则
- 测试：`ai_entry_points_test.dart` 3 条 → 全量 **815 → 818**

**边界**：真实「问 AI」入口 UI / 云端 transport / 授权弹窗接线
仍属平台层；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**818/818 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 121）、20（当前状态）、
CHANGELOG（本条）

---

## v1.25 · 2026-11-12

### M6：密码手动复制通道（已验证）

- `CredentialRepository.passwordForClipboard()` 解密密码仅供内存局部变量，
  UI 不展示、日志不记录；`VaultPage` 新增「复制密码（30 秒后清除）」
  按钮，走 `SensitiveClipboard` 自动清除通道
- 测试：`vault_page_test.dart` +1 条（按钮可见、明文零展示、
  复制后仍不展示明文、repo 返回真实值）→ 全量 **814 → 815**

**边界**：系统剪贴板真实 30 秒清除需真机验证；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**815/815 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 120）、20（当前状态）、
CHANGELOG（本条）

---

## v1.24 · 2026-11-12

### M6：密码备注 Markdown 预览（已验证）

- `VaultPage` 详情弹窗备注区加「预览备注 / 返回编辑」切换，
  复用 `MarkdownPreview` 渲染加粗/列表；预览用固定高度避免
  bottomSheet 无限高导致的嵌套滚动异常；备注仍以 K_item 密文落库
- 测试：`vault_page_test.dart` +1 条（切换可见、返回编辑后可保存）
  → 全量 **813 → 814**

**边界**：备注图片 / 富文本工具栏仍缺；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**814/814 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 119）、20（当前状态）、
CHANGELOG（本条）

---

## v1.23 · 2026-11-12

### M5：命中来源如实标注（已验证）

- `hitSourceLabel()`（docs/06 §8.1）：按关键词/语义命中与向量是否启用
  产出「关键词 / 语义 / 两者 / 语义未启用」四种标签，不再写死假状态
- `SearchPage` 结果卡片改用真实标注；真实向量召回未接入前明确
  显示「命中：关键词（语义未启用）」
- 测试：`hybrid_search_test.dart` +1 条、`search_page_test.dart` 断言适配
  → 全量 **812 → 813**

**边界**：真实向量召回 / RRF 接入 UI 仍缺；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**813/813 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§7）、14（Day 118）、20（当前状态）、
CHANGELOG（本条）

---

## v1.22 · 2026-11-12

### M2：编辑器 `#` 行内标签触发（已验证）

- 新增 `inline_tag_parser.dart`（docs/11 §2.5）：光标前 `#xxx` 触发器
  （要求行首/空白后、≤20 字、遇空白失效）、正文标签抽取去重、
  采纳计划去重且上限 8 并明确标记超出
- `EditorPage` 正文 `onChanged` 显示行内标签提示（含上限文案），
  输入普通正文后提示消失
- 测试：`inline_tag_parser_test.dart` 3 条、`editor_page_test.dart` +1 条
  → 全量 **808 → 812**

**边界**：真实标签建议列表 / 回车自动采纳 / 新建标签仍走已有标签行 UI；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**812/812 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§2）、14（Day 117）、20（当前状态）、
CHANGELOG（本条）

---

## v1.21 · 2026-11-12

### M2：日记 meta 模型与编辑器接线（已验证）

- 新增 `diary_meta.dart`（docs/11 §1.3）：date/weather/mood/location/
  word_count/backfilled 的 JSON 往返与严格校验（日期格式、
  mood 枚举、坏 JSON 拒绝）；中文按字/英文按词统计、忽略 Markdown 标记；
  归属日期早于创建当天即补写
- `EditorPage` 新建日记改为写完整 meta，编辑时保留天气/心情/日期
  只刷新字数与补写标记；坏 meta 不猜测不覆盖
- `DiaryPage` 的「补写」按钮把月历选中日作为 `initialDate` 传给编辑器，
  `meta.date` 显式归属该日，`backfilled` 自动为真（docs/11 §1.2）
- 测试：`diary_meta_test.dart` 4 条、`editor_page_test.dart` +2 条
  → 全量 **802 → 808**

**边界**：天气/心情选择 UI、location 录入仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**808/808 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§2）、14（Day 116）、20（当前状态）、
CHANGELOG（本条）

---

## v1.20 · 2026-11-12

### M4：阅读器高亮标注写回 meta（已验证）

- 新增 `archive_highlight_writer.dart`（docs/05 §9）：读旧快照 →
  `mergeHighlights` 合并去重 → 整体替换 `entry(kind=5).meta`
  → 走唯一 `WriteGateway.writeEntry` 生成新版本与 oplog；
  非归档 / 坏 meta / 不存在条目一律拒绝，不绕过信封加密与 FTS
- `ArchiveReaderPage` 新增「标注高亮」按钮（有 entryId 才启用），
  划词选区可写回真实 meta；`ArchivePage` 跳转传 entryId
- 测试：`archive_highlight_writer_test.dart` 3 条、
  `archive_reader_page_test.dart` +1 条 → 全量 **798 → 802**

**边界**：真实文本选区 offset / 高亮渲染 / 与云端 meta 合并仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**802/802 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 115）、20（当前状态）、
CHANGELOG（本条）

---

## v1.19 · 2026-11-12

### M3 预备：同步设置页（第 12 屏，已验证）

- 新增 `sync_settings_plan.dart`：WebDAV URL 规整（强制 https、
  本机 http 例外、拒绝内嵌凭据/查询串）、表单三道关卡
  （非法 / A5 未确认 / 可探测）、能力探测文案按 DAV token 分支
- 新增 `SyncSettingsPage`（docs/10 第 12 屏）：只做表单校验与状态说明，
  **不持久化账号密码、不发起请求、不实例化 `VaultSyncRuntime`**；
  A5 未确认时永远停在 `needsA5`
- `SettingsHubPage` 新增「同步设置」入口
- 测试：`sync_settings_plan_test.dart` 3 条、
  `sync_settings_page_test.dart` 3 条 → 全量 **792 → 798**

**边界**：真实 `flutter_secure_storage` / OPTIONS 能力探测 /
启动同步仍缺，且必须等 M0 A5；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**798/798 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§3）、14（Day 114）、20（当前状态）、
CHANGELOG（本条）

---

## v1.18 · 2026-11-12

### M8 预备：待处理任务页（第 20 屏，已验证）

- 新增 `job_queue_repository.dart`：读真实 `job_queue` 表，
  状态编码/中文标签、失败重试上限 3 次、指数退避 1/2/4 分钟、
  前台补偿到期筛选、按类型聚合
- 新增 `PendingJobsPage`（docs/10 第 20 屏）：展示状态、类型、
  尝试次数、到期时间；明确「未接后台执行器」，空队列给空状态
- `SettingsHubPage` 新增「待处理任务」入口
- 测试：`job_queue_repository_test.dart` 3 条、
  `pending_jobs_page_test.dart` 3 条 → 全量 **786 → 792**

**边界**：真实后台任务 / 前台补偿执行器 / running 超时回收
仍属平台层；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**792/792 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§10）、14（Day 113）、20（当前状态）、
CHANGELOG（本条）

---

## v1.17 · 2026-11-12

### M2：版本对比页（第 23 屏，已验证）

- 新增 `version_diff.dart`（docs/10 第 23 屏）：把 `line_diff` 的 hunks
  翻译成可读的 +/- / 上下文展示行（带旧/新行号），超 1200 行降级为
  统计视图不跑 O(n·m) DP
- `HistoryPage` 每个历史版本新增「对比当前」按钮，弹窗展示与当前正文的
  行级差异；复用真实 `entry.body`，不造假数据
- 测试：`version_diff_test.dart` 4 条、`trash_history_test.dart` +1 条
  → 全量 **781 → 786**

**边界**：只对比正文文本，不含标题/标签/附件差异；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**786/786 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§2）、14（Day 112）、20（当前状态）、
CHANGELOG（本条）

---

## v1.16 · 2026-11-12

### M5：模型管理页（第 18 屏，已验证）

- 新增 `ModelsPage`（docs/10 第 18 屏 / docs/06 §7）：展示默认模型清单
  （维度/量化/磁盘需求）、5 个下载源优先级、检索降级四态说明、
  备份排除要求；默认状态诚实标注「未接真实下载」，不显示假进度
- `SettingsHubPage` 新增「模型管理」入口
- 测试：`models_page_test.dart` 2 条（页面内容 + 设置入口可进入）
  → 全量 **779 → 781**

**边界**：真实下载 / 校验 / 端侧推理 / 向量同步开关仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**781/781 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§7）、14（Day 111）、20（当前状态）、
CHANGELOG（本条）

---

## v1.15 · 2026-11-12

### 决策表收口：D65~D78（已验证）

- README 决策表从 D64 补到 **D78**，把 v0.94~v1.14 各批次的架构决策
  逐条固化（分组模板、AI 输出关卡、无模型引导、会话分页、同步状态映射、
  分片游标、首次绑定三选一、剪藏只接收不抓取、解锁锁定、U3 对比度、
  连续天数、建议不自动写入、U8 减少动效、M3 硬门槛仍锁住启动）
- 全库复查：22 张表覆盖 docs/13 的 20 张；零生产引用只剩
  `main.dart` 与刻意未接线的 `VaultSyncRuntime`；pubspec 从未改动；
  M3 硬门槛声明仍为「26 个同步用例不全通过，不要进 M4」

**边界**：剩余项全部需要真实 WebDAV / 真机 / 新依赖 / 数据库结构变更 /
平台 channel；不宣称 M4~M9 完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**779/779 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（决策表）、14（Day 110）、20（当前状态）、
CHANGELOG（本条）

---

## v1.14 · 2026-11-12

### M2：减少动效支持补齐（U8，已验证）

- `SketchButton` 按下 / `SketchIconButton` hover / `AppShell` 两处
  AnimatedContainer 的 duration 改走 `SketchMotion.of(context, ...)`，
  系统开启「减少动效」时所有过渡瞬时完成；`_settingsRoute` 原本已尊重
- 测试：`reduced_motion_test.dart` 2 条（Duration.zero、按钮仍可点击且
  transform 不产生布局位移）→ 全量 **777 → 779**

**边界**：抽屉滑入 / 桌面三栏动效仍需真机验证；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**779/779 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§2）、14（Day 109）、20（当前状态）、
CHANGELOG（本条）

---

## v1.13 · 2026-11-12

### M2：分类 / 标签建议判定层（已验证）

- 新增 `taxonomy_suggestions.dart`（docs/11 §2.5）：标题+正文关键词抽取
  （英文词 / 中文 2~4 字滑窗 / 停用词与纯数字过滤），匹配已有分类/标签
  给出 1 个分类 + 2~4 个标签建议；去重已有标签、上限 8、
  **不自动写入**、无匹配时返回空而不编造
- `DiagnosticsPage` 展示规则
- 测试：`taxonomy_suggestions_test.dart` 3 条 → 全量 **774 → 777**

**边界**：真实 AI 建议面板 / 一键采纳 UI 仍缺；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**777/777 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§2）、14（Day 108）、20（当前状态）、
CHANGELOG（本条）

---

## v1.12 · 2026-11-12

### M2：日记连续天数与月历三态（已验证）

- 新增 `diary_streak.dart`（docs/11 §1.4）：今天有日记从今天往回数、
  今天没写但昨天有从昨天算、昨天也没写断签变灰；中间断一天即截断；
  月历三态（用户日记 > 仅 AI 日记 > 空）
- `DiaryPage` 底部显示「连续 N 天」，读当月及前两月真实日记数据；
  断签用次要色，不弹提醒（不做打卡压迫感）
- 测试：`diary_streak_test.dart` 4 条、`diary_page_test.dart` +1 条
  → 全量 **769 → 774**

**边界**：快捷键 / 双击格子 / 触控板横扫 / 天气心情仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**774/774 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§2）、14（Day 107）、20（当前状态）、
CHANGELOG（本条）

---

## v1.11 · 2026-11-12

### M2/M8：主题对比度审计（U3，已验证）

- 新增 `contrast_audit.dart`（docs/10 §10 / U3）：WCAG 2.1 相对亮度与
  对比度计算，审计亮/暗两套色板 ink·muted 在 bg/surface/note/noteAlt
  共 16 组组合；兼容新版 Flutter 归一化 Color 通道与旧版 0~255 通道
- 测试验证 WCAG 黑白 21:1、同色 1:1、文档给出的 13.2:1/5.4:1 达标，
  **亮暗双主题全部 16/16 ≥ 4.5:1**；不达标色板能逐项报告失败原因
- `DiagnosticsPage` 显示 U3 结论
- 测试：`contrast_audit_test.dart` 4 条 → 全量 **765 → 769**

**边界**：只审计色板常量，不覆盖运行时动态色 / 图片上文字；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**769/769 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§2）、14（Day 106）、20（当前状态）、
CHANGELOG（本条）

---

## v1.10 · 2026-11-12

### M3 预备：首次绑定已有 vault 三选一策略（已验证）

- 新增 `first_bind_policy.dart`（docs/04 §8.1）：云端与本地都有数据时
  三选一（合并推荐 / 以云端为准先备份到 trash / 以本地为准先下载到
  quarantine 且需二次确认），云端或本地为空时不弹选择
- `executionFor` 给每个选项输出可执行步骤清单并要求重建 FTS/向量索引
- `DiagnosticsPage` 展示策略
- 测试：`first_bind_policy_test.dart` 3 条 → 全量 **762 → 765**

**边界**：真实 meta.enc 探测 / 备份覆盖 / 绑定 UI 仍属平台层，且需 A5；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**765/765 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§3）、14（Day 105）、20（当前状态）、
CHANGELOG（本条）

---

## v1.09 · 2026-11-12

### M6：CredentialGuard 自定义字段细粒度脱敏（已验证）

- `CredentialGuard.redactCustomFields()` 保留字段名 / 类型 / 是否私密，
  `secret:true` 的 value 一律 `[已隐藏]`，非私密值原样保留；
  与整体 `redact` 的一刀切隐藏形成两层可选用粒度（docs/11 §4.4）
- 测试：`credential_models_test.dart` +1 条 → 全量 **761 → 762**

**边界**：AI 工具返回值接入该细粒度结构仍待平台层；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**762/762 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 104）、20（当前状态）、
CHANGELOG（本条）

---

## v1.08 · 2026-11-12

### M7：会话切换滚动目标判定（已验证）

- 新增 `conversation_scroll.dart`（docs/12 §5 ③）：草稿/空会话回顶部，
  已有会话且有消息定位到最新消息（append-only 正序渲染的最新在底部）；
  切换瞬间先归零，消息加载完成后按 maxExtent 到底，避免沿用旧 offset
- `ChatPage` 用 `_pendingScrollToLatest` + postFrameCallback 接计划
- 测试：`conversation_scroll_test.dart` 3 条、
  `chat_drawer_test.dart` 5 条回归全绿 → 全量 **758 → 761**

**边界**：分页「加载更早」按钮仍缺；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**761/761 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 103）、20（当前状态）、
CHANGELOG（本条）

---

## v1.07 · 2026-11-12

### M6：密码详情 TOTP 复制清除（已验证）

- `VaultPage` 详情弹窗为带 TOTP 的账号提供「复制当前 TOTP（30 秒后清除）」
  按钮，走 `SensitiveClipboard` 自动清除通道；secret 字段始终只给掩码标签
- 测试：`vault_page_test.dart` +1 条（按钮可见、点击不抛异常）
  → 全量 **757 → 758**

**边界**：密码主值复制 / 拖拽换组 / 分组关联表仍缺；真实剪贴板平台行为
需真机验证。M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**758/758 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 102）、20（当前状态）、
CHANGELOG（本条）

---

## v1.06 · 2026-11-12

### M8 预备：解锁失败计数与锁定策略（已验证）

- 新增 `unlock_policy.dart`（docs/08 §6）：生物识别失败 5 次强制主密码、
  主密码连续错误 10 次锁定 5 分钟、锁定过期开启新一轮计数、
  恢复码失败计入同一暴力面、成功后清零、JSON 往返
- `UnlockPage` 用 `ref.listen` 监听错误文本变化累计失败，
  锁定期间禁用按钮并显示倒计时；成功解锁清零计数
- `DiagnosticsPage` 展示阈值
- 测试：`unlock_policy_test.dart` 3 条 → 全量 **754 → 757**；
  `vault_gate_test.dart` 13 条回归全绿

**边界**：失败计数仅当前会话内有效，尚未持久化到安全存储；
真实生物识别 API 仍缺。M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**757/757 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§10）、14（Day 101）、20（当前状态）、
CHANGELOG（本条）

---

## v1.05 · 2026-11-12

### M8 预备：剪藏分享意图判定层（已验证）

- 新增 `share_intent_parser.dart`（docs/08 §4 / docs/05 §3）：
  text/plain 分享里的多 URL 提取、去重、坏 scheme 拒绝、
  纯文本无 URL 降级为想法、空白忽略
- `shareQueueItems` 生成待处理队列项（Extension 只接收不抓取，
  明确 30s 限制），站点键复用 `ArchiveMeta.siteOf` 口径
- `DiagnosticsPage` 展示规则
- 测试：`share_intent_parser_test.dart` 3 条 → 全量 **751 → 754**

**边界**：真实 Intent / Share Extension / 全局热键 / 队列落库与消费
仍属平台层；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**754/754 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§10）、14（Day 100）、20（当前状态）、
CHANGELOG（本条）

---

## v1.04 · 2026-11-12

### M4：归档交互动作判定层（已验证）

- 新增 `archive_recheck_actions.dart`（docs/11 §3.4 / docs/05 §6）：
  单条重抓保留旧快照为历史版本、Wayback 年份徽章（死链且有存档 URL
  才显示）、按 recheck_policy 到期的批量分批、配额清理复用最旧带快照优先
- `ArchivePage` 死链条目显示「查看 2019 存档」而非泛泛的「试 Wayback」
- 测试：`archive_recheck_actions_test.dart` 4 条、
  `archive_page_test.dart` +1 条 → 全量 **746 → 751**

**边界**：真实重抓 / Wayback availability API / 历史版本落库仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**751/751 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 99）、20（当前状态）、
CHANGELOG（本条）

---

## v1.03 · 2026-11-12

### M3 预备：同步分片游标（已验证）

- 新增 `sync_checkpoint.dart`（docs/04 §10）：预算 200 请求耗尽时
  生成可落库游标（阶段 / 待处理路径 / 已完成路径 / 水位 / 时间戳），
  已完成不重复入列、待处理保持顺序、JSON 往返校验
- `planCheckpointResume`：仅当云端水位一致且游标 7 天内才续跑；
  水位前进 / 过期 / 无待处理一律保守重跑，避免重复推或漏推
- `DiagnosticsPage` 展示规则；真实落库由 `SyncWorkspaceStore` 后续接
- 测试：`sync_checkpoint_test.dart` 3 条 → 全量 **743 → 746**

**边界**：判定层未接 SyncEngine 真实预算耗尽路径，也未落库；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**746/746 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§3）、14（Day 98）、20（当前状态）、
CHANGELOG（本条）

---

## v1.02 · 2026-11-12

### M3 预备：同步状态 → UI 映射（已验证）

- 新增 `sync_status_ui.dart`（docs/04 §11）：把 13 个 SyncPhase、
  10 类错误码、冲突数、隔离数、重试时间映射成顶部横幅文案 / 颜色 /
  点击动作；BACKOFF 顶部静默只在设置页显示下次重试
- 优先级明确：致命错误 > 冲突 > 进行中 > 退避 > IDLE；
  `SyncDiagnosticsNote` 提供隔离文件红点与重试倒计时
- `DiagnosticsPage` 展示映射规则；真实状态注入仍需 M0 A5
- 测试：`sync_status_ui_test.dart` 5 条 → 全量 **738 → 743**

**边界**：只做判定层，未接 App 启动 / 真实 WebDAV 状态；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**743/743 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§3）、14（Day 97）、20（当前状态）、
CHANGELOG（本条）

---

## v1.01 · 2026-11-12

### M7：消息分页与 90 天会话归档判定（R15，已验证）

- 新增 `conversation_retention.dart`（docs/09 R15）：50 条分页窗口
  （上限 200）、更早页游标、90 天前会话归档为摘要且只保留最近 5 条原文、
  批量归档按最老优先
- `ConversationRepository.messages(plan:)` 真实分页：倒序取最新一页后
  恢复 append-only 视觉顺序；`ChatPage._switchTo` 默认加载最新 50 条，
  长会话不再一次读全表
- 测试：`conversation_retention_test.dart` 4 条 → 全量 **734 → 738**

**边界**：真实归档任务 / 摘要生成 / UI「加载更早」按钮仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**738/738 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（R15）、14（Day 96）、20（当前状态）、
CHANGELOG（本条）

---

## v1.00 · 2026-11-12

### M7：引用卡片与工具调用折叠卡（已验证）

- `ChatPage` 消息流按 docs/07 §10.1 补两处 UI：
  AI 回答下方渲染 `citations` 引用 chip（点击跳 EditorPage 直达条目），
  `role=3` 工具结果默认折叠为「🔍 工具调用 · 点击展开」
- 测试：`conversation_writer_test.dart` +1 条（引用 chip 可见、
  工具卡默认收起 / 展开可见）→ 全量 **733 → 734**

**边界**：消息分页加载 / 90 天前会话归档为摘要（R15）仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**734/734 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 95）、20（当前状态）、
CHANGELOG（本条）

---

## v0.99 · 2026-11-11

### M7：无模型 / 无 API Key 的诚实引导（C5，已验证）

- 新增 `model_status.dart` / `model_availability_provider.dart`：
  按双模型路由判定顶部文案与空状态引导；默认两端都未就绪，
  **不再写死「端侧模型 · 就绪」**
- `ChatPage` 顶部显示真实状态；检索与工具仍可用时明确引导下载端侧模型
  或配置云端 API Key，绝不假装能生成回复
- 测试：`model_status_test.dart` 2 条 → 全量 **731 → 733**

**边界**：真实 Key 读取 / 端侧模型就绪探测由平台层注入 provider；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**733/733 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9 / C5）、14（Day 94）、
20（当前状态）、CHANGELOG（本条）

---

## v0.98 · 2026-11-11

### M7：对话空状态 3 个示例问题（已验证）

- `ChatPage` 空消息区按 docs/07 §10.3 显示 3 个示例问题 chips，
  点击填入输入框；**不自动发送**，端侧模型未接入前不假装有回复
- 测试：`conversation_writer_test.dart` +1 条（三问可见、点击回填、
  不落库）→ 全量 **730 → 731**

**边界**：真实模型回复与自动提问仍缺；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**731/731 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 93）、20（当前状态）、
CHANGELOG（本条）

---

## v0.97 · 2026-11-11

### M7：System Prompt 与输出强制约束（已验证）

- 新增 `system_prompt.dart`（docs/07 §9）：五段式 system prompt、
  `buildPromptMessages` 永远把它放最前
- `enforceOutputConstraints` 实现 §9.2 四道代码级关卡：假引用整句移除
  （真引用保留）、密码命中整段 `[已隐藏]`、300 字截断、token 预算；
  6 轮上限直接复用 `AgentLoopLimits`，避免两处常量漂移
- `DiagnosticsPage` 展示约束说明
- 测试：`system_prompt_test.dart` 4 条 → 全量 **726 → 730**

**边界**：无真实模型回复，约束层只在「有输出文本时」由平台层调用；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**730/730 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 92）、20（当前状态）、
CHANGELOG（本条）

---

## v0.96 · 2026-11-11

### M5：检索降级四态计划（已验证）

- `planSearchDegradation`（docs/06 §6.3）把四行策略表写成可测判定：
  无模型/下载中/校验中 → 纯 FTS（下载中静默）；索引构建中 →
  FTS + 已构建部分向量并显示进度提示；完成 → 完整混合检索
- 任何状态 `ftsEnabled` 都为真，体现「降级可用」原则；
  旧 `useVectorSearch` 保留为快速就绪判断
- 测试：`model_downloader_test.dart` +1 条 → 全量 **725 → 726**

**边界**：真实向量召回与进度条 UI 仍缺；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**726/726 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§5）、14（Day 91）、20（当前状态）、
CHANGELOG（本条）

---

## v0.95 · 2026-11-11

### M7：OpenAI 兼容客户端纯判定层（已验证）

- 新增 `openai_compat.dart`（docs/07 §7）：4 家服务商 endpoint 配置、
  `/chat/completions` 请求体（tools / 温度 0.3 / 流式）、SSE 增量解析、
  最近 6 轮上下文裁剪 + 2000 字截断、token 预算估算、
  5 分钟检索缓存键、只记 URL/状态码/token 数的脱敏日志
- **不联网、不存 Key、不记 body / API Key**；真实 transport 与
  flutter_secure_storage 仍属平台层
- `DiagnosticsPage` 展示规格
- 测试：`openai_compat_test.dart` 4 条 → 全量 **721 → 725**

**边界**：真实 HTTP / 流式 / Key 存储 / 多家厂商实测仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**725/725 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 90）、20（当前状态）、
CHANGELOG（本条）

---

## v0.94 · 2026-11-11

### M6：账号分组与组内字段模板（已验证）

- 新增 `CredentialGroupRepository`（docs/11 §4.6）：复用
  `category.kind=6` 只读分组树、`category_field_template` 模板字段
  写入/去重/按 sortOrder 读取、`instantiateForGroup` 生成空 secret 字段
- `VaultPage` 新增弹窗加「账号分组」下拉，选组后自动套用该组模板
  （优先于固定模板）——即文档里「分组真正的价值」
- 测试：`credential_group_repository_test.dart` 3 条、
  `vault_page_test.dart` +1 条 → 全量 **717 → 721**

**边界**：分组树 UI / 拖拽换组 / 模板随 taxonomy 通道加密同步仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**721/721 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 89）、20（当前状态）、
CHANGELOG（本条）

---

## v0.93 · 2026-11-11

### M6：图片附件判定层（已验证）

- 新增 `attachment_validator.dart`（docs/09 §8）：按文件头识别
  PNG / JPEG / WebP / GIF（不信任扩展名）、≤5MB 上限守卫、空文件与
  非法格式拒绝并给可执行原因、文件名去路径/可疑字符并按真实格式换扩展名
- `planAttachment` 输出 blob_ref 写入计划（明文结构），真实加密入 blobs
  与附件 UI 仍属平台层
- `DiagnosticsPage` 展示附件规则；测试 `attachment_validator_test.dart`
  4 条 → 全量 **713 → 717**

**边界**：无真实文件选择 / 加密写入 / 附件展示；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**717/717 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 88）、20（当前状态）、
CHANGELOG（本条）

---

## v0.92 · 2026-11-11

### M6：备注字段加密与 L0 端侧边界（已验证）

- `CredentialRepository` 新增 `setNotes` / `notes` / `notesForCloud`：
  备注也走 K_item 字段级加密，明文不落库；云端上下文必须
  `explicitlyAuthorized: true` 才能取到，否则返回空串（docs/11 §4.4）
- `VaultPage` 详情弹窗加备注 Markdown 编辑与保存，明确标注
  「L0 端侧，不同步到云端上下文」
- 测试：`credential_repository_test.dart` +1 条、
  `vault_page_test.dart` +1 条 → 全量 **711 → 713**

**边界**：备注里的加粗/列表目前只是 Markdown 文本，无富文本渲染；
图片附件仍缺。M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**713/713 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 87）、20（当前状态）、
CHANGELOG（本条）

---

## v0.91 · 2026-11-11

### M8：导出与备份页（已验证）

- 新增 `ExportBackupPage`（docs/03 §10）：明文导出二次确认状态机
  idle→warned→confirmed→done、导入无冲突合并判定
  insert/skip/conflictCopy、`/backup/` 隔离与 7 天排期展示
- 设置中心加「导出与备份」入口；`advancePlaintextExport` /
  `decideImport` / `isBackupPath` 不再只有测试引用
- 页面**不打包、不写文件、不联网**，明确真实加密 zip 与 WebDAV
  上传仍属平台层
- 测试：`export_backup_page_test.dart` 2 条 → 全量 **709 → 711**

**边界**：真实 zip / 密码保护 / Markdown 文件夹输出 / 自动备份上传仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**711/711 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§10）、14（Day 86）、20（当前状态）、
CHANGELOG（本条）

---

## v0.90 · 2026-11-11

### M6：智能分组 chips 接列表筛选（已验证）

- `VaultPage` 智能分组 chips 从纯展示改为可点击筛选：选中某组后
  账号列表只显示该组 id 集合，再点一次取消；选中 chip 用 primary 高亮
- 分组结果缓存到 state，避免两个 FutureBuilder 作用域不互通
- 测试：`vault_page_test.dart` +1 条（泄露组只显示泄露账号 / 取消恢复）
  → 全量 **708 → 709**

**边界**：分组树 UI / 拖拽换组 / 字段模板按组自动套用仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**709/709 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 85）、20（当前状态）、
CHANGELOG（本条）

---

## v0.89 · 2026-11-11

### M7：AI 日记检索开关与本地偏好持久化（已验证）

- 新增 `local_settings.dart` / `local_settings_provider.dart`：
  `<appSupport>/settings.json` 存纯本地偏好（不参与同步、不加密、
  不含敏感值），默认「AI 日记不参与检索」（docs/07 §6.1）
- `SettingsHubPage` 提供显式开关；`SearchPage` / `RecordsPage` 的
  `searchHybrid` 从硬编码 false 改为读取该偏好
- `main()` 在 runApp 前装配 `SettingsStore` 并经 `VaultApp` 注入已加载
  偏好；测试可注入临时目录
- 测试：`local_settings_test.dart` 2 条（JSON 往返/坏文件兜底、
  Notifier 切换持久化）→ 全量 **706 → 708**

**边界**：仅此一项偏好持久化，其余设置仍无磁盘状态；向量通道仍缺，
开关只影响 FTS 结果。M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**708/708 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 84）、20（当前状态）、
CHANGELOG（本条）

---

## v0.88 · 2026-11-11

### M2：删除分类确认文案补齐受影响条目数（已验证）

- `OrganizePage._deleteCategory` 先用 `entryIdsForCategory`
  （已含子分类）算真实受影响条目数，确认文案写成
  「N 条笔记会移到「未分类」，不会被删除」（docs/11 §2 / D23）
- `organize_write_test.dart` 在既有删除用例里钉住「1 条笔记」
  数量断言 → 全量保持 **706/706**

**边界**：无层级变更拖拽、无批量改分类 UI；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**706/706 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README、14（Day 83）、20、CHANGELOG（本条）

---

## v0.87 · 2026-11-11

### M7：日记页「现在生成 AI 日记」（已验证）

- `DiaryPage` 加「生成 AI 日记」按钮（docs/11 §3.2）：用选中日期
  （未选则当月今天 / 否则 1 号）的真实活动埋点走
  `DailySummaryService.buildAndStore`，生成 kind=4 日总结并刷新月历
- 无活动时不写空条目，SnackBar 明确提示；端侧模型反思文本仍缺，不编造
- 用已装配的 `vaultDatabaseProvider` / `writeGatewayProvider` /
  `activityLoggerProvider`，避免测试夹具与会话状态耦合
- 测试：`diary_page_test.dart` +1 条 → 全量 **705 → 706**

**边界**：23:50 定时触发、模型反思文本、AI 日记独立配色仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**706/706 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 82）、20（当前状态）、
CHANGELOG（本条）

---

## v0.86 · 2026-11-11

### 诊断页收口：最后两个判定层接生产入口

- `DiagnosticsPage` 增加「演示死链重检查判定」（模拟 404 →
  `LinkCheckResult.dead` + Wayback 建议，明确不发真实请求），
  `link_check_service.dart` 不再只有测试引用
- 展示 Agent 主循环的四种停轮原因，`agent_loop.dart` 不再只有测试引用
- 逐项盘点后 `lib/data` 下已无「零生产引用」模块
- 全量 **705/705**（本批无新增测试断言，仅接线与 1 条 UI 断言更新）

**边界**：真实 HTTP / Wayback、模型主循环调用仍缺；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**705/705 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README、14（Day 81）、20、CHANGELOG（本条）

---

## v0.85 · 2026-11-11

### M4：死链 / 内容变更重检查闭环（已验证）

- 新增 `link_check_service.dart`：把 `classifyHttpStatus` /
  `shouldTryWayback` / `hasContentChanged` 串成一次可复现检查，
  输出 result / changed / tryWayback / shouldRecord / reasons
- 200 且 simhash 汉明距离 > 3 → `changed`；404/410 与网络不可达
  → Wayback；403/451 不回退；距上次检查未过 30 天不重复落证据
- `LinkCheckService.run` 读最近一次 `link_check` 的 simhash 作基线，
  经 `WriteGateway.recordLinkCheck` 落证据，避免同一天刷屏
- 测试：`link_check_service_test.dart` 4 条 → 全量 **701 → 705**

**边界**：真实 HTTP HEAD/GET、Wayback 请求、simhash 计算仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**705/705 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 80）、20（当前状态）、
CHANGELOG（本条）

---

## v0.84 · 2026-11-11

### M5：搜索结果卡片元信息（已验证）

- `SearchPage` 结果卡片补类型标签（笔记/想法/日记/AI 日记/书签/密码）、
  「命中：关键词」来源标记、kind=5 归档徽章（docs/06 §8.1）
- 当前只有 FTS 通道，明确写「关键词」而非谎称语义命中
- 测试：`search_page_test.dart` 1 条 → 全量 **700 → 701**

**边界**：语义命中来源与归档状态徽章（原站存活/失效/有快照）需真实
向量通道与 meta 透出；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**701/701 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§5）、14（Day 79）、20（当前状态）、
CHANGELOG（本条）

---

## v0.83 · 2026-11-11

### M7：会话切换滚动复位（已验证）

- `ChatPage` 增加 `ScrollController` 与缓存的 `_messages` Future：
  切换会话 / 进入草稿 / 发出新消息时统一走 `_switchTo`，
  主区消息列表 `jumpTo(0)` 回到顶部，避免沿用上一会话滚动位置
- 缓存 Future 后，点筛选与 setState 不再让消息区反复闪回加载态
- 测试：`chat_drawer_test.dart` +1 条（滚动到中段后切换会话 offset 归零）
  → 全量 **699 → 700**

**边界**：真实模型回复与流式渲染仍缺；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**700/700 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 78）、20（当前状态）、
CHANGELOG（本条）

---

## v0.82 · 2026-11-11

### M2：Markdown 实时预览（已验证）

- 新增 `markdown_preview.dart`：逐行归类标题 1~3 / 列表 / 任务勾选 /
  引用 / 代码围栏 / 图片 / 段落；围栏内不二次解析，未闭合也保留内容；
  `previewPlainText` 去标记给列表用
- 新增 `MarkdownPreview` 面板（纯 Flutter Text，不引第三方渲染器），
  `EditorPage` 加「预览 / 编辑」切换，补上 docs/09 §4 记录的
  「Markdown 编辑器无实时预览」缺口
- 测试：`markdown_preview_test.dart` 4 条、`editor_page_test.dart` +1 条
  → 全量 **694 → 699**

**边界**：轻量核对，不是完整 CommonMark；不渲染 HTML / 表格 / 脚注。
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**699/699 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 77）、20（当前状态）、
CHANGELOG（本条）

---

## v0.81 · 2026-11-11

### M5：搜索空结果改写建议（已验证）

- 新增 `search_suggestions.dart`（docs/06 §8.2）：不调模型，
  确定性给出至多 3 条去重改写建议（剥停用词/类型限定词/时间意图、
  取最长 token、双词短语）；FTS 有结果但无向量时才显示下载模型提示
- `SearchPage` 空结果页展示「换个说法试试」+ 可点击的建议 chips，
  点击直接回填重搜；明确当前只有关键词匹配、不谎称语义可用
- 测试：`search_suggestions_test.dart` 4 条 → 全量 **690 → 694**

**边界**：建议未由端侧模型生成（模型未接入），真实向量召回仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**694/694 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§5）、14（Day 76）、20（当前状态）、
CHANGELOG（本条）

---

## v0.80 · 2026-11-11

### M5：向量同步判定层（已验证）

- 新增 `vector_sync_policy.dart`（docs/06 §7）：封包结构解析、
  `model_id / dim / dtype / 空 bytes` 任一不匹配即丢弃并标记需重算，
  **绝不混用不同模型的向量**；坏结构逐条隔离不抛异常
- `expectationFromSpec` 从 manifest 取 dim / quant，不硬编码；
  `planVectorRecompute` 批量输出需重算的 entry id
- `DiagnosticsPage` 展示向量同步红线
- 测试：`vector_sync_policy_test.dart` 5 条 → 全量 **685 → 690**

**边界**：真实 `/vault/vec/` 加解密上传下载、entry_vec 写入仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**690/690 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§5）、14（Day 75）、20（当前状态）、
CHANGELOG（本条）

---

## v0.79 · 2026-11-11

### P10：密码模块克制变体落地（已验证）

- 新增 `SecureCard`（docs/09 §15 / P10）：对称 10px 圆角、1.5px 实线边、
  零倾斜、无硬偏移阴影；共用纸白底/墨色/楷体，红色只用于泄露/危险态
- `VaultPage` 账号 tile 改用 `SecureCard`，泄露时 accent 变红；
  内部字母方块去倾斜与硬阴影
- 测试：`secure_card_test.dart` 2 条（圆角/实线/无阴影、accent 覆盖）
  → 全量 **683 → 685**

**边界**：其余密码相关屏（详情弹窗、设置内嵌卡片）仍沿用通用组件；
P10 是产品决策，若用户反馈割裂再统一。M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**685/685 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§15 / P10）、14（Day 74）、
20（当前状态）、CHANGELOG（本条）

---

## v0.78 · 2026-11-11

### M9：同步回归 26 用例清单与门禁（已验证）

- 新增 `sync_regression_matrix.dart`：docs/04 §9 的 T01~T20 +
  docs/09 §12 的 T21~T26 共 26 条，逐条记录场景 / 期望 / 验证状态
- 明确「本地单测覆盖 ≠ 三套服务器全绿」：11 条纯语义标 localVerified，
  15 条标 requiresRealServer；`allPassed` 直到真实环境注入结果才可能为真
- `runReleaseAudit` 追加 A10 同步回归门禁；`DiagnosticsPage` 展示
  本地/待真实环境计数
- 测试：`sync_regression_matrix_test.dart` 4 条 → 全量 **679 → 683**

**边界**：真实 Nextcloud / mod_dav / 坚果云三套环境、强杀重启、
20MB blob、5000 条性能仍缺；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**683/683 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§11/§12）、14（Day 73）、
20（当前状态）、CHANGELOG（本条）

---

## v0.77 · 2026-11-11

### M7：双模型路由四分支（已验证）

- `decideModelRoute`（docs/07 §2.2）把占位的「永远 onDevice」改成
  可验证决策：L0 任务强制端侧且授权不能改；检索/笔记摘要用户可选但
  未逐次授权仍端侧；长文/复杂推理云端需 L2 授权，未授权降级端侧；
  端侧模型未就绪时明确降级纯 FTS 不出设备
- `routeModelForTask` 保留为兼容入口；新增 `ModelRouteDecision`
  带 reason / needsAuthorization
- `DiagnosticsPage` 展示路由策略
- 测试：`agent_policy_test.dart` +1 条 → 全量 **678 → 679**

**边界**：真实模型调用与云端 adapter 仍缺；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**679/679 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 72）、20（当前状态）、
CHANGELOG（本条）

---

## v0.76 · 2026-11-11

### M7：L2/L1 逐次授权弹窗（已验证）

- 新增 `PrivacyAuthorizationSheet` / `requestPrivacyAuthorization`
  （docs/07 §4.2）：显示「向哪个模型发送几条内容 / 多少字」，
  明确仅授权本次、下次重新询问；密码/TOTP/日记永不出现在这类请求里
- 授权结果只返回本次调用方，**不写设置、不落库、不缓存**；
  `authorizationSummary` 只给计数不含内容本体
- `DiagnosticsPage` 提供演示入口（明确不发送任何数据）
- 测试：`privacy_authorization_sheet_test.dart` 3 条 → 全量
  **675 → 678**

**边界**：真实模型主循环把授权结果接进 `ToolCallContext` 仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**678/678 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 71）、20（当前状态）、
CHANGELOG（本条）

---

## v0.75 · 2026-11-11

### M7：工具确认卡片 UI（已验证）

- 新增 `ToolConfirmationCard` / `showToolConfirmation`（docs/07 §4.1）：
  同时显示人话操作、**完整内容预览**、数据流向；数据离开设备时写明目标
  模型名并要求勾选二次确认，未勾选时确认按钮禁用
- 卡片只返回批准/拒绝，不执行工具；`DiagnosticsPage` 提供
  「预览工具确认卡片」演示入口（明确不写库）
- 测试：`tool_confirmation_card_test.dart` 3 条（三段可见 / 二次确认 /
  取消与确认返回值）→ 全量 **672 → 675**

**边界**：真实模型主循环调用卡片、L2 逐次授权弹窗仍缺；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**675/675 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 70）、20（当前状态）、
CHANGELOG（本条）

---

## v0.74 · 2026-11-11

### M7：工具集补齐到 17 个（已验证）

- `buildDefaultToolRegistry` 从 12 扩到 17：新增 `list_activity` /
  `get_stats` / `open_entry` / `update_entry` / `archive_url`，
  覆盖 docs/07 §3.1 中所有可纯本地实现的能力
- `AgentToolDeps.activity` 可选注入活动仓库；`update_entry`、
  `archive_url` 为 confirm 级，先出内容预览再写库；非法 URL 明确拒绝
- `DiagnosticsPage` 工具数改为 17
- 测试：`agent_tools_test.dart` +1 条（活动/统计/深链/更新/归档）
  → 全量 **671 → 672**

**边界**：`web_search` / `fetch_page` 需要 BYOK 搜索 API 与域名白名单，
不做；`add_tags` 与云端模型仍缺。M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**672/672 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 69）、20（当前状态）、
CHANGELOG（本条）

---

## v0.73 · 2026-11-11

### M7：工具集补齐到 12 个（已验证）

- `buildDefaultToolRegistry` 从 4 个扩到 12 个：新增
  `list_categories` / `list_tags` / `entries_by_category` /
  `entries_by_tags` / `uncategorized_entries` / `diary_for_month` /
  `entry_history` / `credential_smart_groups`，全部本地只读、
  auto / L1，统一过 `checkToolCall` 闸门
- `AgentToolDeps.taxonomy` 可选注入历史仓库；缺装配时明确返回不可用
- `DiagnosticsPage` 工具数从 4 改为 12
- 测试：`agent_tools_test.dart` +1 条（分类/标签/分组/日记真实执行）
  → 全量 **670 → 671**

**边界**：仍无 OpenAI 兼容客户端 / 流式回复 / 云端模型；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**671/671 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 68）、20（当前状态）、
CHANGELOG（本条）

---

## v0.72 · 2026-11-11

### M6：账号详情脱敏与改密码入口（已验证）

- `CredentialRepository.detail()` 聚合标题 / 用户名 / TOTP 当前码 /
  泄露状态 / secret 字段掩码标签 / 健康统计；`CredentialDetail.toJson()`
  **不带任何明文**
- `VaultPage` 条目点击开详情弹窗，明确提示「密码以 K_item 密文存储，
  此页不展示明文」；「生成新密码并替换」走 `setPassword` 密文落库
- 测试：`credential_repository_test.dart` +1 条（toJson 无明文）、
  `vault_page_test.dart` +1 条（详情无明文 + 替换生效）→ 全量
  **668 → 670**

**边界**：字段编辑 UI / 拖拽排序 / 图片附件 / 真实自动填充仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**670/670 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 67）、20（当前状态）、
CHANGELOG（本条）

---

## v0.71 · 2026-11-11

### M4：抓取任务队列状态机（已验证）

- 新增 `archive_job_queue.dart`：docs/05 §4 九步流水线（去重→元数据→
  加载→readability→Markdown→PDF→L3→blob→向量队列）的 `next/progress`
- 同 URL 已存在且未确认更新直接失败，不覆盖快照；策略降级跳过 pdf/
  rawHtml；PDF 失败只降级为 L1+L3 不整体失败；其它阶段失败重试 3 次
- docs/05 §7 按需下载：L1 正文优先于 L2 PDF、并发上限 2、
  进度只按已完成字节算、失败保持仅云端（不删云端 blob）
- `DiagnosticsPage` 展示流水线步数与降级策略
- 测试：`archive_job_queue_test.dart` 5 条 → 全量 **663 → 668**

**边界**：真实 WebView / readability.js / PDF 生成 / blob 写入仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**668/668 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§4）、14（Day 66）、20（当前状态）、
CHANGELOG（本条）

---

## v0.70 · 2026-11-11

### M5：阅读器高亮与选区判定接线（已验证）

- `ArchiveReaderPage` 增加「粘贴一段正文，问 AI」输入框与判定按钮，
  用 `canAskAiAboutSelection` 拦截太短/太长选区、提示进入 L1 逐次授权；
  底部显示 `mergeHighlights` 合并后的高亮段数
- 测试：`archive_reader_page_test.dart` +1 条 → 全量 **662 → 663**

**边界**：真实划词手势、AI 问答请求、L1 授权弹窗仍缺；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**663/663 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§5）、14（Day 65）、20（当前状态）、
CHANGELOG（本条）

---

## v0.69 · 2026-11-11

### M4：归档维护计划器（已验证）

- 新增 `archive_maintenance.dart`：把重检查排期、Wayback 回退、
  本地 blob 缓存清理、L2/L3 快照降级收成一份可执行动作清单，
  `toJson()` 可直接写进 job_queue / CI；不联网、不写库
- 只对 dead / unreachable 回退 Wayback，restricted / paywalled 不回退；
  `never` 策略不排重检查；缓存未超预算 / 配额未触线不产生动作
- `DiagnosticsPage` 展示四类维护动作
- 测试：`archive_maintenance_test.dart` 3 条 → 全量 **659 → 662**

**边界**：真实 HTTP 检查、Wayback 请求、PDF 生成与抓取仍属平台层；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**662/662 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§5）、14（Day 64）、20（当前状态）、
CHANGELOG（本条）

---

## v0.68 · 2026-11-11

### M9：发布自检诚实暴露外部缺口（已验证）

- `runReleaseAudit` 增加 `checkExternalGates` 开关：打开后追加
  A7 性能基线（未测≠达标）、A8 三端原生能力缺口、A9 上架材料与审核，
  三者当前均明确不通过；关闭时仍是纯确定性六项自检
- `DiagnosticsPage` 显式打开外部门禁，subtitle 从「自检通过」变成
  「自检有未通过项」，不再把纯逻辑全绿误当成可发布
- 测试：`release_audit_test.dart` +1 条（A7/A8/A9 均失败且摘要可执行）、
  诊断页断言同步 → 全量 **658 → 659**

**边界**：真实集成用例 / 真机 / 商店审核仍缺；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**659/659 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§11）、14（Day 63）、20（当前状态）、
CHANGELOG（本条）

---

## v0.67 · 2026-11-11

### M9：5000 条性能基线判定层（已验证）

- 新增 `performance_baseline.dart`：9 项预算（冷启动 <1.2s、无变化同步
  ≤3 请求、有变化 ≤200、5000 条重建 <8min、包体 <60MB、内存 <400MB、
  中文搜索 P95 <150ms、混合检索 P95 <300ms、1000 条 60fps）
- `evaluatePerformance` 把实测值映射到 pass/fail/unmeasured；**未测显式
  不等于达标**，有未测项发布门禁就不通过；超标给出可执行建议
- `DiagnosticsPage` 展示「9 项预算全未测 · 发布门禁未通过」
- 测试：`performance_baseline_test.dart` 4 条 → 全量 **654 → 658**

**边界**：真实真机测量、三套服务器 26 个集成用例、三端联调仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**658/658 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§11）、14（Day 62）、20（当前状态）、
CHANGELOG（本条）

---

## v0.66 · 2026-11-11

### M8：三端能力矩阵纯校验（已验证）

- 新增 `platform_capabilities.dart`：docs/08 §1 的 11 项能力按三端标注
  `dartReady / nativeRequired / unavailable`，`auditPlatformGaps()` 列出
  每个平台仍需原生的能力，`unavailableFor()` 单列系统不支持项
- 明确「纯逻辑已落地 ≠ 三端可用」；Windows 无系统填充、iOS 无托盘
- `DiagnosticsPage` 展示三端缺口计数
- 测试：`platform_capabilities_test.dart` 4 条 → 全量 **650 → 654**

**边界**：真实原生模块、上架审核、三端联调仍缺；M3 硬门槛未过，
M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**654/654 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§10）、14（Day 61）、20（当前状态）、
CHANGELOG（本条）

---

## v0.65 · 2026-11-11

### M7：Agent 主循环与 MCP 适配器骨架（已验证）

- 新增 `agent_loop.dart`：`runAgentLoop` 按上层计划逐轮调用工具，
  强制 6 轮上限、结果截断 2000 字、统一过闸门；
  deny / requireConfirm / 未注册工具立即停轮
- `McpToolAdapter` 只映射远程 tool 描述为本地 [AgentTool]，
  固定 dangerous/L2，**不发网络请求**；密码条目走第三方 MCP 被闸门直接拒绝
- `DiagnosticsPage` 展示主循环上限与 MCP 骨架状态
- 测试：`agent_loop_test.dart` 4 条 → 全量 **646 → 650**

**边界**：无真实模型 / MCP transport；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**650/650 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 60）、20（当前状态）、
CHANGELOG（本条）

---

## v0.64 · 2026-11-11

### M6：字段模板与自定义字段增删排序（已验证）

- 新增 `credential_template.dart`：社交/开发/金融三套预置模板，
  `instantiate()` 生成空字段；`CustomFieldsEdit` 不可变 add/remove/reorder，
  自动续 sort、拒绝重复 id 与超过 20 个、越界 clamp；secret 掩码只给标签
- `CredentialField.copyWith` 支持不可变编辑
- `VaultPage` 新增弹窗可选模板 → 模板字段整体加密落库（连标签都不明文）
- 测试：`credential_template_test.dart` 4 条、`vault_page_test.dart` +1 条
  → 全量 **641 → 646**

**边界**：无字段编辑 UI / 拖拽排序 / 图片附件；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**646/646 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 59）、20（当前状态）、
CHANGELOG（本条）

---

## v0.63 · 2026-11-11

### M7：滚动摘要日→周→月→年（已验证）

- `DailySummary` 增加 `granularity` 标记（day/week/month/year）
- 新增 `RollupService`：只读指定层级与日期范围的 kind=4 摘要，
  按 7/4/12 的层级预算聚合成上一层；引用逐层校验、坏 meta 跳过、
  不足完整周期时明确写「仅 N 条」而不是假装完整；无下层不写空条目
- `DiagnosticsPage` 加「生成上月摘要」按钮
- 测试：`rollup_service_test.dart` 4 条 → 全量 **637 → 641**

**边界**：不调模型生成反思文本；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**641/641 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 58）、20（当前状态）、
CHANGELOG（本条）

---

## v0.62 · 2026-11-11

### M7：具体工具集接真实仓库（已验证）

- 新增 `lib/data/agent/agent_tools.dart`：4 个工具
  `credential_health` / `search_entries` / `get_entry` / `create_note`
  接真实 `EntryRepository` / `CredentialRepository` / `WriteGateway`
- `invokeTool()` **统一过 `checkToolCall` 闸门**：deny 返回结果文本、
  requireConfirm 返回人话预览、allow 才执行；密码条目 `get_entry`
  只给脱敏描述，`credential_health` 只给聚合统计
- `DiagnosticsPage` 展示真实注册表与工具数
- 测试：`agent_tools_test.dart` 5 条（注册表 / 统计 / FTS 排除 AI 日记 /
  密码脱敏 / 确认写库 + 密码边界拒绝）→ 全量 **632 → 637**

**边界**：不调模型、不联网、不接 MCP；写类工具只有确认预览。
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**637/637 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 57）、20（当前状态）、
CHANGELOG（本条）

---

## v0.61 · 2026-11-11

### M7：日总结流水线接真实活动埋点（已验证）

- 新增 `DailySummaryService`：把 `ActivityLogger.summarizeDay` 的真实聚合
  转成事实 headline + 时间线，用 `validateCitations` 剔除已删除/不存在的
  引用，写成 kind=4 AI 日记条目；空的一天不写空条目
- `DiagnosticsPage` 加「生成昨日总结」按钮，服务不再只有测试引用
- 测试：`daily_summary_service_test.dart` 3 条（空天不写 / 真实活动落库 /
  假引用剔除）→ 全量 **629 → 632**

**边界**：不调端侧模型生成反思文本；kind=4 默认排除检索、不向量化。
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**632/632 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 56）、20（当前状态）、
CHANGELOG（本条）

---

## v0.60 · 2026-11-11

### M9：搜索埋点明文泄露硬拦截（已验证）

- `ActivityLogger` 增加可注入 `knownSecrets`；`recordSearch` 在**落库之前**
  过 `scanForPlaintextLeaks`，夹带密码 / TOTP / secret 字段明文的搜索词
  直接不记录，绝不写进 `activity.query`
- `VaultSession._activate` 解锁时一次性用 `CredentialRepository`
  .knownSecretValues() 装配该集合，写入热路径不重复解密全表
- 测试：`activity_logger_test.dart` +1 条（拦截 + 正常搜索仍记）
  → 全量 **628 → 629**

**边界**：只对搜索词做拦截；其它 extra 字段的扫描与真实日志导出审计
仍留后续；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**629/629 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§11）、14（Day 55）、20（当前状态）、
CHANGELOG（本条）

---

## v0.59 · 2026-11-11

### M7：会话 FTS 索引与结果分区展示（已验证）

- `VaultDatabase.indexConversation/searchConversationIds`：读写已有
  `conversation_fts` 表（此前只有建表语句）
- `ConversationWriter.append` 在**同一事务**里把该会话全部消息重新分词
  写进 FTS，避免「消息有了但搜不到」的中间态
- `ConversationRepository.search()` 返回「会话 / 消息」两个分区；
  `ConversationDrawer` 搜索时显示消息命中分区，可点开原会话
  （标题不含关键词也能看到消息分区）
- 测试：`conversation_writer_test.dart` +1 条（中文 FTS + 分区）、
  `chat_drawer_test.dart` +1 条（抽屉分区 UI）→ 全量 **626 → 628**

**边界**：会话/消息仍不参与同步；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**628/628 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 54）、20（当前状态）、
CHANGELOG（本条）

---

## v0.58 · 2026-11-11

### M7：聊天输入框接密码绝对边界（已验证）

- `CredentialRepository.knownSecretValues()`：在内存里解密已存的密码 /
  TOTP 密钥 / `secret:true` 自定义字段值，只交给 Guard 做「是否夹带」判定，
  绝不写日志、报告或工具返回值
- `ChatPage._send()` 在**写库之前**用 `CredentialGuard.containsSecret`
  拦截：用户把已存密码明文贴进聊天框时 SnackBar 明确拒绝，
  绝不让它进任何模型上下文；正常消息照常落库
- 测试：`conversation_writer_test.dart` +1 条（拦截 + 正常消息可发）
  → 全量 **625 → 626**

**边界**：只拦「本机已存的敏感值」，不拦用户新输入的任意密码；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**626/626 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§9）、14（Day 53）、20（当前状态）、
CHANGELOG（本条）

---

## v0.57 · 2026-11-11

### M5：模型下载器与索引重建判定层（已验证）

- 新增 `lib/data/search/model_downloader.dart`（docs/06 §5 / §6）
  - 五档源优先级、状态机 idle→checking→downloading→verifying→ready/corrupt
  - 磁盘 ≥ 1.5×disk_bytes、`.part` 断点续传、sha256 常量时间比对、
    每源 3 次重试、换源作废 .part、全源失败才标记损坏
  - 索引重建：切换模型先删旧向量、全量按 20 条分批 + cursor 可续、
    单条写入不排全量；下载中/校验中检索降级纯 FTS
  - 备份排除三端四标记（Android 两处 / iOS / Windows）集中校验
- `DiagnosticsPage` 展示源优先级、重试策略、备份排除与重建计划
- 测试：`model_downloader_test.dart` 7 条 → 全量 **618 → 625**

**边界**：真实下载 / Range 请求 / sha256 流式计算 / 推理写 entry_vec 仍属
平台层；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**625/625 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§5）、14（Day 52）、20（当前状态）、
CHANGELOG（本条）

---

## v0.56 · 2026-11-11

### M6：剪贴板 30 秒自动清除（已验证）

- 新增 `lib/data/vault/sensitive_clipboard.dart`：复制敏感值后 30 秒清除，
  **只清仍是本次写入的内容**；用户中途复制了别的东西绝不误删，
  连续复制用 generation 让旧任务失效，可显式 cancel。
  注入 port/sleep 做确定性测试，不依赖真实平台通道
- `FlutterClipboardPort` 是唯一需要 `Clipboard` MethodChannel 的适配层；
  `onboarding_page` 复制恢复码改走 `SensitiveClipboard.copy`
- `vault_gate` 复制的是错误信息（非敏感），保持原样不误清
- 测试：`sensitive_clipboard_test.dart` 4 条 → 全量 **614 → 618**

**边界**：真实设备上的剪贴板权限 / 后台计时 / Android 12+ 系统提示仍属
平台层；M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**618/618 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 51）、20（当前状态）、
CHANGELOG（本条）

---

## v0.55 · 2026-11-11

### M6：账号智能分组与两级树校验（已验证）

- 新增 `lib/data/vault/credential_groups.dart`：收藏 / 未分组 / 已泄露 /
  重复密码 / 超期未改五个智能分组，一个账号可落多个桶且桶内不重复；
  超期按 180 天精确判定、未填修改时间保守视为超期；
  两级分类树深度校验（禁止三级）
- `CredentialRepository.smartGroups()` 用已有健康样本派生，
  `VaultPage` 顶部显示「已泄露 N / 重复密码 N …」分组 chips
- 测试：`credential_groups_test.dart` 3 条 → 全量 **611 → 614**

**边界**：真实分组树 UI / 拖拽换组 / 字段模板 / 剪贴板清除仍缺；
M3 硬门槛未过，M4~M9 未完成。

**验证**：`flutter analyze` 无告警；`flutter test --concurrency=1`
**614/614 passed**；未执行构建；`pubspec.yaml` / `pubspec.lock` 未改动。

**影响文档**：README（数字）、09（§8）、14（Day 50）、20（当前状态）、
CHANGELOG（本条）

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
