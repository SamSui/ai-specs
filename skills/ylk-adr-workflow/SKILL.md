---
name: ylk-adr-workflow
description: 面向 YLK workspace 的跨仓架构决策、需求纠偏、项目认知沉淀、验证和交付归档工作流；用 Beads issue 跟踪进展，用 bd remember 保存经验、认知和踩坑，维护 docs/adr-* 稳定文档。
triggers:
  - 新建或整理 YLK ADR
  - 跨仓需求纠偏
  - ADR 偏离分析
  - 需求与代码对齐
  - 跨仓架构方案
  - ADR 验证和收官
  - 更新 YLK 架构文档
  - 整理项目认知、经验和踩坑
---

# YLK ADR Workflow

## 默认行为与实施闸门

本技能默认处于设计与规划阶段：

- 编写或修订 ADR 文档，明确背景、决策、边界、替代方案、后果和验证标准。
- 提前创建或修订对应的 Beads issue 任务链，拆分调查、ADR 审查、实施、测试、E2E/部署、独立 review 和收官任务，并建立依赖关系。
- 设计阶段可以基于已核实的代码、文档、测试或环境事实，记录项目认知类 Beads memory。
- 未收到用户明确的实施指令前，禁止执行 ADR 及其对应 Beads issue 的具体实施工作，包括修改业务代码、执行修复性测试或构建、写入真实数据库、部署、触发 CI/CD、提交或推送。
- 收到明确实施指令后，才进入实施阶段；实施阶段产生的可复用经验、项目踩坑和实施中确认的规则，按需记录到 Beads memory。

“编写/修订 ADR”和“构建/修订 Beads 任务链”本身属于设计阶段，不等于获得实施授权。用户只要求设计、评审或规划时，完成文档和任务链后停止。

## 目标与产物链路

将 YLK workspace 的需求、跨仓事实、架构决策、实现偏离、验证证据、项目认知和长期经验组织成可追溯链路。主要参考 `docs/adr-resource-mgmt-deviation-fix` 的**颗粒度和文件分工**，不照搬单篇内容、一次性环境信息或敏感值。

```text
任务前背景 / 原型 / 问题 / 决策前事实
  -> ADR 正文：背景、范围、重大决策、替代方案、长期后果、契约及本决策直接相关的认知/踩坑
  -> 主题 README / 偏离矩阵：偏离总览、FIX 归属、改动清单、执行状态
  -> Beads issue：当前进展、待办、阻塞、验证轮次和依赖
  -> result.md / HANDOVER.md：提交、测试、CI/CD、部署、E2E、失败和交接
  -> Beads memory：跨任务可复用的项目认知、经验、踩坑和用户长期规则
```

ADR 不是会话纪要、实施流水账、Skill 制作说明、文档整理记录或 CI/CD 执行报告。

## 载体分工

- **Beads issue** → 任务进展、待办、依赖、负责人、阻塞、调查轮次、实施轮次和验证轮次；使用 `bd create`、`bd update`、`bd close` 等命令操作。
- **Beads memory** → 跨会话、跨任务仍可复用的项目认知、稳定决策、业务契约、重复性经验、踩坑和用户明确的范围边界；使用 `bd remember` 写入、`bd memories` 检索。它是 ADR 的同步载体，不替代与当前决策直接相关的认知、经验和踩坑。
- **`docs/adr-*`** → 正式 ADR、稳定架构说明，以及主题级偏离/FIX 映射；ADR 正文承载前置决策、必要实施状态，以及能够解释本次偏离或后续维护的稳定认知与踩坑，不承载过程报告。
- **`result.md` / `HANDOVER.md`** → 阶段性最终报告、提交、测试、CI/CD、部署交接和未完成项；不替代 task 或 memory。
- **`CURRENT_TASKS.md` / `CURRENT_E2E.md`** → 历史参考资料。新任务不把它们作为过程看板；其中有价值的进展、认知、经验和踩坑按类别迁移，不得丢失。

详细规则见：

- [项目认知、经验与 Beads memory](references/project-knowledge-and-memory.md)
- [ADR 目录约定](references/adr-directory-conventions.md)
- [ADR 正文模板](references/adr-document-template.md)
- [需求基线模板](references/requirements-baseline-template.md)
- [偏离与 FIX 映射模板](references/deviation-matrix-template.md)
- [E2E 与验证证据规则](references/e2e-evidence-rules.md)
- [最终结果与交接报告模板](references/result-report-template.md)

## 标准流程

### 1. 建立任务与需求基线

执行前读取适用的 workspace/子仓 `CLAUDE.md`、`AGENTS.md`、`docs/README.md`、相关 ADR，并搜索已有 memory：

```bash
pwd
git status --short --branch
bd prime
bd memories <关键词>
```

为本轮工作创建父 issue，并按实际授权拆分调查、ADR 草拟、实施、测试、E2E/部署、独立审查和归档子 issue。开始执行用 `bd update <id> --claim`，进展和阻塞用 `bd update <id> --notes "<text>"`。纯设计工作不强制创建实施、构建或 E2E 子 issue。

按 [需求基线模板](references/requirements-baseline-template.md) 建立用户故事、页面/API、后端调用链、数据源、仓库落点、测试用例和不在范围项。当前基线变化保存在 Beads issue；确认后的稳定业务规则和项目认知写入 Beads memory（使用 `bd remember`）或 ADR。

### 2. 先盘点范围，再沿完整调用链调查

