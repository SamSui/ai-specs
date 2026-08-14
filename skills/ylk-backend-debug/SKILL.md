---
name: ylk-backend-debug
description: |
  后端日志分析 → 编码 → 部署 → 测试验证的自动化闭环调试流程。从运行态日志（K8s pod / JVM / Spring Boot）出发，定位根因后直接编码修复、Commit+Push、触发 GitLab CI manual pipeline、再回到目标 pod 验证 API 200，形成完整闭环。K8s/CICD 是载体之一，通用原理适用于任何有日志可查、代码可改、CI 可触发的后端服务。
  触发词：pod 起不来、CrashLoopBackOff、部署后接口不通、Bean 冲突、stale class、CI 构建后 pod 没更新、curl 拿不到 200、走一遍流水线排查、需要日志-编码-部署-验证闭环。
  需要用户提供：远端 K8s 服务器 SSH MCP 连接名、待排查的 deployment（或服务）名；其余从 .gitlab-ci/ 自动抽取。
author: 顾小宇
version: v1.1
last_updated: 2026-08-14
---

# 后端日志分析 → 编码 → 部署 → 验证 自动化闭环

适用于：本地仓库代码已经合到分支上，但部署到远端 K8s 集群的 pod 起不来 / 起来但 API 拿不到 200。
范围覆盖：**Java/Spring Boot 多模块 Maven 项目 + GitLab CI manual pipeline + 远端 K8s 集群通过 SSH MCP 访问**。

## 核心方法论

按以下阶段顺序执行，每步不可跳过：

- **0 自检** → 确认链路的每一环都能动：SSH 登录 / kubectl 看 deploy / kubectl 看日志 / CI 能触发并 rollout
- **1 排查** → 从运行时报错回溯到代码 / 构建 / 部署中的某一层：看 pod 日志 → 锁定 exception → grep 源码 → 对比 jar 内 class → 看 CI 缓存
- **2 Plan/Coding** → 只改修启动阻塞的最小集：不在无关文件做"顺手优化"，CI 层问题就别动源码
- **3 Commit+Push** → conventional commits，推到正确远端：推送前显式 echo 推送目标 + 分支二次确认
- **4 CI 触发** → 按"先 clean、再 build、再 deploy"顺序触发 manual jobs：用 curl + PRIVATE-TOKEN，禁止 glab pipe
- **5 验证** → 新 ReplicaSet 起、pod Running 1/1、curl 拿 200：同一窗口对比 jar mtime、rs hash、pod age、API status

## 必要前提

- 本机能直接 `kubectl` 或者已有可用的 **SSH MCP server**（推荐，已配置好 `mcp__ssh-mcp-server__execute-command` + `mcp__ssh-mcp-server__list-servers`）连到集群所在的跳板机/master 节点
- 本地仓库就是要修的项目，且 `.gitlab-ci/` 是模块化 yml（`build.yml` / `deploy-dev.yml` / `docker-artifacts.csv`）
- GitLab PAT 已配置（一般在 `~/.config/glab-cli/config.yml` 的 `hosts.<gitlab-host>.token`），或用户能现场提供

## Blocker & Escalation Protocol

**STOP and report when** (any one triggers):

- SSH MCP 连接失败或 kubectl 无法连接到集群
- 日志中异常类 grep 源码无结果，无法定位根因
- CI job 连续 2 次触发失败（非目标服务问题）
- 需要修改的源码范围超出本次修复的最小集
- 推送目标 remote 不是 `origin`（datanet.wk）

**NEVER do these when blocked**:

- ❌ 凭记忆猜测 SSH 连接名、deployment 名或 namespace
- ❌ 用 glab pipe 调 API（CLAUDE.md 行为 2）
- ❌ 直接对 success 的 build job 调 `/play`（要 `/retry`）
- ❌ 后台脚本退出就当 CI 跑完——脚本只是触发器，要看 job 真实 status
- ❌ 在排查链路里"顺手"改无关代码（user 明确禁止过：本次问题只修启动阻塞）
- ❌ 默认 actuator 路径 200——本项目 actuator exposure 经常只开 `prometheus`，要先看日志里的 `management.endpoints.web.exposure.include`

**Instead, do this**:

1. Stop immediately — do not attempt workarounds
2. Report: what failed + what you tried + impact scope
3. Wait for owner to decide the path forward
4. 如果链路里要触发 CI，远端 GitLab host 不明确（`git remote -v` 多 remote）→ 必须问
5. 若有多份 PAT，使用哪个 host 的 → 必须问

**Self-check** (before completing any debug session):

- SSH 登录、kubectl、日志、CI job 自检 4 件套是否全部完成？
- ReplicaSet hash 是否真正更新了？jar mtime 是否变新？
- curl 200 是 actuator 还是真实业务路径？
- 是否把旧 RS/pod 状态当成了新状态？

**Fallback**: 情况不在列表中但感觉不对 → 同样协议，STOP and report。"Not in list" ≠ permission to proceed。

## Step 0：会话开始就要问清的变量

⚠️ **不要靠记忆或猜，必须 `AskUserQuestion` 拿，且要 4 个一起问以减少往返**：

```
Q1: 远端 K8s 集群通过哪个 SSH MCP 连接名访问？
    (先跑 mcp__ssh-mcp-server__list-servers 列出选项让用户挑)
Q2: 要排查的 deployment / service 名是什么？
    (示例：df-workbench-sandbox-backend、bridge-gateway)
Q3: 这个 K8s deployment 所在的 namespace 是？（默认 default）
Q4: 本地仓库的当前 git 分支就是要部署的分支吗？(yes / no，no 要切)
```

可选追问：

- "如果链路里要触发 CI，远端 GitLab host 是 `gitlab.datanet.wk` 还是别的？"（如果 `git remote -v` 多 remote 则必须问）
- "若有多份 PAT，使用哪个 host 的？"

## Step 1：自检 4 件套（**关键信息确认后必跑**）

> 这一步是本 skill 的灵魂——不要因为"看起来都能动"就跳过。许多排查最终都败在某一环根本不通却没人去测。**先一次性把 4 个动作并行跑完，再看后面 step**。

```bash
# 1. SSH 登录是否通
mcp__ssh-mcp-server__execute-command(
  connectionName="<SSH_CONN>",
  cmdString='echo 登录成功: $(hostname) $(date +%F\ %T); uname -a'
)

# 2. kubectl 能看到 deployment（用 grep 兜底，名字可能略有差异）
mcp__ssh-mcp-server__execute-command(
  connectionName="<SSH_CONN>",
  cmdString='kubectl get deploy -A 2>&1 | grep -iE "<DEPLOY_KEYWORD>" | head -10'
)

# 3. kubectl 能看到运行时日志
# 注意：先用 deployment 实际 selector 取 pod，不要随手用 app=<name>，往往对不上
mcp__ssh-mcp-server__execute-command(
  connectionName="<SSH_CONN>",
  cmdString='kubectl get deploy <DEPLOY> -n <NS> -o jsonpath="{.spec.selector.matchLabels}"; echo'
)
# 拿到 selector 后再
mcp__ssh-mcp-server__execute-command(
  connectionName="<SSH_CONN>",
  cmdString='POD=$(kubectl get pod -n <NS> -l <SELECTOR_KV> -o jsonpath="{.items[0].metadata.name}"); echo "POD=$POD"; kubectl logs -n <NS> "$POD" --tail=20'
)

# 4. CI 能触发部署 → kubectl 能看到 rollout
# 见 Step 4，先在自检阶段触发一个不影响代码的 deploy job (如 DD0x:service) 验证
# 重点对比 ReplicaSet 在触发前后是否增加了新 hash
```

⚠️ 自检发现的问题：**当场如实汇报，不要边自检边偷偷"顺手修"**。例如发现 deployment AGE 是 32d 不代表挂了 32 天，要看 ReplicaSet/pod 年龄；发现 selector 不是 `app=<name>` 要立刻换。

## Step 2：从 `.gitlab-ci/` 抽取本项目的 pipeline job 命名

⚠️ **不同项目的 job 名是约定俗成的，但具体叫什么必须从 `.gitlab-ci/` 里抽，不能照搬"DD01:deploy"等假设名**。本机的 ylk 工作区是 `B00:clean / B0x:service / DD0x:service` 命名，其他工作区可能是 `build:xx / deploy:xx`。

