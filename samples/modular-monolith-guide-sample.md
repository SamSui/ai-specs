---
title: [项目名称] 模块化单体2.0 本地化落地指南（样本）
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: ⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。 依据：[项目阶段]-design 调研报告 + [项目名称]项目现状
---

# [项目名称] 模块化单体2.0 本地化落地指南（样本）

> **⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。**
>
> **文档版本**：v1.0  
> **维护者**：[架构师]  
> **创建日期**：2026-04-19  
> **依据**：[项目阶段]-design 调研报告 + [项目名称]项目现状  
> **状态**：✅ 正式发布

---

## 一、项目现状分析

### 1.1 当前 Maven 模块结构

[项目名称]项目当前为 **Maven 多模块项目**，共 13 个模块（含 1 个 BOM）：

| 序号 | 模块名 | 类型 | 端口 | 职责 |
|------|--------|------|------|------|
| 1 | `[项目缩写]-deps` | BOM | — | 统一版本锁定（Spring Boot 3.4.12 / MyBatis-Plus 3.5.16） |
| 2 | `[项目缩写]-common` | Lib | — | 通用工具类、全局异常、响应封装 |
| 3 | `[项目缩写]-dataset` | Lib | — | Dataset/Snapshot/File 实体 + Repository + MinIO |
| 4 | `data-source-management` | 服务 | 8083 | 文件接入、ETL、质检、去重、对比、标准化 |
| 5 | `metadata-service` | 服务 | 8082 | Dataset/File/Field/Workspace CRUD + 统计 |
| 6 | `algorithm-platform` | 服务 | 8081 | 算法注册、调度、生命周期管理 |
| 7 | `algorithm-sdk` | Lib | — | 算法发现/调用 SDK（供其他服务引用） |
| 8 | `api-gateway` | 服务 | 8080 | 请求路由、认证、限流 |
| 9 | `config-management` | 服务 | 8087 | 静态配置管理 |
| 10 | `task-management` | 服务 | 8085 | 任务创建、状态追踪、进度跟踪 |
| 11 | `report-management` | 服务 | 8084 | 质量报告、去重报告、异常报告 |
| 12 | `user-management` | 服务 | — | 用户注册、登录认证（Phase 2） |
| 13 | `data-adapter` | Lib | — | 数据源适配器（DB/文件/S3） |

### 1.2 当前 Maven 依赖关系

```
api-gateway
  └── algorithm-platform（HTTP）
  └── metadata-service（HTTP）
  └── data-source-management（HTTP）
  └── config-management（HTTP）

algorithm-platform
  └── algorithm-sdk（compile）
  └── metadata-service（HTTP，可选）

metadata-service
  └── [项目缩写]-common
  └── data-source-management（⚠️ Entity 直接依赖，非 API 调用）

data-source-management
  └── algorithm-sdk（compile）
  └── config-management（HTTP）
  └── metadata-service（HTTP）

[项目缩写]-dataset
  └── spring-boot-starter-data-jpa（⚠️ 与 MyBatis-Plus 混用）
  └── MyBatis-Plus
  └── MinIO
```

**当前主要问题（来自 MODULE-BOUNDARIES.md）**：

| 编号 | 问题 | 模块 |
|------|------|------|
| A-01 | 持有 Dataset/File/Workspace entity 与 DDL 不兼容 | metadata-service |
| A-02 | 持有 DataSourceEntity 与 DDL 不兼容 | data-ingestion |
| A-03 | ConfigEntity 重复定义，Owner 不明确 | data-source-management |
| A-04 | DatasetRepository 在 fat JAR classloader 外层暴露 | algorithm-sdk |
| A-05 | JPA starter 与 MyBatis-Plus 混用 | [项目缩写]-dataset |

### 1.3 当前数据库表归属（21张表）

