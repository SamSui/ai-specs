---
title: [架构模式] — 资深架构师规则集（模板）
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 角色: 资深架构师（Architect） 来源: 基于 [项目]落地指南（[任务ID]产出物）
---

# [架构模式] — 资深架构师规则集（模板）

> **版本**: v1.0  
> **适用阶段**: [项目阶段] 代码重构/设计  
> **角色**: 资深架构师（Architect）  
> **来源**: 基于 `[项目]落地指南`（[任务ID]产出物）  
>
> **⚠️ 本文件为模板，使用前需替换方括号内的占位符为项目实际内容**

---

## 一、模块划分原则

### 1.1 正面清单（Can Do）

**R01-ARCH**: ✅ 三层结构规范：每个 `module-domain-*` 必须包含 `api`、`internal`、`model` 三个一级包。

```
module-domain-{name}/
├── api/                      # 对外暴露的接口定义（其他模块可见）
│   ├── {Domain}Service.java  # 服务接口（Interface）
│   └── {Domain}Api.java      # REST API 定义（可选）
├── internal/                 # 私有实现（仅本模块内可见）
│   ├── service/              # 业务逻辑实现
│   ├── repository/           # 数据访问层（MyBatis-Plus Mapper）
│   ├── event/                # 领域事件定义
│   └── {Domain}ServiceImpl.java
└── model/                    # 数据模型
    ├── entity/               # 数据库实体（Owner 模块放置 @TableName）
    ├── dto/                  # 数据传输对象（跨模块通信用）
    └── vo/                   # 视图对象（API 返回用）
```

**R02-ARCH**: ✅ 模块命名规范：`module-domain-{业务域缩写}`，如：
- `module-domain-datasource` — 数据源管理
- `module-domain-metadata` — 元数据管理
- `module-domain-notify` — 通知中心（试点模块）
- `module-domain-algorithm` — 算法管理

**R03-ARCH**: ✅ Schema/表前缀与模块职责对应，确保"谁拥有数据，谁负责表"。

```
Owner 模块                    表前缀
─────────────────────────────────────────────
module-domain-datasource     → t_data_*
module-domain-metadata       → t_meta_*
module-domain-notify         → t_notify_*
module-domain-algorithm      → t_algo_*
```

### 1.2 负面清单（Must Not Do）

**R04-ARCH**: ❌ **禁止** 在 `api` 包中放置实现类，只能放接口和 DTO。

```java
// ❌ 错误示范
package com.[公司域名].[项目缩写].metadata.api;

// ❌ api 包中出现了 @Service 注解的实现类
@Service
public class DatasetServiceImpl implements DatasetService {
    // ...
}
```

**R05-ARCH**: ❌ **禁止** 将 `internal` 包打包为独立 JAR 后供其他模块依赖（internal 是模块私有实现，不对外暴露）。

```xml
<!-- ❌ 错误示范 -->
<dependency>
    <groupId>com.[公司域名].[项目缩写]</groupId>
    <artifactId>module-domain-metadata-internal</artifactId>  <!-- ❌ internal 不应独立发布 -->
</dependency>
```

**R06-ARCH**: ❌ **禁止** 划分粒度过细（单个模块少于3张表且无独立业务边界）或过粗（超过20张表）。

```
判断标准：
- 如果一个模块的表可以被其他模块直接访问（无 HTTP API）→ 粒度过粗
- 如果一个模块只有 1-2 张表且职责单一 → 考虑合并到相近模块
```

> **来源**: 落地指南 第3章「工程结构规范」；MODULE-BOUNDARIES.md §一/§七

---

## 二、Schema设计原则

### 2.1 正面清单（Can Do）

**R07-ARCH**: ✅ 每张表必须明确标注 Owner 模块，并在 DDL 文件注释中体现。

```sql
-- ============================================================
-- Owner: module-domain-datasource
-- Description: 数据集信息表
-- ============================================================
CREATE TABLE t_data_datasets (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    workspace_id    BIGINT NOT NULL,
    schema_id       BIGINT,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

**R08-ARCH**: ✅ 表前缀规范：采用 `{业务域缩写}_{实体名}` 格式，确保跨模块无歧义。

```sql
-- ✅ 正确示例
t_data_datasets        -- 数据源模块的数据集表
t_meta_metadata_schemas -- 元数据模块的元数据Schema表
t_notify_channels       -- 通知模块的渠道表
t_algo_registries       -- 算法模块的注册表
```

**R09-ARCH**: ✅ 跨模块数据一致性通过以下机制保障：
- **最终一致性**：通过事件总线（Spring Events）异步同步
- **同步调用**：通过 HTTP API 实时查询（延迟敏感场景）
- **禁止**：分布式事务（应避免跨模块强一致性需求设计）

```java
// ✅ 正确：跨模块数据同步使用事件驱动
@Service
public class DatasetServiceImpl {
    @Autowired
    private ApplicationEventPublisher publisher;