对长会话、多仓库或多个问题输入，先建立**主题清单**，按每个主题写明：原始问题/用户故事、涉及仓库、调用链、稳定决策候选、偏离/FIX、明确排除项和证据来源。必须覆盖输入材料中全部独立主题，不能因最后讨论的 Bug、最后修改的文件或最新提交而缩窄 ADR 范围。

主题之间仅因同一业务链路或同一稳定决策相连时，才合并到同一 ADR；否则拆为独立 ADR 或在主题 README 中分别映射。归档前必须保留“输入主题 -> ADR / FIX / 明确排除项”的映射，放在主题 README、偏离矩阵或 Beads issue 中，作为范围完整性审查证据。主题清单属于调查工作底稿，不写成 ADR 正文的“会话主线”。

至少覆盖：

```text
页面操作 -> 请求参数 -> 网关 -> Controller -> Service
-> Feign/RPC -> 下游服务 -> DB/对象存储/消息
-> 结果 API -> 前端展示
```

核对字段来源、转换、持久化列、展示字段、空值、默认值、缓存、重试、权限、事务、异步和跨系统状态。前端页面或 DTO 不能单独证明根因。

### 3. 判断 ADR 范围并拆分决策

影响多个仓库或改变跨系统数据、接口、命名、权限、生命周期、计费、部署或测试架构的稳定决策，创建或扩展 ADR。单行文案、局部样式、普通路由、机械重命名和已有 ADR 覆盖的 FIX，不单独创建 ADR。详见 [ADR 正文模板](references/adr-document-template.md) 和 [ADR 目录约定](references/adr-directory-conventions.md)。

### 4. 记录偏离、实施与验证

设计阶段先记录改造前事实，再把每个用例/FIX 映射到 ADR、预期代码落点、修复方式和证据要求；此阶段不得执行具体实施。只有收到用户明确实施指令后，才进入实施、测试和验证，并将状态更新为实际结果。

偏离/FIX 必须分别记录**实现状态**和**验证状态**，不能用“已完成”或“已修复”掩盖二者差异。实施前独立审查计划，实施后独立 review diff。验证规则见 [偏离与 FIX 映射](references/deviation-matrix-template.md) 和 [E2E 与验证证据](references/e2e-evidence-rules.md)。

### 5. 同步项目认知、经验与踩坑

任务中出现用户确认的决策或已核实的跨仓项目认知时，设计阶段即可按 [项目认知、经验与 Beads memory](references/project-knowledge-and-memory.md) 搜索已有 key，并更新已有 memory 或新增稳定 key。可重复经验、实施中确认的规则和踩坑原则上在获得明确实施指令并进入实施阶段后记录。未验证推断和一次性过程日志不写成长期知识。

### 6. 结果归档

按 [最终结果与交接报告模板](references/result-report-template.md) 汇总实际证据、未完成项、技术债务和后续 task。仅当任务已进入实施或交付阶段时，才创建或更新结果报告。同步根 `docs/README.md`、主题 README、ADR 状态、关系图和偏离/FIX 状态。

## 收官检查

- [ ] 需求、仓库、调用链和范围有事实依据；多主题输入已保留“输入主题 -> ADR / FIX / 明确排除项”映射。
- [ ] ADR 落在正确主题目录，并更新 workspace/主题两级索引。
- [ ] FIX/偏离可映射到 ADR、代码落点和验证证据。
- [ ] 任务进展和阻塞由 Beads issue 可追踪。
- [ ] 设计阶段已将有事实依据的项目认知按需写入 Beads memory；实施阶段再记录实施中确认的经验和踩坑。
- [ ] 已实施的内容，其测试、编译、E2E、部署、未执行项和剩余风险均如实报告；纯设计 ADR 明确标记为未实施/未验证。
- [ ] 独立审查完成，无占位代码、弱断言或范围外改动。
- [ ] 结果报告、后续 issue 和未授权外部动作已明确记录。
- [ ] 未收到用户明确实施指令时，仅完成 ADR 与 Beads issue 设计，不执行具体实施。

完成前执行：

```bash
bd preflight
bd close <已完成 issue-id>
git status --short --branch
git diff --check
```

默认不 commit、push、触发 CI/CD、部署、修改真实数据库或清理真实数据，除非用户明确授权。

## 常见失误

- 把通用 ADR 模板套在 YLK 上，遗漏主题目录、根索引和跨仓关系。
- 把 `CURRENT_TASKS.md` / `CURRENT_E2E.md` 不再作为看板，误解为“不再记录进展、经验、认知和踩坑”；正确做法是分类迁移到 Beads issue、Beads memory、ADR 和结果报告。
- 只看 DTO、页面或单个仓库，不追完整调用链。
- 用“代码已改”替代编译、单测、API、DB、UI、E2E 或部署证据。
- 用 API-only 或弱断言制造 E2E 假通过。
- 每个 FIX 都新建 ADR，造成文档碎片化；应优先归属已有决策。
- 把“不修”“不在范围内”“环境阻塞”和“代码已通过”混为一谈。
- 把长会话最后一个 Bug 当作全部范围，遗漏更早出现的独立主题、仓库边界或决策。
- 用“会话归档”“会话任务主线”“本轮执行过程”等事后叙述代替任务前的背景、偏离与决策。
- 将 Skill 提取、文档整理、CI/CD job 过程、聊天过程或模板化验收清单写进 ADR 正文。
- 复制历史文档里的真实凭据、环境 IP、SSH 信息或数据库密码。