| 表名 | Owner 模块 | 表前缀 |
|------|-----------|--------|
| workspaces | data-source-management | t_workspace_* |
| datasets | data-source-management | t_dataset_* |
| files | data-source-management | t_file_* |
| file_metadata | data-source-management | t_file_meta_* |
| data_sources | data-source-management | t_data_source_* |
| tasks | data-source-management | t_task_* |
| dedup_records | data-source-management | t_dedup_* |
| comparison_records | data-source-management | t_compare_* |
| quality_evaluations | data-source-management | t_quality_* |
| standardization_records | data-source-management | t_standard_* |
| anomaly_records | data-source-management | t_anomaly_* |
| configs | config-management | t_config_* |
| metadata_schemas | metadata-service | t_meta_schema_* |
| fields | metadata-service | t_field_* |
| algorithm_registry | algorithm-platform | t_algo_* |
| dataset_snapshots | [项目缩写]-dataset | t_snapshot_* |
| dataset_files | [项目缩写]-dataset | t_dataset_file_* |
| snapshot_files | [项目缩写]-dataset | t_snapshot_file_* |
| dataset_sync_sources | data-ingestion | t_sync_source_* |
| sync_checkpoints | data-ingestion | t_sync_checkpoint_* |
| sync_history | data-ingestion | t_sync_history_* |

**module-domain-notify 专用表（新建，无需迁移）**：
- `notify_templates` → `t_ntf_template_*`（通知模板配置）
- `notify_records` → `t_ntf_record_*`（通知发送记录）

---

## 二、目标架构定义

### 2.1 三层结构概览

```
[项目名称]（父项目，pom.xml 定义 dependencyManagement）
│
├── app-bootstrap/              【启动模块】
│   └── 负责扫描包、加载配置、注入依赖，不含任何业务逻辑
│
├── module-core/               【核心能力层】
│   └── 通用安全、日志、异常处理基座，所有模块共享
│
└── module-domain-*/           【业务模块 × N】
    ├── api/      → 对外暴露的接口定义（Interface）和 DTO
    ├── internal/ → 业务实现类（Service, Repository），禁止被外部模块直接访问
    └── model/    → 内部领域模型
```

> **行业案例**：Square 通过模块化单体在支付领域实现了高度内聚的领域边界，Stripe 则在早期就采用"模块化先行、微服务在后"的策略，避免了后期拆分的成本。

### 2.2 模块化重组对照表

| 现状模块 | → | 目标模块（module-domain-*） | 备注 |
|----------|---|---------------------------|------|
| data-source-management | → | `module-domain-workspace` | workspaces 表 |
| data-source-management | → | `module-domain-dataset` | datasets/files/file_metadata 表 |
| data-source-management | → | `module-domain-datasource` | data_sources 表 |
| data-source-management | → | `module-domain-task` | tasks 表 |
| data-source-management | → | `module-domain-quality` | dedup/comparison/standardization/anomaly/quality 表 |
| metadata-service | → | `module-domain-metadata` | metadata_schemas/fields 表 |
| algorithm-platform | → | `module-domain-algorithm` | algorithm_registry 表 |
| config-management | → | `module-domain-config` | configs 表 |
| [项目缩写]-dataset | → | `module-domain-notify` + 拆分 Snapshot 到 `module-domain-dataset` | 通知中心 + 数据集快照 |
| user-management | → | `module-domain-user` | 用户表 |
| data-ingestion | → | `module-domain-sync` | 同步相关表 |
| report-management | → | `module-domain-report` | 报告生成（可合并到 quality） |

### 2.3 推荐的试点模块

**🥇 首选：`module-domain-notify`（通知中心）**

理由：
- **低风险**：功能独立，不涉及核心业务表重构
- **边界清晰**：只管理通知模板、渠道配置、发送记录
- **依赖少**：不需要调用其他 domain 模块
- **可验证**：能完整演示 api/internal/model 三层分离 + ArchUnit 约束检查

---

## 三、工程结构规范

### 3.1 完整目录结构模板