```bash
# 列模块
ls .gitlab-ci/ .gitlab-ci/modules/ 2>/dev/null

# 抽 build 阶段所有 job 名 + needs
grep -nE '^[A-Z0-9]+:\S+:|^\s+needs:' .gitlab-ci/build.yml .gitlab-ci/deploy-dev.yml 2>/dev/null

# 找"全量 clean"job（典型名：B00:clean、clean、mvn-clean）
grep -nE 'mvn(w)? clean|maven\.compiler\.useIncrementalCompilation' .gitlab-ci/*.yml

# 找 service ↔ deploy_name 映射
cat .gitlab-ci/docker-artifacts.csv 2>/dev/null
```

把抽到的内容整理成本项目专属映射（job 名不可脑补，必须从实际 yml 里读）：

- **clean** → `<例：B00:clean>` — 跑 `mvnw clean`，独立 manual
- **全量 build** → `<例：B01:all>` — 编译所有 module
- **单服务 build** → `<例：B02:sandbox>` — 只编译目标 service
- **单服务 deploy** → `<例：DD02:sandbox>` — `needs:` 单服务 build，rsync jar + kubectl rollout restart
- **全量 deploy** → `<例：DD01:all>` — needs 全量 build

后续所有 CI 触发动作都引用这张表里的 job 名。

## Step 3：排查实战清单

按"从远到近"的层级一层层剥：

### 3.1 看 pod 日志锁定异常类

```bash
kubectl logs -n <NS> <POD> -c <CONTAINER> --tail=80 2>&1 | tail -100
```

重点抓 `Caused by:`、`Exception in thread`、`UnsatisfiedDependencyException`、`ConflictingBeanDefinitionException`、`NoClassDefFoundError`、连接被拒绝。

### 3.2 异常 → 源码定位

```bash
# 比如 Bean 冲突看哪个类被报，grep 源码
find . -name "<ClassName>.java" -not -path "*/target/*"
grep -rln "<ClassName>" --include="*.java" -- . | grep -v target | head
```

### 3.3 区分"源码层问题" vs "构建层问题"

- **源码里只有 1 份类，但运行时报"两份同名 Bean"** → **构建层 stale class**（B0x 没跑 mvn clean，旧分支编译产物残留在 runner workspace）
- **源码里有 2 份重复类** → **合并/迁移遗留**，删一份
- **`Unsatisfied dependency` + 找不到 Bean** → 源码层 / `@ComponentScan` 路径漏了
- **`NoClassDefFoundError`** → 依赖版本冲突 / `mvn dependency:tree`
- **启动后 200 拿不到、404** → actuator endpoint 没暴露 / context-path 不对 / Ingress 把 `/<prefix>` 剥了

### 3.4 构建层 stale class 快速确认

```bash
# 源码侧只有 1 份的类，target/classes 里却有 2 份 → 100% stale class
find datafield-sandbox-main/target/classes -name '<ClassName>.class' 2>/dev/null
# 历史移动过位置吗（典型场景）
git log --all --oneline -- '<old/path/Xxx.java>' '<new/path/Xxx.java>'
```

→ 修法：**走一遍 clean 流水线**（Step 4）。

## Step 4：CI 触发——按正确顺序串起来

### 4.1 不开新 pipeline，直接 retry 已有 pipeline 上的 job

GitLab 允许对 success job 调 `/jobs/:id/retry` 重跑（同一份 sha）。**不需要 push 一个 commit 来开新 pipeline**。

```bash
TOKEN=<from ~/.config/glab-cli/config.yml>
PID=<project numeric id>

# 1. 查最近的 pipeline + jobs
curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
  "http://<gitlab-host>/api/v4/projects/$PID/pipelines?ref=<branch>&per_page=3" \
  > /tmp/pipes.json
python3 -c "import json;[print(p['id'],p['status'],p['sha'][:8],p['web_url']) for p in json.load(open('/tmp/pipes.json'))]"

curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
  "http://<gitlab-host>/api/v4/projects/$PID/pipelines/<PIPE_ID>/jobs?per_page=50" \
  > /tmp/jobs.json
python3 -c "import json;[print(j['id'],j['status'],j['stage'],j['name']) for j in json.load(open('/tmp/jobs.json'))]"

# 2. 顺序：先 play clean，再 retry build，再 retry deploy
curl -sf -X POST --header "PRIVATE-TOKEN: $TOKEN" \
  "http://<gitlab-host>/api/v4/projects/$PID/jobs/<CLEAN_JOB_ID>/play" \
  > /tmp/clean.json
# 等 success（必须真等，不要看到接口返回就当跑完）
# build 已 success 要用 retry，新 manual 用 play
```

