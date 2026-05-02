---
name: ai-dialectic-writing
description: "AI 辩证法撰写技术文档。五步迭代法 + Kimi Agent 双 Subagent 调度，产出专业级文档。触发词：辩证法撰写 / 写报告 / AI撰写 / 迭代法写 / 深度调研。适用场景：技术方案、研究报告、深度调研、竞品分析。"
version: v3.0
last_updated: 2026-04-30
---

# AI 辩证法撰写技术文档

**当前会话 Agent 即为主 Agent（调度总指挥）**，负责用户交互、任务编排、方向把控。Writer 与 Reviewer 作为 Kimi `Agent` Subagent 执行具体工作，通过文件系统传递产出。

---

## 核心约束

- ❌ 禁止主 Agent 替代 Writer/Reviewer 执行具体任务（只做调度、评审、决策）
- ❌ 禁止跳过 Reviewer 直接进入下一轮修订
- ❌ 禁止 Writer/Reviewer 在对话中输出完整文档内容（全写入指定目录文件）
- ❌ 禁止 Writer/Reviewer 写入 REPORTS_ROOT 以外的目录
- ❌ Writer/Reviewer 不得使用 hardcoded 绝对路径，所有路径由主 Agent 在 dispatch 时注入

---

## 角色定义

**主 Agent**（当前会话 Agent）：
- 用户交互、任务解析、Subagent 调度与评审、决策走向
- 通过 `Agent` 工具创建/恢复 Writer 和 Reviewer 实例
- 评审职责（对 Reviewer 产出物）：✅ 格式规范 · ✅ 逻辑前后一致性 · ✅ 风格要求
- 不负责：❌ 评审意见的逻辑正确性 · ❌ 专业术语准确性 · ❌ 修订意见覆盖度

**Writer**（Kimi Agent Subagent，实例 ID 建议 `writer-{TaskId}`）：
- 素材搜集 → 初稿生成 → 修订 → 终稿润色 · 文件管理
- 通过文件系统读写报告，不在对话中输出全文

**Reviewer**（Kimi Agent Subagent，实例 ID 建议 `reviewer-{TaskId}`）：
- 多方向专家评审 · 问题清单生成 · 质量评级
- 通过文件系统读写评审意见

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

**工具**：`SearchWeb` + `FetchURL`

**顺序**：
1. `SearchWeb` 搜索相关资料
2. `FetchURL` 直接抓取目标页面
3. 仍失败 → 标记为"访问受限"，记录已知信息

**素材命名**：每个素材独立文件，`materials/0{N}-{来源简称}.md`；`00-index.md` 汇总索引（摘要 + URL）。

---

## 核心流程

```
步骤 0：任务确认 → 步骤 1：素材搜集 → 步骤 2：初稿生成
  → 步骤 3：评审 → 步骤 4：修订（2-3 轮）→ 步骤 5：终稿润色 → 步骤 6：归档交付
```

---

## Kimi Agent 调度协议

主 Agent 与 Writer/Reviewer 通过以下方式协作：

1. **状态传递**：通过文件系统（`task-card-*.md`、`report.md`、`review.md`）
2. **实例管理**：
   - 创建 Writer：`Agent(description="Writer-xxx", prompt="...")`，记录返回的 `agent_id`
   - 恢复 Writer：后续轮次使用 `Agent(resume="{agent_id}", prompt="...")`
   - Reviewer 同理
3. **交付验收**：Subagent 完成后，主 Agent 用 `ReadFile` 读取产出文件进行验收
4. **阻塞等待**：每步调度使用 foreground Agent（`run_in_background=false`），主 Agent 等待完成后再决策

> Subagent 的 prompt 中必须注入 `REPORTS_ROOT` 绝对路径，并明确告知"读取任务卡 → 执行 → 写入产出文件"的流程。

---

## 步骤 0：任务确认

**主 Agent 与用户确认**：
- 文档主题 / 类型：`[深度调研]` / `[技术方案]` / `[竞品分析]` / `[研究报告]`
- 评审方向（≥2 个）：`[技术可行性]` `[数据准确性]` `[市场分析]` `[合规风险]` 等
- **REPORTS_ROOT**：`~/reports/{TaskId}/`（或项目子路径，由主 Agent 在 dispatch 时确认）

**主 Agent 准备任务卡片**：
- `task-card-writer.md`：主题、评审方向、Writer 职责边界、REPORTS_ROOT
- `task-card-reviewer.md`：专家专业领域定义、评审方向及具体评审要点、REPORTS_ROOT

**创建目录结构**：
```bash
mkdir -p {REPORTS_ROOT}/materials {REPORTS_ROOT}/archived
```

---

## 步骤 1：素材搜集（Writer Agent 执行）

**主 Agent 调度**：
创建 Writer Agent，prompt 包含：
- `REPORTS_ROOT` 绝对路径
- 任务主题、评审方向
- 指令：读取 `task-card-writer.md` → 联网搜集素材 → 写入 `materials/`

