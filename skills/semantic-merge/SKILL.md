---
name: semantic-merge
type: Skill
tags: [git, merge, conflict-resolution, code-review, CI/CD]
description: 跨项目的语义合并方法论——通过意图理解替代文本匹配合并代码冲突，适用于任何编程语言和项目结构。
author: 顾小宇
version: 1.0
last_updated: 2026-06-06
status: draft
---

# 语义合并全生命周期 SOP

**版本**: 1.0 (de-identified from internal SOP v5.3)  
**适用对象**: 任一具备 git 基础能力、能阅读项目代码的 Agent  
**前置依赖**: git 2.38+（为 `--remerge-diff` 支持）  
**核心约束**: 逻辑文件禁止单边采纳、禁止文本工具/脚本批量处理、一切逻辑合并必须通过 Patch 审计

> **使用前必读**: 本文档中的路径模式（`**/pom.xml`、`**/*.vue` 等）为 Java + Vue 技术栈的示例。使用本 SOP 时，需根据项目的实际技术栈替换 Phase 0 的路径模式。路径匹配规则为 globstar 语义：`**` 跨越任意目录深度，`*` 匹配单层内的非 `/` 字符。

---

## Phase 0: 文件分类与策略指定

**目标**: 在接触任何冲突代码前，将所有冲突文件按类型标记，确定每类文件的合并策略。

### Step 0.1: 获取冲突文件清单

发起合并（不提交，使用 `git merge <source> --no-commit --no-ff`），收集所有冲突文件路径。

### Step 0.2: 按文件类型分类并指定策略

对每个冲突文件，根据其路径匹配以下类别表。类别分为通用类别（跨项目）和项目类别（需替换）。

**通用类别**（无需替换）：

| 类别 | 策略 | 说明 |
|---|---|---|
| `INFRA`（CI/CD 与构建配置） | **保留目标分支 (OURS)** | CI/CD、构建、部署配置是环境绑定文件，绝不能让来源分支覆盖。唯一例外：如果在审计中发现目标分支确实缺少来源分支的关键构建步骤，需人工确认后增量添加。 |
| `CONFIG`（环境配置文件） | **保留目标分支为主 + 新增配置项审计** | 环境绑定配置（数据库地址、注册中心地址、profile）保留目标分支。来源分支新增的配置 key（非环境相关）需逐项审计后合并。 |
| `BUILD`（依赖管理文件） | **合并依赖部分 + 版本冲突人工确认** | 依赖声明采取增量合并（两边的新依赖都加入）。版本号冲突时，取较高版本，并在 Conflict Log 中记录 `VERSION_CONFLICT: <dependency> OURS=x THEIRS=y RESOLVED=z`，进入 Phase 2.3 时由 code-reviewer 特别审查。插件配置保留目标分支。严禁直接单边采纳——版本回退可能导致安全漏洞或编译失败。 |
| `SCHEMA`（数据模型） | **字段完整性优先** | 保留两边的所有非冲突字段。冲突字段（同一字段两边都有改动）必须走完整 Semantic Merge Algorithm。 |
| `LOGIC`（业务逻辑） | **语义合并 (SMA-REQUIRED)** | 必须执行完整语义合并流程。禁止 `--ours`/`--theirs`，禁止 `sed`/`awk`/正则批量替换。 |
| `UI`（前端界面） | **语义合并 (SMA-REQUIRED)** | 前端组件等同逻辑文件，必须走完整语义合并。 |
| `RENAME_DELETE` | **暂停并人工确认** | git 检测到文件重命名或一边删除时，暂停流程。先确认重命名/删除的意图（是重构还是废弃），再做合并决断。 |
| `GENERATED` | **重新生成，不做合并** | 生成文件或二进制文件不参与合并。冲突时，保留目标分支版本，合并后重新构建生成。 |
| `DOC` | **人工处理** | 标记为人工处理队列，不进入自动合并。 |
| `OTHER` | **暂停并人工确认** | 无法分类的文件，暂停流程并列出文件清单，等待人工指定策略后继续。不分配默认策略。 |

**项目类别**（以下为 Java + Vue 技术栈示例，使用前替换为项目的实际模式）：

