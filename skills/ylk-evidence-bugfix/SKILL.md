---
name: ylk-evidence-bugfix
description: |
  面向 YLK workspace 任意子项目的证据驱动 Bug 修复流程。用于跨前后端、跨仓、数据库、对象存储、K8s、GitLab CI/CD 问题；从 Bug 单规范化、真实环境调查、计划独立审查、最小修订、JUnit/Mockito、独立 code review，到经明确授权后的提交、推送、部署和回归验证形成闭环。
  触发词：修 Bug、排查问题、根因分析、跨仓链路、数据库验证、日志排查、修订计划、补单测、部署验证、线上问题。
---

# YLK Evidence Bugfix

适用于 YLK workspace 任意子项目。根据受影响层选择真实代码、API、数据库、日志、消息、对象存储、配置或部署证据；涉及跨服务或数据链路时补齐完整调用链。DTO、VO、前端模板或单一模型结论都不是相关链路 Bug 的充分根因证明。

## References 索引：按场景读取

- **新机器、连接、权限或工具链初始化** → 先读 [new-machine-bootstrap.md](references/new-machine-bootstrap.md)，再读 [ylk-environment-access.md](references/ylk-environment-access.md)。需要 Owner 选择环境、补充连接或决定配置时，调用 `interview` Skill 的 `AskUserQuestion`。
- **Bug 单、调用链、API、日志、数据库、对象存储调查** → 读 [investigation-evidence.md](references/investigation-evidence.md)。它定义证据顺序、脱敏 curl、查询边界、文件链路和根因结论格式。
- **用户提供禅道 Bug ID/链接，或要求从禅道获取 Bug 输入** → 可选读取 [zentao-cli.md](references/zentao-cli.md)。仅使用只读 `zentao-cli bug list/get` 或 GET REST API；它不能替代当前代码和运行环境证据。
- **海星、数桥、区域节点、Compose/Kubernetes、端口或 workload 映射** → 读 [ylk-service-topology.md](references/ylk-service-topology.md)；环境组、SSH-MCP IP 和节点选择读 [ylk-environment-access.md](references/ylk-environment-access.md)。实时资源优先于文档和 memory。
- **YLK 架构导航、仓库职责、业务主链或部署模型背景** → 读 [ylk-architecture-and-deployment.md](references/ylk-architecture-and-deployment.md)，需要追溯原始材料时再读 [sources-and-freshness.md](references/sources-and-freshness.md)。
- **Maven 构建、前端 lint/build、单测、CI/CD、发布和部署回归** → 读 [quality-and-delivery.md](references/quality-and-delivery.md)，以当前仓 `.gitlab-ci.yml` 和 includes 判断交付模型；默认跳过 Docker 镜像构建，只有 CI 明确要求镜像产物的目标服务才执行。Maven 命令还必须遵守本文件的“构建发现与执行规则”。
- **文档来源、历史 memory、Beads 经验或事实冲突** → 读 [sources-and-freshness.md](references/sources-and-freshness.md)，按“当前代码/当前环境优先，历史资料辅助”的规则处理。
- **本机浏览器调试端口** → 读私有 `custom.md`。它只保存本机 Playwright/CDP 配置，不提供 YLK 环境或业务拓扑事实。

**引用边界：**`SKILL.md` 是执行规则的 source of truth；references 是按场景加载的操作资料；`custom.md` 是本机私有 overlay；memory、Beads 和历史文档只能提出假设，不能替代当前代码或环境验证。外部规范只可用于增强证据、授权、停止、委派和验收约束，不得引入与 YLK Bug 修复无关的 Skill 自检、通用 Agent 管理或产品决策能力。不要因为文件名相近而跳过索引或读取不适用的 reference。

## 执行边界与安全规则

