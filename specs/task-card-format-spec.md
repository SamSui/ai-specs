---
title: 任务卡片编写规范 v2.2
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 基于: 任务卡片规范 v2.1 + Agent 系统优化经验 本版变化: ① 任务内容颗粒度规范 ② 全文去项目化 ③ 精简 tokens ④ 增强约束显著性 ⑤ 路径规范独立章节 ⑥ 知识库路径必填
---

# 任务卡片编写规范 v2.2

**版本**: v2.2
**基于**: 任务卡片规范 v2.1 + Agent 系统优化经验
**本版变化**: ① 任务内容颗粒度规范 ② 全文去项目化 ③ 精简 tokens ④ 增强约束显著性 ⑤ 路径规范独立章节 ⑥ 知识库路径必填

---

## 核心约束

这张规范有且仅有三条核心约束。**违反任意一条 → 卡片失效**。

**GC-01: Scope 必须精确到文件/模块级别**
- Scope 模糊 = 范围蔓延的根因
- ❌ `backend/` · `algo/`
- ✅ `backend/data-adapter` · `backend/data-adapter/src/main/java/com.[公司域名].[项目缩写].adapter/*Adapter.java`

**GC-02: 验收标准必须独立存在且每条可测试**
- 无独立 AC = 无法判断完成 = 交付变成黑盒
- 必须在独立的 `## Acceptance Criteria` 章节，表格格式，≥3条
- 每条必须包含验证方式（执行命令验证）

**GC-03: Boundary 必须明确 ✅/❌**
- 无边界 = subagent 不知道什么不该做 = 产出与预期不符
- ✅ **In Scope**（做什么：明确范围，精确到动作）
- ❌ **Out of Scope**（不做什么：明确排除，精准防蔓延）

---

## 目录结构

```
tasks/
└── {YYYYMMDD-M?-标题}/           # 主任务目录
    ├── index.md                  # 主任务清单
    ├── master-track.md           # 任务总表
    ├── cards/                    # 评审报告目录（任务卡片执行过程中由Reviewer生成）
    │   └── T-XXX-001.md
    └── reviews/                  # 评审报告目录（新增）
        ├── T-XXX-001-review.md   # 单任务评审报告
        ├── T-XXX-002-review.md
```

**命名规范**：
- 单任务报告：`{T-XXX-###}-review.md`
- 评审索引：`reviews/index.md`

---

## 文件路径规范

### 两类路径字段的区分

任务卡片有两类路径字段，写法规则不同：

**Definition 类字段（KB 章节）→ 写绝对路径**：
- `## Knowledge Base` 章节：定义知识库的实际位置，**必须写绝对路径**
  - 项目知识库 → `~/projects/{项目名}/specs`
  - 团队知识库 → `~/specs`
  - 记忆知识库 → `memory_search` skill

**Usage 类字段（Reference / Deliver To / Scope）→ 用前缀或相对路径**：
- ✅ `$project_kb/requirements-spec.md`（前缀展开为 `{项目根目录}/specs/requirements-spec.md`）
- ✅ `$team_kb/task-card-format-spec.md`（前缀展开为 `document/team/specs/task-card-format-spec.md`）
- ✅ 绝对路径（如 `/home/USER/.../spec.md`）
- ✅ 项目相对路径（如 `specs/user-stories.md`）
- ❌ 裸文件名（`spec.md`）—— 无法定位

### 有效路径类型速查

| 字段类型 | 可用格式 | 示例 |
|---------|---------|------|
| Reference / Deliver To / Scope | `$project_kb/xxx` / `$team_kb/xxx` / 绝对路径 / 项目相对路径 | `$project_kb/requirements-spec.md` |
| Knowledge Base 章节 | **绝对路径**（三个入口逐一列出） | `项目知识库 → /home/.../{项目名}/specs` |

### Knowledge Base 章节标准写法

```markdown
## Knowledge Base
- **项目知识库** → ~/projects/{项目名}/specs
- **团队知识库** → ~/specs
- **记忆知识库** → memory_search skill
```

**【常见错误】Knowledge Base 章节写了 `$project_kb/` 而非绝对路径**，这会使 subagent 无法确定实际路径。KB 章节是 Definition，不是 Usage。

---

## 必填字段

全部字段均为必填（任何字段缺失 → 卡片失效）：

