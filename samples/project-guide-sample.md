---
title: [项目名称] - 开发者手册（样本）
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: ⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。 本手册汇总项目开发所需的核心知识，涵盖目录结构、构建编译、容器启动、E2E测试、架构决策等。
---

# [项目名称] - 开发者手册（样本）

> **⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。**
>
> 本手册汇总项目开发所需的核心知识，涵盖目录结构、构建编译、容器启动、E2E测试、架构决策等。
>
> **📌 开发过程中遇到任何不清楚的问题，随时回来翻看本文档。** 本文档是项目的"活地图"，业务理解、技术约束、常见错误都会在此持续更新。

---

## 1. 项目概览

[项目名称] [项目阶段] 是一个企业级**数据预处理平台**，核心目标是：**把低质量原始数据集治理成高质量数据集，并生成可追溯的审计日志**。

采用**双语言架构**（Java + Python）+ **单前端**（Vue3 SPA，admin-console 为唯一前端项目）实现。

| 方向 | 技术栈 | 说明 |
|------|--------|------|
| 前端 | Node 24 + Vue 3 + Vite 5 + ElementPlus + Pinia | admin-console 唯一前端（demo-hall 已移入 archived） |
| 后端 | JDK 17 + Spring Boot 3.4.12 + MyBatis-Plus 3.5.16 | 模块化单体 2.0 |
| 算法 | Python 3.11 + FastAPI | 独立算法服务，Registry 注册发现 |

### 1.1 业务定位（必读）

**0 号文件**（`docs/00-智能治理——数据预处理.md`）是所有需求的唯一来源。

> **💡 决策第一原则**：遇到任何技术或业务决策疑问，先问自己：
> **"这是否是 0 号文档要交付验收的能力？技术上是否存在过度设计？"**
>
> 功能要不要做、方案是否过度设计，**一律向 0 号文件对齐**。

系统本质是一个"数据预处理工厂"：

```
原始数据（文件/数据库）
    → 接入（上传/连接）
    → 元数据提取（编码/格式/类型识别）
    → 治理配置（TEXT_PURIFY / DEDUP / ANOMALY / LOGIC / IMPUTE）
    → ETL 执行（事件驱动，algorithm-sdk 直调 Python 算法）
    → SyncRecord 审计日志（每文件 × 每步骤的 input/output 记录）
    → 治理报告（数字指标汇总）
    → 高质量数据集输出
```

**两大界面**：
- **admin-console 流程闭环**：给数据工程师实际操作用（创建数据集 → 接入 → 配置 → 执行 → 看报告）
- **演示中心（/demo）**：给甲方演示算法能力用。ETL 是黑箱，演示中心把每个算法单独拎出来，可调参数、即时看到效果

### 1.2 5 大业务闭环

闭环是"系统能转起来"的灵魂，详见 `specs/ARCHITECTURE-DESIGN-v2.md` §6：

| 闭环 | 一句话说明 | 关键产出 |
|------|-----------|---------|
| ① 数据集治理闭环 | 创建 → 接入 → 配置 → ETL → 报告 | SyncRecord + 治理报告 |
| ② ETL 执行闭环 | 模板参数 → 逐文件执行 → 写审计日志 | sync_record_detail |
| ③ 元数据提取闭环 | 接入 → 自动扫描 → 算法提取 → 入库 | t_ds_file.metadata (JSONB) |
| ④ 事件驱动架构 | Pipeline 发布事件 → Listener 消费 → Executor 执行 | EtlStepEvent + @Async |
| ⑤ 算法调用链路 | Registry 服务发现 → HTTP 直调 Python 算法 | AlgorithmHttpClient.invoke() |

---

## 2. 目录结构

```
./
├── README.md                          # 项目总览
├── docs/                              # 开发文档（本手册所在目录）
│   └── developer.md                   # 开发者手册
├── frontend/                          # 前端项目集
│   └── admin-console/                 # 管理控制台
├── backend/                           # 后端项目（模块化单体）
│   ├── app-bootstrap/                 # 启动入口（Spring Boot Main）
│   ├── module-core/                   # 核心层（异常/日志/工具/安全基座）
│   ├── module-sdk-algo/               # 算法 SDK（算法调用客户端）
│   ├── module-domain-system/          # 系统管理模块（用户/角色/菜单/认证）
│   ├── module-domain-data/            # 数据治理模块（数据集/数据源）
│   ├── module-domain-metadata/        # 元数据模块
│   ├── module-domain-ingest/          # 数据接入/ETL 模块
│   ├── module-domain-quality/         # 质量报告模块
│   ├── module-domain-algo/            # 算法管理模块（Registry/演示）
│   ├── module-domain-user/            # 用户域模块
│   └── db/migration/                  # Flyway 数据库迁移脚本
├── algo/                              # Python 算法服务（FastAPI）
│   ├── api/                           # API 路由层
│   ├── src/                           # 业务逻辑层
│   ├── model/                         # 算法模型
│   ├── tests/                         # pytest 测试
│   └── requirements*.txt              # 各算法服务依赖
├── deployment/                        # Docker 部署编排
│   ├── compose.base.yml               # 基础服务模板（.java / .python）
│   ├── compose.infra.yml              # 基础设施（Postgres/Redis/Caddy）
│   ├── compose.apps.yml               # 应用服务（backend/frontend/algo）
│   ├── compose.test.yml               # 测试编排（E2E / 集成测试）
│   ├── .env                           # 环境变量（密码等敏感信息）
│   └── README.testing.md              # E2E 测试指南
├── specs/                             # 架构设计文档
│   └── ARCHITECTURE-DESIGN-v2.md      # 技术架构设计 v2
├── decisions/                         # 架构决策记录（ADR）
│   └── METADATA-EXTRACTION-SPEC.md    # 元数据提取规范
├── tasks/                             # 任务卡片
│   └── 20260425-M3.2/                 # M3.2 迭代任务
├── tests/                             # 测试项目（Playwright E2E）
│   ├── e2e/                           # E2E 测试用例
│   └── Dockerfile                     # 测试镜像
└── testcases/                         # 测试用例设计
```

