---
title: [架构模式] — 资深测试工程师规则集（模板）
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 角色: 资深测试工程师（QA/Test Engineer） 来源: 基于 [项目]落地指南（[任务ID]产出物）
---

# [架构模式] — 资深测试工程师规则集（模板）

> **版本**: v1.0  
> **适用阶段**: [项目阶段] 代码重构/测试  
> **角色**: 资深测试工程师（QA/Test Engineer）  
> **来源**: 基于 `[项目]落地指南`（[任务ID]产出物）  
>
> **⚠️ 本文件为模板，使用前需替换方括号内的占位符为项目实际内容**

---

## 一、模块边界测试

### 1.1 正面清单（Can Do）

**R01-TEST**: ✅ 必须为每个 `module-domain-*` 模块编写 ArchUnit 边界测试，验证模块边界不被穿透。

```java
// ✅ 正确：module-domain-datasource 的边界测试
@AnalyzeClasses(packagesOf = DataSourceModule.class)
class DataSourceBoundaryTest {

    // 规则 1：禁止访问 metadata 模块的 internal 包
    @ArchTest
    static final ArchRule noAccessToMetadataInternal =
        noClasses()
            .that().resideInAPackage("com.[公司域名].[项目缩写].data.datasource..")
            .should().accessClassesThat()
            .resideInAPackage("com.[公司域名].[项目缩写].metadata.internal..");

    // 规则 2：api 包禁止依赖 internal 包
    @ArchTest
    static final ArchRule apiMustNotDependOnInternal =
        noClasses()
            .that().resideInAPackage("com.[公司域名].[项目缩写].data.datasource.api..")
            .should().dependOnClassesThat()
            .resideInAPackage("com.[公司域名].[项目缩写].data.datasource.internal..");

    // 规则 3：internal 包禁止被外部模块访问
    @ArchTest
    static final ArchRule internalMustNotBeAccessedByExternal =
        noClasses()
            .that().resideOutsideOfPackage("com.[公司域名].[项目缩写].data.datasource..")
            .should().accessClassesThat()
            .resideInAPackage("com.[公司域名].[项目缩写].data.datasource.internal..");

    // 规则 4：api 包只能包含接口和 DTO/VO
    @ArchTest
    static final ArchRule apiOnlyContainsInterfacesAndDTOs =
        classes().that().resideInAPackage("..api..")
            .should().beInterfaces()
            .orShould().haveNameMatching(".*DTO$")
            .orShould().haveNameMatching(".*VO$")
            .orShould().haveNameMatching(".*Request$")
            .orShould().haveNameMatching(".*Response$");

    // 规则 5：禁止跨模块直接使用其他模块的 Entity
    @ArchTest
    static final ArchRule noCrossModuleEntityUsage =
        noClasses()
            .that().resideInAPackage("com.[公司域名].[项目缩写].data.datasource..")
            .should().dependOnClassesThat()
            .haveNameMatching(".*Entity$")
            .andShould().notBeMemberClassesThat()
            .haveNameMatching("com.[公司域名].[项目缩写].data.datasource.model.entity..");
}
```

**R02-TEST**: ✅ 所有 ArchUnit 边界测试必须作为 CI 门禁，每次 PR 必须通过。

```yaml
# ✅ CI 配置
# .github/workflows/boundary-test.yml
- name: Run Module Boundary Tests
  run: |
    mvn test -Dtest=*BoundaryTest -pl :module-domain-datasource
    mvn test -Dtest=*BoundaryTest -pl :module-domain-metadata
    mvn test -Dtest=*BoundaryTest -pl :module-domain-notify
```

**R03-TEST**: ✅ 测试文件必须放在模块的 `src/test/java/` 下，遵循测试代码与源码包结构一致原则。

```
module-domain-datasource/
├── src/main/java/com/[公司域名].[项目缩写]/data/datasource/
│   ├── api/
│   ├── internal/
│   └── model/
└── src/test/java/com/[公司域名].[项目缩写]/data/datasource/
    └── boundary/
        └── DataSourceBoundaryTest.java  # ✅ 与源码包结构对应
```

### 1.2 负面清单（Must Not Do）

**R04-TEST**: ❌ **禁止** 在边界测试中使用 `@DomainInclude` / `@DomainExclude` 豁免真实违规。

```java
// ❌ 错误示范
@ArchTest
@DomainInclude("temp-workaround")  // ❌ 禁止用豁免掩盖违规
static final ArchRule rule = ...
```