- **Task ID**: `T-{前缀}-{序号}`，唯一编号
- **Task**: ≤30字，动词+名词，无歧义
- **Scope**: 精确到文件/模块级别
- **Background**: 为什么做，说明问题来源
- **Task Description**: 条目式，描述交付物和指标，不描述实现步骤
- **Acceptance Criteria**: 独立章节，表格格式，≥3条，每条含验证方式
- **Boundary**: ✅/❌ 格式，明确做什么和不做什么
- **Role**: 执行这个任务卡的角色，如：架构师、产品经理、测试工程师、前端工程师、后端工程师、算法工程师
- **Reference**: 任务卡需要引用的参考文档有效路径（见 §Path Spec）
- **Output**: 产出物描述
- **Deliver To**: 有效路径（见 §Path Spec），禁止裸文件名
- **Dependency**: 前置 Task ID 或"无"
- **Knowledge Base**: 见 §Knowledge Base
- **Requirements**: 执行前准入条件（环境/工具/权限）
- **Notes**: 易错点，来自真实项目经验

---

## 字段详细说明

### Task ID
`T-{前缀}-{序号}`，如 `T-REV-001`。禁止与已有 ID 冲突。

### Task
≤30字，动词+名词结构，无歧义。

### Scope
**必须精确到文件/模块级别**，禁止泛指。

- ❌ `backend/` · `algo/`
- ✅ `backend/data-adapter` · `backend/data-adapter/src/main/java/com.[公司域名].[项目缩写].adapter/*Adapter.java`

### Background
**为什么做**。说明问题来源和解决什么。上游决策、评审发现、技术债均在此标注。

### Task Description

**原则**：描述"交付什么"和"做到什么程度"，不描述"怎么做"。

**调度者负责**（必须明确）：
- 顶层架构和技术选型框架（用什么语言/框架/中间件）
- 具体指标数值（响应时间≤Xms / 内存<500MB / 支持5GB文件）
- 交付物和里程碑定义

**subagent 负责**（禁止调度者侵入）：
- 具体实现路径和代码细节
- 算法实现方式
- 代码结构和内部设计

**越界 vs 正确**：
- ❌ "用 BufferedReader 逐行读取，HashMap 去重" → ✅ "流式去重算法，内存<500MB，支持5GB文件（引用 AC-03）"
- ❌ "Phase 1→Phase 2→Phase 3 操作步骤" → ✅ "分三个里程碑交付，每个里程碑产出物明确（引用 AC-01~AC-02）"
- ❌ "DataAdapter 接口定义 supportedExtensions()..." → ✅ "设计 DataAdapter 接口体系，顶层框架：Consumer模式+Stream API"

### Acceptance Criteria

**≥3条，每条必须包含验证方式**。

- ❌ `代码可运行` — 不可测试
- ❌ `功能完整` — 主观判断
- ✅ `mvn compile BUILD SUCCESS，输出无 error`
- ✅ `ls backend/data-adapter/src/main/java/com.[公司域名].[项目缩写].adapter/*.java | wc -l` 输出 7

**格式**：
```markdown
## Acceptance Criteria
| # | 标准描述 | 验证方式 |
|---|---------|---------|
| 1 | {可量化} | {执行命令} |
| 2 | {可量化} | {执行命令} |
| 3 | {可量化} | {执行命令} |
```

### Boundary

```markdown
- ✅ **In Scope**: {明确范围}
- ❌ **Out of Scope**: {明确排除}
```

### Requirements

执行前必须满足的前提条件（环境/工具/权限）。可测试的交付条件必须写入 Acceptance Criteria，不得写在 Requirements 里。

**归属规则**：
- JDK 1.8 已安装 → Requirements（执行前环境前提）
- 代码逻辑正确可读 → Requirements（定性条件，无法命令验证，可省略）
- Maven 编译通过 → **Acceptance Criteria**（可测试）
- 5GB 文件 Heap < 500MB → **Acceptance Criteria**（可测试）

### Deliver To
有效路径（见 §Path Spec）。禁止裸文件名。

### Dependency
前置 Task ID 或"无"。

---

## 标准模板