- 涉及本机浏览器或 Playwright/CDP 调试时，先读取 `custom.md`；其他任务无需读取。三套环境的 SSH-MCP IP、节点矩阵和通用访问规则见 [YLK 环境访问与节点矩阵](references/ylk-environment-access.md)。
- 不得将 `custom.md`、SSH 配置、shell 历史、环境变量、K8s Secret、CI variables 的敏感值复制到对话、日志、代码、测试、Git、Beads 或子 Agent 提示词。不得输出 Token、密码、私钥或完整连接串，哪怕只输出部分。
- 用户明确提供完整的只读 API 请求（包括认证 Header、Cookie、Referer 或请求体）作为复现/取证材料时，该请求是不可变原始证据，必须直接逐字节原样执行；不得因凭据存在而擅自删除、补充、重排、转写或替换任何参数。执行输入与脱敏报告严格分离，报告模板不得反向生成执行命令；若因工具限制必须转录，先做字节级比较，任何字符、Header、Cookie、Referer、请求体、参数、引号或换行差异均停止，不执行修改版。执行通道不得启用命令跟踪或 verbose 输出，原始 stdout/stderr 不得回显或持久化；只允许报告脱敏摘要。确需临时载体时使用 `0600` 权限、限定本次执行生命周期并立即删除，不得进入 shell history、日志、Beads、Git 或 Agent 提示词；无法满足这些条件时停止执行。敏感信息仅限制回显、长期落盘和转发，不限制使用该请求取证。
- 默认只读。数据库写入、数据重放、重新登记/上架、对象删除、commit、push、触发 pipeline、手动部署都是外部或难逆动作，必须由当前用户明确授权。
- 所有结论都标明证据与未知项；不能以模拟 API、猜测部署、虚构测试结果或静默替代方案制造“已完成”。
- 委派给子 Agent 时，任务描述必须自包含：角色、绝对仓库路径、目标分支、精确到文件/模块或调用边的只读/可编辑范围、适用规范与一手证据路径、目标环境组/节点角色（如涉及远程环境）、交付物及其路径、所需验证、状态报告和完成条件；同时明确禁止泄露凭据与禁止执行外部动作。子 Agent 开工前必须核验 `pwd`、`git status --short --branch`、脱敏 remote、仓库级 `CLAUDE.md`/`AGENTS.md`；涉及远程环境时还必须核验 SSH-MCP connection 与 `hostname; date -Is`。目标未核实前不得读取、修改或执行远程操作。

## 阻塞与升级协议

**自主技术推理不是越权。** 对普通代码歧义、局部证据缺口、多个可行实现、单个只读探针失败或历史资料冲突，Agent 应继续进行静态追踪、调用链比对、反例检查、最小本地试验和定向测试；明确区分事实、假设与待验证项。不得把每个未知都升级为 STOP，也不得因尚未获得远程证据而停止不依赖该证据的本地调查。

**仅满足任一项时 STOP 受影响分支并如实报告：**

- 继续操作会执行未获当前用户授权的写库、删除、重放、重新登记、发布、commit、push、pipeline 或部署等外部/难逆动作；
- 继续操作会读取、回显、持久化或传播未获授权的敏感信息，或无法按用户提供的完整只读请求原样、隔离执行；
- 目标仓库、分支、环境、数据源或权限完全无法判定，且该事实是下一步操作的必要前提；
- 修复需要在多个业务语义、存量数据范围、目标环境或发布策略间作 Owner 才能决定的选择；
- 事实冲突使得继续实施会改变外部契约、处理真实数据或扩大到未授权仓库/公共历史问题。

**允许继续调查，但必须记录不确定性的情况：**

- 只读工具、SSH、API 或数据库调用失败或超时：记录脱敏错误，尝试与该调用独立的代码、配置、日志或本地测试证据；仅在缺失证据决定下一步外部动作时升级；
- 代码、规范、CI、README 或历史资料不一致：以当前代码和可复核运行证据为优先，保留冲突与推理过程；
- 存在多个局部实现方案：比较调用方、契约、失败路径和测试可观察结果，选择最小且可回滚的实现，或在确实涉及业务语义时请求 Owner 决定。