| 类别 | 示例路径模式 | 对应通用类别 |
|---|---|---|
| INFRA 示例 | `**/.gitlab-ci.yml`, `**/build.yml`, `**/deploy*.yml`, `**/.github/**/*.yml`, `**/mvnw*`, `**/Dockerfile*`, `**/nginx*`, `**/sonar*.yml` | INFRA |
| CONFIG 示例 | `**/application*.yml`, `**/application*.properties`, `**/bootstrap*.yml`, `**/.env*`, `**/application-*.yml` | CONFIG |
| BUILD 示例 | `**/pom.xml`, `**/build.gradle`, `**/build.gradle.kts` | BUILD |
| SCHEMA 示例 | `**/entity/**`, `**/dto/**`, `**/vo/**`, `**/mapper/**`(XML), `**/*.sql` | SCHEMA |
| LOGIC 示例 | `**/service/**`, `**/impl/**`, `**/controller/**`, `**/handler/**`, `**/manager/**`, `**/util/**`, `**/config/**`(非 yml) | LOGIC |
| UI 示例 | `**/*.vue`, `**/*.tsx`, `**/*.jsx`, `**/*.html`, `**/*.css`, `**/*.scss` | UI |
| GENERATED 示例 | `**/target/**`, `**/dist/**`, `**/node_modules/**`, `**/*.min.js`, `**/*.jar` | GENERATED |
| DOC 示例 | `**/*.md`, `**/*.txt`, `**/README*` | DOC |

### Step 0.3: 确定三方对比基准

获取 OURS（目标分支）和 THEIRS（来源分支）的共同祖先提交哈希，记录为 `BASE_COMMIT`。这是整个三方对比的基准点——没有它无法进行增量意图分析。

如果在一边分支中文件被重命名，从 BASE_COMMIT 通过当前路径无法直接获取内容时，先执行 `git log --follow --diff-filter=R -- <current_path>` 追踪文件的原始路径，再通过原始路径从 BASE_COMMIT 获取 BASE 版本。

---

## Phase 1: 语义合并流程

**适用范围**: `SCHEMA`, `LOGIC`, `UI` 类别文件  
**禁止操作**:
- `git merge -X ours` 或 `git merge -X theirs` 整文件采纳
- `git checkout --ours/--theirs <file>` 整文件覆盖
- `sed`, `awk`, `grep` 正则批量替换逻辑代码
- 任何基于行匹配而非语义理解的自动化脚本

### Step 1.0: 文件依赖图分析

分析所有 `LOGIC` / `SCHEMA` / `UI` 类别冲突文件之间的依赖关系（import 引用、共同基类、方法调用链）。有共享依赖的文件标记为同一处理组（Serial Group），同一组内的文件必须串行合成——先处理被依赖方，再处理依赖方。完全独立的文件可并行处理。此步骤的目的是防止合成文件 A 时引用了在文件 B 中已被重命名或删除的方法/类。

**方法**：对每个冲突文件，读取其 import 语句和类声明（例如 Java `class X extends/implements`、JS/TS `import ... from`、Vue `import`），构建一个有向图（节点=文件，边=依赖关系）。存在双向边或相同父类的文件标记为同一 Serial Group。

### Step 1.1: 三方代码获取

对每个冲突文件，从三个版本提取：
- `BASE`: 共同祖先版本
- `OURS`: 目标分支版本
- `THEIRS`: 来源分支版本

### Step 1.2: 读取并理解冲突块

对文件中的每个冲突块（由 `<<<<<<<` / `=======` / `>>>>>>>` 标记分隔），执行以下理解的步骤：

**A. 读取三方代码**: 读取 BASE 版本中对应位置的代码，OURS 版本中的代码，THEIRS 版本中的代码。不能只看冲突标记内的内容——必须阅读冲突块前后各至少 20 行上下文。

**B. 理解 OURS 的变更**: 对比 BASE 与 OURS，回答以下问题：
- 这段代码在 OURS 中「新增了什么功能/逻辑」？（不是新增了什么行，是实现了什么能力）
- 这段代码在 OURS 中「删除了什么」？（为什么删除？是被重构替代了还是真的不需要了？）
- 这段代码在 OURS 中「修改了什么」？（参数变了？条件变了？返回值变了？）
- 如果有注释，注释说的是什么意图？代码实际执行的是否与注释一致？