---

## 3. 前端开发

### 3.1 技术栈
- **框架**: Vue 3 + TypeScript
- **构建**: Vite 5
- **UI**: Element Plus + TailwindCSS
- **状态**: Pinia
- **路由**: Vue Router 4（Hash 模式）
- **HTTP**: Axios（Cookie+Session 模式，`withCredentials: true`）

### 3.2 目录结构（以 admin-console 为例）
```
frontend/admin-console/
├── src/
│   ├── api/                 # API 请求封装
│   ├── router/              # 路由配置
│   ├── store/               # Pinia 状态管理
│   ├── views/               # 页面组件
│   │   ├── dataset/         # 数据集管理（闭环①）
│   │   ├── datasource/      # 数据源管理（闭环①）
│   │   ├── etl/             # ETL 配置与执行（闭环②）
│   │   ├── governance/      # 治理报告（闭环①）
│   │   ├── metadata/        # 元数据管理（闭环③）
│   │   ├── demo-hall/       # 演示中心（算法能力展示）
│   │   └── system/          # 系统管理（用户/角色/菜单/部门）
│   ├── components/          # 公共组件
│   └── utils/               # 工具函数
├── mock/                    # vite-plugin-fake-server 模拟数据
├── build/                   # Vite 构建配置
└── package.json
```

### 3.2.1 左侧菜单规划（待实现）

> ⚠️ 当前登录后左侧菜单**未按业务闭环组织**，核心能力菜单不可见。需按以下结构重新梳理：

```
📁 数据治理（核心业务）
  ├── 数据集管理          → /admin#/[项目缩写]-data/dataset        闭环①
  ├── 数据源管理          → /admin#/[项目缩写]-data/datasource     闭环①
  ├── ETL 配置            → /admin#/[项目缩写]-ingest/etl-config   闭环②
  ├── 治理报告            → /admin#/[项目缩写]-quality/report      闭环①
  └── 元数据管理          → /admin#/[项目缩写]-metadata/scan       闭环③

🧪 算法演示
  ├── 演示大厅            → /admin#/demo-hall                演示中心

⚙️ 系统管理
  ├── 用户管理
  ├── 角色管理
  ├── 菜单管理
  └── 部门管理
```

### 3.3 打包编译

```bash
cd frontend/admin-console

# 开发模式
npm run dev

# 生产构建（输出到 dist/）
npm run build
```

### 3.4 认证方式
- **Cookie + Session**：后端通过 `JSESSIONID` Cookie 管理会话
- 前端将用户信息存储到 `localStorage`（仅用于 UI 渲染）
- **不是 JWT**：项目中已移除所有 `accessToken` / `refreshToken` 相关代码
- **🚨 已冻结**：前后端 Cookie+Session 改造已完成，**禁止再改动登录流程**，避免引入登录异常

---

## 4. 后端开发

### 4.1 技术栈
- **JDK**: 17
- **Spring Boot**: 3.4.12
- **ORM**: MyBatis-Plus 3.5.16
- **安全**: Spring Security 6 + Session（Cookie 模式）
- **会话**: Spring Session Redis
- **DB**: PostgreSQL 15 + Flyway 迁移
- **构建**: Maven

### 4.2 模块化单体架构

```
app-bootstrap/              ← 启动入口，聚合所有模块
    ├── module-core/        ← 核心层（异常/日志/i18n/工具）
    ├── module-sdk-algo/    ← 算法 SDK（服务发现 + HTTP 调用）
    └── module-domain-*/    ← 业务域模块（system/data/ingest/...）
```

### 4.3 打包编译

```bash
cd backend

# 打包（跳过测试）
./mvnw package -DskipTests -Dmaven.test.skip=true

# 单独编译某个模块
mvn compile -pl module-domain-system -am
```