    public void createDataset(DatasetDTO dto) {
        // 1. 本模块数据入库
        datasetRepository.insert(toEntity(dto));
        
        // 2. 发布事件，通知其他模块
        publisher.publishEvent(new DatasetCreatedEvent(this, dto.getId()));
    }
}
```

### 2.2 负面清单（Must Not Do）

**R10-ARCH**: ❌ **禁止** 在 DDL 中使用跨模块外键约束（`REFERENCES` 跨 Schema）。

```sql
-- ❌ 错误示范
CREATE TABLE t_data_files (
    dataset_id  BIGINT REFERENCES t_meta_datasets(id),  -- ❌ 跨模块外键
    ...
);
```

**R11-ARCH**: ❌ **禁止** 跨模块在 SQL 中 JOIN 不同前缀的表，即使业务上需要关联查询。

```sql
-- ❌ 错误示范
SELECT d.name, m.schema_name
FROM t_data_datasets d
JOIN t_meta_metadata_schemas m ON d.schema_id = m.id;  -- ❌ 禁止
```

✅ **正确做法**：在应用层通过两次查询 + 内存关联，或通过 HTTP API 调用 Owner 模块的查询接口。

**R12-ARCH**: ❌ **禁止** Consumer 模块自行定义 Owner 模块已拥有的 Entity 类（重复定义）。

```java
// ❌ 错误示范：data-source-management 中重复定义 Dataset entity
@Entity
@TableName("datasets")
public class LocalDatasetEntity {  // ❌ 名称不同但表相同 = 重复定义
    // ...
}
```

> **来源**: 落地指南 第4章「核心约束规则」§数据库Schema隔离；MODULE-BOUNDARIES.md §二/§三

---

## 三、技术选型原则

### 3.1 正面清单（Can Do）

**R13-ARCH**: ✅ 新引入依赖必须满足以下评估标准（任意一条不满足则必须经过架构评审）：

| 评估维度 | 评估标准 | 通过条件 |
|---------|---------|---------|
| **许可合规** | 必须是 Apache 2.0 / MIT / BSD 许可证 | ✅ 必须通过 |
| **安全漏洞** | 依赖库无已知 CVE（使用 `mvn dependency:tree` + `trivy` 扫描） | ✅ 必须通过 |
| **版本一致性** | 引入后不破坏现有 Spring Boot / JDK 版本一致性 | ✅ 必须通过 |
| **维护活跃度** | 最近 6 个月有版本发布（非死项目） | SHOULD |
| **社区生态** | 有活跃社区和文档 | SHOULD |
| **性能影响** | 启动时间和内存占用增幅 <5% | MUST NOT 破坏 |

**R14-ARCH**: ✅ 所有模块统一技术栈版本，版本变更必须经过架构评审。

```
统一技术栈版本（M2.4 阶段）：
- JDK: 17
- Spring Boot: 3.2.x
- MyBatis-Plus: 3.5.5
- MapStruct: 3.5.3
- ArchUnit: 1.3.x
- PostgreSQL: 15.x JDBC Driver: 42.7.x
```

**R15-ARCH**: ✅ 新增依赖必须记录到 `TECH-STACK.md`，注明引入理由和评估结果。

### 3.2 负面清单（Must Not Do）

**R16-ARCH**: ❌ **禁止** 未经评审引入以下类型依赖：
- 新的 ORM 框架（如 JPA / Hibernate）
- 新的消息队列客户端（Kafka / RabbitMQ）
- 新的调度框架（Quartz / XXL-Job）
- 任何涉及数据库连接池变更的库

```xml
<!-- ❌ 错误示范：未经评审引入 JPA -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>  <!-- ❌ JPA 与 MyBatis-Plus 混用 -->
</dependency>
```

**R17-ARCH**: ❌ **禁止** 引入版本与现有技术栈不兼容的库（如 Spring Boot 3.x 项目引入 javax.* 命名空间的库）。

> **来源**: 落地指南 第6章「技术选型」；architecture-design.md §0.2

---

## 四、重构红线

### 4.1 正面清单（Can Do）

**R18-ARCH**: ✅ 以下改动**必须**经过架构评审（Architecture Review）：

1. **模块拆分/合并**：任何涉及模块边界变更的操作
2. **跨模块依赖变更**：新增或删除模块间依赖（特别是 `api` 包之外的依赖）
3. **数据库 Schema 变更**：新增表、修改表前缀、跨模块数据迁移
4. **接口协议变更**：HTTP API 的路径/参数/响应结构变更（影响 Consumer）
5. **技术栈变更**：JDK 版本、Spring Boot 主版本、ORM 框架更换
6. **事件总线消息格式变更**：已有事件的新增字段或类型变更

```java
// ✅ 正确：变更前提交架构评审
// 评审议题：[ARCH-REVIEW] module-domain-datasource 拆分出 ETL 子模块
// 评审材料：ADR-XXX.md（Architecture Decision Record）
```

### 4.2 负面清单（Must Not Do）

**R19-ARCH**: ❌ **禁止** 在没有架构评审的情况下进行以下操作：

```java
// ❌ 场景 1：在 data-source-management 中新增对 metadata-service internal 的依赖
import com.[公司域名].[项目缩写].metadata.internal.repository.MetadataRepository;  // ❌ 违反 R04-DEV