**C. 理解 THEIRS 的变更**: 同样对比 BASE 与 THEIRS，回答相同问题。

**D. 交叉验证**: 检查 OURS 和 THEIRS 各自引用的方法/类/变量是否在对方版本中存在。如果 OURS 调用了一个在 THEIRS 中被删除或重命名的方法，这就是需要标记的跨文件依赖冲突。

**E. 意图归类**: 将每一边的变更按以下标签归类。注意：此归类为启发式辅助判断，**不是最终的合并决策**——归类标签仅作为 Step 1.3 合成表的输入起点。当归类与对代码的实质性理解产生矛盾时（例如归类说「独立变更」但实际两边修改了同一变量的相邻行），以实质性理解为准，在 Conflict Log 中记录为什么覆盖了归类判断：

- **提前返回/校验**: 增加了判空、边界检查、前置条件验证
- **流程分支变化**: if/else/switch 分支新增或修改，return/throw/break 路径变化
- **数据处理变化**: 变量赋值逻辑改变、类型转换、数据清洗步骤新增或修改
- **观测/日志**: 新增日志、监控埋点、审计记录
- **结构变化**: 新增方法/类/接口、注解变更、import 变更
- **功能新增**: 全新的业务逻辑块、新接口实现

**F. 冲突性质判定**: 根据两边的变更，判定冲突属于以下哪种：
- **独立变更**: 两边作用于不同目标（不同变量、不同方法、不同逻辑分支），互不影响
- **叠加变更**: 两边作用于同一目标的不同层面（如一边加判空、一边加分支），需要嵌套组合
- **矛盾变更**: 两边对同一目标做了不同方向的修改（如一边改 A=1、一边改 A=2），需要判定正确值
- **需要重构**: 两边变更交织在一起，无法简单拆分或组合，必须整体重新设计

### Step 1.3: 逻辑合成

**合成原则**: 合成的代码必须同时满足两边各自的业务意图，不丢失任何一方的有效逻辑。这不是文本拼接——可能需要调整代码结构。

**合成指导（按场景）**:

| 冲突性质 | 变更 A | 变更 B | 合成方向 |
|---|---|---|---|
| 独立 | 任意 | 任意 | 两边的变更按原始顺序放入输出 |
| 叠加 | 提前返回/校验 | 流程分支变化 | 校验包在分支外层：先通过校验，再进入分支 |
| 叠加 | 流程分支变化 | 提前返回/校验 | 同上，校验始终在外层 |
| 叠加 | 提前返回/校验 | 数据处理变化 | 先执行校验，通过后执行数据处理 |
| 叠加 | 流程分支变化 | 数据处理变化 | 在每个分支内部执行对应的数据处理 |
| 叠加 | 观测/日志 | 任意 | 日志代码放在操作代码之前 |
| 矛盾 | 提前返回/校验 + 提前返回/校验 | 校验合并：两边条件用 AND 连接 |
| 矛盾 | 数据处理 + 数据处理 | 分析数据流向，确定执行顺序形成流水线。如果无法确定顺序或两边的修改在语义上互斥，标记为需要人工判断 |
| 矛盾 | 流程分支 + 流程分支 | **必须重构**——两个控制流同时作用于同一目标点，无法自动化合并 |
| 需要重构 | 任意 | 任意 | 调用 `executor` 级 Agent 进行整体重构设计，不得在此处尝试文本合并 |
| SCHEMA字段 | 字段类型冲突 | 字段类型冲突 | 同一字段两边类型不同（如 String vs Long）→ 升级人工判断。同一字段两边注解不同 → 取注解并集（注解冲突时升级）。新增字段无冲突 → 全量保留 |

**合成示例**（正例校准）:

场景：两边都在 `process()` 方法中增加了前置校验，但校验不同内容。