打包产物：
- `app-bootstrap/target/app-bootstrap-1.0.0-MVP.jar` — 启动 Fat JAR
- `module-*/target/module-*-1.0.0-MVP.jar` — 各模块 JAR（启动时解压到 /apps/libs/）

### 4.4 数据库迁移

迁移文件位于 `backend/db/migration/`，命名规范：`V{N}__{description}.sql`

```bash
# Flyway 会在应用启动时自动执行
# 如需手动修复 checksum：
UPDATE flyway_schema_history SET checksum = NULL WHERE version = '4';
```

### 4.5 认证与安全

- **认证方式**: Cookie + Session（Spring Security HttpSession）
- **E2E 测试模式**: 通过 `X-E2E-SESSION` Cookie 注入虚拟身份
- **错误码规范**: `CORE_{类型}_{序号}`，如 `CORE_AUTH_002`
- **异常体系**: `BizException` + `ErrorCode` 枚举，`GlobalExceptionHandler` 统一处理

### 4.6 核心架构：SyncRecord 审计日志与事件驱动

> 详细设计见 `specs/ARCHITECTURE-DESIGN-v2.md`，本节提取开发者必须知道的关键信息。

#### 4.6.1 SyncRecord 替代六维度评分

架构 v2 **废弃了旧版六维度评分**（N/C/A/CS/U/V 评分、雷达图、趋势图、overallScore），改用**步骤级审计日志**：

```
GovernanceConfig (数据集级：enableTextPurify/Dedup/Anomaly/Logic/Impute)
    └── SyncRecord (文件级：inputJson / outputJson)
          └── SyncRecordDetail (步骤级：stepType + status + details)
```

**5 种治理步骤的 details 结构**（字段名 camelCase）：

| 步骤 | 关键指标 | 状态 |
|------|---------|------|
| TEXT_PURIFY | encodingDetected, encodingConverted, lineEndingNormalized, emojiRemoved, abnormalPoints, stripHtml | ✅ 已实现 |
| DEDUP | duplicateGroups, duplicateRecords, duplicateRate | ✅ 已实现 |
| ANOMALY | totalAnomalies, byType: {missing_field, format_anomaly, range_anomaly} | ✅ 已实现 |
| LOGIC | issuesFound, status: "PASSED_STUB", note | ⚠️ Stub（TD-002） |
| IMPUTE | recordsTotal, recordsWithMissing, recordsImputed, status: "PASSED_STUB", note | ⚠️ Stub（TD-003） |

#### 4.6.2 事件驱动 ETL 流程

```
EtlPipelineServiceImpl.executePipeline()
  ├── 创建 SyncRecord（inputJson）
  ├── 加载 GovernanceConfig
  └── 按配置顺序发布 EtlStepEvent（每个步骤一个事件）
              │
              │ @EventListener + @Async("etlTaskExecutor")
              ▼
  EtlStepEventListener ──→ EtlStepExecutor
                              ├── MinioFileService.downloadFile() 获取文件
                              ├── AlgorithmHttpClient.invoke() 直调 Python 算法
                              └── 完成后 UPDATE sync_record_detail + sync_record.completed_steps
```

**关键约束**：
- `@EnableAsync` 显式配置线程池（core=4, max=8, queue=100）
- Spring Event 存 JVM 内存，进程重启丢消息 → **TD-001 计划改 MQ**
- 每个 Executor 通过 `MinioFileService` 统一下载文件，禁止各模块自行处理文件下载

#### 4.6.3 Registry 服务发现（算法调用链路）

算法调用**禁止硬编码地址**（如 `localhost:9083`），**统一走 Registry 动态发现**：

```java
// AlgorithmHttpClient.invoke() 内部逻辑
List<AlgorithmInfo> algorithms = registryClient.listAlgorithms();
AlgorithmInfo target = algorithms.stream()
    .filter(a -> a.getName().equals("text_purify_v1"))
    .findFirst().orElseThrow(...);

String url = target.getEndpoint() + "/api/v1/text_purify_v1";
return restTemplate.postForObject(url, request, responseType);
```

Python 算法启动时通过 `RegistryClient` 自动注册到后端 Registry，详见 §5.4。

---

## 5. 算法服务开发

### 5.1 技术栈
- **Python**: 3.11
- **框架**: FastAPI
- **注册**: 通过 Python SDK 的 `RegistryClient` 向后端 Registry 注册

### 5.2 目录结构
```
algo/
├── api/                     # FastAPI 路由
├── src/                     # 业务逻辑
├── model/                   # 算法模型
├── tests/                   # pytest
├── requirements.txt         # 基础依赖
├── requirements-*.txt       # 各算法服务依赖
└── Dockerfile               # 镜像构建
```

### 5.3 启动方式

算法服务通过 Docker Compose 启动，自动注册到后端 Registry：

```yaml
# compose.apps.yml 片段
algo-purify:
  environment:
    - BACKEND_REGISTRY_URL=http://app-backend:8080/api/v1/registry
    - ALGORITHM_ID=purify_v1
```

