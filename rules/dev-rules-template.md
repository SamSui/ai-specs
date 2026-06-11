---
title: [架构模式] — 开发工程师规则集（模板）
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 角色: 开发工程师（Developer） 来源: 基于 [项目]落地指南（[任务ID]产出物）
---

# [架构模式] — 开发工程师规则集（模板）

> **版本**: v1.0  
> **适用阶段**: [项目阶段] 代码重构/开发  
> **角色**: 开发工程师（Developer）  
> **来源**: 基于 `[项目]落地指南`（[任务ID]产出物）  
>
> **⚠️ 本文件为模板，使用前需替换方括号内的占位符为项目实际内容**

---

## 一、模块依赖规则

### 1.1 正面清单（Can Do）

**R01-DEV**: 模块可以依赖其他模块的 `api` 包中的接口定义。

```java
// ✅ 正确：调用 module-domain-metadata 的 API 接口
package com.[公司域名].[项目缩写].data.standardization;

import com.[公司域名].[项目缩写].metadata.api.DatasetService;  // ✅ 通过 api 包依赖
import org.springframework.beans.factory.annotation.Autowired;

public class StandardizationService {
    @Autowired
    private DatasetService datasetService;  // ✅ 通过接口调用，非直接依赖实现
}
```

**R02-DEV**: 同一模块内的 `internal` 包可以自由相互依赖。

```java
// ✅ 正确：module-domain-datasource 内部调用
package com.[公司域名].[项目缩写].data.datasource.internal.etl;

import com.[公司域名].[项目缩写].data.datasource.internal.repository.FileRepository;  // ✅ 内部包间调用
```

**R03-DEV**: 模块可以依赖 `app-bootstrap` 中的配置加载器和启动器。

```java
// ✅ 正确：业务模块依赖 bootstrap 提供的通用工具
package com.[公司域名].[项目缩写].data.datasource.internal.service;

import com.[公司域名].[项目缩写].bootstrap.config.ModuleConfigLoader;
```

### 1.2 负面清单（Must Not Do）

**R04-DEV**: ❌ **禁止** 直接依赖其他模块的 `internal` 包中的任何类（含 `@Service`、`@Repository`、`@Component`）。

```java
// ❌ 错误示范
package com.[公司域名].[项目缩写].data.standardization;

import com.[公司域名].[项目缩写].metadata.internal.service.DatasetServiceImpl;  // ❌ 禁止依赖 internal 实现
import com.[公司域名].[项目缩写].metadata.internal.repository.DatasetRepository;  // ❌ 禁止依赖 internal repository
```

```java
// ❌ 错误示范：直接注入实现类
@Autowired
private DatasetServiceImpl datasetServiceImpl;  // ❌ 必须依赖接口而非实现
```

**R05-DEV**: ❌ **禁止** 直接引用其他模块的 Entity 类作为业务逻辑参数或返回值（跨模块传递）。

```java
// ❌ 错误示范：跨模块直接传递 Entity
public void processDataset(Dataset entity) {  // ❌ Dataset 是 metadata 模块的 entity
    // 业务逻辑...
}
```

**R06-DEV**: ❌ **禁止** 在 SDK lib（如 `algorithm-sdk`）中引用非 lib 模块的 entity/repository。

```java
// ❌ 错误示范：algorithm-sdk 中
package com.[公司域名].[项目缩写].algorithm.sdk;

import com.[公司域名].[项目缩写].repository.entity.Dataset;  // ❌ 禁止
import com.[公司域名].[项目缩写].repository.DatasetRepository;  // ❌ 禁止
```

**R07-DEV**: ❌ **禁止** 在 `module-domain-*` 模块中通过 Maven 依赖传递（POM ` <optional>true</optional>` 或 `<exclusions>`）引入禁止的类。

```xml
<!-- ❌ 错误示范 -->
<dependency>
    <groupId>com.[公司域名].[项目缩写]</groupId>
    <artifactId>module-domain-metadata</artifactId>
    <version>${project.version}</version>
    <exclusions>
        <exclusion>
            <groupId>com.[公司域名].[项目缩写]</groupId>
            <artifactId>module-domain-metadata</artifactId>
            <!-- ❌ 试图排除但 internal 仍然泄漏 -->
        </exclusion>
    </exclusions>
</dependency>
```

> **来源**: 落地指南 第4章「核心约束规则」§依赖单向性；MODULE-BOUNDARIES.md §四/§五