*   BASE: `void process(Data data) { handle(data); }`
*   OURS: 增加了 `if (data == null) return;`（防止空指针）
*   THEIRS: 增加了 `if (!data.isValid()) throw new ValidationException();`（业务校验）
*   **分析**: 两边都是「提前返回/校验」，但作用于不同层面（一个是判空，一个是业务校验）。冲突性质为「独立变更」——两个校验作用于相同对象但不同属性，互不影响。
*   **合成**: 判空放在业务校验之前（空值在前可避免后续调用 `.isValid()` 空指针），两段校验保留在原始位置。
*   **合成后**: `void process(Data data) { if (data == null) return; if (!data.isValid()) throw new ValidationException(); handle(data); }`
*   **关键判断**: 没有把两个 if 合并成 `if (data==null || !data.isValid())`——虽然语法上等价，但合并后丢失了「提前返回」的意图，且无法区分空指针和业务校验两种不同的异常原因。

**合成后自检清单**（每个冲突块合成后立即执行）:
- 合成代码中不存在 `<<<<<<<`、`=======`、`>>>>>>>` 标记
- OURS 的业务逻辑是否完整保留？（逐一核对）
- THEIRS 的业务逻辑是否完整保留？（逐一核对）
- 是否有单边代码被无故删除？（删除必须有明确的废弃理由）
- 如果有注释，注释描述的意图是否与合成后代码的实际行为一致？
- 合成后的代码是否引入了新的编译依赖？（检查 import 是否完备）

### Step 1.4: 冲突日志记录

对每个冲突块，记录以下信息：
- 文件路径 + 冲突行范围
- OURS 变更描述（意图归类 + 具体说明）
- THEIRS 变更描述（意图归类 + 具体说明）
- 冲突性质判定 + 判定理由
- 合成方向 + 合成理由
- 自检结果

### Step 1.5: 提交前扫描与提交合并

所有冲突文件合成完成后，执行以下操作。这是 Phase 2 `--remerge-diff` 审计的前置条件（`git show --remerge-diff` 只对已提交的合并生效）：

**步骤 1 — 冲突标记扫描（提交前）**:

在 `git add` 之前，直接检查所有未合并文件是否还有残留的 `<<<<<<<` / `>>>>>>>` 标记：

```bash
for f in $(git diff --name-only --diff-filter=U); do
    grep -nE '<<<<<<<|>>>>>>>' "$f" && echo "FATAL: $f 有冲突标记残留，回退 Phase 1"
done
```

如果任何文件检出残留标记，**不要提交**——返回 Phase 1 重新合成该文件。扫描必须在 `git add` 之前执行，因为 add 后 git 会将文件从「未合并」状态移除，`git diff --cached` 的输出中 diff 行带有 `+` 前缀，无法匹配冲突标记模式。

**步骤 2 — 提交**:

扫描通过后，暂存并提交：

```bash
git add <所有已解决的冲突文件>
# 对于 RENAME_DELETE / OTHER / DOC / GENERATED 类别的文件：按其 Phase 0 指定的策略处理后一并 add
git merge --continue
```

提交消息格式（此提交为 WIP，后续可能被 `git commit --amend` 修改）：
```
merge: semantic merge <source_branch> into <target_branch> [WIP: pending RPA audit]
```

如果 `git merge --continue` 失败（例如编辑器弹出或 hook 拒绝），使用 `git commit -m "merge: ... [WIP: pending RPA audit]"` 手动提交。

---

## Phase 2: 补丁审计

**前提**: 所有冲突文件已合成完毕，合并已提交（Step 1.5）。

### Step 2.1: 生成重合并补丁

使用 `git show --remerge-diff HEAD` 生成冲突解决补丁。此命令输出的不是「新代码与旧代码的差异」，而是「冲突解决动作」——即为了消除冲突，代码从「两边冲突状态」到「合成后状态」的变化。

**注意**: `HEAD` 必须是合并提交（有两个 parent）。Step 1.5 的 `git merge --continue` 确保了这一点。

### Step 2.2: 补丁自检

Agent 读取生成的补丁内容，逐项检查：

**检查项**:
- 补丁中是否包含 `<<<<<<<` 或 `>>>>>>>` 残留？（有 → 致命错误，执行 `git reset HEAD~1 --soft` 回退，然后返回 Phase 1）
- 补丁中是否有明显的大段单边删除（一方的逻辑代码整块被移除）？（有 → 警告，复核该冲突块的合成理由）
- 补丁中是否引入了新的 import 语句但未在代码中使用？（有 → 补充或修正）
- 补丁中新增的代码是否对应了 Conflict Log 中记录的所有冲突块？（有未覆盖的 → 遗漏冲突）