```
[项目名称]/
├── pom.xml                          # 父 POM，定义 dependencyManagement
│
├── app-bootstrap/                   【启动模块】
│   ├── pom.xml
│   └── src/main/java/com/[项目缩写]/bootstrap/
│       ├── BootstrapApplication.java
│       └── config/
│           ├── ComponentScanConfig.java
│           └── ApplicationProperties.java
│
├── module-core/                     【核心能力层】
│   ├── pom.xml
│   └── src/main/java/com/[项目缩写]/core/
│       ├── security/                # 安全基座
│       │   ├── SecurityUtils.java
│       │   └── AuthenticationFilter.java
│       ├── logging/                 # 日志基座
│       │   └── RequestLogger.java
│       ├── exception/                # 异常基座
│       │   ├── BizException.java
│       │   ├── ErrorCode.java
│       │   └── GlobalExceptionHandler.java
│       └── i18n/                     # 国际化
│           └── MessageResolver.java
│
└── module-domain-{name}/            【业务模块示例：module-domain-notify】
    ├── pom.xml
    └── src/
        ├── main/java/com/[项目缩写]/domain/notify/
        │   ├── api/                  【接口层：对外暴露】⚠️ 外部只能引用此包
        │   │   ├── NotifyService.java          # Service 接口定义
        │   │   ├── NotifyChannelEnum.java      # 枚举常量
        │   │   ├── dto/
        │   │   │   ├── NotifySendRequest.java  # 请求 DTO
        │   │   │   └── NotifySendResponse.java # 响应 DTO
        │   │   └── NotifyQueryCriteria.java    # 查询条件 DTO
        │   │
        │   │   └── internal/          【实现层：禁止被外部模块引用】
        │   │       ├── NotifyServiceImpl.java  # Service 实现
        │   │       ├── NotifyController.java   # REST Controller
        │   │       ├── repository/
        │   │       │   ├── NotifyTemplateMapper.java
        │   │       │   └── NotifyRecordMapper.java
        │   │       └── event/                  # 内部事件
        │   │           ├── NotifyEvent.java
        │   │           └── NotifyEventListener.java
        │   │
        │   └── model/                 【领域模型层】
        │       ├── entity/
        │       │   ├── NotifyTemplate.java     # 通知模板实体
        │       │   └── NotifyRecord.java       # 通知记录实体
        │       ├── converter/
        │       │   └── NotifyConverter.java   # MapStruct 转换器
        │       └── vo/
        │           └── NotifyTemplateVO.java  # 值对象
        │
        └── test/java/com/[项目缩写]/domain/notify/
            ├── ArchUnitTests.java              # ArchUnit 约束测试
            ├── NotifyServiceTest.java         # 单元测试
            └── api/                            # API 契约测试
```

### 3.2 命名规范

| 元素 | 规范 | 示例 |
|------|------|------|
| 模块名 | `module-domain-{业务域}`，全小写 | `module-domain-notify` |
| 包名 | `com.[公司域名].[项目缩写].domain.{业务域}` | `com.[公司域名].[项目缩写].domain.notify` |
| API 接口 | `{Domain}Service.java` | `NotifyService.java` |
| 实现类 | `{Domain}ServiceImpl.java` | `NotifyServiceImpl.java` |
| 实体类 | `{DomainEntity}.java` | `NotifyTemplate.java` |
| DTO | `{动作}{对象}Request/Response.java` | `NotifySendRequest.java` |
| Mapper | `{Domain}{Entity}Mapper.java` | `NotifyTemplateMapper.java` |
| 事件类 | `{Domain}Event.java` | `NotifyEvent.java` |

### 3.3 依赖规范

```
app-bootstrap
  └── module-core
  └── 所有 module-domain-*

module-core
  └── （无业务模块依赖）

module-domain-*
  └── module-core
  └── 其他 module-domain-*/api  （⚠️ 仅限 api 包，禁止引用 internal/model）

module-domain-*/api
  └── module-core
  └── 其他 module-domain-*/api （可选）

module-domain-*/internal
  └── module-core
  └── 本模块的 api 和 model
  └── 其他 module-domain-*/api （⚠️ 通过接口调用，禁止直接引用 internal）
```

---

## 四、核心约束规则

### 4.1 依赖单向性规则

**规则**：模块 A 可以依赖模块 B 的 `api` 包，但**绝对禁止**直接依赖其 `internal` 或 `model` 实现。

#### ✅ 正确的跨模块调用

```java
// module-domain-dataset 中的 NotifyService 依赖 NotifyService
package com.[公司域名].[项目缩写].domain.dataset.internal;

import com.[公司域名].[项目缩写].domain.notify.api.NotifyService;  // ✅ 通过 API 接口调用

@Service
public class DatasetServiceImpl {
    @Autowired
    private NotifyService notifyService;  // ✅ 接口注入

    public void onDatasetCreated(Dataset dataset) {
        notifyService.sendNotify(...);  // ✅ 通过接口调用
    }
}
```

