---
name: ylk-delivery-triple
description: |
  面向 YLK workspace 任意子项目的授权后交付流程：核验工作树和远端、按仓原子 commit、推送、依据目标仓当前 GitLab CI 建立服务到交付物的映射，并通过 glab 触发和跟踪构建与部署。
  触发词：commit push CI/CD 三连、提交推送发布、触发 GitLab 流水线、构建部署、交付上线。
---

# YLK Delivery Triple

适用于 YLK workspace 任意仓库的授权后交付。流程仅处理已完成且已验证的改动：`commit → push → CI/CD`。以目标仓当前分支、remote、`.gitlab-ci.yml`、includes、交付物配置和运行环境为事实来源；不得照搬其他仓、历史流水线、memory 或本次会话中的服务名、job 名、环境和部署方式。

## 适用边界

- 仅在当前用户明确授权 commit、push、触发 pipeline 或部署时执行对应动作；授权范围不自动外推到其他仓、分支、环境、job 或后续发布。
- 必须先完成适用的代码审查、定向测试、编译/lint/build 和 `git diff --check`。验证失败、未执行或与改动无关时，不能把改动交付为已验证。
- 不负责修复业务代码、写库、数据重放、重新登记、删除对象或处理存量数据。发现这些需要时，停止该分支并请求单独授权。
- 不 force push、不改 protected branch 策略、不跳过 CI、不删除或覆盖用户已有改动。

## 交付前核验

对每个目标仓分别执行，并记录脱敏结果：

```bash
git status --short --branch
git diff --check
git diff --stat
git remote get-url origin | sed -E 's#(https?://)[^/@]+@#\1<redacted>@#'
git branch --show-current
git log -1 --oneline
```

逐项确认：

1. 仓库绝对路径、当前分支、目标 remote host、推送目标分支和是否为 protected branch；
2. 所有待提交文件均属于已授权范围；新增文件、未跟踪文件、用户已有修改和跨仓改动必须逐个盘点；
3. 提交前的测试、编译、代码审查与格式检查结果真实且适用；
4. 本次 commit 的意图与文件范围一致，按仓独立提交，不将无关文档、私有配置、凭据、临时产物或其他 Skill 混入；
5. `git diff --cached --check` 在暂存后仍通过。

发现 remote、分支、文件范围、验证结论或授权范围不明确时，不得 commit 或 push；先停止受影响仓并报告。普通代码调查、静态比对或本地验证不因此停止。

## 原子 Commit 与 Push

1. 只暂存已核对文件，避免使用无差别 `git add .`；
2. 使用仓库既有提交语言和 Conventional Commit 风格；
3. commit 后核对 `git show --stat --oneline HEAD`，确认提交内容与预期一致；
4. push 前再次输出并核对 remote、分支和 push 目标；不得使用 `--force`，除非当前用户明确授权该次 force push；
5. 正常推送后读取 `git status --short --branch`，确认本地分支与目标远端关系；
6. 任一仓 push 失败时，只报告该仓的脱敏错误与当前提交状态，不回退其他仓已成功的独立提交，也不擅自改用其他 remote 或分支。

## CI/CD 交付物映射

每个要交付的服务或前端项目，在触发 job 前必须从目标仓当前 `.gitlab-ci.yml`、所有 include、构建/deploy module、产物清单、Dockerfile、Helm values 或部署脚本建立唯一映射：

| 服务/模块 | 构建 job | 产物类型与路径 | workload 引用或挂载位置 | deploy job | rollout 方式 |
|-----------|----------|----------------|--------------------------|------------|--------------|
| `<target>` | `<job>` | `<JAR、静态包或 image>` | `<deployment/path>` | `<job>` | `<command>` |

映射至少要能证明：

- 构建 job 实际构建哪个模块或前端项目；
- 产物的准确路径、名称和保留方式；
- deploy job 使用哪个产物、复制/挂载到哪里、重启哪个 workload；
- CI variables、rules、needs、branch/tag 条件与当前交付是否匹配；
- 发布目标环境与用户授权是否一致。

映射无法建立，或 job 与映射不一致时，停止触发该 CI/CD 分支并报告证据缺口。不得通过同名服务、历史成功流水线、镜像 tag 或其他仓配置猜测交付模型。

## Docker 决策

默认跳过 Docker 镜像构建。只有目标仓当前 CI 与部署映射明确证明镜像是该服务本次交付物、且目标 workload 直接消费该镜像时，才允许触发 Docker build/push job 并验证镜像 digest。

当 deploy job 复制、挂载或替换 JAR、静态资源包等外挂产物后执行 rollout/restart 时，镜像仅是运行时基础层，Docker job 不属于本次交付，必须跳过；不得将镜像 tag 当作代码版本或部署完成证据。

## 使用 glab 触发与跟踪

- 多 GitLab host 环境必须显式指定 `GITLAB_HOST`；不要依赖当前目录或 `glab` 默认 host 推断。
- 获取 pipeline、job、变量和状态时使用 `glab` 的目标 host 与目标项目；API 调用不得使用 `glab api | python` 管道。需要 API 解析时，使用受控临时 JSON 文件后解析，完成立即删除。
- 先确认 push 对应 commit 已被目标 GitLab 项目接收，再创建或定位该 ref 的 pipeline；不能对错误分支、旧 commit 或不明确项目触发。
- 手动 job 必须按映射顺序触发：先构建，构建成功并产物可用后再触发 deploy。不得为“完整性”触发不属于交付映射的 Docker、全量构建、测试或部署 job。
- 持续跟踪 pipeline 和 job 状态。失败时报告 job URL/ID、脱敏日志摘要、失败阶段、是否影响已交付服务；不得把 allow_failure、manual 或已创建 pipeline 当作成功。

## 部署后回归

按实际交付模型收集证据：

- pipeline 与目标 job 成功；
- 实际 JAR、静态包或镜像 digest 与本次 commit 对应；
- workload 已加载该交付物，rollout/Ready 状态正常；
- 相关日志无新增启动或运行错误；
- 受影响 API、页面、数据库、消息、对象存储、缓存或异步任务按本次改动的实际边界验证。

外挂 JAR 模式核验容器/主机上的 JAR 校验和、时间戳或实际文件内容；镜像模式核验部署引用的 digest。未涉及的层面明确标记“不适用”，不得作为流水线失败条件。存量数据、缓存、历史审核记录或对象路径不会因发布自动修复，必须单独说明并获得独立操作授权。

## 失败与完成标准

**STOP 的条件仅限于：** 未授权外部动作、目标仓/分支/remote/环境无法判定、交付物映射无法建立、需要 Owner 决定发布环境或业务数据范围、或继续会泄露敏感信息/改变未授权外部契约。

**继续调查但不宣称完成：** 普通只读命令失败、局部 CI 配置歧义、历史资料冲突或单个远程探针失败时，记录脱敏错误并继续用当前代码、CI 配置、日志与本地证据调查；只有该缺口阻断下一步外部动作时才停止该分支。

完成前逐项自检：

1. 每个 commit、push、pipeline、job 与部署是否均有已核对的仓、分支、remote、映射和授权？
2. 是否错误触发 Docker、全量或其他不在映射中的 job？
3. 是否将未执行、失败、allow_failure 或仅创建的 pipeline 写成成功？
4. 是否泄露、持久化或提交了 Token、密码、私钥、完整连接串或私有配置？
5. 每个仓是否保持独立、原子且可追溯的提交？

全部满足后，报告每仓提交 SHA、推送目标、pipeline/job 状态、实际交付物、部署与回归证据，以及未执行项和剩余风险。