如果自检发现致命错误（冲突标记残留），必须 `git reset HEAD~1 --soft` 后重新进入 Phase 1。

### Step 2.3: 专家评审

将 Conflict Log 和 `--remerge-diff` 补丁提交给 `code-reviewer` (Opus 级别) 进行评审。

评审维度：
- **意图完整性**: 补丁是否完整实现了 OURS 和 THEIRS 的所有变更意图，有没有遗漏？
- **逻辑正确性**: 合成后的逻辑是否存在新的边界条件错误？是否存在条件极性错误（注释说「跳过 X」，但代码实际是「只在 X 时执行」）？
- **副作用分析**: 是否有跨文件影响未考虑（方法签名变更、常量值变更、事件发布重复等）？

对于 code-reviewer 标记为 HIGH 严重度的发现，**必须进行对抗性验证**——读取相关文件上下文，确认该发现是真实问题还是假阳性。对抗性验证结果记录在 Conflict Log 中。

**判定流程**:
- `APPROVED`: 进入 Phase 3
- `REVISE`: 按以下流程处理:
  1. 返回 Phase 1.3，重新合成对应文件
  2. 合成完成后执行 `git add <修改的文件>`
  3. 使用 `git commit --amend --no-edit` 更新合并提交（保留提交消息，刷新内容）
  4. 重新执行 Step 2.1 生成更新的 `--remerge-diff`
  5. 返回 Step 2.2 自检，通过后重新提交 Step 2.3 审查
- `REJECT`: 标记为需要人工介入，输出完整的 Conflict Log + 补丁 + 审查意见

---

## Phase 3: 编译与测试验证

### Step 3.1: 编译检查

对项目的每个受影响模块执行编译。对于多模块项目，使用模块级编译（例如 Maven: `mvn compile -pl <module_path> -am -q`）。

编译失败 → 修复后执行 `git add <修复的文件>; git commit --amend --no-edit`，然后重新进入 Step 2.1 生成更新的 `--remerge-diff`，再执行 Step 2.2 自检。

**说明**: 编译修复可能改变了合并提交的内容，必须重新生成 remerge-diff 以确保审计数据与提交一致。

### Step 3.2: 测试

至少执行受影响模块的单元测试。合并涉及跨模块依赖变更时，扩大测试范围。

### Step 3.3: 诊断扫描

对改动文件执行 LSP 诊断（语法错误、类型错误、未使用导入等），确认零错误。

---

## Phase 4: MR 生命周期管理

### Step 4.1: 提交与推送

如果 Phase 3 中有修复导致 commit 被 amend，此时更新提交消息去掉 `[WIP: pending RPA audit]` 标记：

```bash
git commit --amend -m "merge: semantic merge <source_branch> into <target_branch>

Conflict files: <总数>
Resolution: SMA + RPA audit
Review patch: generated via --remerge-diff"
```

推送至远程特性分支。

### Step 4.2: 创建 MR

创建 Merge Request（GitLab 用 `glab mr create`，GitHub 用 `gh pr create`）。

MR 描述必须包含：
- 合并策略（SMA）
- 冲突文件数
- 评审状态（已通过 code-reviewer 审查）
- 编译和测试结果

### Step 4.3: 启动基线漂移监控

在 Agent 会话中启动后台监控进程：

```bash
# 记录目标分支当前 HEAD
TARGET_BRANCH="<target_branch>"
git fetch origin "$TARGET_BRANCH"
BASELINE_HEAD=$(git rev-parse "origin/$TARGET_BRANCH")

# 后台轮询：每 5 分钟检测基线是否变化
while sleep 300; do
    git fetch origin "$TARGET_BRANCH" 2>/dev/null
    CURRENT_HEAD=$(git rev-parse "origin/$TARGET_BRANCH" 2>/dev/null)
    if [ "$BASELINE_HEAD" != "$CURRENT_HEAD" ]; then
        echo "[SMA-MONITOR] 基线已变化: $BASELINE_HEAD -> $CURRENT_HEAD"
        echo "[SMA-MONITOR] 触发 Phase 5 增量处理"
        BASELINE_HEAD="$CURRENT_HEAD"
        # Agent 在此响应：进入 Phase 5 增量流程（手动触发，不在后台 shell 内自动执行）
    fi
done &
# 记录后台进程 PID 以便后续终止
echo $! > /tmp/sma-monitor.pid
```