#### ❌ 禁止的跨模块调用

```java
// module-domain-dataset 中的 NotifyServiceImpl 依赖 NotifyServiceImpl
package com.[公司域名].[项目缩写].domain.dataset.internal;

import com.[公司域名].[项目缩写].domain.notify.internal.NotifyServiceImpl;  // ❌ 禁止直接引用 internal

@Service
public class DatasetServiceImpl {
    @Autowired
    private NotifyServiceImpl notifyService;  // ❌ 禁止直接注入实现类
}
```

### 4.2 ArchUnit 约束测试示例

**Maven 依赖**：

```xml
<dependency>
    <groupId>com.tngtech.archunit</groupId>
    <artifactId>archunit-junit5</artifactId>
    <version>1.3.0</version>
    <scope>test</scope>
</dependency>
```

**约束测试代码**（每个 module-domain-* 必须包含）：

```java
package com.[公司域名].[项目缩写].domain.notify;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.library.dependencies.SlicesRuleDefinition;

import static com.tngtech.archunit.library.ProxyFreezableArchice.FREEZABLE;

@AnalyzeClasses(
    packages = "com.[公司域名].[项目缩写].domain.notify",
    importOptions = ImportOption.DoNotIncludeTests.class
)
public class ArchUnitTests {

    // 【规则1】禁止从 internal 包对外暴露接口
    @ArchTest
    static final ArchRule no_public_classes_in_internal =
        ArchRuleDefinition.noClasses()
            . that().resideInAPackage("..internal..")
            .and().areAnnotatedWith(Controller.class)
            .should().bePublic();

    // 【规则2】禁止从 api 包引用 internal 包
    @ArchTest
    static final ArchRule api_should_not_import_internal =
        ArchRuleDefinition.noClasses()
            . that().resideInAPackage("..api..")
            .should().accessClassesThat().resideInAPackage("..internal..");

    // 【规则3】禁止从 api 包引用 model 包
    @ArchTest
    static final ArchRule api_should_not_import_model =
        ArchRuleDefinition.noClasses()
            . that().resideInAPackage("..api..")
            .should().accessClassesThat().resideInAPackage("..model..");

    // 【规则4】禁止循环依赖检测
    @ArchTest
    static final ArchRule no_cyclic_dependencies =
        SlicesRuleDefinition.slices()
            .matching("com.[公司域名].[项目缩写].domain.(..)")
            .should().beFreeOfCycles();

    // 【规则5】禁止跨模块引用 internal（强制执行依赖单向性）
    @ArchTest
    static final ArchRule no_cross_module_internal_access =
        ArchRuleDefinition.noClasses()
            .that().resideOutsideOfPackage("..internal..")
            .should().accessClassesThat().resideInAPackage("..module-domain-*.internal..");
}
```

**补充说明**：事件类（Event）作为跨模块通信的数据结构，允许放在 `model` 包中供外部模块 import。但 **Repository、Entity、Service 实现类**严格禁止跨模块访问。此例外仅适用于 `*Event.java` 类型的文件，判定逻辑为：

```java
ArchRuleDefinition.noClasses()
    .that().resideOutsideOfPackage("..internal..")
    .and().that().dontHaveNameMatching(".*Event")
    .should().accessClassesThat().resideInAPackage("..module-domain-*.internal..")
```