### 5.4 Registry 服务发现机制

Python 算法启动时通过 SDK 自动注册，后端通过 Registry 动态发现后**直调**（Registry 不中转请求）：

```python
from algorithm_sdk import RegistryClient

client = RegistryClient(endpoint="http://backend:8080/api/v1/registry")
client.register(
    name="text_purify_v1",
    version="v1",
    endpoint="http://algo-text_purify_v1:9083",
    capabilities=["encoding_convert", "line_normalize", "html_strip", "emoji_remove"]
)
client.start()  # 启动心跳保活
```

**算法清单（Phase 1）—— 以代码实现为准**：

> ⚠️ 旧任务卡中的算法名称（如 `text_purify_v1`）与实际代码实现不一致。**所有命名以代码实现为准**，禁止按旧文档规范回改。

| 算法（代码实现名） | 目录/模块 | 能力 | 状态 |
|------|------|------|------|
| `purify` | `algo/purify/` | 编码检测/转换、换行符标准化、HTML去标记、Emoji移除 | ✅ |
| `deduplication` | `algo/deduplication/` | 文本/图像去重 | ✅ |
| `anomaly_detect` | `algo/anomaly_detect/` | 异常文件检测 | ✅ |
| `image_standardize` | `algo/image_standardize/` | 图像分辨率标准化、元数据提取 | ✅ |
| `logic_detect` | — | 内容逻辑检测 | ⚠️ Stub |
| `impute` | — | 缺失值处理 | ⚠️ Stub |

**新增算法的标准流程**：
1. 在 `algo/` 下新建子目录，实现 FastAPI 路由
2. 继承 Python SDK 的 `RegistryClient` 注册
3. 后端通过 `AlgorithmHttpClient.invoke(algorithmName, ...)` 调用，**无需改后端代码**

---

## 6. 容器部署

### 6.1 环境准备

```bash
cd deployment

# 确保 .env 已配置（敏感信息）
cp .env.example .env
# 编辑 .env 填入真实密码
```

### 6.2 启动全部服务

```bash
cd deployment

# 启动基础设施 + 应用服务
docker compose up -d

# 查看状态
docker compose ps

# 查看日志
docker compose logs app-backend --tail=50
docker compose logs admin-console --tail=20
```

### 6.3 关键服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| Caddy (proxy) | 80/443 | 统一入口，自动路由 |
| app-backend | 8080 | Spring Boot 后端 |
| admin-console | 80 (内部) | Nginx 托管前端静态资源 |
| Postgres | 5432 | 数据库 |
| Redis | 6379 | Session 存储 |

### 6.4 Caddy 路由规则

```
localhost:80
  ├── /api/*     → app-backend:8080
  ├── /admin*    → admin-console:80
  └── /demo*     → demo-hall:80
```

### 6.5 重建并重启服务

```bash
# 重建指定服务
docker compose up -d --build app-backend admin-console

# 或先 down 再 up（彻底重建）
docker compose down app-backend admin-console
docker compose up -d --build app-backend admin-console
```

---

## 7. E2E 测试

### 7.1 测试架构

- **E2E 容器**: `network_mode: host`，容器内 `localhost:80` = 宿主机 Caddy
- **浏览器**: Playwright Chromium
- **入口**: 通过 Caddy 访问前端和后端

### 7.2 运行 E2E 测试

```bash
cd deployment

# 运行所有 E2E 测试
docker compose run --rm test-e2e

# 运行指定测试文件
docker compose run --rm \
  -e TESTING_ENTRYPOINT="test-m27-login.spec.ts" \
  test-e2e

# 查看报告
ls -la test-results/
```

### 7.3 测试环境特殊配置

- `SPRING_PROFILES_ACTIVE=test` — 启用 E2E Session 固件
- `X-E2E-SESSION` Cookie — 前端路由守卫识别后构造虚拟用户
- `auth-enabled: false` — 部分环境关闭认证（联调模式）

### 7.4 测试用例清单

| 文件 | 用例数 | 说明 | 闭环覆盖 |
|------|--------|------|---------|
| `test-m27-login.spec.ts` | 3 | 登录/重定向/失败处理 | 系统管理 |
| `test-m27-system-admin.spec.ts` | 5 | 菜单/部门/角色/用户/菜单管理 | 系统管理 |
| `test-loop-dataset.spec.ts` | — | 数据集 CRUD + 文件管理 | 闭环① |
| `test-loop-datasource.spec.ts` | — | 数据源 9 端点 | 闭环① |
| `test-loop-etl.spec.ts` | — | ETL 配置 + 执行 + 状态检查 | 闭环② |
| `test-loop-governance.spec.ts` | — | 治理报告查看 | 闭环① |
| `test-loop-metadata-scan.spec.ts` | — | 元数据扫描 + Tab 展示 | 闭环③ |
| `test-loop-quality-report.spec.ts` | — | 质量报告 | 闭环① |
| `test-demo-hall.spec.ts` | — | 演示大厅 4 个 Tab | 演示中心 |
| `test-algo-registry.spec.ts` | — | 算法注册/心跳/列表 | 闭环⑤ |
| `test-system-api.spec.ts` | — | 系统管理 API | 系统管理 |

