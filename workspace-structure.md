---
title: 工作区目录结构
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 在创建或修改任何文件前，请确认： - [ ] 此内容属于私有还是共享？
---

### ✅ 操作前检查清单

在创建或修改任何文件前，请确认：

- [ ] 此内容属于私有还是共享？
- [ ] 我是否访问了正确的目录？
- [ ] 我是否尊重了他人的隐私边界？
- [ ] 是否符合目录结构规范？
author: 顾小宇
tags: [知识库, AI工程化, 指南]
description: 以下是工作区的目录结构及各文档、文件夹的用途。我将严格遵守此结构来管理工作区。 ~/.openclaw/workspace/
---

## 工作区目录结构

以下是工作区的目录结构及各文档、文件夹的用途。我将严格遵守此结构来管理工作区。

```
~/.openclaw/workspace/
├─ agents/
│   ├─ {agentId}/        - 我的私有空间，所有不与他人共享的内容均存放于此（注：请替换为实际智能体ID）
│   │   ├─ projects/     - 我创建的所有内容均在此分类，以保持私有空间整洁有序
│   │   ├─ memory/       - 个人记忆目录，按日期归档
│   │   ├─ AGENTS.md     - 我的行为准则，执行任何操作时均须遵守
│   │   ├─ MEMORY.md     - 精选的长期记忆（总结提炼的见解）
│   │   ├─ SOUL.md       - 我的工作风格与个性特质
│   │   ├─ TOOLS.md      - 关于工具与技能使用的个人笔记
│   │   └─ USER.md       - 对服务对象的认知模型
│   └─ .../              - 他人的私有空间，我绝不可访问
│
└─ shared/               - 需与他人共享的内容存放于此，亦包含团队协作内容及他人分享给我的资料
    ├─ TEAM.md           - 团队信息与成员名录，与他人沟通时需参考此文件
    ├─ projects/         - 协作开发的项目代码，每个子目录为一个独立项目
    │   └─ {projectWorkspace} - 项目目录
    │      ├─ docs/         - 项目有价值的公开资料，如白皮书、报告、原始研究等
    │      ├─ specs/        - 项目需求与规格说明
    │      ├─ ./    - 项目的构建产物与交付件，如代码、测试用例、UI设计等
    │      ├─ reviews/      - 项目评审文档
    │      ├─ decisions/    - 项目决策文档
    │      └─ archived/     - 项目归档文档
    ├─ specs/            - 需求与规格说明
    ├─ archived/         - 归档文档
    ├─ docs/             - 有价值的公开资料
    └─ others/           — 未分类或暂无法归类的文档
```

---

### 知识库体系整体架构

```
~/.openclaw/workspace/
├─ agents/
│   └─ {agentId}/        - 每个Agent的工作空间
│       ├─ memory/       - Agent的工作日志和定期总结
│       ├─ docs/         - 有价值的资料，如白皮书、报告、原始研究等
│       ├─ reports/      - Agent整理的调研报告，有专门的目录结构见下文`调研报告`章节
│       ├─ .learnings/   - Agent的工作过程中积累的有价值的洞见和知识，有专门的目录结构见下文`洞见目录`章节
|       ├─ DREAMS.md     - Openclaw 从记忆中抽取的洞见
│       └─ MEMORY.md     - 精选的长期记忆
│
└─ shared/               - Agent的协作空间，包含团队协作内容，如项目、团队项目、团队文档、团队规范、团队决策、团队评审、团队产出物等
    ├─ projects/         - 协作开发的项目代码，每个子目录为一个独立项目
    │   └─ {projectWorkspace} - 项目目录
    │      ├─ docs/           - 项目有价值的公开资料，如白皮书、报告、原始研究等
    │      ├─ specs/          - 项目级规范性文档
    │      ├─ reviews/        - 项目评审文档
    │      ├─ tasks/          - 项目开发过程性文档: 任务卡、调度记录、任务评审报告、里程碑评审报告，有专门的目录结构见下文`任务目录`章节
    │      ├─ decisions/      - 项目决策文档
    │      └─ reports/        - 项目有关的调研报告，有专门的目录结构见下文`调研报告`章节
    ├─ specs/            - 团队级规范性文档
    ├─ decisions/        - 团队级决策文档
    ├─ docs/             - 团队级有价值的公开资料
    └─ reports/          - 团队级调研报告，有专门的目录结构见下文`调研报告`章节
```

### 任务目录

```
tasks/
├─  xxx.md                        # 任务清单(某次临时任务清单或对应同名目录的任务清单)
└── {YYYYMMDD-M?-标题}/           # 主任务目录
    ├── index.md                  # 主任务清单
    ├── master-track.md           # 任务跟踪表
    ├── cards/                    # 任务卡片
    │   └── T-XXX-001.md
    └── reviews/                  # 评审报告目录（任务卡片执行过程中由Reviewer生成）
        ├── T-XXX-001-review.md   # 单任务评审报告
        ├── T-XXX-002-review.md
```

**参考文档**

- 任务卡片编写规范 - specs/task-card-format-spec.md
- 主任务清单编写规范 - specs/master-task-list-format-spec.md


### 调研报告

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

**参考文档**

- 深度调研报告撰写技能 - skills/ai-dialectic-writing/SKILL.md


### 洞见目录

```
{agentWorkDir}
├── DREAMS.md     - Openclaw 从记忆中抽取的洞见
└── .learnings/
    ├── LEARNINGS.md           # 记录Agent做错的、纠正过的、发现更好方案的点点滴滴，下次不再犯同样的错。
    ├── ERRORS.md              # 记录Agent运行命令失败和工具报错，方便回溯问题和避免重蹈覆辙。
    └── FEATURE_REQUESTS.md    # 记录Agent暂时的能力边界，作为后续能力建设的参考清单。
```

**参考文档**

- 知识洞见技能 - skills/self-improvement/SKILL.md

---

### 🧠 核心原则

#### 1. 隐私边界

| 位置 | 访问权限 | 规则 |
|----------|--------|------|
| `agents/{myId}/` | **私有** | 我的个人工作区 |
| `agents/{otherId}/` | **禁止访问** | 绝不访问他人的私有空间 |
| `shared/` | **公开** | 团队协作空间 |

#### 2. 内容组织

| 内容类型 | 存放位置 |
|-------------|----------|
| 个人笔记 | `agents/{myId}/` |
| 团队项目 | `shared/projects/` |
| 通用规范 | `shared/specs/` |
| 项目规范 | `shared/projects/{projectWorkspace}/specs/` |
| 项目评审 | `shared/projects/{projectWorkspace}/reviews/` |
| 项目决策 | `shared/projects/{projectWorkspace}/decisions/` |
| 项目产出物 | `shared/projects/{projectWorkspace}/./` |

---

### ✅ 操作前检查清单

在创建或修改任何文件前，请确认：

- [ ] 此内容属于私有还是共享？
- [ ] 我是否访问了正确的目录？
- [ ] 我是否尊重了他人的隐私边界？
- [ ] 是否符合目录结构规范？