**在 `pom.xml` 中激活 Maven surefire 插件**：

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>3.2.5</version>
    <configuration>
        <includes>
            <include>**/*ArchUnitTests.java</include>
        </includes>
    </configuration>
</plugin>
```

> **ArchUnit 检测盲区**（基于调研报告 §5.2）：
> 1. **反射访问**：通过 `Class.forName()` 或 Spring 反射注入的依赖，ArchUnit 无法追踪
> 2. **动态代理**：JDK/CGLIB 生成的代理类，调用路径可能被截断
> 3. **字符串拼接**：运行时拼接的类路径字符串无法被静态分析捕获
> 4. **建议**：在 CI 中对 ArchUnit 测试结果做覆盖率统计，确保关键模块的覆盖率 > 80%

---

## 五、数据库 Schema 隔离方案

### 5.1 目标 Schema 隔离方案（重构后）

> **说明**：以下为 M2.4 重构后的目标表前缀。当前 DDL 中的实际表名（如 `t_workspace_*`）将在重构过程中逐步迁移到目标前缀（`t_ws_*`）。迁移期间 entity 类的 `@TableName` 注解需要同步更新。迁移顺序见 §6.3。

| Domain 模块 | 表前缀 | 表名 |
|------------|--------|------|
| **module-domain-workspace** | `t_ws_*` | workspaces |
| **module-domain-dataset** | `t_ds_*` | datasets, files, file_metadata, dataset_snapshots, dataset_files, snapshot_files |
| **module-domain-datasource** | `t_dsrc_*` | data_sources, dataset_sync_sources, sync_checkpoints, sync_history |
| **module-domain-task** | `t_task_*` | tasks |
| **module-domain-quality** | `t_q_*` | dedup_records, comparison_records, quality_evaluations, standardization_records, anomaly_records |
| **module-domain-metadata** | `t_meta_*` | metadata_schemas, fields |
| **module-domain-algorithm** | `t_algo_*` | algorithm_registry |
| **module-domain-config** | `t_cfg_*` | configs |
| **module-domain-notify** | `t_ntf_*` | notify_templates, notify_records |
| **module-domain-user** | `t_user_*` | users |
| **module-domain-sync** | `t_sync_*` | sync_checkpoints, sync_history, dataset_sync_sources |
| **module-domain-report** | `t_rpt_*` | dedup_report |

### 5.2 跨模块禁止 JOIN 验证

**在 ArchUnit 中可加入 SQL 静态分析规则**（建议在 CI 阶段扫描 `*Mapper.xml` 文件）：

```java
// 检查 Mapper XML 中是否存在跨模块 JOIN
@ArchTest
static final ArchRule no_cross_domain_join_in_xml =
    ArchRuleDefinition.noCode()
        .that().residesInArtifact("module-domain-dataset-*.jar")
        .and().hasNameMatching(".*Mapper\\.xml")
        .should().containPattern("JOIN t_q_")  // 禁止 quality 表被 dataset 模块 JOIN
        .orShould().containPattern("JOIN t_cfg_")  // 禁止 config 表被 dataset 模块 JOIN
```

### 5.3 物理隔离策略

**方案 A（推荐）：PostgreSQL Schema 隔离**

```sql
-- 每个 domain 模块使用独立 schema
CREATE SCHEMA t_ws;
CREATE SCHEMA t_ds;
CREATE SCHEMA t_dsrc;
CREATE SCHEMA t_task;
CREATE SCHEMA t_q;
CREATE SCHEMA t_meta;
CREATE SCHEMA t_algo;
CREATE SCHEMA t_cfg;
CREATE SCHEMA t_ntf;
```

**方案 B：单一 Schema + 表前缀隔离**

如果暂时不拆分 Schema，必须使用明确的前缀命名：

```sql
-- dataset 模块只能操作 t_ds_* 表
-- quality 模块只能操作 t_q_* 表
-- 禁止跨前缀的 JOIN 和子查询
```

---

## 六、技术选型

### 6.1 技术栈总览

| 技术 | 版本 | 用途 |
|------|------|------|
| **Spring Boot** | 3.4.x | 框架基座 |
| **Spring Boot Starter Web** | 3.4.x | REST API |
| **MyBatis-Plus** | 3.5.16 | 数据访问（每个模块独立 SqlSessionFactory） |
| **MapStruct** | 1.5.5 | DTO ↔ Entity 转换 |
| **ArchUnit** | 1.3.0 | 依赖规则强制检查 |
| **Lombok** | 1.18.42 | 减少样板代码 |
| **Micrometer + Prometheus** | latest | 监控埋点 |
| **PostgreSQL** | 15.x | 主数据库 |
| **MinIO** | latest | 文件存储 |
| **Spring Events** | 内置 | 进程内事件总线（替代 Guava EventBus） |

### 6.2 MyBatis-Plus 多模块配置

每个 `module-domain-*` 必须配置**独立的 `SqlSessionFactory`**：

```java
package com.[公司域名].[项目缩写].domain.dataset.internal.config;

@Configuration
@MapperScan("com.[公司域名].[项目缩写].domain.dataset.internal.repository")
public class MyBatisConfig {

    @Primary
    @Bean
    public SqlSessionFactory datasetSqlSessionFactory(
            DataSource datasetDataSource,
            MybatisPlusProperties properties) throws Exception {
        MybatisPlusSqlSessionFactoryBean factory =
            new MybatisPlusSqlSessionFactoryBean();
        factory.setDataSource(datasetDataSource);
        factory.setMapperLocations(
            new PathMatchingResourcePatternResolver()
                .getResources("classpath:mapper/**/*.xml"));
        factory.setTypeHandlersPackage("com.[公司域名].[项目缩写].domain.dataset.internal.repository.handler");
        factory.setGlobalConfig(properties.getGlobalConfig());
        return factory.getObject();
    }
}
```

### 6.3 BOM 版本锁定（父 pom.xml）

```xml
<properties>
    <spring.boot.version>3.4.12</spring.boot.version>
    <mybatis.plus.version>3.5.16</mybatis.plus.version>
    <lombok.version>1.18.42</lombok.version>
    <mapstruct.version>1.5.5</mapstruct.version>
    <archunit.version>1.3.0</archunit.version>
    <postgresql.version>42.7.8</postgresql.version>
    <micrometer.version>1.13.0</micrometer.version>