// ❌ 场景 2：在 SQL 中新增跨模块 JOIN
// ❌ 场景 3：删除或重命名已发布的 API 接口参数
// ❌ 场景 4：将 module-domain-A 的表移动到 module-domain-B（需数据迁移方案）
```

**R20-ARCH**: ❌ **禁止** 在 CI/CD 流水线之外手动部署或修改配置（所有变更必须通过代码审查）。

**R21-ARCH**: ❌ **禁止** 在生产环境直接执行跨模块数据修正脚本（必须经过架构评审 + 数据备份方案）。

**R-ARCH-REF**: 拆分微服务的量化触发条件（基于 Shopify/Stripe/Uber 行业案例）：
> 1. **构建时间**：某模块构建时间 > 整体构建时间的 30% → 考虑独立编译/发布
> 2. **团队发布周期**：两个团队发布频率差异 > 5:1 → 考虑拆分独立部署周期
> 3. **资源消耗**：某模块 CPU/内存消耗 > 整体 40% → 考虑独立扩缩容
> 4. **跨模块调用深度**：某接口跨 3+ 模块调用 → 重审领域划分是否合理
> 5. **数据一致性边界**：跨模块事务 > 5 个 → 考虑事件驱动最终一致性

> **来源**: 落地指南 第4章「核心约束规则」§重构红线；MODULE-BOUNDARIES.md §八

---

## 五、架构守护

### 5.1 正面清单（Can Do）

**R22-ARCH**: ✅ 必须制定并维护 ArchUnit 规则，用于自动化验证模块边界。

```java
// ✅ 正确：ArchUnit 边界测试示例
@AnalyzeClasses(packagesOf = DataSourceModule.class)
public class ArchUnitBoundaryTest {

    // 规则 1：api 包中的类不能依赖 internal 包中的类
    @ArchTest
    static final ArchRule apiMustNotDependOnInternal =
        noClasses()
            .that().resideInAPackage("..api..")
            .should().dependOnClassesThat()
            .resideInAPackage("..internal..");

    // 规则 2：禁止跨模块依赖 internal 包
    @ArchTest
    static final ArchRule noCrossModuleInternalAccess =
        noClasses()
            .that().resideInAPackage("com.[公司域名].[项目缩写].data..")
            .should().accessClassesThat()
            .resideInAPackage("com.[公司域名].[项目缩写].metadata.internal..");

    // 规则 3：api 包只能包含接口和 DTO
    @ArchTest
    static final ArchRule apiOnlyContainsInterfacesAndDTOs =
        classes().that().resideInAPackage("..api..")
            .should().beInterfaces()
            .orShould().haveNameMatching(".*DTO$")
            .orShould().haveNameMatching(".*VO$");
}
```

**R23-ARCH**: ✅ ArchUnit 测试必须作为 CI 门禁的一部分，每次 PR 必须通过所有边界测试。

```yaml
# ✅ CI 配置示例
# .github/workflows/arch-test.yml
- name: Run ArchUnit Tests
  run: mvn test -Dtest=*ArchUnit* -pl module-domain-datasource
