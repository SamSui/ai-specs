---
name: ai-dialectic-writing
description: "AI 辩证法撰写技术文档。五步迭代法 + 双持久化 Subagent，产出专业级文档。触发词：辩证法撰写 / 写报告 / AI撰写 / 迭代法写 / 深度调研。适用场景：技术方案、研究报告、深度调研、竞品分析。"
---

# AI 辩证法撰写技术文档

**当前会话 Agent 即为主 Agent（调度总指挥）**，负责用户交互、任务编排、方向把控。Writer 与 Reviewer 作为双持久化 Subagent 执行具体工作。

---

## 核心约束

- ❌ 禁止主 Agent 替代 Writer/Reviewer 执行具体任务（只做调度、评审、决策）
- ❌ 禁止跳过 Reviewer 直接进入下一轮修订
- ❌ 禁止 Writer/Reviewer 产出物放入个人 workspace
- ❌ 禁止在消息正文发完整文档（全通过文件消息发送）
- ❌ Writer/Reviewer 不得使用 hardcoded 绝对路径，所有路径由主 Agent 在 dispatch 时注入

---

## 角色定义

**主 Agent**（当前会话 Agent）：
- 用户交互、任务解析、Subagent 调度与评审、决策走向
- 评审职责（对 Reviewer 产出物）：✅ 格式规范 · ✅ 逻辑前后一致性 · ✅ 风格要求
- 不负责：❌ 评审意见的逻辑正确性 · ❌ 专业术语准确性 · ❌ 修订意见覆盖度

**Writer**（持久化 Subagent）：
- 素材搜集 → 初稿生成 → 修订 → 终稿润色 · 文件管理

**Reviewer**（持久化 Subagent）：
- 多方向专家评审 · 问题清单生成 · 质量评级

---

## 目录结构

```
reports/{TaskId}/
├── task-card-writer.md       # Writer 任务卡片
├── task-card-reviewer.md     # Reviewer 任务卡片（含专家领域、评审方向）
├── master-track.md           # 执行总表
├── materials/               # 素材文件夹
│   ├── 00-index.md          # 素材索引（各素材摘要 + 来源链接）
│   └── 0N-xxx.md           # 单个素材文档（按需命名）
├── report.md                # 当前报告（含附录：修订记录）；每次修订前归档
├── review.md                # 最新评审意见；新一轮评审前归档
├── archived/                # 中间版本归档
│   ├── report_v{N}.md       # 修订前的版本
│   └── review_v{N}.md       # 新评审前的版本
└── final.md                 # 终稿（无修订痕迹，可独立阅读）
```

> 版本与修订记录作为文档内部章节，不体现在文件名中。每轮评审修订在同一文件上增量更新。

---

## 素材搜集工具

**工具**：`web_search` + `web_fetch`

**顺序**：
1. `web_search` 搜索相关资料
2. `web_fetch` 直接抓取目标页面
3. `web_fetch` 失败（网络阻断）→ `curl --socks5-hostname 10.8.6.160:11080` 访问
4. 仍失败 → `curl --socks5-hostname 10.8.6.160:11080` 访问

**素材命名**：每个素材独立文件，`materials/0{N}-{来源简称}.md`；`00-index.md` 汇总索引（摘要 + URL）。

---

## 核心流程

```
步骤 0：任务确认 → 步骤 1：素材搜集 → 步骤 2：初稿生成
  → 步骤 3：评审 → 步骤 4：修订（2-3 轮）→ 步骤 5：终稿润色 → 归档交付
```

---

## 步骤 0：任务确认

**主 Agent 与用户确认**：
- 文档主题 / 类型：`[深度调研]` / `[技术方案]` / `[竞品分析]` / `[研究报告]`
- 评审方向（≥2 个）：`[技术可行性]` `[数据准确性]` `[市场分析]` `[合规风险]` 等
- **REPORTS_ROOT**：`/home/openclaw/.openclaw/workspace/shared/reports/{TaskId}/`（或项目子路径，由主Agent在 dispatch 时确认）

**主 Agent 注入 REPORTS_ROOT**：
在调度 Writer/Reviewer 之前，确认并注入 REPORTS_ROOT 前缀到 task string 的 Deliver To 字段。Writer/Reviewer 不得自行构造路径。

**创建任务卡片**：
- `task-card-writer.md`：主题、评审方向、Writer 职责边界
- `task-card-reviewer.md`：专家专业领域定义、评审方向及具体评审要点

---

## 步骤 1：素材搜集（Writer 执行）

**主 Agent 调度**：注入 REPORTS_ROOT，启动 Writer Subagent，交代主题 / 评审方向 / `{REPORTS_ROOT}/materials/` 绝对路径；要求：必须联网搜索，每个素材独立文件，建立索引。

**Writer 产出**：
- `{REPORTS_ROOT}/materials/00-index.md`：素材索引（各素材摘要 + 来源 URL）
- `{REPORTS_ROOT}/materials/0{N}-{xxx}.md`：各素材文档
- Handoff → Next 注"请主Agent确认素材方向"

**主 Agent 确认**：浏览素材索引，决定是否开始初稿。

---

## 步骤 2：初稿生成（Writer 执行）