⚠️ **常见坑**：

- 不要 glab pipe（CLAUDE.md 行为 2），用 curl + 临时文件
- "脚本结束 ≠ 流水线结束"，后台轮询脚本退出后**必须再调一次 API 确认 job status=success**
- Spring Boot 启动慢的项目要给 deploy 后 60s+ 才看 pod，不要立刻断言

### 4.2 在自动化里串轮询

```bash
wait_job () {
  local jid="$1" name="$2"
  for i in $(seq 1 240); do
    s=$(curl -sf --header "PRIVATE-TOKEN: $TOKEN" \
        "http://<host>/api/v4/projects/$PID/jobs/$jid" \
        | python3 -c "import json,sys;print(json.load(sys.stdin)['status'])")
    echo "$(date +%T) $name(id=$jid) status=$s"
    case "$s" in
      success) return 0;;
      failed|canceled|skipped) echo "$name ended $s"; return 1;;
    esac
    sleep 15
  done
}
```

后台跑这个脚本（`run_in_background:true`）之后，**收到 task-notification 不代表 CI 跑完**，要 `Read` log 文件确认它走到 `DONE` 才算。

## Step 5：验证 API 200

在 CI 触发完 → 等 pod 起来这段时间记基线，方便对比：

```bash
# 基线（CI 触发前）
echo "=== 基线 ==="; date
ls -la <APP_INSTALL_DIR>/backend/<service>.jar   # jar mtime
kubectl get rs -n <NS> -l <SELECTOR> --sort-by=.metadata.creationTimestamp | tail -3
kubectl get pod -n <NS> -l <SELECTOR>

# 触发完后等 60-180s 再对比：
# - jar mtime 应该变新
# - 出现一个新的 ReplicaSet hash，旧的缩到 0
# - pod Running 1/1，RESTARTS=0
# - 日志里有"启动成功"/"Tomcat started"
```

拿 200：

```bash
POD=$(kubectl get pod -n <NS> -l <SELECTOR> -o jsonpath='{.items[0].metadata.name}')

# 先看实际端口（不要信 deployment yaml 的 containerPort，看 ss 实测）
kubectl exec -n <NS> "$POD" -c <CONTAINER> -- ss -ltn

# 先打 actuator（管理端口和业务端口可能不同）
kubectl exec -n <NS> "$POD" -c <CONTAINER> -- sh -c '
  for u in /actuator/prometheus /actuator/health /<prefix>/actuator/health; do
    code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:<PORT>$u)
    echo "[$code] $u"
  done'

# 如果 actuator 都 404，直接打日志里看到的真实业务路径
# 拿到 200 即收口
```

## Step 6：复盘 + 记忆沉淀

每一次实质性根因都该写一条 project memory（不在本 skill 范围，但要提醒用户）：

- 路径：`~/.claude/projects/<this-project-encoded>/memory/<slug>.md`
- 收录到 `MEMORY.md` 索引
- 写"症状 / 修复 / 已踩 / 机制改进选项"四段

## 一次成功 run 的形态

```
0  自检：SSH ✅ deploy ✅ logs ✅ deploy-job ✅
1  排查：日志拿到 ConflictingBeanDefinitionException → 源码只 1 份 → target/classes 2 份 → stale class
2  Plan/Coding：no-op（不改源码）
3  Commit+Push：no-op
4  CI：B00:clean play → success; B0x:svc retry → success; DD0x:svc retry → success
5  验证：jar mtime 新; 新 RS 出现; pod Running 1/1; curl /actuator/prometheus → 200; curl /<biz> → 200
6  写 memory：ci-bxx-stale-class-trap.md
```

整套流程在 ylk/datafield-sandbox 上一次跑通：

- 5 分钟内完成 0→5 步
- 没动一行源码，靠 CI 重跑解决
- 沉淀的 memory 在 [[ci-b02-stale-class-trap]] 里
