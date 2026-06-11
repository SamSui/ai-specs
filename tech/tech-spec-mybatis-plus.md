---
title: MyBatis-Plus 使用规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 最后更新: 2026-04-01 1. [核心原则](#核心原则)
---

# MyBatis-Plus 使用规范

> **版本**: v1.0  
> **作者**: [规范作者]  
> **最后更新**: 2026-04-01  
> **状态**: ✅ 已评审

---

## 📋 目录

1. [核心原则](#核心原则)
2. [实体类规范](#实体类规范)
3. [Mapper 层规范](#mapper-层规范)
4. [Service 层规范](#service-层规范)
5. [代码示例](#代码示例)
6. [常见问题](#常见问题)

---

## 核心原则

### 1.1 设计理念

- **极简主义**: 优先使用 MP 提供的 CRUD 能力，避免过度封装
- **可维护性**: 代码结构清晰，注释到位，便于团队协作
- **性能优先**: 注意 N+1 问题，合理使用索引和缓存
- **扩展性**: 复杂场景使用 XML 或自定义 SQL

### 1.2 技术栈约定

```java
// POM 依赖
<dependency>
    <groupId>com.baomidou</groupId>
    <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
    <version>3.5.5</version> // 保持与 Spring Boot 3.x 兼容
</dependency>

<!-- PostgreSQL 驱动 -->
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
</dependency>
```

---

## 实体类规范

### 2.1 基本结构

```java
package com.[公司域名].[项目缩写].metadata.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.experimental.FieldNameConstants;
import org.jetbrains.annotations.NotNull;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 元数据实体类
 * 
 * @author [规范作者]
 * @date 2026-04-01
 */
@Data
@FieldNameConstants
@TableName(value = "metadata", autoResultMap = true)
public class MetadataEntity {
    
    // ==================== 主键 ====================
    
    /**
     * 主键 ID (UUID 格式)
     * 使用雪花算法或 UUID，避免分布式系统的 ID 冲突
     */
    @TableId(value = "id", type = IdType.UUID)
    @NotNull
    private String id;
    
    // ==================== 核心业务字段 ====================
    
    /**
     * 元数据名称
     * 索引：IDX_metadata_name
     */
    @TableField(value = "name")
    @NotNull
    private String name;
    
    /**
     * 元数据类型 (enum)
     * 示例：TABLE, VIEW, INDEX, FUNCTION
     */
    @TableField(value = "metadata_type")
    @NotNull
    private String metadataType;
    
    /**
     * JSONB 存储的扩展属性
     * 注意：使用 FlattenedTypeHandler 转换转为合理的 PG JSONB 类型
     */
    @TableField(value = "properties")
    private Object properties; // bytea ощ包裹的 JSONB
    
    // ==================== 关系字段 ====================
    
    /**
     * 关联的 Schema ID
     */
    @TableField(value = "schema_id")
    private String schemaId;
    
    // ==================== 审计字段 ====================
    
    /**
     * 创建人 ID
     */
    @TableField(value = "created_by", fill = FieldFill.INSERT)
    private String createdBy;
    
    /**
     * 创建时间
     */
    @TableField(value = "created_at", fill = FieldFill.INSERT)
    @NotNull
    private LocalDateTime createdAt;
    
    /**
     * 最后修改人 ID
     */
    @TableField(value = "updated_by", fill = FieldFill.INSERT_UPDATE)
    private String updatedBy;
    
    /**
     * 最后修改时间
     */
    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    @NotNull
    private LocalDateTime updatedAt;
    
    /**
     * 软删除标记 (0=未删除，1=已删除)
     * 配合 MyBatis-Plus 的 LogicDelete 使用
     */
    @TableField(value = "deleted")
    private Integer deleted = 0;
    
    // ==================== 构造方法 ====================
    
    /**
     * 无参构造方法 (必须保留，MP 需要)
     */
    public MetadataEntity() {
    }
    
    // ==================== 业务方法 ====================
    
    /**
     * 生成记录 ID
     */
    private void generateId() {
        this.id = UUID.randomUUID().toString().replace("-", "");
    }
    
    /**
     * 标记为已删除
     */
    public void markDeleted() {
        this.deleted = 1;
    }
}
```

### 2.2 字段命名规范

| 规则 | 示例 | 说明 |
|------|------|------|
| 主键统一使用 `id` | `id` | 使用 `@TableId` 标注 |
| 大写下划线转小驼峰 | `CREATED_AT` → `createdAt` | 自动转换 |
| 布尔类型用 `is/isNot` 前缀 | `is_active` → `isActive` | 避免歧义 |
| 逻辑删除字段固定命名 | `deleted`, `is_deleted` | 配合 MP 配置 |
| 时间字段统一用 `DateTime` | `created_at` → `createdAt` | PostgreSQL 适配 |
| 枚举字段用 `Type/Status` 后缀 | `user_type` → `userType` | 语义清晰 |

### 2.3 注解使用规范

#### 2.3.1 主键策略

```java
// ✅ 推荐：雪花算法 (分布式友好)
@TableId(value = "id", type = IdType.ASSIGN_ID)

// ⚠️ 可选：UUID (安全性要求高的场景)
@TableId(value = "id", type = IdType.UUID)

// ❌ 不推荐：AUTO (PostgreSQL SERIAL 有性能瓶颈)
@TableId(value = "id", type = IdType.AUTO)

// ❌ 不推荐：NONE (需要手动生成 ID，容易出错)
@TableId(value = "id", type = IdType.NONE)
```

#### 2.3.2 表名映射

```java
// ✅ 推荐：使用 autoResultMap=true (复杂查询需要)
@TableName(value = "t_user", autoResultMap = true)

// ⚠️ 简单场景可以省略
@TableName("t_user")

// ❌ 避免使用自动表名策略 (可维护性差)
@TableName(value = "user", strategy = TableFieldNamingStrategy.CAMEL_TO_UNDERSCORE)
```

#### 2.3.3 字段映射

```java
// ✅ 字段名与列名不一致时
@TableField(value = "user_name", exist = false)
private String userName; // exist=false 防止删除时需维护字段

// ⚠️ 列在 POJO 中未声明但作为投影字段
@TableField(exist = false)
private String projectionField; // 临时字段，不映射到数据库

// ✅ 只读字段 (填充策略)
@TableField(value = "created_at", fill = FieldFill.INSERT)
private LocalDateTime createdAt;
```

#### 2.3.4 逻辑删除

```java
// ✅ 推荐：全局配置 + 字段标注
// application.yml
mybatis-plus:
  global-config:
    db-config:
      logic-delete-field: deleted
      logic-delete-value: 1
      logic-not-delete-value: 0

// 实体类
@TableField(value = "deleted")
private Integer deleted = 0;

// ❌ 避免在 Mapper 中手动处理
// 直接使用 baseMapper.selectByMap() 即可
```

### 2.4 类型适配 (PostgreSQL 特有)

```java
/**
 * PostgreSQL 类型特殊处理
 */
public class PgTypeAdapter {
    
    // ==================== JSONB 处理器 ====================
    
    @Configuration
    public MybatisPlusConfig mybatisPlusConfig(JdbcTemplate jdbcTemplate) {
        // JSONB 使用 FlattenedJsonbTypeHandler 转为合理的 PG JSONB 类型
        typeHandlerRegistry.register(FlattenedJsonbTypeHandler.class);
        return new MybatisPlusConfig();
    }
    
    // ==================== UUID 处理器 ====================
    
    // PostgreSQL UUID 类型 → 转换为 String
    @TableField(typeHandler = UUIDTypeHandler.class, value = "creator_id")
    private String creatorId;
    
    // ==================== 数组处理 ====================
    
    @TableField(typeHandler = StringArrayHandler.class, value = "permissions")
    private List<String> permissions;
    
    // ==================== JSONB 嵌套对象 ====================
    
    @TableName("t_metadata")
    public class Metadata {
        // ✅ 推荐：使用 FlattenJsonbTypeHandler
        @TableField(typeHandler = FlattenJsonbTypeHandler.class, value = "properties")
        private MetadataProperties properties;
        
        @Data
        @JsonNaming(JsonNamingConvention.SNAKE_CASE)
        public static class MetadataProperties {
            private String description;
            private List<Tag> tags;
            private Map<String, Object> extra;
        }
    }
}
```

---

## Mapper 层规范

### 3.1 基础 Mapper 接口

```java
package com.[公司域名].[项目缩写].metadata.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.[公司域名].[项目缩写].metadata.entity.MetadataEntity;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;

/**
 * 元数据 Mapper 接口
 * 
 * @author [规范作者]
 * @date 2026-04-01
 */
@Mapper
public interface MetadataMapper extends BaseMapper<MetadataEntity> {
    
    // ==================== MP 基础 CRUD (已继承，无需手动编写) ====================
    // int insert(MetadataEntity entity)
    // int deleteById(Long id)
    // int updateById(MetadataEntity entity)
    // MetadataEntity selectById(Long id)
    // List<MetadataEntity> selectBatchIds(List<Long> ids)
    
    // ==================== 自定义查询方法 ====================
}
```

### 3.2 条件构建器规范

```java
/**
 * 使用 QueryWrapper/LambdaQueryWrapper 的最佳实践
 */
public class MetadataQueryExample {
    
    // ==================== LambdaQueryWrapper (推荐) ====================
    
    /**
     * ✅ 推荐：使用 LambdaQueryWrapper (编译期类型安全)
     */
    public List<MetadataEntity> searchMetadata(String name, String type) {
        LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
        
        // 多个条件 AND
        wrapper.like("name", name)
              .eq("metadata_type", type)
              .isNotNull("schema_id");
        
        // 条件包裹 (name 不为空才生效)
        if (StringUtils.isNotBlank(name)) {
            wrapper.and(w -> w.eq("name", name));
        }
        
        // 排序
        wrapper.orderByDesc("created_at");
        
        // 分页 (MP 会包装成物理分页)
        wrapper.last("LIMIT 10 OFFSET 0");
        
        return metadataMapper.selectList(wrapper);
    }
    
    // ==================== IN 查询 ====================
    
    /**
     * ✅ 推荐：使用 IN 查询批量数据
     */
    public List<MetadataEntity> batchSearchByIds(List<String> ids) {
        LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
        wrapper.in("id", ids).isNotNull("metadata_type");
        return metadataMapper.selectList(wrapper);
    }
    
    // ==================== 关联查询 ====================
    
    /**
     * ✅ JOIN 查询 (避免 N+1 问题)
     */
    default List<MetadataEntity> queryWithSchemas(List<String> schemaIds) {
        LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
        wrapper.in("schema_id", schemaIds)
              .select("id", "name", "schema_id") // 只查询需要的字段
              .groupBy("id"); // 防止重复
        return selectList(wrapper);
    }
    
    // ==================== 子查询 ====================
    
    /**
     * ✅ 子查询场景
     */
    default List<MetadataEntity> queryRecentModified(String schemaId, int count) {
        StringBuilder sql = new StringBuilder();
        sql.append("<script>");
        sql.append("SELECT * FROM metadata WHERE schema_id = #{schemaId}");
        sql.append("AND created_at > (");
        sql.append("SELECT created_at FROM metadata WHERE schema_id = #{schemaId}");
        sql.append("ORDER BY created_at DESC LIMIT 1 OFFSET #{count})");
        sql.append("ORDER BY created_at DESC");
        sql.append("</script>");
        
        return selectBySql(sql.toString(), new HashMap<String, Object>() {{
            put("schemaId", schemaId);
            put("count", count);
        }});
    }
}
```

### 3.3 复杂 SQL (XML) 规范

```xml
<!-- metadata-mapper.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" 
    "http://mybatis.org/dtd/mybatis-3-mapper.dtd">

<mapper namespace="com.[公司域名].[项目缩写].metadata.mapper.MetadataMapper">
    
    <!-- ==================== ResultMap (复杂对象映射) ==================== -->
    
    <resultMap id="MetadataWithSchema" type="com.[公司域名].[项目缩写].metadata.dto.MetadataWithSchemaDTO">
        <result column="id" property="id" />
        <result column="name" property="name" />
        <result column="metadata_type" property="metadataType" />
        <association property="schema" 
                    javaType="com.[公司域名].[项目缩写].metadata.dto.SchemaDTO">
            <result column="schema_name" property="name"/>
        </association>
    </resultMap>
    
    <!-- ==================== 动态 SQL 片段 ==================== -->
    
    <!-- 公共 WHERE 条件 -->
    <sql id="Base_Column_List">
        id, name, metadata_type, properties, schema_id,
        created_by, created_at, updated_by, updated_at, deleted
    </sql>
    
    <!-- 通用过滤条件 (逻辑删除 + 审计字段) -->
    <sql id="Common_Where_Clause">
        <if test="deleted != null">
            AND deleted = #{deleted}
        </if>
        <if test="createdBy != null">
            AND created_by = #{createdBy}
        </if>
    </sql>
    
    <!-- ==================== 复杂查询 ==================== -->
    
    <!-- 分页查询元数据 (支持多种排序方式) -->
    <select id="queryMetadataPage" resultType="com.[公司域名].[项目缩写].metadata.dto.MetadataDTO" 
            parameterType="com.[公司域名].[项目缩写].metadata.dto.MetadataQueryCriteria">
        SELECT
            id, name, metadata_type,
            properties::json as properties, -- PostgreSQL JSONB 类型转换
            schema_id,
            created_at,
            updated_at
        FROM metadata
        WHERE deleted = 0
        <if test="name != null and name != ''">
            AND name ILIKE CONCAT('%', #{name}, '%') -- PostgreSQL 模糊查询 (不区分大小写)
        </if>
        <if test="metadataType != null and metadataType != ''">
            AND metadata_type = #{metadataType}
        </if>
        <if test="schemaId != null">
            AND schema_id = #{schemaId}
        </if>
        <if test="startTime != null">
            AND created_at &gt;= #{startTime}
        </if>
        <if test="endTime != null">
            AND created_at &lt;= #{endTime}
        </if>
        ORDER BY
            <choose>
                <when test="sortField == 'name'">
                    name ${sortOrder}
                </when>
                <when test="sortField == 'createdAt'">
                    created_at ${sortOrder}
                </when>
                <otherwise>
                    created_at DESC
                </otherwise>
            </choose>
        LIMIT #{pageSize}
        OFFSET #{offset}
    </select>
    
    <!-- ==================== 批量操作 ==================== -->
    
    <!-- 批量插入 (PostgreSQL 返回自增 ID) -->
    <insert id="batchInsertWithIdSelect" parameterType="list" useGeneratedKeys="true" keyColumn="id" keyProperty="id">
        INSERT INTO metadata (id, name, metadata_type, properties, created_by, created_at)
        VALUES
        <foreach collection="list" item="item" separator=",">
            (
                #{item.id},
                #{item.name},
                #{item.metadataType},
                #{item.properties},
                #{item.createdBy},
                NOW()
            )
        </foreach>
    </insert>
    
    <!-- ==================== JSONB 查询 ==================== -->
    
    <!-- 查询 JSONB 属性中包含特定值的记录 -->
    <select id="queryByPropertyInJsonb" resultType="com.[公司域名].[项目缩写].metadata.dto.MetadataDTO">
        SELECT
            id, name, metadata_type,
            properties::json as properties
        FROM metadata
        WHERE deleted = 0
        AND properties::json->>'description' ILIKE CONCAT('%', #{keyword}, '%')
        <if test="value != null">
            AND properties::json->>'status' = #{value}
        </if>
    </select>
    
    <!-- ==================== 流式查询 (大数据量) ==================== -->
    
    <!-- 使用 Cursor 分批查询 (避免 OOM) -->
    <select id="queryLargeDataset" resultType="com.[公司域名].[项目缩写].metadata.dto.MetadataDTO" 
            fetchSize="1000" timeout="600000">
        SELECT id, name, metadata_type FROM metadata
        WHERE deleted = 0
        ORDER BY created_at
    </select>
</mapper>
```

### 3.4 避免常见错误

```java
// ❌ 错误 1: 过度使用 QueryWrapper (性能问题)
public List<MetadataEntity> badSearch() {
    LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
    wrapper.select("id").select("name").select("metadata_type"); // 多次 select 会覆盖
    wrapper.orderByDesc("id").orderByAsc("name"); // 多次 orderBy 前面失效
    return metadataMapper.selectList(wrapper);
}

// ✅ 正确做法
public List<MetadataEntity> goodSearch() {
    LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
    wrapper.select("id", "name", "metadata_type")
           .orderByDesc("name");
    return metadataMapper.selectList(wrapper);
}

// ❌ 错误 2: SQL 注入风险 (userInput 直接拼接)
public List<MetadataEntity> vulnerableSearch(String userInput) {
    // 不要用 #{}，必须用 #{userInput}
    String sql = "SELECT id FROM metadata WHERE name = '" + userInput + "'";
    return metadataMapper.selectBySql(sql);
}

// ✅ 正确做法：参数化查询
public List<MetadataEntity> safeSearch(String userInput) {
    LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
    wrapper.eq("name", userInput);
    return metadataMapper.selectList(wrapper);
}

// ❌ 错误 3: N+1 查询问题
public List<MetadataEntity> getWithSchemas(List<String> ids) {
    List<MetadataEntity> list = metadataMapper.selectBatchIds(ids);
    for (MetadataEntity item : list) {
        Schema schema = schemaMapper.selectById(item.getSchemaId()); // N+1 次查询!
        item.setSchema(schema);
    }
    return list;
}

// ✅ 正确做法: JOIN 或批量查询
public List<MetadataEntity> getWithSchemasOptimized(List<String> ids) {
    LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
    wrapper.in("id", ids)
           .select("id", "name", "schema_id")
           .join("schema", "schema.id = metadata.schema_id")
           .select("schema.name schema_name");
    return metadataMapper.selectList(wrapper);
}
```

---

## Service 层规范

### 4.1 基础 Service 层结构

```java
package com.[公司域名].[项目缩写].metadata.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.[公司域名].[项目缩写].metadata.dto.*;
import com.[公司域名].[项目缩写].metadata.entity.MetadataEntity;
import com.[公司域名].[项目缩写].metadata.mapper.MetadataMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;

/**
 * 元数据 Service 接口
 * 
 * @author [规范作者]
 * @date 2026-04-01
 */
public interface MetadataService extends IService<MetadataEntity> {
    // 定义业务方法
}

/**
 * 元数据 Service 实现
 * 
 * @author [规范作者]
 * @date 2026-04-01
 */
@Service
public class MetadataServiceImpl extends ServiceImpl<MetadataMapper, MetadataEntity> implements MetadataService {
    // 实现业务方法
}
```

### 4.2 事务管理规范

```java
/**
 * 事务管理最佳实践
 */
@Service
public class MetadataServiceTransaction {
    
    @Autowired
    private MetadataMapper metadataMapper;
    
    // ==================== 只读方法 (默认 READ_ONLY) ====================
    
    /**
     * ✅ 推荐：只读查询用 READONLY 提升性能
     * PostgreSQL 会自动优化为只读事务，减少锁竞争
     */
    @Transactional(readOnly = true)
    public MetadataEntity getMetadata(String id) {
        return metadataMapper.selectById(id);
    }
    
    // ==================== 写操作 (默认 REQUIRED) ====================
    
    /**
     * ✅ 推荐：显式声明写操作的事务传播
     */
    @Transactional(
        propagation = Propagation.REQUIRED,
        rollbackFor = Exception.class,
        timeout = 30
    )
    public void createMetadata(MetadataCreateDTO createDTO) {
        MetadataEntity entity = DOUtils.toEntity(createDTO);
        metadataMapper.insert(entity);
        
        // 后续业务逻辑...
    }
    
    // ==================== 新事务 (@Transactional(new=true)) ====================
    
    /**
     * ⚠️ 慎用：REQUIRES_NEW 会新建独立事务，嵌套事务不支持
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW, rollbackFor = Exception.class)
    public void logAuditLog(String operation) {
        // 即使外层事务回滚，这条日志也会成功
        auditLogMapper.insert(new AuditLogEntity());
    }
    
    // ==================== 只读 + 重试 ====================
    
    /**
     * ✅ 推荐：读操作加重试机制
     */
    @Transactional(readOnly = true)
    @Retryable(
        value = {OptimisticLockingFailureException.class},
        maxAttempts = 3,
        backoff = @Backoff(delay = 1000)
    )
    public MetadataEntity getMetadataWithRetry(String id) {
        return metadataMapper.selectById(id);
    }
    
    // ==================== 事务隔离级别 ====================
    
    /**
     * ✅ REPEATABLE_READ (PostgreSQL 默认)
     * 适用于需要一致读的场景
     */
    @Transactional(isolation = Isolation.REPEATABLE_READ)
    public void processConsistentRead() {
        // 业务逻辑
    }
    
    /**
     * ⚠️ READ_COMMITTED (默认)
     * 适用于高并发读多写少场景
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public void processHighConcurrencyRead() {
        // 业务逻辑
    }
}
```

### 4.3 分页管理规范

```java
/**
 * 分页查询最佳实践
 */
@Service
public class MetadataServicePagination {
    
    private final MetadataMapper metadataMapper;
    
    // ==================== 基础分页 ====================
    
    /**
     * ✅ 推荐：使用 Page 对象 (会自动转为物理分页)
     */
    @Transactional(readOnly = true)
    public Page<MetadataEntity> pageQuery(Integer page, Integer size, String name) {
        Page<MetadataEntity> pageParam = new Page<>(page, size);
        
        LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
        wrapper.like("name", name);
        
        return metadataMapper.selectPage(pageParam, wrapper);
    }
    
    // ==================== 排序分页 ====================
    
    /**
     * ✅ 推荐：带排序的分页
     * namespace 安全：用 enum 枚举限制排序字段
     */
    @Transactional(readOnly = true)
    public Page<MetadataDTO> pageQueryWithSort(
            Integer page, Integer size,
            SortField sortField, SortOrder sortOrder,
            String name) {
        
        // 验证 sortField (防止注入)
        Map<String, String> columnMap = Map.of(
            SortField.NAME.getValue(), "name",
            SortField.CREATED_AT.getValue(), "created_at",
            SortField.UPDATED_AT.getValue(), "updated_at"
        );
        String column = columnMap.getOrDefault(sortField.getValue(), "id");
        
        Page<MetadataDTO> pageParam = Page.of(page, size)
            .setOrder(ColumnOrder.valueOf(sortOrder), column);
        
        LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
        wrapper.like("name", name);
        // 注意：QueryWrapper 的 orderBy 会覆盖 Page 对象的 order
        // 如果 Page.setOrder() 已设置，则不要再在 Wrapper 用 orderBy
        // 或者反过来，选择一种方式下执行
        
        // 正确做法 1: 只用 Page 对象的 order (推荐)
        return metadataMapper.selectPage(pageParam, wrapper);
        
        // 正确做法 2: Wrapper 显式覆盖 (当需要复杂排序时)
        if (sortOrder == SortOrder.ASC) {
            wrapper.orderByAsc(column);
        } else {
            wrapper.orderByDesc(column);
        }
        return metadataMapper.selectPage(pageParam, wrapper);
    }
    
    // ==================== 大数据量分页 ====================
    
    /**
     * ⚠️ 深分页问题优化 (offset 很大时性能下降)
     */
    @Transactional(readOnly = true)
    public Page<MetadataEntity> pageQueryWithKeyset(Integer page, Integer size, String lastId) {
        // 使用 Keyset Pagination (键集分页)
        Page<MetadataEntity> pageParam = new Page<>(page, size);
        
        LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.isNotBlank(lastId)) {
            wrapper.gt("id", lastId); // 基于上一页最后一条 ID
        }
        wrapper.orderByAsc("id");
        
        return metadataMapper.selectPage(pageParam, wrapper);
    }
    
    // ==================== 自定义 Page (返回 DTO) ====================
    
    /**
     * ✅ 推荐：返回 DTO (隔离数据库表结构变化)
     */
    @Transactional(readOnly = true)
    public TableResult<MetadataDTO> pageQueryToDTO(
            Integer page, Integer size, String name) {
        
        Page<MetadataDTO> pageDTO = Page.of(page, size);
        
        LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
        wrapper.like("name", name);
        
        // 包装自定义分页 (MP 内部实现)
        Page<MetadataDTO> result = metadataMapper.selectPage(pageDTO, wrapper);
        
        return TableResult.builder()
                .code(200)
                .message("success")
                .data(result.getRecords())
                .total(result.getTotal())
                .page(result.getCurrent())
                .pageSize(result.getSize())
                .build();
    }
}
```

### 4.4 批量操作规范

```java
/**
 * 批量操作最佳实践
 */
@Service
public class MetadataServiceBatch {
    
    private static final int BATCH_SIZE = 500;
    
    // ==================== 批量插入 ====================
    
    /**
     * ✅ 推荐：分批插入 + 事务控制
     * 避免一次性插入过多导致事务过大、锁表时间长
     */
    @Transactional(rollbackFor = Exception.class)
    public void batchInsert(List<MetadataCreateDTO> dtos) {
        List<MetadataEntity> entities = DOUtils.toEntityList(dtos);
        
        // 分批处理 (每批 500 条)
        int size = entities.size();
        for (int i = 0; i < size; i += BATCH_SIZE) {
            int end = Math.min(i + BATCH_SIZE, size);
            List<MetadataEntity> batch = entities.subList(i, end);
            
            // 使用 expand=true 支持批量 VALUES
            metadataMapper.insertBatchSomeColumn(batch);
            
            log.info("Batch {}-{} inserted", i, end);
        }
    }
    
    // ==================== 批量更新 ====================
    
    /**
     * ✅ 推荐：分批更新 + 条件限制
     */
    @Transactional(rollbackFor = Exception.class)
    public void batchUpdate(List<MetadataUpdateDTO> dtos) {
        for (int i = 0; i < dtos.size(); i += BATCH_SIZE) {
            int end = Math.min(i + BATCH_SIZE, dtos.size());
            List<MetadataUpdateDTO> batch = dtos.subList(i, end);
            
            for (MetadataUpdateDTO dto : batch) {
                MetadataEntity entity = new MetadataEntity();
                entity.setId(dto.getId());
                entity.setName(dto.getName());
                entity.setMetadataType(dto.getMetadataType());
                entity.setProperties(dto.getProperties());
                
                // 注意：updateById 只更新非 NULL 字段
                metadataMapper.updateById(entity);
            }
        }
    }
    
    // ==================== 批量删除 ====================
    
    /**
     * ✅ 推荐：使用 removeByMap (物理删除效率高)
     */
    @Transactional(rollbackFor = Exception.class)
    public void batchDelete(List<String> ids) {
        // 软删除 (推荐)
        for (String id : ids) {
            MetadataEntity entity = new MetadataEntity();
            entity.setId(id);
            entity.setDeleted(1);
            metadataMapper.updateById(entity);
        }
        
        // 硬删除 (慎用 - 仅用于清理历史数据)
        // metadataMapper.deleteBatchIds(ids);
    }
    
    // ==================== 大数据量查询 ====================
    
    /**
     * ✅ 推荐：流式查询 (避免内存溢出)
     */
    @Transactional(readOnly = true)
    public void exportLargeDataset(Consumer<MetadataEntity> consumer) {
        try {
            // fetchSize=1000 表示每次从数据库拉取 1000 条
            List<MetadataEntity> list = metadataMapper.queryLargeDataset();
            
            for (MetadataEntity item : list) {
                consumer.accept(item);
                // 处理完一条就释放内存
            }
        } catch (Exception e) {
            log.error("Export failed", e);
            throw e;
        }
    }
    
    // ==================== 异常处理 ====================
    
    /**
     * ✅ 推荐：添加回滚逻辑
     */
    @Transactional(rollbackFor = Exception.class)
    public void batchInsertWithRollback(List<MetadataCreateDTO> dtos) {
        try {
            batchInsert(dtos);
        } catch (BatchInsertException e) {
            log.error("Batch insert failed", e);
            throw e;
        } catch (Exception e) {
            log.error("Unknown error", e);
            // 这里可以添加补偿逻辑 (如记录失败数据到错误表)
            recordFailedData(dtos);
            throw e;
        }
    }
}
```

### 4.5 工具类规范

```java
/**
 * 元数据查询工具类
 */
@Component
public class MetadataQueryUtil {
    
    /**
     * 构建通用查询条件
     */
    public static LambdaQueryWrapper<MetadataEntity> buildCommonQuery(
            String name, String type, String schemaId) {
        
        LambdaQueryWrapper<MetadataEntity> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq("deleted", 0); // 默认逻辑删除过滤
        
        if (StringUtils.isNotBlank(name)) {
            wrapper.and("name", MetaQueryConditionBuilder.getCondition(name));
        }
        
        if (StringUtils.isNotBlank(type)) {
            wrapper.eq("metadata_type", type);
        }
        
        if (StringUtils.isNotBlank(schemaId)) {
            wrapper.eq("schema_id", schemaId);
        }
        
        return wrapper;
    }
    
    /**
     * 条件构建器工厂模式 (支持复杂条件)
     */
    @Component
    public class MetaQueryConditionBuilder {
        
        public static Condition getConfigCondition(String name) {
            String[] parts = name.split(":");
            if (parts.length == 2) {
                return new Condition(parts[0], parts[1]);
            }
            return new Condition("eq", name);
        }
        
        @Data
        public static class Condition {
            public final String operator;
            public final String value;
        }
    }
}
```

---

## 代码示例

### 5.1 完整 CRUD 示例

```java
/**
 * 元数据管理完整业务示例
 */
@Service
@RequestMapping("/api/v1/metadata")
public class MetadataController {
    
    private final MetadataService metadataService;
    private final SchemaService schemaService;
    
    @PostMapping
    @Validated
    public ResponseEntity<MetadataDTO> create(@RequestBody @Valid MetadataCreateDTO createDTO) {
        MetadataEntity entity = DOUtils.toEntity(createDTO);
        metadataService.save(entity);
        return ResponseEntity.status(HttpStatus.CREATED)
                           .body(DOUtils.toDTO(entity));
    }
    
    @GetMapping("/{id}")
    @Transactional(readOnly = true)
    public ResponseEntity<MetadataDTO> get(@PathVariable String id) {
        MetadataEntity entity = metadataService.getById(id);
        if (entity == null) {
            return ResponseEntity.notFound().build();
        }
        // 关联查询 Schema 信息
        MetadataWithDataDTO dto = metadataService.getWithSchema(id);
        return ResponseEntity.ok(DOUtils.toDTO(dto));
    }
    
    @GetMapping
    public ResponseEntity<TableResult<MetadataDTO>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(required = false) String name,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String schemaId) {
        
        TableResult<MetadataDTO> result = metadataService.pageQuery(
                page, size, name, type, schemaId);
        return ResponseEntity.ok(result);
    }
    
    @PutMapping("/{id}")
    @Validated
    public ResponseEntity<MetadataDTO> update(
            @PathVariable String id,
            @RequestBody @Valid MetadataUpdateDTO updateDTO) {
        
        MetadataEntity entity = metadataService.getById(id);
        if (entity == null) {
            return ResponseEntity.notFound().build();
        }
        
        // 更新字段
        DOUtils.updateEntityById(entity, updateDTO);
        metadataService.updateById(entity);
        
        return ResponseEntity.ok(DOUtils.toDTO(entity));
    }
    
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable String id) {
        metadataService.removeById(id); // 软删除
        return ResponseEntity.noContent().build();
    }
}
```

### 5.2 MyBatis-Plus 插件配置

```yaml
# application.yml
spring:
  datasource:
    driver-class-name: org.postgresql.Driver
    url: jdbc:postgresql://localhost:5432/[项目数据库名]
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}

mybatis-plus:
  configuration:
    # 开启驼峰命名转换
    map-underscore-to-camel-case: true
    # 开启日志
    log-impl: org.apache.ibatis.logging.stdout.StdOutImpl
    # 缓存开启
    cache-enabled: true
  global-config:
    db-config:
      # 主键策略
      id-type: assign_id
      # 逻辑删除字段名
      logic-delete-field: deleted
      # 逻辑删除值 (已删除=1)
      logic-delete-value: 1
      # 逻辑未删除值 (未删除=0)
      logic-not-delete-value: 0
      # 通用填充字段 (自动填充策略)
      db-collect-strategy:
        created_by: insert
        created_at: insert
        updated_by: insert,update
        updated_at: insert,update
  extensions:
    # 分页插件配置
    pagination:
      count-page: true  # 是否进行 count 查询
      overflow: always  # 始终查询
      reasonable: false # 分页流式处理
      default-limit: 1000 # 最大单页容量 (性能保护)
  mapper-locations: classpath*:mapper/*.xml
  type-handlers-package: com.[公司域名].[项目缩写].handler
```

**配置类**

```java
@Configuration
public class MybatisPlusConfig {
    
    /**
     * 分页插件配置 (Spring Boot 3.x)
     */
    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        
        // 分页插件 (必须第一个)
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.POSTGRE_SQL));
        
        // 优化插件 (二级缓存清理)
        interceptor.addInnerInterceptor(new CacheInterceptor());
        
        // 性能分析插件 (开发环境使用)
        if (PropertiesUtils.isDev()) {
            interceptor.addInnerInterceptor(new PerformanceInterceptor());
        }
        
        // 乐观锁插件
        interceptor.addInnerInterceptor(new OptimisticLockerInterceptor());
        
        return interceptor;
    }
    
    /**
     * 自动填充处理器 (解决审计字段)
     */
    @Bean
    public MetaObjectHandler metaObjectHandler() {
        return new UserMetaObjectHandler();
    }
    
    /**
     * PostgreSQL 类型处理器注册
     */
    @Bean
    public SqlSessionFactory sqlSessionFactory(DataSource dataSource) throws Exception {
        MybatisPlusbatisSqlSessionFactoryBean factoryBean = new MybatisPlusbatisSqlSessionFactoryBean();
        factoryBean.setDataSource(dataSource);
        
        // 注册自定义类型处理器
        TypeHandlerRegistry registry = factoryBean.getTypeHandlerRegistry();
        registry.register(Object.class, FlattenedJsonbTypeHandler.class);
        registry.register(UUID.class, UUIDTypeHandler.class);
        
        // PostgreSQL 驱动特定配置
        Properties properties = new Properties();
        properties.setProperty("jdbcType", "OTHER"); // JSONB 的 JDBC 类型
        properties.setProperty("columnType", "11111"); // JSONB OID
        registry.register("org.postgresql.util.PGobject", 
                        MappingTypeHandler.class, 
                        PlancdownJsonbTypeHandler.class, 
                        properties);
        
        // 配置 Mapper 位置
        factoryBean.setMapperLocations(
            new PathMatchingResourcePatternResolver()
                .getResources("classpath*:mapper/*.xml"));
        
        // 配置 TypeHandlers
        factoryBean.setTypeHandlerPackage("com.[公司域名].[项目缩写].handler");
        
        return factoryBean.getObject();
    }
}

/**
 * 用户信息自动填充处理器
 */
@Component
public class UserMetaObjectHandler implements MetaObjectHandler {
    
    @Value("${app.user.open-id}")
    private String currentUserId;
    
    @Override
    public void insertFill(MetaObject metaObject) {
        if (StringUtils.isNotEmpty(currentUserId)) {
            strictInsertFill(metaObject, "createdBy", String.class, currentUserId);
            strictInsertFill(metaObject, "createdBy", String.class, currentUserId);
            strictInsertFill(metaObject, "createdAt", LocalDateTime.class, LocalDateTime.now());
        }
    }
    
    @Override
    public void updateFill(MetaObject metaObject) {
        if (StringUtils.isNotEmpty(currentUserId)) {
            strictUpdateFill(metaObject, "updatedBy", String.class, currentUserId);
            strictUpdateFill(metaObject, "updatedAt", LocalDateTime.class, LocalDateTime.now());
        }
    }
}
```

---

## 常见问题

### 6.1 JSONB 查询性能问题

**问题**: JSONB 字段查询性能差

**解决**:
```sql
-- ❌ 错误: 不使用索引
SELECT * FROM metadata WHERE properties @> '{"description": "test"}';

-- ✅ 正确: 使用 GIN 索引 + 包含查询
CREATE INDEX idx_metadata_properties ON metadata USING GIN (properties);
SELECT * FROM metadata WHERE properties @> '{"status": "active"}';
```

### 6.2 UUID 查询慢

**问题**: UUID 作为主键查询性能差

**解决**:
```sql
-- ✅ 使用 PostgreSQL 的 pg_vector 扩展 (推荐 v15+)
CREATE EXTENSION IF NOT EXISTS pgvector;
ALTER TABLE metadata ADD COLUMN id_embedding vector(1536);

-- 使用 HNSW 索引
CREATE INDEX idx_metadata_embedding ON metadata USING HNSW (id_embedding vector_cosine_ops);

-- 相似度搜索
SELECT * FROM metadata 
ORDER BY id_embedding <=> (SELECT id_embedding FROM metadata WHERE name='test') 
LIMIT 10;
```

### 6.3 软删除后数据恢复

**问题**: 误删数据如何恢复

**解决**:
```java
@Service
public class MetadataRecoveryService {
    
    @Autowired
    private MetadataMapper metadataMapper;
    
    /**
     * 恢复已删除数据 (硬查询)
     */
    @Transactional(rollbackFor = Exception.class)
    public void recoverDeletedData(List<String> ids) {
        Map<String, Object> map = new HashMap<>();
        map.put("deleted", 1);
        map.put("id", ids);
        
        LambdaUpdateWrapper<MetadataEntity> wrapper = new LambdaUpdateWrapper<>();
        wrapper.in("id", ids)
              .set("deleted", 0)
              .eq("deleted", 1);
        
        metadataMapper.update(null, wrapper);
    }
}
```

### 6.4 批量插入 ID 生成

**问题**: 批量插入时 ID 如何生成

**解决**:
```java
/**
 * ID 生成策略 (雪花算法 + UUID 混合)
 */
@Component
public class CompositeIdGenerator implements IdentifierGenerator {
    
    private final IdWorker idWorker = new IdWorker(-1L);
    
    @Override
    public Number nextId(Object object) {
        MetadataEntity entity = (MetadataEntity) object;
        
        if (StringUtils.isBlank(entity.getId())) {
            // 选择策略: 简单用雪花算法
            return idWorker.nextId();
        }
        
        return Long.parseLong(entity.getId());
    }
}
```

---

## 附录

### A1. 参考文档

- [MyBatis-Plus 官方文档](https://baomidou.com/)
- [PostgreSQL 官方文档](https://www.postgresql.org/docs/)
- [Spring Boot 3.x 官方参考](https://docs.spring.io/spring-boot/docs/current/reference/html/)

### A2. 版本演进记录

| 版本 | 日期 | 变更 | 作者 |
|------|------|------|------|
| v1.0 | 2026-04-01 | 初始版本 | [规范作者] |

---

*本文档由[规范作者]于 2026-04-01 编写，欢迎基于本文档进行技术分享和扩展*
