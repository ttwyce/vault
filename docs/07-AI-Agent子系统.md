# 07 · AI Agent 子系统

## 1. 定位

Agent 不是聊天机器人，是**四个具体能力的载体**：

| 能力 | 用户价值 | 隐私级别 |
|---|---|---|
| **找回** | 「三个月前那篇文章在哪」→ 给出可点击入口 | L1 |
| **回顾** | 每天自动生成时间线与总结 | L0（端侧） |
| **伴写** | AI 日记（与用户日记物理隔离） | L0（端侧） |
| **代劳** | 搜索网页、整理标签、生成周报 | L1/L2 |

## 2. Agent 运行时

### 2.1 主循环（自实现，不引入编排框架）

```
run(userInput):
  messages = [systemPrompt, ...history, user(userInput)]
  for turn in 1..maxTurns(=6):
    resp = llm.chat(messages, tools = registry.schemas)
    if resp.toolCalls.isEmpty:
        return resp.text
    for call in resp.toolCalls:
        guard = policy.check(call)          # 风险分级 + 隐私闸门
        if guard.needsConfirm:
            approved = await ui.confirm(call, guard.preview)
            if !approved: messages += toolResult(call, "用户拒绝"); continue
        result = await registry.execute(call, guard.redactedArgs)
        messages += toolResult(call, result)
  return 达到最大轮次提示
```

**关键设计**：

- 最多 6 轮，防止无限工具调用烧 token
- 每次工具调用前必过 `policy.check()`，这是安全边界
- 工具结果统一截断（默认 2000 token），避免上下文爆炸

### 2.2 双模型路由

```
if task ∈ {credential, diary, daily_summary, totp}:
    → 端侧模型（L0，强制）
elif task ∈ {search, chat, summarize_note}:
    → 用户选择：端侧 / 云端（默认端侧，若已下载）
elif task ∈ {long_doc_analysis, complex_reasoning}:
    → 云端（需用户授权 L2）
```

## 3. 工具集

### 3.1 工具清单

| 工具 | 风险 | 参数 | 返回 |
|---|---|---|---|
| `search_entries` | auto | `query, kinds?, from?, to?, limit?` | 条目摘要列表（id + 标题 + 片段 + 时间） |
| `get_entry` | auto | `id, include_body?` | 条目内容（credential 返回脱敏版） |
| `list_activity` | auto | `from, to, limit?` | 活动时间线 |
| `get_stats` | auto | `period` | 统计（条目数、活跃天数、标签分布） |
| `create_entry` | confirm | `kind, title, body, tags?` | 新条目 id |
| `update_entry` | confirm | `id, title?, body?, tags?` | 更新后 rev |
| `add_tags` | confirm | `ids[], tags[]` | 成功数 |
| `archive_url` | confirm | `url, policy?` | 归档任务 id |
| `open_entry` | auto | `id` | 深链 `vault://entry/<id>`（UI 渲染成卡片） |
| `credential_health` | auto | — | 仅统计：重复 N、弱 N、超期 N |
| `web_search` | dangerous | `query` | 搜索结果摘要（需 BYOK 搜索 API） |
| `fetch_page` | dangerous | `url` | 页面正文（域名白名单 + 明确提示） |

### 3.2 工具定义示例（schema 规范）

```json
{
  "name": "search_entries",
  "description": "在用户的笔记库中检索条目。支持关键词与语义混合检索。返回条目标题、片段、时间和 ID。当用户询问过去记录过的内容时优先使用。",
  "parameters": {
    "type": "object",
    "properties": {
      "query":   { "type": "string", "description": "检索语句，自然语言或关键词均可" },
      "kinds":   { "type": "array", "items": { "type": "integer" },
                   "description": "限定类型：1笔记 2想法 3日记 5书签。不传则全部（不含AI日记）" },
      "from":    { "type": "string", "description": "起始时间 ISO8601，可选" },
      "to":      { "type": "string", "description": "结束时间 ISO8601，可选" },
      "limit":   { "type": "integer", "default": 10, "maximum": 30 }
    },
    "required": ["query"]
  }
}
```

**描述写得好不好直接决定 Agent 表现**。要求：
- 说明「什么时候该用」，不只是「做什么」
- 参数给默认值和边界
- 返回值说明清楚（尤其 `id` 可用于后续 `get_entry` / `open_entry`）

### 3.3 工具注册表抽象（为 MCP 预留）

```
abstract class AgentTool {
  String get name;
  String get description;
  Map<String, dynamic> get schema;
  RiskLevel get risk;               // auto / confirm / dangerous
  PrivacyLevel get maxPrivacy;      // 该工具允许处理的数据级别
  Future<ToolResult> execute(Map<String, dynamic> args);
}
```

二期接 MCP 时，只需实现 `McpToolAdapter implements AgentTool`，
把远程 server 的 tool 描述映射进来，**主循环零改动**。

## 4. 权限与隐私

### 4.1 风险分级