**继续调查时 NEVER：**

- ❌ 静默切换其他环境、其他 API、模拟数据、猜测的命令或替代业务语义；
- ❌ 隐藏错误、降低验证标准或把未执行的验证写成通过；
- ❌ 自行扩大范围、选择发布环境、写库、处理存量数据或修改未授权仓库；
- ❌ 为了继续排查而读取、回显或传播未获用户提供的凭据；
- ❌ 对用户已提供的完整只读请求擅自改写认证 Header、Cookie、Referer、请求体或其他参数；需要执行时必须原样使用。

**正确流程：**

1. 对可本地验证的问题，写明假设、反例和证据缺口后继续调查；
2. 对真正阻塞的分支，停止该分支，保留已执行命令、脱敏错误和影响范围；
3. 说明已验证事实、失败点、不能继续的原因及可选路径；
4. 属于 Owner 决策时调用 `interview` Skill，并用 `AskUserQuestion` 提问；
5. 获得明确决定后，从该决定对应的步骤继续，不把决定外推到其他仓库或环境。

**完成前自检：**

1. 是否把失败、缺失证据、假设或未执行验证写成了“已完成”“通过”或等价结论？
2. 是否因工具失败、权限缺失、范围不明或验证成本高，而静默切换了环境、方案、数据、接口或验证标准？
3. 每个结论是否能回溯到当前代码、当前环境或明确标注的一手证据，且所有外部动作均已获当前用户明确授权？

任一项不能明确回答时，不得宣称完成；仅当该不确定性会触发上述硬 STOP 条件时停止受影响分支并报告。

## 启动与本机配置

1. 首次使用或迁移机器，执行 [新机器初始化](references/new-machine-bootstrap.md)。`custom.md` 缺失时只影响本机 Playwright/CDP 调试能力；环境角色不明时读取 [ylk-environment-access.md](references/ylk-environment-access.md) 并按 bootstrap 规则核验，不得猜测补全。
2. 如需 Owner 补充配置或做路线选择，必须遵守 `~/.claude/skills/interview/SKILL.md`；若该 Skill 不可用，使用 workspace 的 `ai-specs/skills/interview/SKILL.md`。每个 `AskUserQuestion` 必须具备问题、背景、原因、建议、适用规范/无适用规范说明、交付验收、过度设计判断七项。
3. 在目标仓修改前执行：

```bash
pwd
git status --short --branch
git remote get-url origin | sed -E 's#(https?://)[^/@]+@#\1<redacted>@#'
git branch --show-current
```

4. 在 workspace 根执行 `bd prime`、`bd where` 和 `bd memories`；项目已有对应 issue、用户要求跟踪，或工作需要跨 Agent/跨阶段持续协调时，通过 `bd` 维护任务与持久知识。issue 不是普通只读调查或单一修复进入实施的前置条件；创建、claim、更新或关闭 issue 仅在项目流程或当前用户要求适用时执行。跨仓命令使用绝对路径或每条命令明确 `cd`。
5. 资料来源、适用范围和时效性规则见 [来源与时效性](references/sources-and-freshness.md)。
6. 服务端口、`Deployment`、`StatefulSet` 和历史拓扑映射见 [YLK 服务端口与部署拓扑](references/ylk-service-topology.md)；该文件只作调查导航，实时状态必须查询目标环境。

## Maven 构建发现与执行规则

**先发现真实构建方式，再执行任何 Maven 命令。优先级固定如下：**

1. 当前仓 `.gitlab-ci.yml`、`.gitlab-ci/`、include 的 job script、`docker-artifacts.csv` 中与目标模块对应的构建命令、profile、JDK 和产物路径；
2. 根 `README.md` 的构建说明；
3. 适用 `CLAUDE.md`、`AGENTS.md`、根 `pom.xml` 的 reactor 模块和 Maven Wrapper；
4. CI/README 均没有充分信息时，报告缺口并按阻塞协议处理，不能猜测 profile、模块名或全局 Maven 兼容性。