</properties>
```

---

## 七、配置隔离规范

### 7.1 每个模块独立配置文件

```
module-domain-*/src/main/resources/
├── application.yml              # 共享配置（Spring Boot 自动加载）
├── application-module.yml       # 模块私有配置（⚠️ 禁止共享）
└── mapper/                      # MyBatis XML 映射文件
```

### 7.2 application-module.yml 模板

```yaml
# module-domain-notify 配置示例
[项目缩写]:
  notify:
    # 邮件配置
    mail:
      host: ${NOTIFY_MAIL_HOST:smtp.example.com}
      port: ${NOTIFY_MAIL_PORT:587}
      username: ${NOTIFY_MAIL_USERNAME:}
      password: ${NOTIFY_MAIL_PASSWORD:}  # ⚠️ 生产环境使用密文
    # 短信配置
    sms:
      provider: ${NOTIFY_SMS_PROVIDER:aliyun}
      access-key: ${NOTIFY_SMS_AK:}
      access-secret: ${NOTIFY_SMS_AS:}
    # 飞书配置
    feishu:
      webhook-url: ${NOTIFY_FEISHU_WEBHOOK:}
      app-id: ${NOTIFY_FEISHU_APP_ID:}
      app-secret: ${NOTIFY_FEISHU_APP_SECRET:}
```

### 7.3 配置加载顺序

1. `application.yml`（共享配置，最高优先级）
2. `application-module.yml`（模块私有配置）
3. 环境变量 / 命令行参数（`--[项目缩写].notify.mail.host=...`）

---

## 八、进程内通信协议

### 8.1 同步调用：Interface 接口

```java
// module-domain-notify/api/NotifyService.java
public interface NotifyService {
    NotifySendResponse send(NotifySendRequest request);
    NotifyRecord getRecord(UUID recordId);
    Page<NotifyRecord> query(NotifyQueryCriteria criteria);
}
```

```java
// module-domain-dataset/internal/DatasetServiceImpl.java
@Service
public class DatasetServiceImpl {
    // ✅ 通过接口注入，不关心实现
    @Autowired
    private NotifyService notifyService;

    public void onDatasetReady(Dataset dataset) {
        // ✅ 模块 A 调用模块 B 的接口，双方解耦
        notifyService.send(NotifySendRequest.builder()
            .channel(NotifyChannelEnum.FEISHU)
            .templateCode("dataset-ready")
            .params(Map.of("datasetName", dataset.getName()))
            .build());
    }
}
```

### 8.2 异步解耦：Spring Events 事件总线

**事件定义**（事件是 `model` 层的一部分，属于模块私有）：

```java
// module-domain-dataset/model/event/DatasetCreatedEvent.java
// 注意：事件类位于 `model` 包，属于跨模块共享契约，外部模块通过 import 引用
public class DatasetCreatedEvent {
    private final UUID datasetId;
    private final String datasetName;
    private final UUID workspaceId;