| 级别 | 行为 | 示例 |
|---|---|---|
| `auto` | 直接执行 | 检索、读取、统计 |
| `confirm` | 弹确认卡片，展示将写入的内容 | 创建、修改、打标签、归档 |
| `dangerous` | 二次确认 + 显示数据流向 | 联网搜索、抓取外部页面、导出 |

**确认卡片必须显示**：

- 将要执行的操作（人话，不是 JSON）
- 将写入/发送的**完整内容预览**
- 数据是否离开设备

### 4.2 隐私分级

| 级别 | 数据范围 | 默认用于 | 用户可见性 |
|---|---|---|---|
| **L0 端侧** | 内容不出设备 | 密码、TOTP、日记正文、日总结、AI 日记 | 无提示（承诺内） |
| **L1 脱敏** | 仅命中的片段（top-k） | 笔记问答、书签摘要 | 弹窗：「将向 <模型名> 发送 3 条笔记的 512 字」 |
| **L2 全量** | 完整条目内容 | 长文分析、跨库整理 | 逐次授权，不可记忆 |

### 4.3 密码数据的绝对边界

**以下行为在任何配置下都禁止**：

1. 密码明文进入任何 prompt 上下文
2. 密码字段进入向量化流程
3. 密码条目被 `get_entry` 返回明文（返回「已存在 · 长度 18 · 含符号」这类描述）
4. 密码条目同步到第三方 MCP server
5. 密码相关的 AI 分析走云端模型

`credential_health` 只返回聚合统计。这是**代码级硬约束**，写在 `CredentialGuard` 里，
所有工具执行前统一过一遍，而不是靠每个工具自觉。

## 5. 每日总结流水线

### 5.1 数据来源（这是成败关键）

**App 只能看到 App 内的行为。** 如果只基于此，总结会退化为「你今天写了 3 条笔记」，一周就腻。

三个层次的燃料：

| 层次 | 数据 | 价值 |
|---|---|---|
| 基础 | `activity` 表：浏览、编辑、搜索、剪藏 | 中 |
| 增强 | 用户主动快速记录（一句话「今天在调 WebDAV 限流」） | 高 |
| 外部（可选，默认关） | 日历、任务清单 | 高但隐私成本大 |

**产品形态建议**：不是「AI 写一篇日记」，而是 **「当日时间线 + 一句话总结」**。
前者可信、可验证；后者容易写成正确的废话。

### 5.2 流水线

```
触发：
  Windows: 23:50 定时（托盘常驻，可靠）
  Android: 当日首次打开 App 时补算前一天
  iOS:     同 Android（BGTask 不可靠，不做承诺）

输入：
  - 当天 activity（按 entry 聚合：浏览 N 次、编辑 M 次、停留 X 分钟）
  - 当天新增/编辑条目的标题 + 前 100 字（不读全文）
  - 当天剪藏的 URL + 标题

处理（端侧模型，L0）：
  prompt → 输出 JSON：
  {
    "headline": "今天主要在调 WebDAV 的限流重试逻辑",
    "timeline": [
      {"time": "09:20", "what": "记录了限流退避的三档策略"},
      {"time": "14:05", "what": "归档了 3 篇关于 RFC 6578 的文章"}
    ],
    "open_threads": ["冲突副本 UI 还没设计"],
    "citations": ["<entry_id>", "<entry_id>"]
  }

输出：
  写入 entry(kind=4 diary_ai, created_at=当天 23:59)
  meta.citations = [...]
```

### 5.3 滚动摘要

不要每天重读全部历史，用分层：

```
日摘要（读当天 activity）
  → 周摘要（读 7 条日摘要）
    → 月摘要（读 4 条周摘要）
      → 年摘要（读 12 条月摘要）
```

查询「去年我主要在忙什么」只需读 12 条月摘要，O(log n)。

存储：周/月/年摘要作为独立 `kind=4` 条目，`meta.granularity = week|month|year`。

## 6. AI 日记

### 6.1 三条硬规则

| 规则 | 实现 |
|---|---|
| **物理隔离** | `kind=4`，独立视图，独立配色，独立图标（🤖 标识） |
| **必须可溯源** | `meta.citations` 存 entry_id 列表，UI 每条结论可点开原文 |
| **不污染检索** | 默认检索排除 `kind=4`，设置里提供开关 |

### 6.2 AI 日记的内容

不是复述日总结，而是**第一人称的反思**：

```
「今天大部分时间在跟 WebDAV 的限流较劲。下午想到一点：退避策略其实不该只看
HTTP 状态码，还该看本地队列积压量 —— 积压多的时候应该更激进地降频。
这个想法后来记在了 <链接> 里，但当时没展开。」
```

要求：
- 引用具体条目（可点击）
- 允许表达「不确定」「没想清楚」
- 长度 150~300 字，不写长篇
- **绝不编造未发生的事**（prompt 里明确约束 + 输出后校验 citations 是否都存在）

### 6.3 用户日记 vs AI 日记