```markdown
# {Task Name}

**Task ID**: T-XXX-001
**Task**: {≤30字，动词+名词}
**Role**: {Agent ID 或人名}
**Priority**: 🔴P0 / 🟡P1 / 🟡P2
**Estimated Time**: Xh
**Deadline**: YYYY-MM-DD HH:MM

---

## Task Info
- **Scope**: {精确文件/模块路径}
- **Reference**: {参考文档路径，见 §Path Spec}
  - $project_kb/requirements-spec.md
  - $team_kb/task-card-format-spec.md
  - ...
- **Output**: {产出物描述}
- **Deliver To**: {有效路径，见 §Path Spec}
- **Dependency**: {Task ID 或无}

## Background
{为什么做，解决什么问题，问题来源}

## Task Description
1. {交付物/指标 1}
2. {交付物/指标 2}
3. {交付物/指标 3}

## Requirements
- {执行前准入条件}

## Notes
- {易错点 1，来自真实项目经验}
- {易错点 2，来自真实项目经验}

## Boundary
- ✅ **In Scope**: {范围}
- ❌ **Out of Scope**: {排除项}

## Acceptance Criteria
| # | 标准描述 | 验证方式 |
|---|---------|---------|
| 1 | {可量化} | {执行命令} |
| 2 | {可量化} | {执行命令} |
| 3 | {可量化} | {执行命令} |

## Knowledge Base
- **项目知识库** → ~/projects/{项目名}/specs
- **团队知识库** → ~/specs
- **记忆知识库** → memory_search skill
```

---

## 任务卡片调度前检查

任务卡片进入调度队列前必须通过。检查不通过 → 禁止调度。

### 检查项说明

- CHECK-01: Background 章节存在
- CHECK-02: Boundary 存在且边界清楚
- CHECK-03: Scope 存在且明确
- CHECK-04: Task Description 存在、内容清晰、AC引用完整、调度者与subagent职责清晰不越界
- CHECK-05: Acceptance Criteria 存在且 ≥ 3条
- CHECK-06: Knowledge Base 章节存在
- CHECK-07: 所有文件路径符合 §Path Spec 规范，无歧义

---

## 编写检查清单

- [ ] Task ID 唯一且连续
- [ ] Task ≤ 30字
- [ ] Scope 精确到文件/模块级别
- [ ] Reference 包含核心参考
- [ ] Output 包含具体文件名
- [ ] Deliver To 为有效路径（见 §Path Spec）
- [ ] Dependency 正确标注
- [ ] **Background 必填**
- [ ] **Task Description 必填，条目式，颗粒度恰当**
- [ ] **Boundary ✅/❌ 明确**
- [ ] **Acceptance Criteria ≥ 3条，每条含验证方式，独立章节**
- [ ] Requirements 与 Acceptance Criteria 区分正确
- [ ] Knowledge Base 章节存在，三个入口齐全
- [ ] 无 Markdown 表格（代码块外，改用列表）
- [ ] 强调词保留（✅/❌/🔴/🟡）

---

## 反模式

### Scope 泛指
- ❌ `backend/` · `specs/`
- ✅ `backend/data-adapter/src/main/java/com.[公司域名].[项目缩写].adapter/*Adapter.java`

### Acceptance Criteria 不可测试
- ❌ `代码可运行` · `功能完整` · `性能良好`
- ✅ `mvn compile BUILD SUCCESS` · `ls file | wc -l ≥ 7`

### Requirements 与 Acceptance Criteria 混用
- ❌ 可测试条件写在 Requirements 里，无独立 Acceptance Criteria 章节
- ✅ 独立的 `Acceptance Criteria` 章节

### Boundary 缺失
- ❌ 泛指"完成相关功能"
- ✅ ✅ In Scope: 实现用户登录；❌ Out of Scope: 不包含权限管理

### 路径无效
- ❌ `spec.md` · `T-FIX-01.md`（裸文件名）
- ✅ 绝对路径或 `../../archived/tasks/20260405-M1-fix/cards/T-FIX-01.md`

---

## Handoff 证据规范

```bash
ls -la {Deliver To}
file {Deliver To}
wc -c {Deliver To}
```

---

## 规范体系

```
主任务清单（Owner审批）
    ↓ 拆解
任务卡片（按本规范）
    ↓ 执行
subagent 产出
    ↓ 评审（SPEC-REVIEWER）
MilestoneReview（SPEC-MILESTONE）
    ↓ 调度闭环（SPEC-SCHEDULING）
```
