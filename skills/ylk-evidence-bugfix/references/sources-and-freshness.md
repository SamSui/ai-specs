# 来源与时效性

本 Skill 汇总可复用流程，不把历史文档当作实时事实。**读取时机**：需要判断资料来源、历史经验、架构背景、事实冲突或引用有效性时读取。调查时按“当前代码和环境优先，历史资料辅助”的顺序交叉验证。

**STOP**：如果来源文件不存在、路径失效、版本冲突无法解释，或历史资料与当前环境结论冲突，不得静默选一方；记录冲突并按主 Skill 的 Blocker 协议升级。**NEVER** 把 memory、Beads、README 或历史拓扑单独当作实时运行证据。

## 原始资料来源

- **Workspace 规则与仓库地图** → `/home/openclaw/Codes/ylk/CLAUDE.md`、workspace 根 `CLAUDE.md`、各目标仓 `CLAUDE.md` / `AGENTS.md`。用于 Git、Beads、技术栈、跨仓边界和操作权限。
- **架构、命名与仓库拓扑** → `docs/adr-arch/019-workspace-repository-topology-and-naming.md`。用于识别数桥、海星、区域节点、前后端仓关系；不用于确认当前部署。
- **运行与可信沙箱资料** → `docs/handovers/tee-trusted-sandbox-handover.md`。用于部署和依赖背景；实际 namespace、deployment、镜像和挂载必须查询当前环境。
- **平台逻辑参考** → `datafield-platform/datafield-platform-service-node-logic-report.md`。用于定位历史业务链路；以当前分支源码为准。
- **构建与发布资料** → 目标仓 `.gitlab-ci.yml`、`.gitlab-ci/`、`docker-artifacts.csv`、根 `README.md`、`datafield-installer` Helm values 与部署脚本。目标模块构建命令的优先级：CI 第一、README 第二、其余项目资料第三。
- **用户级 YLK project memory** → `~/.claude/projects/-home-openclaw-Codes-ylk-datafield-platform/memory/MEMORY.md`，以及所链接的 `frontend-api-path-prefix`、`k8s-external-jar-deploy`、`workbench-multi-entry-routing`、`migration-target-db-mapping` 等主题。它们是排查提示，需回到代码/环境验证。
- **Beads memory** → workspace 根执行 `bd memories` 后查询 `ylk-bug-fix-workflow`、`ylk-environment-evidence`、`ylk-delivery-gates`、`ylk-build-constraints`。它们记录历史经验，不可绕过当前 issue、CI 或环境事实。
- **Agent 约束设计** → `/home/openclaw/Codes/archived/aiwg/document/team/specs/SPEC-AGENT.md`。本 Skill 采用其场景化约束、STOP、禁止动作、正确流程和完成前自检思想；不将其中其他项目的具体身份/协作配置直接带入 YLK。
- **Owner 交互规则** → `~/.claude/skills/interview/SKILL.md`；若不可用，使用 `ai-specs/skills/interview/SKILL.md`。用于需要 Owner 决策的结构化 `AskUserQuestion`。
- **YLK 环境访问与服务拓扑** → 本 Skill 的 `references/ylk-environment-access.md`、`references/ylk-service-topology.md`，以及 `~/.claude/projects/-home-openclaw-Codes-ylk-datafield-workbench/memory/ylk-platform-topology.md`、`~/.claude/projects/-home-openclaw-Codes-ylk/memory/project-mapping.md`、`~/.claude/projects/-home-openclaw-Codes-ylk/memory/tech-debt-k8s.md`。memory 提供历史 K8s/Compose 拓扑基线，reference 记录通用环境访问规则和已核验的 Compose project、Service 端口、NodePort、Deployment、StatefulSet；实时环境查询优先。
- **本机浏览器调试配置** → 用户级 `custom.md`，只保存当前机器的 Playwright/CDP 端口，不承载通用环境或业务拓扑。

## 时效性规则

- **代码事实** → 当前分支源码、当前 CI 配置、当前 `pom.xml`/lockfile 优先。
- **运行事实** → 当前环境的只读 API、日志、数据库 schema/查询、K8s 资源和运行时配置优先。
- **历史经验** → docs、memory、Beads、交接文档只用于提出假设和缩小搜索范围。
- **冲突处理** → 当前代码/环境与历史资料冲突时，记录冲突、使用当前证据，并按 `SKILL.md` 阻塞协议请求决定；NEVER 静默选择更符合预期的一方。