**主 Agent 调度**：Writer 基于 `{REPORTS_ROOT}/materials/` 生成初稿，写入 `{REPORTS_ROOT}/report.md`。

**report.md 结构**：
```markdown
# {主题}

## 摘要
...

## 章节 1
...

## 附录：修订记录
（第 {N} 轮修订 YYYY-MM-DD）
- 问题 #1：...（位置 + 修改内容 + 理由）
```

**Writer 产出**：
- `{REPORTS_ROOT}/report.md`：完整初稿
- Handoff → Next 注"请主Agent调度 Reviewer 评审"

---

## 步骤 3：专家评审（Reviewer 执行）

**主 Agent 调度**：将 `{REPORTS_ROOT}/report.md` 注入后发给 Reviewer Subagent。

**review.md 结构**：
```markdown
# 评审意见：{主题}

## 总体评级
**[A/B/C/D]（具体说明）**

## 分方向评审
### 方向 1：[技术可行性]
- ✅ 优势 / ⚠️ 需补充 / ❌ 风险

### 方向 2：[数据准确性]
...

## 具体问题清单
| # | 位置 | 问题描述 | 严重度 |
|---|------|---------|--------|
| 1 | 第 X 章 | ... | P1 |
| 2 | 第 X 章 | ... | P2 |

## 修订建议
1. ...
```

**Reviewer 产出**：
- `review.md`：评审意见全文
- Handoff → Next 注"请主Agent决策走向"

---

## 步骤 4：修订（2-3 轮迭代）

**主 Agent 决策**：根据评级决定轮数 — A/B+ → 1 轮；B/B- → 2 轮；C/D → 3 轮。

**进入新评审前的归档**：
```bash
cp {REPORTS_ROOT}/report.md {REPORTS_ROOT}/archived/report_v{N}.md
cp {REPORTS_ROOT}/review.md {REPORTS_ROOT}/archived/review_v{N}.md
```

**Writer 修订**：在 `{REPORTS_ROOT}/report.md` 末尾追加：
```markdown
## 附录：修订记录
### 第 {N} 轮修订（YYYY-MM-DD）
- 响应问题 #1：...（位置 + 修改内容 + 理由）
```

**Reviewer 再审**：更新 `review.md`，新增一轮评审记录，标注残留问题。循环直到主 Agent 决策进入步骤 5。

---

## 步骤 5：终稿润色（Writer 执行）

**主 Agent 调度**：确认进入终稿，Writer 润色 `{REPORTS_ROOT}/report.md` → 生成 `{REPORTS_ROOT}/final.md`。

**润色要求**：剔除修订痕迹 · 确保文档可独立阅读 · 统一术语文风 · 检查逻辑连贯性。

**Writer 产出**：
- `final.md`：终稿 v2.0
- Handoff → Next 注"请主Agent归档交付"

---

## 步骤 6：归档交付（主 Agent 执行）

```bash
cp {REPORTS_ROOT}/report.md {REPORTS_ROOT}/archived/report_final.md
cp {REPORTS_ROOT}/review.md {REPORTS_ROOT}/archived/review_final.md
```

**主 Agent 操作**：
1. 更新 `master-track.md` 状态 → ✅ 完成
2. 文件消息发送 `final.md` 给用户
3. 输出执行报告

**执行报告格式**：
```
# 执行报告
- 撰写时间: YYYY-MM-DD HH:MM
- 文档主题: {主题}
- 评审轮数: N
- 遗留问题: N（P1 以上）

## 评审记录
| 轮次 | 评级 | 主要问题 |
|------|------|---------|
| 第 1 轮 | B+ | P1 X 个，P2 X 个 |
| 第 2 轮 | A | 无 |

## 交付物
- 终稿：final.md
- 中间文件已归档至 archived/
```

---

## Writer 任务单核心要点

> 详细内容 → task-publish SKILL

- **Task**：撰写《{主题}》{类型}报告
- **Scope**：素材搜集 → 初稿 → 修订 → 终稿润色
- **Output**：`{REPORTS_ROOT}/materials/` + `{REPORTS_ROOT}/report.md` + `{REPORTS_ROOT}/final.md`
- **Deliver To**：`{REPORTS_ROOT}/`
- **素材搜集**：`web_search` + `web_fetch`；每个素材独立文件；建立 `00-index.md` 索引
- **禁止**：产出物放入个人 workspace；素材搜集不联网仅凭知识

---

## Reviewer 任务单核心要点

> 详细内容 → task-publish SKILL

- **Task**：对《{主题}》报告进行多方向专家评审
- **Scope**：分方向评审 · 问题清单 · 质量评级
- **Output**：`{REPORTS_ROOT}/review.md`
- **Deliver To**：`{REPORTS_ROOT}/`
- **Dependency**：Writer 完成 `report.md`
- **禁止**：产出物放入个人 workspace；评审泛泛而谈无具体位置

---

## 参考文档

- `~/.openclaw/skills/task-publish/SKILL.md` — 调度与 Handoff 协议（详细）
- `~/.openclaw/skills/task-publish/references/task-lifecycle.md`
- `~/.openclaw/skills/task-publish/references/communication.md`
- `~/.openclaw/skills/task-publish/references/patterns.md`
- `~/.openclaw/skills/ai-dialectic-writing/references/dialectic-flow.md` — 辩证法流程详解（按需）