> 完整 E2E 覆盖矩阵见 `tests/e2e/E2E_COVERAGE_V2.md`

---

## 8. 架构文档与决策

### 8.1 核心文档位置

| 文档 | 路径 | 说明 |
|------|------|------|
| 架构设计 v2 | `specs/ARCHITECTURE-DESIGN-v2.md` | 数据治理审计日志、事件驱动、算法调用链路 |
| 元数据提取规范 | `decisions/METADATA-EXTRACTION-SPEC.md` | 10种文件类型 + 10种数据库类型的元数据提取 |
| 前端定位器规范 | `specs/FE-LOCATOR-SPEC.md` | E2E 测试的定位器规范 |
| E2E 测试指南 | `deployment/README.testing.md` | 测试执行、故障排除 |

### 8.2 关键架构决策

| 决策 | 内容 |
|------|------|
| **模块化单体 2.0** | 旧 8 个微服务合并为单一进程，通过 Maven 模块隔离 |
| **Cookie+Session 认证** | 废弃 JWT，使用 Spring Security HttpSession + Redis 存储 |
| **Registry 服务发现** | 算法地址不硬编码，通过 Registry 动态发现后直调 |
| **事件驱动 ETL** | `EtlStepEvent` + `@EventListener` + `@Async` 异步执行治理步骤 |
| **SyncRecord 审计日志** | 废弃六维度评分，采用步骤级审计记录 |
| **MinioFileService** | 文件服务统一接口，不分散在各模块 |

### 8.3 技术债务（Tech Debt）

| ID | 债务 | 优先级 |
|----|------|--------|
| TD-001 | Spring Event → MQ（进程重启消息丢失）| P1 |
| TD-002 | LOGIC 步骤 → LLM 语义分析 | P2 |
| TD-003 | IMPUTE 步骤 → 各类型专用算法 | P2 |
| TD-004 | 对比报告（时间线趋势/数据集对比）| P2 |

> 完整 Tech Debt 清单（含 M3.2 Sprint 遗留项）见 `decisions/tech-debt-log.md`

### 8.4 演示中心设计目的

**为什么有演示中心（/demo）？**

admin-console 的流程闭环是给数据工程师用的，但 ETL 执行是**黑箱**——甲方看不到"算法到底做了什么"。演示中心把每个算法单独拎出来，可调参数、即时看到效果，解决"信得过"的问题。

| 维度 | admin-console 流程闭环 | 演示中心 |
|------|----------------------|---------|
| **用户** | 数据工程师 | 甲方（决策层/验收方） |
| **入口** | `/admin` | `/demo` |
| **操作** | 创建数据集 → 接入 → 配置 → 执行 → 看报告 | 选择算法 → 调参数 → 上传文件 → 即时看效果 |
| **可见性** | ETL 是黑箱，只看结果报告 | 单算法透明执行，看中间过程 |
| **调用方式** | Pipeline 自动调度 | `/demo/invoke` 统一入口直调 |

> 演示大厅前端代码在 `frontend/admin-console/src/views/demo-hall/`，已合并到 admin-console 项目内（原独立 demo-hall 项目已移入 `archived/`）

### 8.5 Phase 1 边界与降级清单

**本期（[项目阶段]）做了的**：
- 文本预处理：编码检测/转换、换行符标准化、Emoji 移除、HTML 去标记
- 结构化数据：缺失检测、日期异常、完整性报告
- 元数据提取：通用元数据 + CSV/Parquet/JSON 等文件类型
- 数据集管理：CRUD、文件列表、治理配置、ETL 执行、审计日志、治理报告
- 系统管理：用户/角色/菜单/部门（前端管理控制台需要）

**降级到 Phase 2 的**：
- 图像/音频/视频标准化（格式转换、分辨率调整、降噪等）
- 数据库类型元数据提取（MySQL/PostgreSQL/MongoDB/Redis/Hive 等 10 种）
- 对比报告（TIME_SERIES / DATASET_COMPARE）

**Stub 实现（占位，记 TD）**：
- LOGIC 步骤：返回 `PASSED_STUB`，未来升级为 LLM 语义分析（TD-002）
- IMPUTE 步骤：返回 `PASSED_STUB`，未来升级为各类型专用算法（TD-003）

**移除的（过度设计）**：
- 六维度评分体系（N/C/A/CS/U/V）、雷达图、趋势图
- 数据血缘/来源追溯、生命周期管理、持续优化
- 原独立 demo-hall / monitor-center 前端项目

---

## 9. 任务与需求

### 9.1 任务卡片位置

```
tasks/
└── 20260425-M3.2/          # M3.2 迭代任务
    ├── ./          # 任务产出物
    └── reviews/            # 评审记录
```