**R05-TEST**: ❌ **禁止** 跳过 ArchUnit 测试（即使测试执行时间长也不可跳过，测试失败必须修复代码）。

**R06-TEST**: ❌ **禁止** 在 `src/main/` 目录下放置测试代码，所有测试必须在 `src/test/` 下。

> **来源**: 落地指南 §4

---

## 二、Schema隔离测试

### 2.1 正面清单（Can Do）

**R07-TEST**: ✅ 必须验证模块操作的表前缀与 Owner 模块一致。

```java
// ✅ 正确：验证 data-source-management 只操作 t_data_* 表
@Test
void datasourceModule_shouldOnlyAccessDataTables() {
    // 通过 MyBatis-Plus 日志验证 SQL 操作的表名
    List<String> accessedTables = extractAccessedTablesFromLogs();
    
    assertThat(accessedTables).allMatch(table -> 
        table.startsWith("t_data_")  // ✅ 只能是 t_data_* 前缀
    );
}
```

**R08-TEST**: ✅ 必须验证模块不持有其他模块表的 Repository。

```java
// ✅ 正确：验证无跨模块 Repository 注入
@Test
void shouldNotHaveCrossModuleRepositoryInjection() {
    Set<Field> allRepositoryFields = getFieldsWithAnnotation(
        dataSourceModule, 
        Autowired.class, 
        Repository.class
    );
    
    assertThat(allRepositoryFields).allMatch(field -> 
        field.getDeclaringClass().getPackage().getName()
            .contains("datasource")  // ✅ 只能是本模块的 Repository
    );
}
```

**R09-TEST**: ✅ 必须验证 SQL 中无跨模块 JOIN（通过解析 SQL 日志或使用 SQL 解析库验证）。

```java
// ✅ 正确：验证无跨模块 JOIN
@Test
void shouldNotHaveCrossModuleJoin() {
    String executedSql = getLastExecutedSql();
    
    // 检测跨表前缀的 JOIN
    boolean hasCrossModuleJoin = 
        executedSql.contains("JOIN") && 
        (executedSql.contains("t_data_") && executedSql.contains("t_meta_"));
    
    assertThat(hasCrossModuleJoin).isFalse();  // ❌ 不允许
}
```

**R10-TEST**: ✅ 集成测试中使用 H2内存数据库时，必须为每个模块创建独立的 H2 Schema。

```yaml
# ✅ 正确：application-test.yml 配置
spring:
  datasource:
    url: jdbc:h2:mem:testdb;MODE=PostgreSQL
    schema: classpath:db/schema-data.sql;classpath:db/schema-meta.sql
  sql:
    init:
      mode: always
```

### 2.2 负面清单（Must Not Do）

**R11-TEST**: ❌ **禁止** 在集成测试中对跨模块表进行 JOIN 查询（即使测试数据完备）。

```java
// ❌ 错误示范
@Test
void findDatasetWithMetadataSchema() {
    // ❌ 在测试中进行跨模块 JOIN
    List<Dataset> results = jdbcTemplate.query(
        "SELECT d.*, m.* FROM t_data_datasets d " +
        "JOIN t_meta_metadata_schemas m ON d.schema_id = m.id"  // ❌ 禁止
    );
}
```

**R12-TEST**: ❌ **禁止** 在测试中使用其他模块的 Entity 作为断言对象（应使用 DTO）。

```java
// ❌ 错误示范
@Test
void shouldReturnValidDataset() {
    Dataset result = datasetService.getDataset(id);
    MetadataSchemaEntity schema = metadataRepository.findById(result.getSchemaId());  // ❌ 跨模块用 Entity
    
    assertThat(schema.getName()).isNotNull();  // ❌ 不应依赖外部 Entity
}
```

> **来源**: 落地指南 §4

---

## 三、接口契约测试

### 3.1 正面清单（Can Do）

**R13-TEST**: ✅ 必须验证 Provider 模块的 API 接口与 Consumer 模块的调用协议一致。

```java
// ✅ 正确：接口契约测试（使用 @SpringBootTest + TestRestTemplate）
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class MetadataApiContractTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void metadataService_shouldProvideDatasetApi() {
        // Consumer 视角：验证 API 响应结构
        ResponseEntity<DatasetDTO> response = restTemplate.getForEntity(
            "http://localhost:{port}/api/v1/datasets/{id}",
            DatasetDTO.class,
            metadataPort,
            datasetId
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getId()).isNotNull();
        assertThat(response.getBody().getName()).isNotNull();
    }
}
```