先用只读命令定位证据：

```bash
rg -n 'mvnw|mvn |MAVEN|MAVEN_OPTS|profile|pl |am |MODULE_NAME|JAR_PATH' \
  .gitlab-ci.yml .gitlab-ci docker-artifacts.csv README.md 2>/dev/null
rg -n '<module>' pom.xml
test -x ./mvnw && echo wrapper-present
```

- **多模块 Maven 项目：NEVER 进入子模块运行 `mvnw` 或 Maven。** 必须在主项目根目录执行，使用 CI/README 已确认的模块坐标，并结合 `-pl <module> -am`：

```bash
./mvnw -pl <module> -am test -Dtest=<TestClass> -DfailIfNoTests=false
./mvnw -pl <module> -am compile
```

- `./mvnw` 存在时优先使用它；不存在时只能使用 CI 或 README 明确批准的入口与版本。
- “selected project not in reactor”首先是工作目录、根 `pom.xml` 或模块坐标证据不足，不是测试失败；修正 reactor 后再判断测试。
- 单模块项目仍在其仓库根目录运行，不从相邻仓或 workspace 根误执行。

## 强制流程

### 1. 将 Bug 单改写为可验证规格

Bug 输入可以来自用户描述、已有 issue，或可选的禅道 Bug ID/链接。用户提供禅道来源时，按 [zentao-cli 输入来源](references/zentao-cli.md) 只读获取并标注来源；未提供时不得为了走流程强行查询禅道。

用户要求“查看未提交内容”“准备提交”时，先做工作树盘点：逐仓执行 `git status --short --branch`、`git diff --stat`、`git diff --check`，标记每个文件与当前问题的关联及验证状态；只有用户明确要求 review/审查时才进入 code review 流程。跨仓工作树混有旧方案时，按用户明确指示决定是否 stash；不得自行丢弃、恢复或覆盖 stash。

按实际涉及范围记录业务背景、入口、请求/事件、受影响组件、预期/实际结果以及数据、缓存、异步、对象存储和跨系统契约影响。对争议字段或数据建立来源表，按实际链路记录入口、内存模型、持久化、跨系统传输、下游处理、回读与消费位置，并为每一跳附代码、API、日志或数据证据。未涉及的层面标记为“不适用”，缺失项标为“待调查”，不以猜测补齐。模板见 [调查与证据](references/investigation-evidence.md)。

### 2. 先调查，后写计划，禁止改代码

沿完整链路调查：

```text
前端操作 → 请求参数 → 网关 → Controller → Service → 本地分支/缓存
→ Feign/RPC → 下游服务 → 数据库/对象存储 → 审核或详情 API → 前端展示
```

按 Bug 实际涉及的边界验证对应证据：本地与远端分支、持久化或内存模型、缓存、内容与引用、跨系统契约、异步处理或存量数据。仅对实际涉及的边界执行验证，不得将未涉及的数据库、对象存储、远端服务或 UI 链路作为固定前置条件。涉及多个入口或接口时，分别核对参数形态、数量边界和处理语义；一个入口的能力不得推导另一个入口或下游接口的能力。若已证明属于不同契约且用户未授权扩展下游接口，只核查必要边界，不继续改造无关接口。

若输入可能表示目录、前缀、数组、逗号分隔值或多个对象，先确认实际类型和集合边界；仅在证据表明存在集合语义时，完整核实发送方编码、接收类型、解包/遍历规则、顺序语义及空集合和单项兼容行为。单对象仅验证存在性、类型、传输和错误处理。未取得协议或代码证据前，禁止提出取首项、排序筛选或其他丢弃数据方案。环境证据操作见 [调查与证据](references/investigation-evidence.md)，部署导航见 [架构与部署](references/ylk-architecture-and-deployment.md)。