Agent 收到 `[SMA-MONITOR] 基线已变化` 输出后，进入 Phase 5 增量处理流程。

**终止监控**（MR 合并或手动中止时）:
```bash
kill $(cat /tmp/sma-monitor.pid) 2>/dev/null; rm -f /tmp/sma-monitor.pid
```

---

## Phase 5: 持续增量 Patch 循环

**触发条件**: 目标分支（远程基线）在 MR 打开后发生了新提交。

### Step 5.1: 同步并检测

拉取远程目标分支最新代码，尝试合并到当前特性分支：

```bash
git fetch origin <target_branch>
git merge origin/<target_branch> --no-edit
```

合并后分两种情况：

**情况 A — 无文本冲突（自动合并成功）**:
git 自动合并成功不代表安全——自动合并在无冲突标记的情况下可能产生语义错误（如远程基线修改了方法签名、异常传播路径、默认参数等）。必须对自动合并结果执行完整验证：
1. 执行 `git show --remerge-diff HEAD` 确认输出为空（或仅含树结构变更，无代码级冲突解决）
2. 执行 Step 2.2 自检（检查 remerge-diff 输出中有无异常内容）
3. 执行 Phase 3 编译+测试验证
4. 验证全部通过后才能推送；任何失败 → 执行 `git reset --hard HEAD~1` 回退此次自动合并，按情况 B 处理

**情况 B — 有文本冲突**:
产生冲突标记的文件为增量冲突。进入 Step 5.2。

### Step 5.2: 增量冲突提取

核心原则：**只处理本次新增的冲突文件，严禁覆盖已有的冲突解决方案。**

提取方式：使用 `git diff --name-only --diff-filter=U` 获取未合并文件列表，对比之前 Phase 1 已处理过的文件清单（记录在 Conflict Log 中），差异部分即为新增冲突。如果某个文件同时出现在「已处理」和「未合并」列表中（即之前合成过的文件再次出现冲突），仍视为新增冲突，按 Step 5.3 特别规则处理。

### Step 5.3: 对新增冲突执行完整 SMA + RPA + 编译验证

新增冲突的每个文件必须走完整的 Phase 0 分类 → Phase 1 语义合并 → **Step 1.5 提交** → Phase 2 Patch 审计 → Phase 3 编译测试流程。

这不是「快速修复」——增量 patch 与首次合并享有同等的质量门禁。

**特别规则**: 如果某个文件之前已被 SMA 处理过，本次又出现新冲突，即使该文件在 Phase 0 归类时属于 INFRA 或 BUILD，也必须执行完整的意图理解和语义合成，不得使用「单边采纳」捷径。（原因：增量重新冲突表明基线变更影响了构建依赖语义或环境配置逻辑，Phase 0 的简化策略不再适用。）

### Step 5.4: 增量提交

提交消息格式：
```
fix(merge): resolve incremental conflicts with remote baseline

Remote <target_branch> moved. Resolved <N> new conflict files.
Previous resolutions preserved. Incremental patch: SMA + RPA audit.
```

### Step 5.5: 循环与终止

推送后回到 Step 5.1 继续监控。

终止条件（满足任一）：
- `git merge` 无冲突且 Phase 3 全通过
- 达到最大循环次数（默认 10 次）→ 标记 MR 为需要人工介入
- 用户手动中止

---

## 错误预防与已知陷阱

以下陷阱来自实战合并经验的教训总结，每条都对应实际发生过的错误。

### 陷阱 1: CI/CD 文件被来源分支覆盖

**实际案例**: 某次大型合并中有 9 个 CI/CD 配置文件在初始处理时未正确识别为 INFRA 类别，差点被来源分支版本覆盖。