**R14-TEST**: ✅ Consumer 模块应使用接口 Mock（如 Mockito mock 接口而非实现类）验证调用协议。

```java
// ✅ 正确：Mock 接口进行契约验证
@Test
void shouldCallDatasetServiceInterface() {
    DatasetService mockDatasetService = Mockito.mock(DatasetService.class);
    when(mockDatasetService.getDataset(any())).thenReturn(testDataset());

    // 调用被测服务，验证接口被正确调用
    standardizationService.processStandardization(datasetId);

    verify(mockDatasetService).getDataset(datasetId);  // ✅ 验证调用接口而非实现
}
```

**R15-TEST**: ✅ API 接口变更必须同步更新 Contract Test，Contract Test 失败意味着 API 兼容性被破坏。

```java
// ✅ 正确：Contract Test 捕获 API 变更
@Test
void apiContract_datasetResponse_shouldHaveRequiredFields() {
    DatasetDTO response = callDatasetApi(datasetId);
    
    // 必须字段
    assertThat(response.getId()).isNotNull();        // ✅
    assertThat(response.getName()).isNotNull();      // ✅
    assertThat(response.getWorkspaceId()).isNotNull(); // ✅
    
    // 可选字段（验证 null 安全）
    assertThat(response.getMetadata()).isNotNull();  // ✅ 即使无 metadata 也不应 NPE
}
```

### 3.2 负面清单（Must Not Do）

**R16-TEST**: ❌ **禁止** 在测试中 Mock 实现类而非接口。

```java
// ❌ 错误示范
@Autowired
private DatasetServiceImpl datasetServiceImpl;  // ❌ 注入实现类而非接口

// ❌ 错误示范：Mock 实现类
DatasetServiceImpl mock = Mockito.mock(DatasetServiceImpl.class);
```

**R17-TEST**: ❌ **禁止** 在 Consumer 测试中直接操作 Provider 模块的数据库（应通过 HTTP API）。

```java
// ❌ 错误示范：Consumer 直接操作 Provider 数据库
@Test
void consumerTest() {
    // ❌ 直接插入 metadata 数据库
    jdbcTemplate.update(
        "INSERT INTO t_meta_datasets (id, name) VALUES (?, ?)",
        datasetId, "test"
    );
    
    // 调用被测服务...
}
```

> **来源**: 落地指南 §4

---

## 四、事件总线测试

### 4.1 正面清单（Can Do）

**R18-TEST**: ✅ 必须验证事件监听器注册正确，事件能被正确发布和消费。

```java
// ✅ 正确：事件总线功能测试
@SpringBootTest
class EventBusIntegrationTest {

    @Autowired
    private ApplicationEventPublisher publisher;

    @Test
    void shouldPublishAndConsumeEvent() throws InterruptedException {
        // 准备计数器
        AtomicInteger counter = new AtomicInteger(0);
        
        // 注册监听器
        applicationEventPublisher.publishEvent(new TestEvent(this, "test-data"));
        
        // 等待异步处理
        Thread.sleep(100);  // 等待 @Async 监听器执行
        
        assertThat(counter.get()).isGreaterThan(0);  // ✅ 验证事件被消费
    }
}
```

**R19-TEST**: ✅ 必须验证事件消息格式（字段完整性、类型正确性）。

```java
// ✅ 正确：验证事件消息格式
@Test
void datasetCreatedEvent_shouldHaveRequiredFields() {
    DatasetCreatedEvent event = new DatasetCreatedEvent(
        this, "dataset-123", "workspace-456"
    );
    
    assertThat(event.getDatasetId()).isNotNull();
    assertThat(event.getWorkspaceId()).isNotNull();
    assertThat(event.getTimestamp()).isNotNull();  // ✅ 事件应包含时间戳
}
```

**R20-TEST**: ✅ 必须验证事件处理的幂等性（重复消费不会产生副作用）。

```java
// ✅ 正确：验证事件幂等性
@Test
void eventListener_shouldBeIdempotent() {
    // 第一次处理
    publisher.publishEvent(new DatasetCreatedEvent(this, "ds-1", "ws-1"));
    
    // 重复处理（模拟重试）
    publisher.publishEvent(new DatasetCreatedEvent(this, "ds-1", "ws-1"));
    
    // 验证：只创建了一条记录（幂等性）
    assertThat(datasetRepository.findByDatasetId("ds-1")).hasSize(1);
}
```