### 3. 输出初步修订计划并独立审查

每项计划写清根因与至少两类证据、已确认事实/待验证假设/已排除假设、受影响仓库/文件/上下游、最小改动、不修改范围、按实际受影响边界选择的单测/编译/API/DB/UI 验证及存量数据边界；未涉及项标记为“不适用”，缺失证据标记为“待调查”。回归修复还必须对比当前工作树、`HEAD` 与 `HEAD~1` 或已部署版本，列出相关字段在持久化、接口响应与外部契约中的历史语义。用户已确认的字段或契约语义是任务不变量，后续只能修正计算、来源或容错，不得删除或替换为新语义，除非用户明确重新决策。修改共享字段前搜索其他仓读写使用；现有字段可在边界映射层修正且不改变持久化或外部契约时，禁止新增重复字段。正常依赖遵循目标仓既有 import 风格；全限定名仅用于命名冲突或明确静态分析规避，不作为漏 import 的临时修复。公共历史缺陷、无关重构、依赖升级和数据修复不得混入。

代码、API、对象元数据、数据库或日志已确认的字段语义、传输标识或对象 key 是冻结事实；只有更新且可复核的矛盾证据才能改变，且必须保留旧证据、记录新证据与影响范围。计划审查通过后，如新增证据改变输入、对象类型、协议语义、根因、影响范围或部署模型，立即标记原计划 `STALE` 并停止实施；更新证据、根因、假设、范围和验证项后重新独立审查。

由独立 reviewer 审查，结论只能为 `APPROVE`、`CHANGES_REQUIRED`、`BLOCKED`。审查通过前不得实施；审查重点是完整调用链、覆盖/空值风险、持久化和协议语义、UI 回归、最小范围和存量数据边界。

### 4. 实施、测试与独立 Review

- 修改前重新读取目标文件，保留用户已有修改；修改后立即核对字段、事件和持久化语义。
- 后端业务分支以 JUnit + Mockito 覆盖正常路径、关键空值/空白、历史值保留、真实 Mapper/下游参数、持久化字段与新建/更新/重试差异。所有本次新增或修改的 Java `@Test` 方法必须紧邻 `@Test` 添加 JavaDoc，明确测试场景、关键输入或前置状态、预期的可观察结果；仅靠方法名、行尾注释或泛泛说明不合格。
- 测试与编译必须遵循本 Skill 的 Maven 规则。前端执行修改文件定向 lint/typecheck 和项目可用的最小 build。
- 独立 reviewer 评审未提交 diff，重点核对空值、覆盖、事务、异步、对象存储、协议、UI 事件和测试缺口。
- 质量门禁与既有失败归因见 [质量与交付](references/quality-and-delivery.md)。

### 5. 授权后的交付与回归

默认在质量门禁完成后停止。用户明确授权 commit、push、pipeline 或部署后，重新核对仓库、remote host、分支、文件、是否 force、pipeline 和目标环境。触发任何 CI job 前，必须由当前 `.gitlab-ci.yml`、includes、`docker-artifacts.csv` 和部署配置建立唯一映射：`服务/模块 → 构建 job → 产物类型与路径 → workload 引用/挂载位置 → rollout 方式`。多数后端服务部署更新外挂 JAR 并 rollout；其 Docker job 不属于本次交付，不需要也不得为了“完整”触发。只有映射证明 CI 明确将镜像作为目标服务交付物时才构建和验证镜像；job 与映射不一致时停止。仅对本次变更实际涉及且对应交付模型存在的 pipeline、交付物加载、rollout、日志、API、数据库、消息、对象存储、缓存和页面回归收集证据；未涉及或不适用项明确标记为“不适用”。

## 最终交付

报告根因与证据、修改仓库和文件、测试覆盖与结果、编译/lint/build 归因、真实环境/API/数据库验证、存量数据影响、未执行的外部动作、剩余风险与阻塞原因。不得将未验证项描述为已解决。