### 9.2 需求来源

| 来源 | 路径 | 说明 |
|------|------|------|
| PRD | 外部文档 | 产品需求文档 |
| 架构设计 | `specs/ARCHITECTURE-DESIGN-v2.md` | 技术方案 |
| 决策记录 | `decisions/` | ADR / Q 决策 |
| E2E 测试 | `tests/e2e/*.spec.ts` | 验收标准 |

---

## 10. 常用命令速查

```bash
# === 前端 ===
cd frontend/admin-console
npm install
npm run dev          # 开发
npm run build        # 生产构建

# === 后端 ===
cd backend
mvn compile          # 编译
mvn package -DskipTests -Dmaven.test.skip=true   # 打包

# === 部署 ===
cd deployment
docker compose up -d                    # 启动全部
docker compose up -d --build app-backend admin-console   # 重建并启动
docker compose logs -f app-backend      # 跟踪日志
docker compose ps                       # 查看状态

# === E2E ===
cd deployment
docker compose run --rm -e TESTING_ENTRYPOINT="test-m27-login.spec.ts" test-e2e
```

---

## 11. 团队与规范

| 成员 | 角色 | 职责 |
|------|------|------|
| [技术负责人] | CEO | 项目决策、最终审批 |
| [架构师] | 架构师 | 架构设计、技术评审 |
| [后端负责人] | 全栈工程师 | 开发实施 |
| [产品经理] | 产品经理 | 需求文档、验收标准 |
| [测试负责人] | 测试工程师 | 测试计划、质量把关 |

**开发规范**: TDD + SDD（Spec-Driven Development），核心模块先写 spec 再实现代码。

**M3.2 现状说明**：任务卡标注"完成"仅表示代码片段写完并通过评审，**系统尚未联调通**。当前状态：
- 后端：编译通过 ✅
- 算法：Docker 镜像已构建 ✅
- 前端：能部署运行 ✅
- **联调**：数据集治理全流程（创建 → 接入 → 配置 → ETL → 报告）**尚未跑通** ❌

后续开发需以"**端到端跑通**"为完成标准，而非"代码片段写完"。

**数据安全**: 所有资料和代码仅允许本地存储（`{PROJECT_ROOT}/`），禁止上传至任何云存储或在线文档平台。

---

## 12. 新开发者快速上手路径

> 按角色选择阅读路径，通读预计 30 分钟，即可理解业务并上手开发。

### 12.1 通用必读（所有角色）

```
① 本文档 §1（业务定位 + 5大闭环）        ← 5分钟，知道系统在干什么
② docs/00-智能治理——数据预处理.md        ← 10分钟，理解0号文件需求来源
③ specs/FEATURE-INVENTORY-REQUIRED.md    ← 10分钟，知道哪些功能要做、哪些不做
④ specs/ARCHITECTURE-DESIGN-v2.md §6     ← 10分钟，理解5大闭环详细设计
```

### 12.2 前端开发者路径

```
① 本文档 §3（前端技术栈 + 认证方式）
② frontend/admin-console/README.md
③ specs/FE-LOCATOR-SPEC.md               ← 写 E2E 测试前必读
④ 本文档 §7（E2E 测试）
⑤ 启动：npm run dev → 访问 http://localhost:5173/admin
```

**关键认知**：
- 前端是**Hash 模式**路由（`/#/login`），不是 History 模式
- 认证是 **Cookie+Session**，不是 JWT。Axios 必须设置 `withCredentials: true`
- admin-console 是**唯一前端项目**，demo-hall 页面在 `src/views/demo-hall/` 内

### 12.3 后端开发者路径

```
① 本文档 §4（后端技术栈 + 模块化单体 + 核心架构）
② 本文档 §4.6（SyncRecord + 事件驱动 + Registry）
③ backend/module-*/README.md             ← 各模块职责
④ backend/module-*/API.md                ← 各模块接口定义
⑤ 本文档 §6（容器部署）
⑥ 启动：cd deployment && docker compose up -d
```

**关键认知**：
- 新增业务接口 → 写在对应的 `module-domain-*/api/` 下
- 新增算法调用 → 通过 `AlgorithmHttpClient.invoke(algorithmName, ...)`，禁止硬编码地址
- 新增数据库字段 → 必须同时改 **Entity + Flyway Migration**
- 所有业务异常 → 必须用 `BizException` + `ErrorCode`

### 12.4 算法开发者路径

```
① 本文档 §5（算法技术栈 + Registry 注册）
② algo/internal/*/README.md              ← 各算法子模块说明
③ decisions/METADATA-EXTRACTION-SPEC.md  ← 元数据提取规范
④ 新增算法：参照现有算法目录结构，实现 FastAPI + RegistryClient 注册
```

**关键认知**：
- Python 算法是**独立进程**，通过 Registry 向后端注册自己的地址和能力
- 后端通过 `AlgorithmHttpClient.invoke()` 直调，不是后端转发
- 算法返回 JSON 时，字段名用 **snake_case**，后端消费时映射为 camelCase