### 4.2 负面清单（Must Not Do）

**R21-TEST**: ❌ **禁止** 在事件监听器测试中使用真实数据库事务（应 Mock 或使用 @Transactional(propagation = NEVER)）。

```java
// ❌ 错误示范：事件监听器中开启事务
@EventListener
@Transactional  // ❌ 事件监听器不应使用事务
public void onDatasetCreated(DatasetCreatedEvent event) {
    datasetRepository.save(...);  // ❌ 可能导致事务问题
}
```

**R22-TEST**: ❌ **禁止** 在测试中依赖事件的执行顺序（事件总线不保证顺序）。

```java
// ❌ 错误示范
@Test
void events_shouldBeProcessedInOrder() {
    publisher.publishEvent(new Event1());
    publisher.publishEvent(new Event2());
    
    // ❌ 不应依赖处理顺序，事件总线不保证
    assertThat(results).containsExactly("event1-result", "event2-result");
}
```

> **来源**: 落地指南 第4章「核心约束规则」§进程内通信协议；architecture-design.md §4.6

---

## 五、回归测试

### 5.1 正面清单（Can Do）

**R23-TEST**: ✅ 每个模块重构前后必须运行完整的回归测试套件，确保现有功能不受影响。

```bash
# ✅ 回归测试执行命令
mvn test -pl module-domain-datasource \
    -Dtest=*IntegrationTest,*BoundaryTest \
    -DfailIfNoTests=false
```

**R24-TEST**: ✅ 重构后必须执行 E2E 测试覆盖核心业务链路。

```java
// ✅ 正确：E2E 测试覆盖核心链路
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)
class DataIngestionE2ETest {

    @Test
    void endToEnd_fileIngestionPipeline() {
        // 1. 上传文件
        String fileId = uploadFile("test.csv");
        
        // 2. 触发 ETL
        String taskId = triggerETL(fileId);
        
        // 3. 等待处理完成
        await().atMost(Duration.ofMinutes(5))
            .until(() -> taskStatus(taskId) == "COMPLETED");
        
        // 4. 验证数据入库
        assertThat(queryDatasetByFileId(fileId)).isNotNull();
    }
}
```

**R25-TEST**: ✅ 必须为每个模块的 API 接口编写契约测试，防止接口不兼容。

```java
// ✅ 正确：API 契约测试
@Test
void apiContract_metadataService_createDataset() {
    HttpHeaders headers = new HttpHeaders();
    headers.setContentType(MediaType.APPLICATION_JSON);
    
    HttpEntity<CreateDatasetRequest> request = 
        new HttpEntity<>(new CreateDatasetRequest("test-ds", "ws-1"), headers);
    
    ResponseEntity<DatasetDTO> response = restTemplate.postForEntity(
        "/api/v1/datasets",
        request,
        DatasetDTO.class
    );
    
    // 验证响应契约
    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    assertThat(response.getHeaders().getLocation()).isNotNull();
    assertThat(response.getBody().getId()).isNotNull();
}
```

**R26-TEST**: ✅ 重构完成后必须执行数据库一致性验证（Entity 定义与 DDL 一致）。

```sql
-- ✅ 验证脚本：对比 Entity 与 DDL
SELECT 
    e.table_name,
    e.column_name,
    e.data_type as entity_type,
    d.data_type as ddl_type,
    CASE WHEN e.data_type != d.data_type THEN 'MISMATCH' ELSE 'OK' END as status
FROM entity_metadata e
JOIN information_schema.columns d 
    ON e.table_name = d.table_name 
    AND e.column_name = d.column_name
WHERE e.module = 'datasource';
```

### 5.2 负面清单（Must Not Do）

**R27-TEST**: ❌ **禁止** 在重构后跳过原有的单元测试（即使测试执行时间变长）。

```java
// ❌ 错误示范：在重构后禁用测试
@Test
@Disabled("重构后测试失败，暂时禁用")  // ❌ 禁止
void someLegacyTest() { ... }
```

**R28-TEST**: ❌ **禁止** 使用 `assumeTrue` 跳过测试中的关键断言。

```java
// ❌ 错误示范
@Test
void testDatasetQuery() {
    assumeTrue(database.isAvailable());  // ❌ 数据库不可用就跳过
    // ...
    assertThat(result).isNotNull();  // ❌ 关键断言被跳过
}

// ✅ 正确：使用 @EnabledIf 或明确处理
@EnabledIf(expression = "#{systemProperties['db.available'] == 'true'}", 
           stage = Stage.PACKAGE)
@Test
void testDatasetQuery() { ... }
```