    public DatasetCreatedEvent(UUID datasetId, String datasetName, UUID workspaceId) {
        this.datasetId = datasetId;
        this.datasetName = datasetName;
        this.workspaceId = workspaceId;
    }
    // getters...
}
```

**事件发布**（同步 → 异步解耦）：

```java
// module-domain-dataset/internal/DatasetServiceImpl.java
@Service
public class DatasetServiceImpl {
    @Autowired
    private ApplicationEventPublisher eventPublisher;

    public void createDataset(CreateDatasetRequest request) {
        // 同步执行业务逻辑
        Dataset dataset = datasetMapper.insert(request.toEntity());
        
        // ✅ 异步通知：发布事件，不阻塞主流程
        eventPublisher.publishEvent(new DatasetCreatedEvent(
            dataset.getId(),
            dataset.getName(),
            dataset.getWorkspaceId()
        ));
    }
}
```

**事件监听**（在 `module-domain-notify` 中）：

```java
// module-domain-notify/internal/event/NotifyEventListener.java
@Component
public class NotifyEventListener {
    @Autowired
    private NotifyService notifyService;

    // ✅ 监听其他模块的事件，实现跨模块异步解耦
    @EventListener
    @Async  // 可选：异步处理，不阻塞发布方
    public void onDatasetCreated(DatasetCreatedEvent event) {
        notifyService.send(NotifySendRequest.builder()
            .channel(NotifyChannelEnum.FEISHU)
            .templateCode("dataset-ready")
            .params(Map.of("datasetName", event.getDatasetName()))
            .build());
    }
}
```

### 8.3 通信协议选择决策树

```
是否需要实时返回结果？
  ├── 是 → 使用同步 Interface 调用
  └── 否 → 是否需要跨模块异步解耦？
            ├── 是 → 使用 Spring Events 事件总线
            └── 否 → 使用异步 Interface 调用（@Async）
```

---

## 九、演进路径：何时拆分为微服务

### 9.1 判断指标

| 指标 | 阈值 | 说明 |
|------|------|------|
| **构建时间占比** | 单模块构建 > 整体构建的 80% | 该模块应该独立部署 |
| **资源消耗** | CPU/内存消耗 > 其他模块 5 倍 | 高负载模块独立扩缩容 |
| **发布周期差异** | 需要独立发布频率 > 一周一次 | 不同节奏的模块应拆分 |
| **团队边界** | 不同团队负责不同模块 | 团队自治需要服务边界 |
| **技术异构** | 需要不同技术栈（如 Python） | 技术不兼容时必须拆分 |
| **故障隔离** | 一个模块故障影响全局 | 需要故障隔离的关键模块 |

> Shopify 在 28亿行 Ruby、1000+ 开发者的规模下，通过 Majestic Monolith 架构每天仍能完成 20+ 次部署，证明了规模不是拆分的唯一信号。真正的拆分信号是团队发布周期冲突或独立扩缩容需求（见 §9.2）。

### 9.2 拆分步骤

```
阶段一：模块化单体（当前目标）
  → 统一进程，模块通过 Interface + Events 通信

阶段二：模块化集群
  → 统一进程 + 水平扩展，部分模块独立部署

阶段三：微服务
  → 每个 module-domain-* 独立进程，独立数据库