### 12.5 修改代码后验证清单

| 修改内容 | 必须执行 | 验证方式 |
|---------|---------|---------|
| 前端 `.vue/.ts` | `npm run build` | 刷新页面看效果 |
| 后端 `.java` | `mvn package -DskipTests` + `docker compose up -d --build app-backend` | 调 API 验证 |
| 数据库 Migration | 确认 Flyway 执行成功 | `docker compose logs app-backend` 看迁移日志 |
| 算法 `.py` | `docker compose up -d --build <algo-service>` | 演示中心或 E2E 验证 |
| 前端 locator | — | E2E 测试通过 |

---

## 13. 注意事项与易犯错误

### 13.1 修改源码后必须重新编译打包

**错误**: 改了 `.java` 文件后直接 `docker compose up -d --build`，发现容器里还是旧代码。

**原因**: `compose.apps.yml` 通过 `volumes` 挂载的是 `backend/*/target/*.jar`，不是源码目录。必须先 `mvn package` 生成新 JAR，再重建容器。

**正确流程**:
```bash
cd backend
mvn package -DskipTests -Dmaven.test.skip=true   # ① 编译打包
cd ../deployment
docker compose up -d --build app-backend          # ② 重建容器
```

### 13.2 Redis 密码必须与 `.env` 一致

**错误**: 后端启动报 `RedisCommandExecutionException: WRONGPASS invalid username-password pair`。

**原因**: `deployment/.env` 中 `REDIS_PASSWORD=change_me_in_production`，但 `application.yml` 中默认值写的是 `[项目缩写]123`。

**正确做法**: 确保 `backend/app-bootstrap/src/main/resources/application.yml` 中的 `spring.data.redis.password` 与 `.env` 中的 `REDIS_PASSWORD` 完全一致。推荐用环境变量占位符：
```yaml
password: ${REDIS_PASSWORD:change_me_in_production}
```

### 13.3 异常类型必须使用 BizException

**错误**: 后端抛出 `RuntimeException("用户名或密码错误")`，前端收到 500 `CORE_SYS_001` "系统内部错误"。

**原因**: `GlobalExceptionHandler` 只注册了 `BizException`、`MethodArgumentNotValidException`、`Throwable` 三个处理器。`RuntimeException` 落入 `Throwable` 兜底处理器，返回 500。

**正确做法**: 所有业务异常统一使用 `BizException` + `ErrorCode` 枚举：
```java
throw new BizException(ErrorCode.Auth.INVALID_CREDENTIALS);
```

### 13.4 前端认证是 Cookie+Session，不是 JWT

**错误**: 在代码中引入 `accessToken`、`refreshToken`、`formatToken` 等 JWT 概念。

**原因**: 项目明确采用 Spring Security HttpSession + JSESSIONID Cookie 认证模式。前端 `localStorage` 只存用户信息用于 UI 渲染，不存任何 token。

**正确做法**:
- 后端 `LoginResponse` 只返回 `userId/username/roles/permissions`，不返回 token
- 前端 `setToken()` 只存用户信息到 `localStorage`
- Axios 请求设置 `withCredentials: true`，由浏览器自动携带 Cookie

### 13.5 Entity 字段与数据库 Migration 必须同步

**错误**: 给 `SyncTaskEntity` 加了 `pipelineId` 字段，但启动时报数据库列不存在。

**原因**: MyBatis-Plus 的 Entity 字段名必须与数据库表列名一致。新增字段需要同时修改：
1. Java Entity 类
2. Flyway Migration 文件（`backend/db/migration/V{N}__*.sql`）
3. 如果是已有环境，用 `DO $$ BEGIN ... EXCEPTION WHEN duplicate_column THEN NULL; END $$;` 保证幂等

### 13.6 E2E 测试用例密码必须与数据库一致

**错误**: E2E 测试填 `admin123` 登录，但数据库实际密码是 `idata.123`，测试失败。

**原因**: E2E 容器通过 Caddy 访问真实后端，不走前端 mock。测试用例中的凭证必须与 `t_sys_user` 表中存储的密码一致。

**正确做法**: 修改测试用例中的密码，或通过 Flyway `afterMigrate` 脚本初始化测试数据。

### 13.7 Docker Compose 不要加 `-f` 参数

**错误**: `docker compose -f compose.apps.yml build app-backend` 报 "undefined network [项目缩写]-net"。

**原因**: 项目通过 `deployment/.env` 中的 `COMPOSE_FILE=compose.infra.yml,compose.apps.yml,compose.test.yml` 合并多个 compose 文件。单独 `-f` 一个文件会丢失网络定义和其他服务的依赖。

**正确做法**: 始终在 `deployment/` 目录下执行，不加 `-f`：
```bash
cd deployment
docker compose up -d
docker compose build app-backend
```

### 13.8 Docker 缓存导致 rebuild 不生效