```

**R24-ARCH**: ✅ 新增模块或修改模块边界时，必须同步更新 ArchUnit 规则并提交 Review。

### 5.2 负面清单（Must Not Do）

**R25-ARCH**: ❌ **禁止** 在 ArchUnit 测试中使用 `@DomainInclude` / `@DomainExclude` 等机制人为豁免违规依赖。

```java
// ❌ 错误示范：人为豁免违规
@ArchTest
@DomainInclude("legacy-code")  // ❌ 禁止用豁免掩盖设计问题
static final ArchRule rule = ...
```

**R26-ARCH**: ❌ **禁止** ArchUnit 规则通过后永久不变，规则必须随架构演进同步更新（每次更新需 Review）。

**R27-ARCH**: ❌ **禁止** 在本地测试通过但 CI 失败时直接关闭测试或修改测试代码绕过，必须修复代码。

> **来源**: 落地指南 第4章「核心约束规则」§架构守护；MODULE-BOUNDARIES.md §八

---

## 六、试点模块规范（M2.4 阶段）

### 6.1 正面清单（Can Do）

**R28-ARCH**: ✅ 推荐 `module-domain-notify`（通知中心）作为 M2.4 重构试点模块，原因：
- 表数量少（2-3张）
- 职责单一（发送通知）
- 与其他模块耦合度低
- 可独立验证重构流程

**R29-ARCH**: ✅ 试点模块验证通过后，方可推广到其他模块。

### 6.2 负面清单（Must Not Do）

**R30-ARCH**: ❌ **禁止** 同时对多个模块进行重构（试点期间应聚焦单一模块，降低风险）。

> **来源**: 落地指南 §2.3

---

## 七、Python算法服务包边界强制规则（适用范围：仅Python算法服务）

**R31-ARCH（Python）**：✅ `api` 包必须通过 `__init__.py` 的 `__all__` 显式导出公开接口，禁止在 `__all__` 之外暴露实现。

**R32-ARCH（Python）**：✅ `api/` 层禁止直接 `import internal.*`（对应 D-001 §2.3 规则3）。通过显式的包边界约束，确保 `internal` 实现不会泄露到对外 API 中。
> 补充说明：ruff F401 只能检测"导入了但未使用"，无法检测跨模块引用。ruff F403/F405 才是检测导入行为的规则，但仍然不是字节码级别的包边界检测。包边界强制需依靠显式 `__all__` 导出约束（见 R31）配合 CI 自定义脚本。

**R33-ARCH（Python）**：✅ ruff 无直接规则强制要求 `__all__` 必须存在；无 `__all__` 的包并不违反 ruff 检查。若需强制所有对外包必须包含 `__all__`，应配合自定义 CI 脚本（如扫描所有 `__init__.py` 文件并检查 `__all__` 定义）。

**R34-ARCH（Python）**：✅ Python项目结构必须包含 `api/`、`internal/`、`model/` 三层，与 Java 落地指南的 `api/`、`internal/`、`model/` 包一一对应。

**R35-ARCH（Python）**：✅ `algorithm_id` 必须使用 snake_case 格式（如 `text_purify_v1`），与 Java backend 注册协议保持一致。

---

## 验收标准对照

| AC | 要求 | 规则覆盖 |
|----|------|---------|
| AC-02 | ≥8条，涵盖模块划分/Schema/选型/重构红线 | R01-R30 共30条规则 |
| AC-04 | 每条规则有明确来源引用 | 每条规则注明来源章节 |
| AC-05 | 措辞具体，无模糊表述 | 所有规则使用 MUST NOT / 必须 / 禁止 |

---

## 附录：架构评审议程模板

```
# Architecture Review 议程

## 1. 变更概述
- 变更类型：[模块拆分/合并/依赖变更/Schema变更/技术选型变更]
- 涉及模块：[列出所有受影响的模块]
- 变更原因：[业务驱动/技术债务/性能需求]

## 2. 影响分析
- 依赖关系变化：[附上依赖关系图]
- 数据库变更：[DDL diff]
- API 兼容性：[是否破坏性变更]
- 风险评估：[高/中/低]

## 3. 方案对比（如适用）
- 方案 A：[描述]
  - 优点：...
  - 缺点：...
- 方案 B：[描述]
  - ...

## 4. 决策
- [ ] 批准
- [ ] 有条件批准（需修改以下内容：...）
- [ ] 拒绝（原因：...）

## 5. 后续行动
- [ ] 更新 ArchUnit 规则
- [ ] 更新 MODULE-BOUNDARIES.md
- [ ] 制定数据迁移方案（如涉及）
- [ ] 更新 API 文档
```

### 第2轮补充修订（2026-04-19）：融入T-RESEARCH-001调研报告拆分决策量化标准（Shopify/Stripe/Uber）