---

## 二、包访问规则

### 2.1 正面清单（Can Do）

**R08-DEV**: ✅ 每个模块的 `api` 包对其他模块可见，可供依赖。

```
module-domain-datasource/
├── api/                    ✅ 其他模块可见
│   ├── DatasetService.java
│   └── DataSourceApi.java
├── internal/               ❌ 其他模块不可见
│   ├── service/
│   ├── repository/
│   └── domain/
└── model/                  ✅ model 包通常可见（Entity/DTO）
    └── entity/
```

**R09-DEV**: ✅ 模块内部可通过 `internal` 包组织私有实现，编译成独立的内部 JAR。

**R10-DEV**: ✅ `model` 包中的 DTO/VO 可跨模块共享（作为接口参数类型）。

```java
// ✅ 正确：使用 DTO 而非 Entity
package com.[公司域名].[项目缩写].data.standardization.api;

import com.[公司域名].[项目缩写].data.datasource.model.dto.DatasetDTO;  // ✅ DTO 可跨模块使用

public interface StandardizationService {
    StandardizationResult process(DatasetDTO dataset);  // ✅ 用 DTO 而非 Entity
}
```

### 2.2 负面清单（Must Not Do）

**R11-DEV**: ❌ **禁止** 在 `api` 包中放置 `@Service`、`@Repository`、`@Component` 等 Spring Bean 实现类，只能放接口和 DTO。

```java
// ❌ 错误示范：api 包中放置了实现类
package com.[公司域名].[项目缩写].metadata.api;

// ❌ 错误：实现类不应该在 api 包中
@Service
public class DatasetServiceImpl implements DatasetService {
    // ...
}
```

**R12-DEV**: ❌ **禁止** 从其他模块的 `internal` 包导入任何类，即使在同一 JAR 内也不允许跨模块 internal 访问。

```java
// ❌ 错误示范
package com.[公司域名].[项目缩写].data.standardization.internal;

import com.[公司域名].[项目缩写].metadata.internal.repository.DatasetRepository;  // ❌ 绝对禁止
```

> **来源**: 落地指南 第4章「核心约束规则」§依赖单向性；MODULE-BOUNDARIES.md §一

---

## 三、数据库操作规则

### 3.1 正面清单（Can Do）

**R13-DEV**: ✅ 每张表有且只有一个 Owner 模块，该模块负责定义 `@TableName`、BaseMapper 和 DDL 文件。

```java
// ✅ 正确：data-source-management 是 datasets 表的 Owner
package com.[公司域名].[项目缩写].data.datasource.model.entity;

@TableName("datasets")  // ✅ 仅 Owner 模块可标注
public class DatasetEntity {
    // ...
}
```

```java
// ✅ 正确：Owner 模块定义 Mapper
package com.[公司域名].[项目缩写].data.datasource.repository;

@Mapper
public interface DatasetRepository extends BaseMapper<DatasetEntity> {
    // MyBatis-Plus 单表 CRUD 零代码
}
```

**R14-DEV**: ✅ Consumer 模块通过 HTTP API 调用 Owner 模块暴露的数据操作接口。

```java
// ✅ 正确：data-source-management 调用 metadata-service 的 HTTP API
@RestController
public class MetadataClient {
    @Autowired
    private RestTemplate restTemplate;

    public DatasetDTO getDataset(String datasetId) {
        // ✅ 调用 metadata-service 的 REST API
        return restTemplate.getForObject(
            "http://metadata-service:8082/api/v1/datasets/{id}",
            DatasetDTO.class,
            datasetId
        );
    }
}
```

**R15-DEV**: ✅ 每个模块操作本模块表前缀的表，跨模块操作必须通过接口调用。

```sql
-- ✅ 正确：data-source-management 模块操作 t_data_* 表
SELECT * FROM t_data_files WHERE dataset_id = ?;
SELECT * FROM t_data_sources WHERE source_type = ?;
```

### 3.2 负面清单（Must Not Do）

**R16-DEV**: ❌ **禁止** 在 SQL 中进行跨模块 JOIN（即使表前缀不同也不允许）。

```sql
-- ❌ 错误示范：跨模块 JOIN
SELECT d.*, m.*
FROM t_data_datasets d
INNER JOIN t_meta_metadata_schemas m ON d.schema_id = m.id;  -- ❌ 禁止跨模块 JOIN
```