**错误**: `docker compose up -d --build app-backend` 后，容器内代码仍是旧的。

**原因**: Docker 可能使用了构建缓存，没有检测到 target/ 目录下 JAR 文件的变化。

**正确做法**: 先 `docker compose down app-backend` 再 `docker compose up -d --build app-backend`，或者删除旧容器：
```bash
docker compose down app-backend
docker compose up -d --build app-backend
```

### 13.9 算法 SDK 重构时注意单元测试

**错误**: 重构 `AlgorithmHttpClient` 移除 `purify()` 等专用方法后，`AlgorithmHttpClientTest` 编译失败。

**原因**: 测试文件引用了已删除的方法。由于 `mvn compile` 不编译 test 代码，`mvn package` 才会暴露这个问题。

**正确做法**: 重构 SDK 接口时同步更新或删除对应的单元测试。如暂时无法修复，打包时跳过测试：
```bash
mvn package -DskipTests -Dmaven.test.skip=true
```

### 13.10 前端构建产物直接挂载到 Nginx

**错误**: 前端改了代码但容器里页面没变化。

**原因**: `compose.apps.yml` 中 `admin-console` 服务通过 volume 挂载 `frontend/admin-console/dist/` 到 Nginx 的 `html` 目录。如果 `dist/` 目录不是最新的构建产物，容器内看到的仍是旧代码。

**正确做法**: 每次修改前端代码后，先执行 `npm run build` 生成新的 `dist/`，再重启容器：
```bash
cd frontend/admin-console
npm run build
cd ../../deployment
docker compose up -d --build admin-console
```

### 13.11 算法地址硬编码绕过 Registry

**错误**: 在 `EtlStepExecutor` 或 `DemoController` 中直接写 `http://localhost:9083/api/v1/text_purify_v1`。

**原因**: 架构决策明确要求算法地址通过 Registry 动态发现。硬编码会导致：① 算法容器 IP 变化时调用失败；② 多实例时无法负载均衡；③ 新增算法必须改后端代码。

**正确做法**: 统一使用 `AlgorithmHttpClient.invoke(algorithmName, request, responseType)`，由 RegistryClient 自动发现地址：
```java
// ✅ 正确
TextPurifyResponse resp = algorithmHttpClient.invoke(
    "text_purify_v1", request, TextPurifyResponse.class);

// ❌ 错误
String url = "http://localhost:9083/api/v1/text_purify_v1";
restTemplate.postForObject(url, request, TextPurifyResponse.class);
```

### 13.12 治理步骤 details 字段名用 snake_case

**错误**: Python 算法返回 `"encoding_detected": "GBK"`，后端直接序列化到 `details` JSONB，导致前端展示时字段名不一致。

**原因**: `SyncRecordDetail.details` 是 JSONB 字段，按架构约定字段名必须是 **camelCase**（Java 惯例）。Python 返回 snake_case，后端消费时必须映射转换。

**正确做法**: Python 算法返回 snake_case 是合理的（Python 惯例），但后端在构建 `SyncRecordDetail` 时，手动映射为 camelCase：
```java
// ✅ 正确
details.put("encodingDetected", pythonResponse.getEncoding_detected());
details.put("lineEndingNormalized", pythonResponse.getLine_ending_normalized());

// ❌ 错误：直接把 Python 响应 JSON 塞进 details
details = JSON.parseObject(pythonResponseBody); // 字段名是 snake_case！
```

### 13.13 混淆"流程闭环"与"演示中心"的调用路径

**错误**: 在 admin-console 的数据集治理页面直接调用 `/demo/invoke` 端点执行 ETL。

**原因**: `/demo/invoke` 是演示中心的**独立入口**，用于单算法演示，不走 Pipeline、不写 SyncRecord、不生成治理报告。数据集治理必须通过 `EtlPipelineServiceImpl.executePipeline()` 走完整事件驱动流程。

**正确做法**: 
- **数据集治理（admin-console）**: 调用 `POST /api/v1/datasets/{id}/execute` → Pipeline → Event → Executor → SyncRecord → 报告
- **算法演示（演示中心）**: 调用 `POST /api/v1/demo/invoke` → 直调算法 → 返回即时结果（不写审计日志）

### 13.14 修改 GovernanceConfig 时未同步 ETL 模板参数

**错误**: 给 `GovernanceConfig` 新增字段（如 `customEncoding`），但 ETL 执行时该字段未填充到 `step.params`，导致算法收不到参数。

**原因**: `EtlPipelineServiceImpl` 在发布事件前，需要将 GovernanceConfig 中的配置项映射到每个 `EtlStepEvent` 的 `params` 中。新增字段必须同时修改映射逻辑。

**正确做法**: 修改 GovernanceConfig 时，检查两处：
1. `GovernanceConfigEntity` / DTO（新增字段定义）
2. `EtlPipelineServiceImpl.executePipeline()`（配置 → stepParams 的映射逻辑）
3. 如有前端配置页面，同步修改前端表单和 API 调用