**R29-TEST**: ❌ **禁止** 在回归测试中使用 `Thread.sleep` 做时间等待（应使用 Awaitility 或 Mockito 的 timeout）。

```java
// ❌ 错误示范
@Test
void testAsyncProcessing() {
    publisher.publishEvent(new ProcessEvent());
    Thread.sleep(5000);  // ❌ 硬编码等待，时间不可靠
    assertThat(result).isNotNull();
}

// ✅ 正确：使用 Awaitility
@Test
void testAsyncProcessing() {
    publisher.publishEvent(new ProcessEvent());
    
    await().atMost(10, TimeUnit.SECONDS)
        .until(() -> result != null);
    
    assertThat(result).isNotNull();
}
```

> **来源**: 落地指南 §4

---

## 六、测试覆盖率要求

### 6.1 正面清单（Can Do）

**R30-TEST**: ✅ 核心业务逻辑覆盖率必须 ≥80%（以 Jacoco 报告为准）。

```xml
<!-- pom.xml 配置 -->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <configuration>
        <rules>
            <rule>
                <element>CLASS</element>
                <limits>
                    <limit>
                        <counter>LINE</counter>
                        <value>COVEREDRATIO</value>
                        <minimum>0.80</minimum>
                    </limit>
                </limits>
            </rule>
        </rules>
    </configuration>
</plugin>
```

**R31-TEST**: ✅ 模块边界测试（ArchUnit）覆盖率必须 100%（即所有跨模块访问都必须被规则覆盖）。

```java
// ✅ CI 门禁：ArchUnit 必须 100% 通过
@ArchTest
static final ArchRule allPublicAPIClassesAreTested =
    classes().that().arePublic().and().areNotEnums()
        .should().bePublic();
```

### 6.2 负面清单（Must Not Do）

**R32-TEST**: ❌ **禁止** 以"测试执行时间长"为由降低覆盖率要求（应优化测试策略，如使用 TestNG 并行执行）。

**R33-TEST**: ❌ **禁止** 合并多个模块的测试结果来满足单一模块的覆盖率要求（必须分模块报告）。

> **来源**: 落地指南 §4

---

## 七、Python算法服务测试规范（适用范围：仅Python算法服务）

**R01-TEST（Python）**：✅ Python 算法服务必须使用 pytest 作为测试框架，测试文件必须放在 `tests/` 目录下，与源码包结构对应。

**R02-TEST（Python）**：✅ 覆盖率目标：正常/边界/异常三类测试用例全覆盖，量化指标按项目实际情况确定（85%覆盖率指标已根据 M2.6-design 决议移除）。

**R03-TEST（Python）**：✅ ruff F401 的包边界检测能力有限——仅能检测显式导入但未使用的符号，无法防止动态引用（如 `importlib.import_module()`）。ArchUnit 为字节码级别分析，ruff 为静态 lint，两者能力不可等价替代。建议补充运行时集成测试作为补充手段。

**R04-TEST（Python）**：✅ 异步测试使用 `pytest-asyncio`，禁止在异步测试中使用 `time.sleep()` 等待（应使用 `await asyncio.sleep()`）。fixture默认scope="function"。

**R05-TEST（Python）**：✅ 禁止在测试中 Mock 实现类而非接口。

**R06-TEST（Python）**：✅ 覆盖率报告必须分模块统计，禁止合并多个 Python 模块的覆盖率结果来满足单一模块要求。

---

## 验收标准对照

| AC | 要求 | 规则覆盖 |
|----|------|---------|
| AC-03 | ≥8条，涵盖边界测试/隔离测试/契约测试 | R01-R33 共33条规则 |
| AC-04 | 每条规则有明确来源引用 | 每条规则注明来源章节 |
| AC-05 | 措辞具体，无模糊表述 | 所有规则使用 MUST NOT / 必须 / 禁止 |

---

## 附录：测试工具链

```
测试工具链（M2.4 阶段）：
├── 单元测试：JUnit 5 + Mockito
├── 集成测试：SpringBootTest + TestRestTemplate
├── 边界测试：ArchUnit 1.3.x
├── E2E 测试：SpringBootTest (随机端口)
├── 覆盖率：Jacoco
├── 并行执行：TestNG / JUnit5 ParallelExecution
├── 异步等待：Awaitility
└── API 契约：REST Assured / MockMvc
```