| | 用户日记（kind=3） | AI 日记（kind=4） |
|---|---|---|
| 输入 | 用户手写 | 自动生成 |
| 可编辑 | 是 | 否（可删除、可「重新生成」） |
| 检索 | 参与 | 默认排除 |
| 向量化 | 是 | 否（避免污染语义空间） |
| 加密 | 同其他条目 | 同其他条目 |
| 同步 | 是 | 是 |

**AI 日记不向量化**是个重要决定：否则用户搜自己的东西时，语义空间会被大量 AI 生成文本占据。

## 7. 云模型接入（BYOK）

### 7.1 配置项

```
服务商：DeepSeek / 通义 / Kimi / OpenRouter / 自定义
BaseURL：https://api.deepseek.com/v1
API Key：存在 flutter_secure_storage
模型名：deepseek-chat
温度：0.3（Agent 任务建议低温）
最大输出：2048
```

统一走 OpenAI 兼容的 `/chat/completions` + `tools` 参数，一套代码覆盖所有厂商。

### 7.2 成本控制

| 措施 | 说明 |
|---|---|
| 上下文裁剪 | 只保留最近 6 轮对话 + 工具结果截断 2000 token |
| 检索先行 | 先检索再生成，不把整库塞 prompt |
| 工具结果摘要化 | 检索返回标题+片段，不返回全文 |
| 每日预算提示 | 估算 token 用量，超过阈值提醒 |
| 缓存 | 相同 query 的检索结果 5 分钟内复用 |

### 7.3 Key 安全

- 存 `flutter_secure_storage`，不写日志、不进崩溃上报
- 请求日志只记 URL + 状态码 + token 数，**不记 body**
- 提供「清除所有 AI 数据」一键操作

## 8. 联网搜索（二期）

无后端 → 客户端直连搜索 API（BYOK）：

| 服务 | 国内可用性 | 备注 |
|---|---|---|
| Tavily | 差（需外网） | 质量好，专为 AI 设计 |
| Brave Search | 差 | 有免费额度 |
| Exa | 差 | 语义搜索 |
| SearXNG（自建） | 好 | 用户填自己的实例地址 |
| 模型自带联网 | 视厂商 | 最省事，优先推荐 |

**建议**：一期不做独立搜索 API，只支持「模型厂商自带的联网能力」。
二期再补 SearXNG / Tavily。

## 9. Prompt 规范

### 9.1 System Prompt 结构

```
[角色] 你是用户的私人知识库助手，可以检索其笔记、想法、日记、网页归档。

[能力边界]
- 你能看到用户的笔记内容，但看不到密码明文，这是设计如此。
- 你只能通过工具访问数据，不要凭空猜测内容。

[行为准则]
- 回答「我记过什么」类问题时，必须先调用 search_entries，不得凭印象回答。
- 引用条目时必须给出可点击的引用，让用户能跳回原文。
- 不确定时明说，不要编造条目或时间。
- 涉及密码、TOTP 时，只回答统计信息，不输出任何凭据内容。

[输出格式]
- 中文回答，简洁，不超过 300 字（除非用户要求详细）。
- 引用格式：在相关句子后用「（见：<条目标题>）」标注。
```

### 9.2 强制约束（不靠 prompt，靠代码）

| 约束 | 实现 |
|---|---|
| 不得编造引用 | 输出后校验所有 citation id 是否真实存在，不存在则移除该句 |
| 不得输出密码 | `CredentialGuard` 在结果返回前扫描，命中即替换为 `[已隐藏]` |
| 不得无限调用 | maxTurns = 6 |
| 不得超预算 | 单次对话 token 上限 |

## 10. UI 设计要点

### 10.1 对话界面

- 消息流 + 工具调用折叠卡（默认收起，显示「🔍 检索了 3 条笔记」）
- 引用以卡片形式嵌在回答里，点击直达条目详情
- 顶部显示当前模型（端侧 / 云端 + 名称）

### 10.2 入口

| 入口 | 场景 |
|---|---|
| 底部 Tab「助手」 | 完整对话 |
| 全局搜索框下方「问 AI」 | 从检索直接升级为问答 |
| 阅读器内划词「问 AI」 | 针对当前内容提问 |
| 条目详情「相关推荐」 | 语义相似条目 |

### 10.3 空状态

首次进入显示 3 个示例问题，点击即用：

- 「我上个月记过关于同步冲突的内容吗？」
- 「帮我看看这周都做了什么」
- 「有哪些网页已经打不开了？」

## 11. 验收标准

| # | 标准 |
|---|---|
| C1 | 问「三个月前那篇讲 X 的文章」能返回正确条目 + 可点击入口（top 3 命中） |
| C2 | 日总结每天自动生成，且每条结论都能溯源到真实条目 |
| C3 | 密码明文在任何情况下不出现在 prompt、日志、向量中（代码审计 + 测试） |
| C4 | 云端调用前必弹隐私提示，显示发送字数 |
| C5 | 无模型 / 无 API Key 时，Agent 入口不崩溃，给出明确引导 |
| C6 | 工具调用最多 6 轮，超时/失败有降级提示 |
| C7 | AI 日记默认不出现在搜索结果中 |
| C8 | 引用 id 不存在时自动剔除，不展示假引用 |