**Writer 执行**：
- 使用 `SearchWeb` 搜索、`FetchURL` 抓取
- 每个素材独立文件：`{REPORTS_ROOT}/materials/0{N}-{xxx}.md`
- 建立索引：`{REPORTS_ROOT}/materials/00-index.md`

**Writer 产出**：
- `{REPORTS_ROOT}/materials/00-index.md`
- `{REPORTS_ROOT}/materials/0{N}-{xxx}.md`

**主 Agent 确认**：读取 `00-index.md`，浏览素材方向，决定是否进入初稿。若素材不足，恢复 Writer Agent 补充搜集。

---

## 步骤 2：初稿生成（Writer Agent 执行）

**主 Agent 调度**：
恢复 Writer Agent（`resume`），prompt 更新为初稿任务：
- 基于 `materials/` 生成初稿
- 写入 `{REPORTS_ROOT}/report.md`

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

**主 Agent 验收**：读取 `report.md`，确认格式和完整性，决定是否调度 Reviewer。

---

## 步骤 3：专家评审（Reviewer Agent 执行）

**主 Agent 调度**：
创建 Reviewer Agent，prompt 包含：
- `REPORTS_ROOT` 绝对路径
- 指令：读取 `task-card-reviewer.md` → 读取 `report.md` → 生成评审意见 → 写入 `review.md`

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
- `{REPORTS_ROOT}/review.md`

**主 Agent 决策**：根据评级决定修订轮数 — A/B+ → 1 轮；B/B- → 2 轮；C/D → 3 轮。

---

## 步骤 4：修订（2-3 轮迭代）

**进入新评审前的归档**（主 Agent 执行）：
```bash
cp {REPORTS_ROOT}/report.md {REPORTS_ROOT}/archived/report_v{N}.md
cp {REPORTS_ROOT}/review.md {REPORTS_ROOT}/archived/review_v{N}.md
```

**Writer 修订**：
主 Agent 恢复 Writer Agent，prompt 包含：
- 当前 `report.md` 路径
- 最新 `review.md` 路径（或将其关键内容直接注入 prompt）
- 指令：按评审意见修订，在 `report.md` 末尾追加修订记录

```markdown
## 附录：修订记录
### 第 {N} 轮修订（YYYY-MM-DD）
- 响应问题 #1：...（位置 + 修改内容 + 理由）
```

**Reviewer 再审**：
主 Agent 恢复 Reviewer Agent，prompt 更新为"基于修订后的 report.md 重新评审"，更新 `review.md`。

**循环直到**主 Agent 决策进入步骤 5。

---

## 步骤 5：终稿润色（Writer Agent 执行）

**主 Agent 调度**：
恢复 Writer Agent，prompt 更新为终稿任务：
- 读取 `report.md`
- 润色后生成 `{REPORTS_ROOT}/final.md`

**润色要求**：剔除修订痕迹 · 确保文档可独立阅读 · 统一术语文风 · 检查逻辑连贯性。

**Writer 产出**：
- `{REPORTS_ROOT}/final.md`：终稿

---

## 步骤 6：归档交付（主 Agent 执行）

```bash
cp {REPORTS_ROOT}/report.md {REPORTS_ROOT}/archived/report_final.md
cp {REPORTS_ROOT}/review.md {REPORTS_ROOT}/archived/review_final.md
```

**主 Agent 操作**：
1. 更新 `master-track.md` 状态 → ✅ 完成
2. 读取 `final.md`，向用户汇报终稿路径和摘要
3. 输出执行报告

**执行报告格式**：
```markdown
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
- 终稿：{REPORTS_ROOT}/final.md
- 中间文件已归档至 {REPORTS_ROOT}/archived/
```

---

## Writer 任务单核心要点

- **Task**：撰写《{主题}》{类型}报告
- **Scope**：素材搜集 → 初稿 → 修订 → 终稿润色
- **Input**：`{REPORTS_ROOT}/task-card-writer.md` + `{REPORTS_ROOT}/materials/`
- **Output**：`{REPORTS_ROOT}/materials/` + `{REPORTS_ROOT}/report.md` + `{REPORTS_ROOT}/final.md`
- **素材搜集**：`SearchWeb` + `FetchURL`；每个素材独立文件；建立 `00-index.md` 索引
- **修订要求**：按 `review.md` 逐条响应，在附录记录修改内容
- **禁止**：产出物写入 REPORTS_ROOT 以外；素材搜集不联网仅凭知识；在对话中输出全文

---

## Reviewer 任务单核心要点

- **Task**：对《{主题}》报告进行多方向专家评审
- **Scope**：分方向评审 · 问题清单 · 质量评级
- **Input**：`{REPORTS_ROOT}/task-card-reviewer.md` + `{REPORTS_ROOT}/report.md`
- **Output**：`{REPORTS_ROOT}/review.md`
- **Dependency**：Writer 完成 `report.md`
- **评审方向**：严格按 `task-card-reviewer.md` 中定义的专家领域和方向执行
- **禁止**：产出物写入 REPORTS_ROOT 以外；评审泛泛而谈无具体位置；在对话中输出全文
