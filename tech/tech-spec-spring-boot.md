---
title: Spring Boot 3.x 项目结构规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 关联规范: [MyBatis-Plus 规范](tech-spec-mybatis-plus.md)、[错误码规范](../specs/doc-spec-error-codes.md) app-bootstrap/          ...
---

# Spring Boot 3.x 项目结构规范

> **版本**: v1.0  
> **创建日期**: 2026-04-29  
> **适用范围**: 使用 Spring Boot 3.x + Maven 的 Java 后端项目  
> **关联规范**: [MyBatis-Plus 规范](tech-spec-mybatis-plus.md)、[错误码规范](../specs/doc-spec-error-codes.md)

---

## 1. 项目结构

### 1.1 模块划分（模块化单体）

```
app-bootstrap/                    # 启动入口
├── src/main/java/com.[公司域名].[项目缩写]/
│   └── BootstrapApplication.java
└── pom.xml

module-core/                      # 核心层
├── api/                          # 通用接口/工具
├── internal/                     # 异常/日志/i18n/安全基座
└── pom.xml

module-domain-{business}/         # 业务域模块
├── api/                          # 对外暴露的接口定义
│   └── {Domain}Service.java
├── internal/                     # 私有实现
│   ├── service/                  # 业务逻辑
│   ├── repository/               # 数据访问（MyBatis-Plus Mapper）
│   ├── event/                    # 领域事件
│   └── config/                   # 模块配置
├── model/                        # 数据模型
│   ├── entity/                   # 数据库实体
│   ├── dto/                      # 数据传输对象
│   └── vo/                       # 视图对象
└── pom.xml
```

### 1.2 包名规范

```
com.[公司域名].[项目缩写].domain.{业务域}
├── .api.{Domain}Service          # 服务接口
├── .internal.service             # 实现类
├── .internal.repository          # Mapper 接口
├── .internal.event               # 事件定义
├── .model.entity                 # Entity
├── .model.dto                    # DTO
└── .model.vo                     # VO
```

---

## 2. 分层规范

### 2.1 Controller 层

```java
@RestController
@RequestMapping("/api/v1/{module}")
@RequiredArgsConstructor
public class DatasetController {
    
    private final DatasetService datasetService;
    
    @GetMapping
    public ApiResponse<Page<DatasetVO>> list(PageParam param) {
        return ApiResponse.success(datasetService.list(param));
    }
    
    @PostMapping
    public ApiResponse<DatasetVO> create(@RequestBody @Valid DatasetDTO dto) {
        return ApiResponse.success(datasetService.create(dto));
    }
}
```

**约束**：
- 仅负责参数校验和结果包装，不含业务逻辑
- 返回统一 `ApiResponse<T>`
- 使用 `@Valid` 进行入参校验

### 2.2 Service 层

```java
@Service
@RequiredArgsConstructor
public class DatasetServiceImpl implements DatasetService {
    
    private final DatasetMapper datasetMapper;
    
    @Override
    @Transactional(rollbackFor = Exception.class)
    public DatasetVO create(DatasetDTO dto) {
        // 业务逻辑...
    }
}
```

**约束**：
- 业务逻辑集中在此处
- 跨模块调用必须通过 `api` 包接口，禁止直接引用其他模块的 `internal`
- 事务注解在 Service 层

### 2.3 Repository 层

详见 [MyBatis-Plus 规范](tech-spec-mybatis-plus.md)。核心要点：

```java
@Mapper
public interface DatasetMapper extends BaseMapper<DatasetEntity> {
    // 复杂 SQL 写在 XML 中，禁止在 Mapper 接口中写 @Select 等注解
}
```

---

## 3. 模块边界

### 3.1 正面清单（Can Do）

- ✅ 模块可以依赖其他模块的 `api` 包中的接口定义
- ✅ 同一模块内的 `internal` 包可以自由相互依赖
- ✅ 模块可以依赖 `app-bootstrap` 中的配置加载器

### 3.2 负面清单（Must Not Do）

- ❌ **禁止**直接依赖其他模块的 `internal` 包中的任何类
- ❌ **禁止**在 SDK/lib 模块中定义 Mapper/Repository
- ❌ **禁止**跨模块直接注入 Mapper（fat JAR classloader 隔离问题）

### 3.3 Entity Owner 原则

每张表有且只有一个 Owner 模块：
1. 定义 entity 类（`@TableName`）
2. 定义 MyBatis-Plus `BaseMapper<>` 接口
3. 维护 DDL 文件
4. 其他模块通过 HTTP API 或 `api` 包接口调用

---

## 4. 异常处理

### 4.1 统一异常体系

```java
// 业务异常
throw new BizException(ErrorCode.Dataset.NOT_FOUND);

// 参数校验异常（自动处理）
// 由 @Valid 触发，GlobalExceptionHandler 统一处理

// 系统异常（兜底）
throw new BizException(ErrorCode.SYSTEM_ERROR);
```

### 4.2 GlobalExceptionHandler

```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(BizException.class)
    public ApiResponse<Void> handleBizException(BizException e) {
        return ApiResponse.error(e.getErrorCode());
    }
    
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ApiResponse<Void> handleValidation(MethodArgumentNotValidException e) {
        return ApiResponse.error(ErrorCode.VALIDATION_ERROR, e.getMessage());
    }
}
```

**关键约束**：所有业务异常统一使用 `BizException` + `ErrorCode` 枚举，禁止抛出裸 `RuntimeException`。

---

## 5. 配置管理

### 5.1 配置文件分层

```yaml
# application.yml — 通用配置
spring:
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:dev}

# application-dev.yml — 开发环境
# application-test.yml — 测试环境（E2E Session 固件）
# application-prod.yml — 生产环境
```

### 5.2 配置注入规范

```java
@ConfigurationProperties(prefix = "[项目缩写].feature")
@Data
public class FeatureProperties {
    private boolean enabled = true;
    private int timeout = 30;
}
```

**约束**：
- 使用 `@ConfigurationProperties` 而非 `@Value` 零散注入
- 前缀使用项目缩写，避免冲突
- 提供默认值，避免配置缺失启动失败

---

## 6. 日志规范

### 6.1 日志级别使用

| 级别 | 使用场景 |
|------|----------|
| **ERROR** | 业务异常、系统错误、需要告警的事件 |
| **WARN** | 非预期但可恢复的情况、性能阈值突破 |
| **INFO** | 关键业务流程节点（启动、配置加载、任务完成） |
| **DEBUG** | 详细调试信息，生产环境关闭 |

### 6.2 日志格式

推荐结构化 JSON 日志（生产环境）：

```json
{"timestamp":"2026-04-29T10:00:00","level":"INFO","logger":"c.e.d.DatasetService","traceId":"abc123","message":"Dataset created","datasetId":"ds-001"}
```

---

## 7. 检查清单

- [ ] Controller 仅含参数校验和结果包装
- [ ] Service 含业务逻辑和事务控制
- [ ] Mapper 仅数据访问，复杂 SQL 放 XML
- [ ] 跨模块调用走 `api` 接口，不穿透 `internal`
- [ ] 所有业务异常使用 `BizException` + `ErrorCode`
- [ ] 配置使用 `@ConfigurationProperties` 集中管理
- [ ] 日志级别使用恰当，生产环境关闭 DEBUG

---

*版本: v1.0 | 最后更新: 2026-04-29*