```sql
-- ❌ 错误示范：子查询跨模块
SELECT * FROM t_data_files
WHERE dataset_id IN (
    SELECT id FROM t_meta_datasets  -- ❌ 禁止跨模块子查询
);
```

**R17-DEV**: ❌ **禁止** Consumer 模块直接持有 Owner 模块的 Entity 重复定义（即使类名不同）。

```java
// ❌ 错误示范：data-source-management 中重复定义 Dataset
package com.[公司域名].[项目缩写].data.datasource.model.entity;

@Entity
@TableName("datasets")
public class LocalDatasetEntity {  // ❌ 虽然类名不同，但表相同，属于重复定义
    // ...
}
```

**R18-DEV**: ❌ **禁止** 跨模块直接注入 Repository。

```java
// ❌ 错误示范
@Autowired
private DatasetRepository datasetRepository;  // ❌ 如果 DatasetRepository 属于其他模块，禁止直接注入
```

> **来源**: 落地指南 第4章「核心约束规则」§数据库逻辑隔离；MODULE-BOUNDARIES.md §二/§三

---

## 四、事件总线使用规范

### 4.1 正面清单（Can Do）

**R19-DEV**: ✅ 以下场景**必须**使用 Spring Events 或 Guava EventBus 进行异步解耦：
- 写操作完成后的通知（如文件处理完成通知元数据更新）
- 非核心路径的异步处理（如日志记录、监控指标上报）
- 多消费者场景（一个事件触发多个下游处理）

```java
// ✅ 正确：使用 Spring Events 进行异步通知
// 事件定义
public class FileProcessedEvent extends ApplicationEvent {
    private final String fileId;
    private final String status;
    public FileProcessedEvent(Object source, String fileId, String status) {
        super(source);
        this.fileId = fileId;
        this.status = status;
    }
}

// 事件发布
@Service
public class FileProcessingService {
    @Autowired
    private ApplicationEventPublisher publisher;

    public void processFile(String fileId) {
        // ... 处理逻辑
        publisher.publishEvent(new FileProcessedEvent(this, fileId, "success"));
    }
}

// 事件监听（异步）
@EventListener
@Async
public void onFileProcessed(FileProcessedEvent event) {
    // ... 元数据更新逻辑（异步执行）
}
```

**R20-DEV**: ✅ 事件命名规范：`{模块名}+{操作名}+Event`

```java
// ✅ 正确的事件命名
DatasetCreatedEvent      // 数据集创建事件
FileStandardizedEvent    // 文件标准化完成事件
DeduplicationCompletedEvent  // 去重完成事件
```

### 4.2 负面清单（Must Not Do）

**R21-DEV**: ❌ **禁止** 在事件监听器中进行同步数据库事务操作（应确保事务边界在事件发布前完成）。

```java
// ❌ 错误示范：事件监听器中开启新事务（事务传播问题）
@EventListener
public void onDatasetCreated(DatasetCreatedEvent event) {
    // ❌ 在事件监听器中执行数据库操作可能导致事务不一致
    datasetRepository.save(...);
}
```

**R22-DEV**: ❌ **禁止** 使用事件总线替代接口调用进行同步数据查询（事件是异步的，不适合需要返回值场景）。

```java
// ❌ 错误示范：用事件做同步查询
@EventListener
public void onQueryRequest(DatasetQueryEvent event) {
    event.setResult(datasetRepository.findById(event.getDatasetId()));  // ❌ 事件没有返回值
}
```

> **来源**: 落地指南 第4章「核心约束规则」§进程内通信协议；architecture-design.md §4.6

---

## 五、提交规范

### 5.1 提交信息格式（必须遵循 Conventional Commits）

**R23-DEV**: ✅ 所有提交信息必须遵循以下格式：

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

其中 `<type>` 必须为以下之一：
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档变更
- `style`: 代码格式（不影响功能）
- `refactor`: 重构（既不是新功能也不是修复）
- `test`: 测试相关
- `chore`: 构建/工具变更

```bash
# ✅ 正确示例
git commit -m "feat(datasource): add multi-format file adapter support"
git commit -m "fix(metadata): resolve dataset query pagination offset issue"
git commit -m "refactor(core): extract common event bus utilities to bootstrap"
git commit -m "docs(api): update dataset API documentation with new fields"
```

