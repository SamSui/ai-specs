---
name: interview
description: "决策采访技能。当需要 Owner 决策时，将问题整理成结构化选项卡片，通过 AskUserQuestion 向用户发起交互，用户选择选项或输入自定义想法即完成回答。适用于：架构师向 Owner 逐项征询决策的场景。触发词：逐项采访 / 采访 / 决策选项 / 选择决策。"
version: v3.0
last_updated: 2026-04-30
---

# Interview Skill — 决策采访技能

## 何时使用

满足以下任一条件时，触发本技能：
1. Owner 说"逐项采访我"、"逐条采访"、"一个个确认"
2. 需要 Owner 做决策，且有 ≥1 个可选方案
3. 架构师向 Owner 征询技术/产品/资源决策

**不适用于**：纯信息查询、状态汇报、无需决策的进度同步。

---

## 核心流程

```
1. 【收集】把待决策问题整理成结构化选项（背景 / 现状 / 选项 / 影响）
2. 【提问】使用 AskUserQuestion 工具向用户发出单条决策问题
3. 【等待】用户选择选项（A/B/C）或在 Other 中输入自定义想法
4. 【记录】每个决策结果 → 记录到 AGENTS.md / 更新 ADR
5. 【循环】如有下一个问题，重复步骤 2-4
```

---

## AskUserQuestion 格式规范

每次调用 **AskUserQuestion** 工具时，严格按以下结构组织参数：

### 参数映射规则

| AskUserQuestion 字段 | 内容来源 | 约束 |
|---------------------|---------|------|
| `header` | `决策采访 Q{序号}` 或分类标签（如 `Auth`、`Style`、`架构`） | 最多 12 字符 |
| `question` | **背景** + **现状** + **影响** 的完整描述 | 必须包含三要素 |
| `options` | 每个选项一个对象，含 `label` 和 `description` | 2~4 个选项 |
| `multi_select` | `false`（决策问题默认单选） | 除非用户明确要求多选 |

### 选项（options）设计规范

- `label`（1~5 词）：简洁标识 + 选项字母，如 `"A: API刷新缓存"`
- `description`：说明**选这个选项后的具体方向和结果**，禁止只写"方案A"这种无信息描述
- 若某选项是推荐项，在 `label` 末尾加 `"(Recommended)"`
- 系统会自动追加 `Other` 选项，用户可输入自定义想法，**无需在 options 中预留"

### question 文本模板

```markdown
**背景**: {为什么这个问题需要现在决策，对项目有何影响}

**现状**: {当前状态/已有的方案/已有哪些约束}

**影响**: {如果不决策，或选错选项的潜在风险是什么}
```

> 禁止将问题拆成多个 AskUserQuestion 同时发出。一次调用只问一个决策点。

---

## 交互协议

### 用户响应方式
- 点击选项按钮：`A` / `B` / `C`
- 或在 `Other` 中输入想法：_"我觉得A更合适因为..."_
- 文字回复也视为有效决策，主 Agent 负责解析意图

### 一个一个问题来（关键约束）
- **每次只调用一次 AskUserQuestion**，等用户回答后再问下一个
- AskUserQuestion 工具本身限制了一次只能提一个问题，天然 enforcing 此约束
- 禁止在单次 question 文本中嵌入多个独立问题

### 决策结果记录
每次用户选择后，立即在对话中确认并记录：
```markdown
✅ Q-{序号} 决策：{选项字母 / 自定义摘要}
→ 决策时间: {HH:MM}
→ 落地位置: {ADR文件名或章节}
```

同时写入项目文档（按优先级）：
1. 若涉及架构变更 → 更新 `document/decisions/ADR-xxx.md`
2. 若影响 Agent 行为规范 → 更新 `AGENTS.md`
3. 若影响开发规范 → 更新 `document/team/specs/` 下对应文件

---

## 连续采访模式（多个相关决策）

如果有一系列相关决策需要连续确认：

1. **先预告总数**：在第一个 AskUserQuestion 的 `question` 开头加 `📋 决策采访（共 N 项，当前第 1 项）`
2. **逐个调用**：每轮等用户回复后，再发起下一轮 AskUserQuestion
3. **中间摘要**：每完成 3~5 个决策后，输出已确认决策的摘要列表，帮助用户保持上下文

禁止将多个问题塞进一次 AskUserQuestion 的 options 中（如把"是否要做A"和"是否要做B"并列成两个选项）。

---

## 常见错误

| # | 错误 | 正确做法 |
|---|------|---------|
| 1 | 一次 AskUserQuestion 里问 2 个独立问题 | 一次只问 1 个 |
| 2 | 选项描述太抽象（如 label 只写"方案A"） | label 简述 + description 写明方向和结果 |
| 3 | question 中没有说清楚背景/现状/影响 | 三要素必须完整 |
| 4 | 用户没回复就继续发下一个问题 | AskUserQuestion 会阻塞等待，必须等回复 |
| 5 | 决策结果没落地到文档 | 立即更新 ADR / AGENTS.md |

---

## 示例对话

**架构师**（调用 AskUserQuestion）：

```json
{
  "header": "决策采访 Q1",
  "question": "**背景**: T-M2-013 热更新方案需要确定实现方式，这会影响 API 网关和配置中心的改动范围。\n\n**现状**: M1.4 已有静态配置读取机制，无热更新能力。\n\n**影响**: 选 B 会显著增加 M2 开发复杂度；选 C 影响后续 M3 验收。",
  "options": [
    {"label": "A: API刷新缓存 (Recommended)", "description": "PUT API 更新 JSON 后主动刷新内存缓存，不改配置中心"},
    {"label": "B: 引入配置中心", "description": "引入 Apollo/Nacos 管理配置，增加系统复杂度"},
    {"label": "C: 暂不上线", "description": "热更新记录为技术债务，影响 M3 验收"}
  ]
}
```

**Owner**: 选择 `A`

**架构师**:
> ✅ Q1 决策：A（PUT API 刷新内存缓存）
>
> 落地位置：`document/decisions/ADR-013-hot-update.md`
>
> ---
>
> （调用 AskUserQuestion 开始 Q2）

---

## 与 task-publish 的关系

- **task-publish** 管"任务怎么调度执行"
- **interview** 管"架构师和 Owner 之间的决策闭环"

两者结合：Owner 通过 interview 做决策 → 架构师通过 task-publish 调度执行。