```

---

## 十、避坑检查清单

| 编号 | 检查项 | 优先级 | 状态 |
|------|--------|--------|------|
| 🔴 P-01 | 禁止跨模块 JOIN（通过表前缀 + ArchUnit 约束） | 必须 | ✅ |
| 🔴 P-02 | 版本一致性（所有模块引用同一个 BOM 版本） | 必须 | ✅ |
| 🔴 P-03 | 配置文件隔离（每个模块独立的 application-module.yml） | 必须 | ✅ |
| 🟡 P-04 | 核心流程异步化（非核心路径使用 Spring Events） | 建议 | ✅ |
| 🟡 P-05 | ArchUnit 约束测试必须通过才能合入 | 必须 | ✅ |
| 🟡 P-06 | Entity Owner 唯一（每张表只有一个模块持有 Repository） | 必须 | ✅ |
| 🟡 P-07 | 禁止在 `internal` 包中定义 `@Controller` | 必须 | ✅ |
| 🟡 P-08 | API 接口放在 `api` 包，实现类放在 `internal` 包 | 必须 | ✅ |
| 🟡 P-09 | Domain 模块禁止直接引用其他模块的 Entity/Repository | 必须 | ✅ |

---

## 附录 A：落地实施路线图

### 阶段 1：试点（2~3 周）

**目标**：选择 `module-domain-notify` 作为试点，验证完整流程

1. 创建 `module-domain-notify` 模块结构（api/internal/model）
2. 从 `[项目缩写]-dataset` 中迁移通知相关代码
3. 编写 ArchUnit 约束测试
4. 验证配置隔离
5. 输出试点报告

### 阶段 2：核心迁移（4~6 周）

**目标**：按优先级逐步迁移核心业务模块

| 优先级 | 模块 | 依赖关系 |
|--------|------|---------|
| P0 | `module-domain-config` | 被其他模块依赖，最先迁移 |
| P0 | `module-domain-dataset` | 核心数据集模块 |
| P1 | `module-domain-quality` | 质量相关表 |
| P1 | `module-domain-metadata` | 元数据相关表 |
| P2 | `module-domain-algorithm` | 算法注册 |

### 阶段 3：收尾（2~3 周）

**目标**：完成剩余模块，清理技术债务

1. 迁移 `module-domain-workspace`、`module-domain-task`
2. 清理 `[项目缩写]-dataset` 中的重复 Entity（ACTION A-01 ~ A-05）
3. 统一 MyBatis-Plus 配置
4. 运行全量 ArchUnit 测试

---

## 附录 B：ArchUnit 完整规则清单

```java
// 完整 ArchUnit 规则（建议做成共享测试基类）
public class DomainArchitectureRules {

    // 1. 依赖单向性：api → api（可选），internal → api+internal+model（本模块）
    @ArchTest
    static ArchRule no_internal_access_from_outside = ArchRuleDefinition.noClasses()
        .that().resideOutsideOfPackage("..module-domain-$(domain)..")
        .should().accessClassesThat().resideInPackage("..module-domain-$(domain)..internal..");

    // 2. 分层：Controller 只能在 internal 包
    @ArchTest
    static ArchRule controllers_must_be_in_internal = ArchRuleDefinition.classes()
        .that().haveNameMatching(".*Controller")
        .should().resideInAPackage("..internal..");

    // 3. Service 实现类命名：*ServiceImpl
    @ArchTest
    static ArchRule service_impl_naming = ArchRuleDefinition.classes()
        .that().resideInAPackage("..internal..service..")
        .and().haveNameNotContaining("Service")  // 接口名不含 Impl
        .should().haveNameMatching(".*ServiceImpl");

    // 4. 禁止直接注入其他模块的 Repository
    @ArchTest
    static ArchRule no_cross_module_repository = ArchRuleDefinition.noClasses()
        .that().resideInAPackage("..module-domain-$(domain)..")
        .should().accessClassesThat().haveNameMatching(".*Repository")
        .andShould().accessClassesThat().resideInAPackage("..module-domain-(*).internal..");
}
```

---

## 附录 C：参考文档

| 文档 | 路径 |
|------|------|
| M2.4 调研报告 | `../../reports/M2.4-design-research/final.md` |
| 模块边界定义 | `../../specs/MODULE-BOUNDARIES.md` |
| 数据库表结构 | `../../specs/database-schema.md` |
| 需求规格 | `../../specs/requirements-spec.md` |
| 架构设计 | `../../specs/architecture-design.md` |
| ERD | `../../specs/ERD.md` |
| 后端项目 README | `../../artifacts/backend/README.md` |

---

*本文档由 Architect（[架构师]）编写，面向 [项目名称]项目 M2.4 重构团队*

### 第2轮补充修订（2026-04-19）：融入T-RESEARCH-001调研报告发现（Shopify案例/ArchUnit局限性/行业案例）