**R24-DEV**: ✅ Commit message 必须包含 **Task ID**（如有对应任务卡片）。

```bash
git commit -m "feat(datasource): add ETL pipeline for CSV ingestion [T-DATA-012]"
```

### 5.2 Code Review 要求

**R25-DEV**: ✅ 所有合入主分支的代码变更必须经过 Code Review，Reviewer 必须检查：

1. 依赖关系是否符合「模块依赖规则」（R01-R07）
2. 是否存在跨模块 `internal` 访问
3. 数据库操作是否遵循「数据库操作规则」（R13-R18）
4. ArchUnit 边界测试是否通过（由 CI 自动检查）
5. 变更是否引入新的跨模块 JOIN

**R26-DEV**: ❌ **禁止** 绕过 Code Review 直接合入（即使是小改动）。

**R27-DEV**: ❌ **禁止** 在 Commit message 中使用无意义的描述如 "update"、"fix bug"、"modify"。

```bash
# ❌ 错误示范
git commit -m "update"
git commit -m "fix bug"
git commit -m "modify code"
```

> **来源**: 落地指南 第4章「工程规范」；architecture-design.md §0.4；review-rule.md

---

## 六、配置与版本规范

### 6.1 正面清单（Can Do）

**R28-DEV**: ✅ 每个模块必须拥有独立的配置文件 `application-{module}.yml`。

```yaml
# ✅ 正确：module-domain-datasource 的独立配置
# 文件路径：module-domain-datasource/src/main/resources/application-datasource.yml
datasource:
  module:
    etl:
      batch-size: 1000
      max-retries: 3
    dedup:
      hamming-threshold: 5
```

**R29-DEV**: ✅ 所有模块必须使用相同版本的 Spring Boot / MyBatis-Plus / JDK。

```xml
<!-- ✅ 正确：统一版本管理于父 POM -->
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.x</version>  <!-- 所有子模块必须使用 3.2.x -->
</parent>

<properties>
    <java.version>17</java.version>
    <mybatis-plus.version>3.5.5</mybatis-plus.version>
</properties>
```

### 6.2 负面清单（Must Not Do）

**R30-DEV**: ❌ **禁止** 在 `application.yml` 中硬编码其他模块的配置。

```yaml
# ❌ 错误示范
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/metadata-db  # ❌ 模块配置不应混在一起
```

**R31-DEV**: ❌ **禁止** 在代码中使用魔法值（Magic Number/String），应统一抽取到配置或常量类。

```java
// ❌ 错误示范
if (status == 1) {  // ❌ 魔法值
    // ...
}

// ✅ 正确
public static final int STATUS_COMPLETED = 1;
if (status == STATUS_COMPLETED) {
    // ...
}
```

> **来源**: 落地指南 第5章「数据库Schema设计」；architecture-design.md §0.3

---

## 七、Python算法服务开发规范（适用范围：仅Python算法服务）

**R01-DEV（Python）**：✅ `algorithm_id` 必须使用 snake_case 格式，且全局唯一。

**R02-DEV（Python）**：✅ Python 算法服务的错误处理必须使用独立 `exceptions.py` 模块，集中定义业务异常。

**R03-DEV（Python）**：✅ Python 算法服务必须通过环境变量配置注册地址，禁止硬编码 `BACKEND_REGISTRY_URL`。

**R04-DEV（Python）**：✅ 注册接口字段名必须与 Java 对齐，使用 `protocol`（而非 `algorithm_protocol`）。

---

## 验收标准对照

| AC | 要求 | 规则覆盖 |
|----|------|---------|
| AC-01 | ≥10条，涵盖依赖/包访问/数据库/事件/提交 | R01-R31 共31条规则 |
| AC-04 | 每条规则有明确来源引用 | 每条规则注明来源章节 |
| AC-05 | 措辞具体，无模糊表述 | 所有规则使用 MUST NOT / 必须 / 禁止 |

---

## 附录：常见违规场景自查清单

```
开发工程师在提交代码前，必须确认：
□ 是否引入了新的 cross-module internal 依赖？
□ 是否有跨模块直接注入 Repository？
□ SQL 中是否有跨模块 JOIN？
□ 是否使用了 Spring Events 做异步解耦（适合的场景）？
□ Commit message 是否符合 Conventional Commits 规范？
□ 是否附上了 Task ID？
□ 是否有未抽取的魔法值？
□ 变更是否经过 Code Review？
```
