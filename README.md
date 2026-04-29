---
title: AI 工程化经验知识库
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 定位：跨项目的通用 AI 协作工程化规范、方法论与技能模板。 核心原则：规范可复用、经验可迁移、样本可参考。
---

# AI 工程化经验知识库

> **定位**：跨项目的通用 AI 协作工程化规范、方法论与技能模板。  
> **适用对象**：使用 AI Agent 辅助软件工程开发的团队与个人。  
> **核心原则**：规范可复用、经验可迁移、样本可参考。

---

## 📂 目录总览

| 目录 | 内容 | 使用场景 |
|------|------|----------|
| [`specs/`](specs/) | **通用文档编写规范** — README、API、测试用例、任务卡片、主任务清单、评审报告的格式标准 | 新项目启动时，定义文档规范 |
| [`rules/`](rules/) | **评审与角色规则** — 23条评审原则、Reviewer执行协议、开发/架构/测试角色规则模板 | 质量把控、代码评审、Agent角色定义 |
| [`skills/`](skills/) | **可复用 AI 技能** — 辩证法撰写、里程碑闭环分析、决策采访 | 主Agent调度Subagent时复用 |
| [`tech/`](tech/) | **技术深度规范** — MyBatis-Plus、PostgreSQL+JSONB 等专项技术最佳实践 | 技术选型、代码审查、团队培训 |
| [`samples/`](samples/) | **经验样本** — 去项目化后的项目文档范例 + 项目骨架模板（前后端/算法/E2E/部署） | 参考结构、快速起步 |

---

## 🚀 快速开始

### 场景一：新项目启动，需要定义文档规范

```
1. 阅读 specs/README.md → 了解全套规范体系
2. 按需选用 specs/doc-spec-*.md → 定义项目文档标准
3. 参考 samples/skeleton-*.md → 选择项目骨架模板快速起步
4. 参考 samples/project-guide-sample.md → 编写项目开发者手册
```

### 场景二：引入代码评审机制

```
1. 阅读 rules/review-rules.md → 理解 23 条核心评审原则
2. 阅读 specs/reviewer-protocol.md → 配置 Reviewer Agent
3. 选用 rules/*-rules-template.md → 定义各角色约束
```

### 场景三：使用 AI 技能完成复杂任务

```
1. 浏览 skills/ 目录 → 查看可用技能清单
2. 阅读对应 SKILL.md → 理解触发条件与执行流程
3. 按技能定义调度 Subagent → 复用成熟工作流
```

---

## 📋 规范体系地图

```
文档生命周期规范
├── README 编写规范          specs/doc-spec-readme.md
├── API 文档编写规范          specs/doc-spec-api.md
├── 前端组件 API 规范         specs/doc-spec-api-frontend.md
├── 测试用例编写规范          specs/doc-spec-testcase.md
├── 任务卡片编写规范          specs/task-card-format-spec.md
├── 主任务清单编写规范        specs/master-task-list-format-spec.md
└── 评审报告编写规范          specs/review-report-spec.md

评审与质量保障
├── 23条评审原则              rules/review-rules.md
├── Reviewer 执行协议         specs/reviewer-protocol.md
└── 角色规则模板              rules/*-rules-template.md

技术规范
├── MyBatis-Plus 使用规范     tech/tech-spec-mybatis-plus.md
├── PostgreSQL+JSONB 规范     tech/tech-spec-postgresql-jsonb.md
├── Spring Boot 项目结构      tech/tech-spec-spring-boot.md
├── FastAPI 项目结构          tech/tech-spec-fastapi.md
├── Vue3 项目结构             tech/tech-spec-vue3.md
└── Docker 容器化规范         tech/tech-spec-docker.md
```

---

## 🔧 如何使用本知识库

### 作为项目级规范引用

在项目的 `AGENTS.md` 或 `README.md` 中引用本知识库的规范：

```markdown
## 文档规范
- README 编写遵循：[doc-spec-readme]({知识库路径}/specs/doc-spec-readme.md)
- API 文档编写遵循：[doc-spec-api]({知识库路径}/specs/doc-spec-api.md)
- 任务卡片编写遵循：[doc-spec-task-card]({知识库路径}/specs/doc-spec-task-card.md)

## 评审规则
- 代码评审遵循：[review-rules]({知识库路径}/rules/review-rules.md)
- Reviewer Agent 协议：[reviewer-protocol]({知识库路径}/specs/reviewer-protocol.md)
```

### 作为 Agent 知识库加载

在调度 Subagent 时注入知识库路径：

```
Knowledge Base:
- 项目知识库 → {项目根目录}/specs
- 团队知识库 → {本知识库路径}/specs
- 评审规则 → {本知识库路径}/rules/review-rules.md
```

---

## ⚠️ 使用约束

1. **0号文档是变量**：本知识库中的 `0号文件`、`PRD`、`需求主文档` 均为占位符，实际使用时替换为项目自身的核心需求文档。
2. **规范需适配**：`specs/` 中的规范为通用框架，使用前需根据项目实际情况调整章节和字段。
3. **样本仅供参考**：`samples/` 中的文档为脱敏后的项目经验，核心方法论可复用，具体实现细节需按项目调整。
4. **路径需替换**：所有规范中使用的绝对路径（如 `/home/openclaw/...`）仅为示例，实际部署时替换为真实路径。

---

## 📌 维护说明

| 事项 | 说明 |
|------|------|
| **更新频率** | 每完成一个项目迭代后，提炼可复用经验并补充 |
| **版本管理** | 各规范文件头部标注版本号，修订需更新版本和修订记录 |
| **准入标准** | 新文档需满足：①去项目化 ②有明确适用范围 ③含检查清单 ④可独立使用 |
| **废弃流程** | 过时文档移至 `archived/` 子目录（如有），保留历史版本供追溯 |

---

## 📖 推荐阅读顺序

**新成员（首次接触本知识库）**：
1. 本 README → 了解全貌（5分钟）
2. `rules/review-rules.md` §1-2 → 理解评审思维（10分钟）
3. `specs/doc-spec-task-card.md` → 理解任务卡片标准（10分钟）
4. `samples/project-guide-sample.md` → 参考项目手册结构（15分钟）

**项目启动前**：
1. `specs/doc-spec-readme.md` + `doc-spec-api.md` → 定义文档规范
2. `rules/*-rules-template.md` → 定义角色约束
3. `skills/` → 评估可复用的 AI 工作流

---

*版本: v1.0*  
*最后更新: 2026-04-29*  
*状态: ✅ 正式发布*