**预防**: INFRA 类别文件始终保留目标分支版本。这些文件是环境绑定的，不存在「合并」的概念。

### 陷阱 2: 文件编码损坏

**实际案例**: 部分源文件从 Windows 环境（GBK 编码）迁移到 Linux 环境（UTF-8 编码）后出现中文注释乱码，编译报编码错误。

**预防**: 在读写任何文件前检查编码。如果检测到非 UTF-8 编码，先转换为 UTF-8 再操作。

### 陷阱 3: 并行 Agent 编辑同一文件的不同区域

**实际案例**: 某次合并中，两个相互依赖的 Service 类被不同子 Agent 同时编辑，存在竞争风险。实际处理中将其分配给同一个 Agent 串行解决。

**预防**: 按文件依赖关系排序冲突文件。有共享依赖（相互引用、共同基类）的文件必须串行处理。完全独立的文件可以并行处理。分配 Agent 任务时先做文件依赖图分析。

### 陷阱 4: Agent 执行超时

**实际案例**: 前端合并中，多个子 Agent（分别处理不同组件）执行超时（>90s），最终手动介入解决。

**预防**: 为子 Agent 设置合理的超时时间（建议 120s）。超时后不要盲等——主动检查 Agent 的工作进度，判断是「接近完成」还是「卡住」。如果 Agent 卡住，不要直接 `--ours` 或 `--theirs` 采纳——手动分析冲突并走 SMA 流程。

### 陷阱 5: DTO/VO 字段丢失

**实际案例**: OURS 有字段 A，THEIRS 有字段 B，合并后只保留了一边的字段，导致序列化/反序列化错误。

**预防**: SCHEMA 类别文件的字段处理必须保证两边字段并集完整。冲突字段走 SMA 语义合并，非冲突字段全量保留。

### 陷阱 6: Import 语句遗漏

**实际案例**: 合成的新代码使用了来源分支引入的类，但因为 import 在文件的非冲突区域、该 import 在目标分支不存在，导致编译失败。

**预防**: 合成完成后，执行 LSP 诊断扫描。所有 `unresolved symbol` 错误必须修复。

### 陷阱 7: 注释与代码极性不匹配

**实际案例**: 在某次合并审计中，某 Service 方法存在一个隐蔽 bug——注释说「调试指令不参与报告」（skip-intent），但代码中的 guard 条件使用了反向极性（`!DEBUG_MODE.equals(type)`），导致只有调试指令被保护，而生产上报逻辑落在 guard 块之外，无条件执行。这个 bug 同时存在于合并双方的代码中，任何文本对比工具都无法发现——因为它不是「合并错误」，而是「双方共有的设计缺陷」。

**预防**: 在 Phase 1 的逻辑合成自检中，专门检查「注释意图」与「代码实际行为」是否一致。如果注释说「跳过 X」，代码的 guard 条件必须排除 X，而不是包含 X。特别是检查 guard 条件下的代码块之外，是否存在应该被保护但未被保护的操作。这是一个必须用「意图理解」而非「文本对比」来解决的问题——也是为什么 SOP 禁止单边采纳和脚本批处理的根本原因。

---

## 升级路径

遇到以下情况时，Agent 必须暂停当前流程并升级为人工决策，不得继续自动化：

1. **无法归类的冲突**: 冲突涉及的语言或框架超出 Agent 的理解范围
2. **矛盾变更为流程分支 vs 流程分支**: 两个控制流作用在同一代码点，无法确定正确行为
3. **跨仓库影响**: 冲突涉及多个仓库之间的接口契约变更（API 签名、消息格式、数据库 Schema）
4. **安全相关变更**: 冲突涉及认证、授权、加密、SQL 拼接、XSS 防护等安全敏感代码
5. **超过最大重试次数**: 同一冲突块经过 3 次合成-审查-修改循环仍未通过

升级时输出：
- 完整的 Conflict Log（所有已处理和未处理的冲突记录）
- `--remerge-diff` 补丁（已处理部分）
- 未解决冲突的具体描述和阻塞原因
- 推荐的人工处理方向

---

## Agent 执行总清单

