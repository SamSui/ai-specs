---
title: 质量、交付与部署门禁
author: 顾小宇
tags: [质量门禁, 交付, 部署, CI/CD]
description: 测试、构建、Git、CI/CD 与部署的验证矩阵、失败归因和交付门禁规则。
version: v1.0
last_updated: 2026-08-14
---

# 质量、交付与部署门禁

> 来源与时效性：见 [来源与时效性](sources-and-freshness.md)。**读取时机**：开始测试、编译、lint、build、CI、commit、push、部署或回归前读取。构建命令以当前仓 GitLab CI 为第一来源，README 为第二来源；不要照搬其他仓或历史命令。**不能替代**：当前 pipeline、仓库工作树、目标环境 rollout 和授权状态。

## 验证矩阵

- Java Service/Mapper/转换逻辑 → JUnit + Mockito 定向测试、根项目 `./mvnw -pl <module> -am compile`。
- Feign/RPC/协议字段 → 请求对象捕获、字段契约测试、必要时下游 API/DB 对比。
- 定时任务/异步回写 → 纯转换单测或 mock 调度依赖，验证真实持久化字段。
- Vue 组件 → 修改文件定向 ESLint，项目可用时 typecheck/build。
- SQL/migration → schema 校验、升级/回滚策略、受影响查询验证。
- K8s/CI/CD → pipeline、rollout、日志、关键 API。

## 测试与工作目录

测试必须断言与本次修改直接相关的可观察结果，而非仅断言“不抛异常”。根据实际代码路径覆盖适用的新建/更新差异、局部下游响应、null/空白、历史值、JSON/transient 字段、失败 fallback、并发或重试行为；未涉及的类别无需强制覆盖。

所有本次新增或修改的 Java `@Test` 方法必须有紧邻注解的 JavaDoc，且至少写明：测试场景、关键输入或前置状态、预期的可观察结果。方法命名、行尾注释和仅描述实现细节的注释不能替代 JavaDoc。缺少该注释属于质量门禁失败，补齐后再执行测试与交付。

Maven 命令必须由目标仓根目录运行；多模块必须使用 CI/README 已确认的模块坐标与 `-pl -am`：

```bash
cd /path/to/repository
./mvnw -pl <module> -am test -Dtest=<TestClass> -DfailIfNoTests=false
./mvnw -pl <module> -am compile
```

NEVER 在子模块执行 `mvnw`。先从 `.gitlab-ci.yml`、`.gitlab-ci/` 和 `docker-artifacts.csv` 提取命令；其次才参考 `README.md`。错误 reactor、错误项目目录和缺失本地依赖不等于代码测试失败。

每次验证后：

```bash
git diff --check
git status --short
rg -n 'TODO|FIXME|test\.skip|test\.only' <changed-files>
```

`FIXME` 只能标记已证明的历史共性问题且明确不在本次范围。`test.skip`、`test.only`、未实现分支和虚假测试是阻塞项。

## 失败归因

1. 收集完整错误并定位文件；
2. 错误在本次文件则修复；
3. 错误仅在未修改文件时，报告具体错误及无关证据；
4. 仍须完成修改文件的定向验证，不能用全量失败替代验证。

## Git、CI/CD 与部署

默认禁止 commit、push、Dolt sync、pipeline、手动部署、生产库写入和业务重放。获得明确授权后，先核对：

```bash
git status --short --branch
git diff --check
git diff --stat
git remote get-url origin | sed -E 's#(https?://)[^/@]+@#\1<redacted>@#'
git branch --show-current
```

确认目标仓、remote、GitLab host、当前/目标分支、提交文件、MR/protected branch 规则、是否 force 和目标环境。多 GitLab host 时必须显式传入 `GITLAB_HOST`。调用 API 不用 `glab api | python` 管道，改为 curl 写入临时 JSON 后解析。

触发任何 CI job 前，必须从当前 `.gitlab-ci.yml`、include、`docker-artifacts.csv` 与部署配置建立并记录唯一交付物映射：

| 服务/模块 | 构建 job | 产物类型与路径 | workload 引用或挂载位置 | rollout 方式 |
|-----------|----------|----------------|--------------------------|--------------|
| `<target>` | `<job>` | `<JAR 或 image>` | `<deployment/path>` | `<command>` |

映射无法建立，或所选 job 与映射不一致时停止。以目标仓 CI 为准：多数 YLK 后端服务通过更新外挂 JAR 后 `rollout restart` 部署，镜像只提供运行时基础层；目标 workload 读取外挂 JAR 时，Docker 镜像构建 job 不属于本次交付，必须跳过，不能将镜像 tag 当作代码版本证据。仅当映射证明 CI 明确将镜像作为该服务的交付物时，才构建和验证镜像。

部署完成需验证与本次变更和交付模型相关的证据：pipeline、实际交付物、目标 workload 是否加载对应版本、rollout/Ready/日志，以及受影响的 API、数据库、消息、对象存储、缓存或页面行为。采用外挂 JAR 时，核验挂载 JAR 的校验和或时间戳及容器内实际内容；采用镜像时，核验镜像 digest。未涉及的层面标记为“不适用”，不得作为失败条件。

代码发布通常不修复既有镜像、审核单、缓存或对象路径。交付必须明确新数据、存量数据、必要的迁移/重放动作，以及其独立授权状态。