**Phase 0 完成确认**:
- [ ] 所有冲突文件已按路径模式分类（路径模式已按项目技术栈替换）
- [ ] RENAME_DELETE 和 OTHER 类别文件已人工确认策略
- [ ] BUILD 类别已标记为「增量合并 + 版本确认」
- [ ] BASE_COMMIT 已记录

**Phase 1 完成确认**:
- [ ] Step 1.0 文件依赖图分析已完成，Serial Group 已标记
- [ ] 每个冲突文件的三方代码（BASE/OURS/THEIRS）都已获取
- [ ] 每个冲突块都有 Conflict Log 记录（意图归类 + 性质判定 + 合成方向 + 自检结果）
- [ ] 每个冲突块通过了自检清单（无残留标记、逻辑完整、注释一致性）
- [ ] 合成的代码中无 `<<<<<<<` / `>>>>>>>` 残留
- [ ] 未使用 `--ours` / `--theirs` / `checkout` 单边采纳任何逻辑文件
- [ ] 未使用 `sed` / `awk` / 正则批量替换
- [ ] Step 1.5 合并已提交（`git merge --continue` 成功，提交前文件 grep 扫描通过）
- [ ] Step 1.5 提交前文件 grep 扫描通过（零残留）

**Phase 2 完成确认**:
- [ ] `git show --remerge-diff HEAD` 补丁已生成
- [ ] 补丁自检通过（无残留标记、无异常单边删除）
- [ ] code-reviewer 评审通过 (APPROVED)
- [ ] code-reviewer 标记的所有 HIGH 发现都经过了对抗性验证
- [ ] 如有 REVISE 循环，每次循环中已执行 `git add` → `git commit --amend --no-edit` → 重新生成 remerge-diff

**Phase 3 完成确认**:
- [ ] 编译通过
- [ ] 相关模块测试通过
- [ ] LSP 诊断零错误
- [ ] 如有编译修复，已执行 `git commit --amend --no-edit` 并重新生成 remerge-diff

**Phase 4 完成确认**:
- [ ] 提交消息符合 merge: 规范（`[WIP]` 标记已移除）
- [ ] MR 已创建并包含合并摘要
- [ ] 基线监控已启动（后台轮询进程运行中，PID 已记录）

**Phase 5 持续监控**:
- [ ] 每次增量 patch（包括 git 自动合并无冲突的情况）走完整 Phase 1-3 流程
- [ ] 增量提交消息符合 fix(merge): 规范
- [ ] 最大循环次数内未超限

---

## 关于「不在 SOP 中写代码」的原则

本 SOP 不包含任何可执行的脚本、伪代码或程序化方法。每一条指令描述的是「Agent 需要理解什么、做出什么判断、采取什么行动」，而不是「Agent 运行什么命令/脚本」。

意图理解——而非文本匹配——是这套方法论的核心。SOP 中的所有判断节点（意图归类、冲突性质判定、合成方向选择）都需要 Agent 实际阅读和理解代码的业务含义后才能执行。这不是一个可以脚本化的流程。

如果 Agent 执行本 SOP 时遇到无法判断的情况，升级路径就是为此设计的：暂停、记录、升级——而不是盲猜或调用脚本。

---

## 技术栈适配指南

将本 SOP 应用于项目时，需完成以下适配工作：

1. **路径模式替换**: 在 Phase 0.2 中，根据项目的技术栈替换示例路径模式。参考 `ai-specs/tech/` 中的技术规范（如 `tech-spec-spring-boot.md`、`tech-spec-vue3.md`）确认项目标准路径。
2. **构建命令适配**: 在 Phase 3.1 中，替换 `mvn compile` 为项目实际的构建命令（如 `npm run build`、`go build`、`cargo build`）。
3. **import 语句模式**: 在 Step 1.0 依赖图分析中，确认项目使用的 import/依赖声明语法（Java `import`、JS/TS `import/require`、Python `import/from`、Rust `use` 等），适配依赖图构建逻辑。
4. **文件扩展名**: 在 Phase 0.2 路径模式中，替换 `.vue`、`.tsx` 等前端扩展名为项目实际使用的扩展名。

---

*版本: 1.0 (de-identified)*  
*基于内部 SOP v5.3 提炼*  
*最后更新: 2026-06-06*  
*状态: draft*
