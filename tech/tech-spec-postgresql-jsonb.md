---
title: PostgreSQL + JSONB 使用规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 最后更新: 2026-04-01 1. [核心原则](#核心原则)
---

# PostgreSQL + JSONB 使用规范

> **版本**: v1.0  
> **作者**: [规范作者]  
> **最后更新**: 2026-04-01  
> **状态**: ✅ 已评审

---

## 📋 目录

1. [核心原则](#核心原则)
2. [元数据模型设计](#元数据模型设计)
3. [JSONB 基础规范](#jsonb 基础规范)
4. [索引优化策略](#索引优化策略)
5. [查询最佳实践](#查询最佳实践)
6. [常见问题与解决方案](#常见问题与解决方案)
7. [性能基准测试](#性能基准测试)

---

## 核心原则

### 1.1 设计理念

- **结构规范化**: JSONB 存储的内容应有明确 Schema 定义 (JSON Schema)
- **索引优先**: 频繁查询的 JSONB 字段必须建立 GIN 或 GIST 索引
- **类型明确**: 避免过度使用 JSONB，优先使用原生 PostgreSQL 类型
- **性能可控**: 大数据量场景必须评估 GIN 索引的存储开销

### 1.2 技术选型决策树

```
是否需要存储结构化数据？
│
├─ No → 使用 TEXT 或 BYTEA
│
└─ Yes → 是否频繁查询 JSONB 内部字段？
   │
   ├─ No → 使用 JSONB (仅需存储 + 整体读取)
   │
   └─ Yes → 查询频率如何？
      │
      ├─ 低频 (< 10% 的查询) → JSONB + GIN 索引
      │
      ├─ 中频 (10%-50% 的查询) → JSONB + GIN 索引 + 部分字段冗余为普通列
      │
      └─ 高频 (> 50% 的查询) → 拆分到独立表或使用原生列
```

### 1.3 数据量边界

| 场景 | 建议 | 备注 |
|------|------|------|
| 小表 (< 100 万行) | 可使用 JSONB + GIN | GIN 索引占用约原始数据 30% |
| 中表 (100 万 -1000 万) | JSONB + GIN + 部分冗余 | 需监控索引大小 |
| 大表 (> 1000 万) | 拆分 + 分区 | 避免单表过大 |

---

## 元数据模型设计

### 2.1 核心元数据表

```sql
-- 元数据主表 (存储基础信息)
CREATE TABLE metadata (
    -- 主键 (使用 UUID，支持分布式)
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 基础信息 (原生字段，高频查询)
    name                VARCHAR(255) NOT NULL,
    metadata_type       VARCHAR(50) NOT NULL,
    schema_id           UUID,
    
    -- 扩展属性 (JSONB，存储动态字段)
    properties          JSONB DEFAULT '{}'::jsonb,
    
    -- 审计字段
    created_by          UUID NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by          UUID,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 软删除
    deleted             SMALLINT DEFAULT 0 NOT NULL CHECK (deleted IN (0, 1)),
    
    -- 约束
    CONSTRAINT chk_metadata_type CHECK (metadata_type IN ('TABLE', 'VIEW', 'INDEX', 'FUNCTION', 'TRIGGER', 'MATERIALIZED_VIEW')),
    CONSTRAINT idx_metadata_name_schema UNIQUE (name, schema_id)
);

-- Schema 主表
CREATE TABLE schema_def (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,
    version         VARCHAR(50) NOT NULL,
    properties      JSONB,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted         SMALLINT DEFAULT 0 NOT NULL CHECK (deleted IN (0, 1)),
    CONSTRAINT uq_schema_name_version UNIQUE (name, version, deleted)
);

-- 元数据索引表 (显式存储索引定义)
CREATE TABLE metadata_index (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,
    metadata_id     UUID NOT NULL REFERENCES metadata(id) ON DELETE CASCADE,
    
    -- GIN 索引覆盖的 JSONB 路径 (用于索引覆盖优化)
    index_paths     TEXT[],
    index_type      VARCHAR(20) DEFAULT 'GIN',
    
    -- 索引统计信息 (定期同步)
    index_size      BIGINT,
    index_usage_count BIGINT DEFAULT 0,
    
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted         SMALLINT DEFAULT 0 NOT NULL CHECK (deleted IN (0, 1)),
    
    CONSTRAINT uq_metadata_index_name UNIQUE (metadata_id, name)
);

-- 元数据属性字典 (校验 JSONB 结构)
CREATE TABLE metadata_property_dict (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metadata_type   VARCHAR(50) NOT NULL,
    property_path   VARCHAR(255) NOT NULL, -- JSON 路径，如 $.description
    property_type   VARCHAR(50) NOT NULL,  -- STRING, NUMBER, BOOLEAN, ARRAY, OBJECT
    required        BOOLEAN DEFAULT FALSE,
    default_value   JSONB,
    description     TEXT,
    validation_rule TEXT, -- JSON Schema 片段
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_property_path UNIQUE (metadata_type, property_path)
);
```

### 2.2 分区表设计 (大数据量场景)

```sql
-- 使用声明式分区 (PostgreSQL 10+)
CREATE TABLE metadata_partitioned (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,
    metadata_type   VARCHAR(50) NOT NULL,
    properties      JSONB DEFAULT '{}'::jsonb,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted         SMALLINT DEFAULT 0 NOT NULL CHECK (deleted IN (0, 1))
) PARTITION BY RANGE (created_at);

-- 按月分区 (保留 24 个月数据)
CREATE TABLE metadata_2026_01 PARTITION OF metadata_partitioned
    FOR VALUES FROM ('2026-01-01' TO '2026-02-01');

CREATE TABLE metadata_2026_02 PARTITION OF metadata_partitioned
    FOR VALUES FROM ('2026-02-01' TO '2026-03-01');

-- 归档分区 (历史数据只读压缩)
CREATE TABLE metadata_archive (
    id              UUID PRIMARY KEY,
    name            VARCHAR(255),
    properties      JSONB,
    created_at      TIMESTAMP WITH TIME ZONE
);
```

### 2.3 JSON Schema 定义

```json
/**
 * 元数据属性 JSON Schema (示例：TABLE 类型)
 */
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://[公司域名]/[项目缩写]/metadata/table.schema.json",
  "title": "Table Metadata Properties",
  "description": "数据表的元数据属性定义",
  "type": "object",
  "properties": {
    "description": {
      "type": "string",
      "description": "数据表描述",
      "maxLength": 2000
    },
    "owner": {
      "type": "string",
      "description": "表所有者 ID"
    },
    "columns": {
      "type": "array",
      "description": "列定义数组",
      "items": {
        "$ref": "#/definitions/columnDefinition"
      }
    },
    "indexes": {
      "type": "array",
      "description": "索引定义数组",
      "items": {
        "$ref": "#/definitions/indexDefinition"
      }
    },
    "foreignKeys": {
      "type": "array",
      "description": "外键定义数组",
      "items": {
        "$ref": "#/definitions/foreignKeyDefinition"
      }
    },
    "partitionStrategy": {
      "type": "string",
      "description": "分区策略",
      "enum": ["RANGE", "LIST", "HASH", "NONE"]
    },
    "statistics": {
      "type": "object",
      "description": "统计信息",
      "properties": {
        "rowCount": {
          "type": "integer",
          "minimum": 0
        },
        "sizeBytes": {
          "type": "integer",
          "minimum": 0
        },
        "lastAnalyzedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "tags": {
      "type": "array",
      "description": "标签数组",
      "items": {
        "type": "string"
      },
      "maxItems": 50
    },
    "customProperties": {
      "type": "object",
      "description": "自定义扩展属性",
      "additionalProperties": true
    }
  },
  "required": ["description", "columns"],
  "additionalProperties": true,
  "definitions": {
    "columnDefinition": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string",
          "description": "列名"
        },
        "dataType": {
          "type": "string",
          "description": "数据类型",
          "enum": ["VARCHAR", "INTEGER", "BIGINT", "TIMESTAMP", "BOOLEAN", "JSONB", "UUID"]
        },
        "nullable": {
          "type": "boolean",
          "default": true
        },
        "defaultValue": {
          "description": "默认值 (JSONB 支持任意类型)"
        },
        "description": {
          "type": "string"
        }
      },
      "required": ["name", "dataType"]
    },
    "indexDefinition": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        },
        "columns": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "name": {"type": "string"},
              "order": {"type": "string", "enum": ["ASC", "DESC"]}
            }
          }
        },
        "indexType": {
          "type": "string",
          "enum": ["btree", "hash", "gin", "gist", "brin", "spgist"]
        },
        "isUnique": {
          "type": "boolean",
          "default": false
        }
      },
      "required": ["name", "columns"]
    },
    "foreignKeyDefinition": {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "columns": {
          "type": "array",
          "items": {"type": "string"}
        },
        "referencedTable": {"type": "string"},
        "referencedColumns": {
          "type": "array",
          "items": {"type": "string"}
        },
        "onDelete": {
          "type": "string",
          "enum": ["CASCADE", "RESTRICT", "SET NULL", "SET DEFAULT"]
        },
        "onUpdate": {
          "type": "string",
          "enum": ["CASCADE", "RESTRICT", "SET NULL", "SET DEFAULT"]
        }
      },
      "required": ["name", "columns", "referencedTable"]
    }
  }
}
```

---

## JSONB 基础规范

### 3.1 字段类型选择

```java
/**
 * PostgreSQL JSONB 类型在 Java 中的映射
 */
public class JsonbTypeMappings {
    
    // ==================== 推荐映射 ====================
    
    /**
     * ✅ 推荐：使用 Jackson's ObjectNode (可序列化 JSONB)
     * 优势：支持类型校验、自动转换
     */
    @TableField(typeHandler = FlattenedJsonbTypeHandler.class)
    private ObjectNode properties;
    
    /**
     * ✅ 推荐：使用 org.postgresql.util.PGobject (原生映射)
     * 优势：直接存为 PG JSONB 二进制
     */
    @TableField(typeHandler = PgObjectHandler.class)
    private PGobject properties;
    
    /**
     * ✅ 推荐：使用 Map<String, Object> + Jackson
     * 优势：灵活处理动态字段
     */
    @TableField(typeHandler = JsonObjectHandler.class)
    private Map<String, Object> properties;
    
    /**
     * ✅ 推荐：自定义 DTO + Jackson
     * 优势：强类型校验
     */
    @TableField(typeHandler = FlattenedJsonbTypeHandler.class)
    private MetadataPropertiesDTO properties;
    
    // ==================== 不推荐映射 ====================
    
    /**
     * ❌ 不推荐：字符串 (避免手动 JSON 序列化)
     */
    private String properties;
    
    /**
     * ❌ 不推荐：byte[] (难以调试)
     */
    private byte[] properties;
}
```

### 3.2 类型处理器 (Type Handler)

```java
/**
 * FlattenedJsonbTypeHandler - 将 Java 对象转为 PostgreSQL JSONB
 * https://github.com/gtnelson/hibernate-types/blob/main/hibernate-types-postgres/src/main/java/org/hibernate/bytecode/types/Types/JsonbType.java
 */
public class FlattenedJsonbTypeHandler extends BaseTypeHandler<JsonNode> {
    
    private static final ObjectMapper MAPPER = new ObjectMapper();
    
    @Override
    public void setNonNullParameter(PreparedStatement ps, int i, JsonNode parameter, JdbcType jdbcType) throws SQLException {
        if (parameter == null) {
            ps.setObject(i, null, Types.OTHER);
            return;
        }
        
        PGobject obj = new PGobject();
        obj.setType("jsonb");
        try {
            obj.setValue(MAPPER.writeValueAsString(parameter));
        } catch (JsonProcessingException e) {
            throw new SQLException("Failed to serialize JSON", e);
        }
        ps.setObject(i, obj, Types.OTHER);
    }
    
    @Override
    public JsonNode getNullableResult(ResultSet rs, String columnName) throws SQLException {
        PGobject obj = (PGobject) rs.getObject(columnName);
        if (obj == null) {
            return null;
        }
        try {
            return MAPPER.readTree(obj.getValue());
        } catch (JsonProcessingException e) {
            throw new SQLException("Failed to parse JSON", e);
        }
    }
    
    @Override
    public JsonNode getNullableResult(ResultSet rs, int columnIndex) throws SQLException {
        return getNullableResult(rs, columnName(columnIndex, rs));
    }
    
    @Override
    public JsonNode getNullableResult(PreparedStatement ps, int columnIndex) throws SQLException {
        return getNullableResult(ps, columnName(columnIndex, ps));
    }
    
    private String columnName(int columnIndex, ResultSet rs) throws SQLException {
        return rs.getMetaData().getColumnName(columnIndex);
    }
    
    private String columnName(int columnIndex, PreparedStatement ps) {
        return "column" + columnIndex;
    }
}
```

### 3.3 MyBatis-Plus JSONB 配置

```java
/**
 * MyBatis-Plus + JSONB 整合配置
 */
@Configuration
public class JsonbExtensionConfig {
    
    /**
     * 注册全局 JSONB 类型处理器
     */
    @Bean
    public SqlSessionFactory sqlSessionFactory(DataSource dataSource) throws Exception {
        MybatisPlusbatisSqlSessionFactoryBean factoryBean = new MybatisPlusbatisSqlSessionFactoryBean();
        factoryBean.setDataSource(dataSource);
        
        // JSONB 处理器 (Object → JSONB)
        TypeHandlerRegistry registry = factoryBean.getTypeHandlerRegistry();
        registry.register(Object.class, FlattenedJsonbTypeHandler.class);
        registry.register(JsonNode.class, FlattenedJsonbTypeHandler.class);
        registry.register(String.class, FlattenedJsonbTypeHandler.class);
        
        // 数组处理器
        registry.register(List.class, PgArrayHandler.class);
        registry.register(Map.class, JsonObjectHandler.class);
        
        return factoryBean.getObject();
    }
    
    /**
     * MP 全局配置 (启用 JSONB 支持)
     */
    @Bean
    public GlobalConfigurationCustomizer globalConfigurationCustomizer() {
        return config -> {
            config.getDbConfig().setTablePrefix("t_");
            // 启用元数据缓存
            config.setMetaObjectHandler(metaObjectHandler());
        };
    }
}
```

---

## 索引优化策略

### 4.1 GIN 索引 (JSONB 首选)

```sql
-- ==================== 基础 GIN 索引 ====================

/**
 * GIN 索引类型选择 (PostgreSQL 14+)
 */

-- ✅ 默认：包含索引 (支持包含查询和成员查询)
CREATE INDEX idx_metadata_properties ON metadata USING GIN (properties);

-- ✅ 优化：jsonb_path_ops (只支持 @?, @> 操作符，空间更小)
CREATE INDEX idx_metadata_properties_path_ops ON metadata USING GIN (properties jsonb_path_ops);

-- ✅ 优化：jsonb_ops (支持全部操作符，性能略低)
CREATE INDEX idx_metadata_properties_jsonb_ops ON metadata USING GIN (properties jsonb_ops);

-- ==================== 索引表达式 (针对嵌套字段) ====================

/**
 * 表达式索引 (支持 . 路径查询 + 包含查询)
 */

-- 嵌套字段：$.description (指字符串值)
CREATE INDEX idx_metadata_properties_description ON metadata USING GIN ((properties->>'description'));

-- 嵌套对象：$.statistics (指整个对象)
CREATE INDEX idx_metadata_properties_statistics ON metadata USING GIN ((properties->'statistics'));

-- 数组元素 (支持 ANY / ALL 查询)
CREATE INDEX idx_metadata_properties_tags ON metadata USING GIN ((properties->' tags));

-- ==================== 部分索引 (减少索引体积) ====================

/**
 * 仅索引特定 metadata_type 的数据 (减少 GIN 索引开销)
 */
CREATE INDEX idx_metadata_table_properties ON metadata 
    USES GIN (properties)
    WHERE metadata_type = 'TABLE';

CREATE INDEX idx_metadata_function_properties ON metadata 
    USING GIN (properties)
    WHERE metadata_type = 'FUNCTION';

-- ==================== 组合索引 ====================

/**
 * 外表字段 + 内部 JSONB 字段的复合索引
 */
CREATE INDEX idx_metadata_type_properties ON metadata 
    USING GIN (metadata_type, properties);

-- 表达式 + GIN 组合
CREATE INDEX idx_metadata_type_description ON metadata 
    USING GIN ((metadata_type), (properties->>'description'));
```

### 4.2 其他索引类型

```sql
-- ==================== B-Tree 索引 (用于范围查询) ====================

/**
 * 当只查询 JSONB 的简单字段时，B-Tree 比 GIN 更快
 */
CREATE INDEX idx_metadata_properties_owner ON metadata 
    USING BTREE ((properties->>'owner'));

创造索引 idx_metadata_stats_rowcount ON metadata
    USING BTREE ((properties#>'{statistics,rowCount}'::int));

-- ==================== BRIN 索引 (用于大数据量分区表) ====================

/**
 * 数据按 created_at 分区，BRIN 索引极小 (约原始数据 0.1%)
 */
CREATE INDEX idx_metadata_partitioned_created_at ON metadata_partitioned
    USING BRIN (created_at);

CREATE INDEX idx_metadata_partitioned_stats ON metadata_partitioned
    USING BRIN ((properties#>'{statistics}'::jsonb));

-- ==================== GIST 索引 (全文检索) ====================

/**
 * 使用 pg_trgm 扩展进行模糊搜索
 */
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_metadata_properties_trgm ON metadata
    USING GIN (properties jsonb_trgm_ops);
```

### 4.3 索引维护策略

```sql
-- ==================== 索引统计信息收集 ====================

/**
 * 定期分析索引使用情况
 */
ANALYZE metadata;

-- 查询索引使用统计
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,      -- 索引扫描次数
    idx_tup_read,  -- 读取行数
    idx_tup_fetch  -- 获取行数
FROM 
    pg_stat_user_indexes
WHERE 
    tablename = 'metadata'
ORDER BY 
    idx_scan DESC;

-- ==================== 索引重建 ====================

/**
 * 定期 REINDEX 优化碎片
 */
REINDEX INDEX CONCURRENTLY idx_metadata_properties;

-- 批量重建所有索引 (维护窗口)
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT indexname, schemaname 
        FROM pg_indexes 
        WHERE tablename = 'metadata'
    LOOP
        EXECUTE format('REINDEX INDEX CONCURRENTLY %I.%I', rec.schemaname, rec.indexname);
        RAISE NOTICE 'Reindexed: %', rec.indexname;
    END LOOP;
END $$;

-- ==================== 索引删除策略 ====================

/**
 * 删除未使用的索引 (基于 pg_stat_user_indexes)
 */
DO $$
DECLARE
    unused_idx RECORD;
BEGIN
    FOR unused_idx IN 
        SELECT indexname
        FROM pg_stat_user_indexes
        WHERE tablename = 'metadata'
          AND idx_scan < 10  -- 使用次数极少
          AND indexname NOT LIKE 'pkey%'  -- 保留主键
    LOOP
        -- 仅记录，不要自动删除
        RAISE NOTICE 'Consider dropping: % (scans: %)', 
            unused_idx.indexname,
            (SELECT idx_scan FROM pg_stat_user_indexes 
             WHERE indexname = unused_idx.indexname);
    END LOOP;
END $$;
```

---

## 查询最佳实践

### 5.1 基础查询

```java
/**
 * MyBatis-Plus JSONB 查询示例
 */
public interface MetadataDao {
    
    // ==================== 包含查询 (@>) ====================
    
    /**
     * 查询 properties 包含指定对象
     * SQL: WHERE properties @> '{"description": "test"}'
     */
    List<MetadataEntity> queryByPropertiesContain(Map<String, Object> properties);
    
    // ==================== 存在查询 (?) ====================
    
    /**
     * 查询 properties 包含某个键
     * SQL: WHERE properties ? 'description'
     */
    List<MetadataEntity> queryByPropertyExists(String propertyName);
    
    // ==================== 相等查询 (=) ====================
    
    /**
     * 查询 JSONB 字段等于指定值
     * SQL: WHERE properties->>'description' = 'test'
     */
    List<MetadataEntity> queryByPropertyValue(String propertyName, String value);
    
    // ==================== 模糊查询 (LIKE) ====================
    
    /**
     * 查询 JSONB 中包含关键字
     * SQL: WHERE properties #>>'{"statistics","description"}' ILIKE '%test%'
     */
    List<MetadataEntity> queryByPropertyValueLike(String path, String keyword);
}
```

### 5.2 复杂查询场景

```xml
<!-- metadata-mapper.jsonb.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" 
    "http://mybatis.org/dtd/mybatis-3-mapper.dtd">

<mapper namespace="com.[公司域名].[项目缩写].metadata.dao.MetadataJsonbDao">
    
    <!-- ==================== 包含查询 ==================== -->
    
    <select id="queryByPropertiesContain" 
            resultType="com.[公司域名].[项目缩写].metadata.entity.MetadataEntity">
        SELECT * FROM metadata
        WHERE deleted = 0
        AND properties @> #{properties::jsonb}
        <if test="limit != null">
            LIMIT #{limit}
        </if>
    </select>
    
    <!-- ==================== 数组包含查询 ==================== -->
    
    <select id="queryByArrayContains" 
            resultType="com.[公司域名].[项目缩写].metadata.entity.MetadataEntity">
        SELECT * FROM metadata
        WHERE deleted = 0
        AND properties->'tags' @> #{tags::jsonb}
    </select>
    
    <!-- ==================== 嵌套对象查询 ==================== -->
    
    <select id="queryByNestedObject" 
            resultType="com.[公司域名].[项目缩写].metadata.entity.MetadataEntity">
        SELECT 
            id,
            name,
            properties,
            properties#>'{statistics}'::jsonb as stats,
            properties#>'{statistics,rowCount}':' #>'{statistics,size}'",
            properties #>'{statistics,rowCount}'::int 
                  as row_count,
            properties #>'{statistics}' ::jsonb ->> 'size'
                  as size_bytes
        FROM metadata
        WHERE deleted = 0
          AND properties #>'{statistics}'::jsonb @> #{statsFilter::jsonb}
    </select>
    
    <!-- ==================== 多条件组合查询 ==================== -->
    
    <select id="queryMultiCondition" 
            resultType="com.[公司域名].[项目缩写].metadata.entity.MetadataEntity">
        SELECT * FROM metadata
        WHERE deleted = 0
        <if test="name != null">
            AND name #{name}
        </if>
        <if test="metadataType != null">
            AND metadata_type = #{metadataType}
        </if>
        <if test="tag != null">
            AND properties->'tags' ? #{tag}
        </if>
        <if test="description != null">
            AND properties->>'description' ILIKE CONCAT('%', #{description}, '%')
        </if>
        <if test="owner != null">
            AND properties->>'owner' = #{owner}
        </if>
        ORDER BY created_at DESC
        LIMIT 100
    </select>
    
    <!-- ==================== JSONB 聚合查询 ==================== -->
    
    <select id="aggregateByProperty" resultType="map">
        SELECT 
            properties->>'metadataType' as type,
            COUNT(*) as count,
            ROUND(AVG((properties #>'{statistics,rowCount})'::numeric), 2) as avg_rows,
            SUM((properties #>'{statistics,size}') ::integer) as total_size_bytes
        FROM metadata
        WHERE deleted = 0
        GROUP BY 1
        HAVING COUNT(*) &gt; #{minCount}
    </select>
    
    <!-- ==================== 全文检索 (pg_trgm) ==================== -->
    
    <select id="fullTextSearch" 
            resultType="com.[公司域名].[项目缩写].metadata.entity.MetadataEntity">
        SELECT 
            id, name, properties,
            similarity(properties::text, #{keyword}) as similarity_score
        FROM metadata
        WHERE deleted = 0
          AND properties::text % #{keyword}  -- trgm 相似度匹配
        ORDER BY similarity_score DESC
        LIMIT 50
    </select>
    
    <!-- ==================== 使用 jsonb_paths (PostgreSQL 14+) ==================== -->
    
    <select id="queryByJsonPath" 
            resultType="com.[公司域名].[项目缩写].metadata.entity.MetadataEntity">
        SELECT * FROM metadata
        WHERE deleted = 0
          AND properties @@ '$.description ? (@ .value == "test")'
    </select>
    
    <!-- ==================== JSONB 数组索引查询 ==================== -->
    
    <select id="queryByArrayElement" 
            resultType="com.[公司域名].[项目缩写].metadata.entity.MetadataEntity">
        SELECT * FROM metadata
        WHERE deleted = 0
          AND EXISTS (
            SELECT 1 FROM jsonb_array_elements(properties->'columns') col
            WHERE col->>'name' = #{columnName}
          )
    </select>
</mapper>
```

### 5.3 MyBatis-Plus 查询构建

```java
/**
 * JSONB 查询构建器 (使用查询包装器)
 */
public class JsonbQueryStrategy {
    
    /**
     * 包含查询 (IN)
     */
    public static LambdaQueryWrapper<MetadataEntity> propertiesContains(
            LambdaQueryWrapper<MetadataEntity> wrapper, Map<String, Object> properties) {
        
        wrapper.apply("properties @> #{properties::jsonb}", properties);
        return wrapper;
    }
    
    /**
     * 数组包含 (ANY)
     */
    public static LambdaQueryWrapper<MetadataEntity> arrayContains(
            LambdaQueryWrapper<MetadataEntity> wrapper, String path, List<String> values) {
        
        JsonArray jsonValues = new JsonArray();
        values.forEach(jsonValues::add);
        
        wrapper.apply("properties->>{path} {@values::jsonb}", path, jsonValues);
        return wrapper;
    }
    
    /**
     * 嵌套字段不存在 (NOT ? EXISTS)
     */
    public static LambdaQueryWrapper<MetadataEntity> propertyNotExists(
            LambdaQueryWrapper<MetadataEntity> wrapper, String path) {
        
        wrapper.notLike("properties", path.contains(".") ? path.replace(".", ",") : path);
        return wrapper;
    }
    
    /**
     * JSONB 字段为空 (eq NULL)
     */
    public static LambdaQueryWrapper<MetadataEntity> propertyIsNull(
            LambdaQueryWrapper<MetadataEntity> wrapper, String path) {
        
        if (path.contains(".")) {
            path = path.replace(".", ",");
            wrapper.isNull("properties #>" + path);
        } else {
            wrapper.isNull("properties->>" + path);
        }
        return wrapper;
    }
}
```

---

## 常见问题与解决方案

### 6.1 问题：JSONB 查询慢

**症状**:
```sql
-- 执行计划显示 Seq Scan (顺序扫描)
EXPLAIN ANALYZE SELECT * FROM metadata WHERE properties @> '{"status": "active"}';
```

**解决方案**:
```sql
-- 1. 确认索引存在
SELECT indexname FROM pg_indexes WHERE tablename = 'metadata';

-- 2. 强制使用索引
SET enable_seqscan = off;
EXPLAIN ANALYZE SELECT * FROM metadata WHERE properties @> '{"status": "active"}';

-- 3. 收集统计信息
ANALYZE metadata;

-- 4. 如仍慢，考虑(jsonb_path_ops (性能更好，但功能受限制)
CREATE INDEX idx_metadata_properties_fast ON metadata USING GIN (properties jsonb_path_ops);
```

### 6.2 问题：UPDATE JSONB 导致锁表

**症状**:
```java
// 批量更新导致长事务，锁表时间过长
for (MetadataEntity item : list) {
    metadataMapper.updateById(item); // 10000 次更新
}
```

**解决方案**:
```java
// ✅ 方案 1: 使用 UPSERT 批量更新
@Transactional
public void batchUpdateOptimized(List<MetadataEntity> entities) {
    for (int i = 0; i < entities.size(); i += 500) {
        int end = Math.min(i + 500, entities.size());
        List<MetadataEntity> batch = entities.subList(i, end);
        
        // 使用 JSONB 的 JSON_MERGE_PATCH (PostgreSQL 9.5+)
        jdbcTemplate.batchUpdate(
            "UPDATE metadata SET properties = properties || #{1} WHERE id = #{2}",
            batch
        );
    }
}

// ✅ 方案 2: 使用 RETURNING 批量返回
public List<MetadataEntity> updateAndReturn(List<UpdateRequest> requests) {
    List<MetadataEntity> result = new ArrayList<>();
    
    for (UpdateRequest req : requests) {
        jdbcTemplate.update(
            "UPDATE metadata SET properties = properties || :properties WHERE id = :id RETURNING *",
            (ps) -> {
                ps.setObject(1, new PGobject().fromJson(req.getPropertiesJson()));
                ps.setUUID(2, req.getId());
            },
            (rs) -> {
                MetadataEntity entity = toEntity(rs);
                result.add(entity);
                return true;
            }
        );
    }
    
    return result;
}
```

### 6.3 问题：JSONB 存储过大

**症状**:
```sql
SELECT pg_size_pretty(pg_table_size('metadata'));  -- 10GB
SELECT pg_size_pretty(pg_relation_size('idx_metadata_properties'));  -- 3GB 索引
```

**解决方案**:
```sql
-- 1. 压缩 JSONB
CREATE INDEX idx_metadata_properties_compressed ON metadata 
    USING GIN (to_jsonb(jsonb_strip_nulls(properties)));

-- 2. 将大字段分离到扩展表
CREATE TABLE metadata_properties_ext (
    metadata_id UUID PRIMARY KEY REFERENCES metadata(id) ON DELETE CASCADE,
    properties JSONB
);

-- 迁移大 JSONB 到扩展表
INSERT INTO metadata_properties_ext (metadata_id, properties)
SELECT id, properties 
FROM metadata 
WHERE pg_size_bytes(properties) > 10240; -- > 10KB

-- 更新主表，只保留小规模 JSONB
UPDATE metadata 
SET properties = '{}'::jsonb
WHERE pg_size_bytes(properties) > 10240;

-- 3. 使用分区表
-- (参考 2.2 章)
```

### 6.4 问题：JSONB 类型转换失败

**症状**:
```
Exception: ERROR: invalid input syntax for type json
```

**解决方案**:
```java
/**
 * 安全的 JSONB 转换工具
 */
@Component
public class JsonbUtils {
    
    private static final ObjectMapper MAPPER = new ObjectMapper();
    
    /**
     * 安全转换 (处理特殊字符)
     */
    public static PGobject toJsonb(Object obj) throws JsonProcessingException {
        PGobject result = new PGobject();
        result.setType("jsonb");
        
        if (obj instanceof String) {
            // 字符串必须先解析再转换
            result.setValue(MAPPER.writeValueAsString(MAPPER.readTree((String) obj)));
        } else {
            result.setValue(MAPPER.writeValueAsString(obj));
        }
        
        return result;
    }
    
    /**
     * 容错解析 (处理损坏的 JSONB)
     */
    public static JsonNode parseJsonb(PGobject pgObject) {
        if (pgObject == null || ! "jsonb".equals(pgObject.getType())) {
            return null;
        }
        
        try {
            String json = pgObject.getValue();
            return MAPPER.readTree(json);
        } catch (JsonProcessingException e) {
            log.error("Failed to parse JSONB: {}", json, e);
            // 返回 null 或默认值
            return MAPPER.createObjectNode();
        }
    }
}
```

---

## 性能基准测试

### 7.1 测试数据生成

```sql
-- 生成测试数据 (100 万行)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    i INTEGER;
    metadata_type VARCHAR[] := ARRAY['TABLE', 'VIEW', 'INDEX', 'FUNCTION'];
    tags TEXT[] := ARRAY['production', 'staging', 'dev', 'database', 'api'];
BEGIN
    FOR i IN 1..1000000 LOOP
        INSERT INTO metadata (id, name, metadata_type, properties)
        VALUES (
            gen_random_uuid(),
            'metadata_' || i::text,
            metadata_type[floor(random() * array_length(metadata_type, 1) + 1)::integer],
            jsonb_build_object(
                'description', 'Description for metadata ' || i::text,
                'rowCount', floor(random() * 100000),
                'tags', array_agg(tag) FILTER (WHERE random() > 0.5),
                'statistics', jsonb_build_object(
                    'size', floor(random() * 1073741824),
                    'lastAnalyzedAt', (NOW() - (random() * 3600 * 24 * 90 || ' days')::interval)
                ),
                'owner', gen_random_uuid()::text
            )
        );
        
        IF i % 100000 = 0 THEN
            RAISE NOTICE 'Generated % records', i;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Test data generation completed';
END $$;
```

### 7.2 性能对比测试

```sql
-- ==================== 场景 1: 简单字段查询 ====================

-- 无索引 (顺序扫描)
EXPLAIN ANALYZE
SELECT * FROM metadata
WHERE properties->>'description' LIKE '%test%';

-- 有 GIN 索引
EXPLAIN ANALYZE
SELECT * FROM metadata
WHERE properties @> '{"description": "test data"}';

-- ==================== 场景 2: 数组包含查询 ====================

-- 无索引
EXPLAIN ANALYZE
SELECT * FROM metadata
WHERE 'tags' = ANY((properties #>'{tags}')::text[]);

-- 有 GIN 索引
EXPLAIN ANALYZE
SELECT * FROM metadata
WHERE properties->'tags' @> '["production"]';

-- ==================== 场景 3: 嵌套对象查询 ====================

-- 无索引 (完整扫描)
EXPLAIN ANALYZE
SELECT * FROM metadata
WHERE (properties #>'{statistics}')"@> '{"rowCount": 10000}';

-- 有表达式索引
EXPLAIN ANALYZE
SELECT * FROM metadata
WHERE (properties->'statistics') @> '{"rowCount": 10000}';

-- ==================== 场景 4: 全文检索 ====================

-- 使用 pg_trgm
EXPLAIN ANALYZE
SELECT * FROM metadata
WHERE properties::text % 'production environment';

-- 使用 TO_TSVECTOR (更强大但更慢)
EXPLAIN ANALYZE
SELECT * FROM metadata
WHERE to_tsvector('english', properties::text) @@ to_tsquery('english', 'production & environment');
```

### 7.3 性能优化建议

| 场景 | 推荐索引 | 预计提升 | 说明 |
|------|---------|---------|------|
| 简单包含查询 | GIN properties | 100x | 必须建索引 |
| 数组包含 | GIN (properties->'tags') | 50x | 表达式索引 |
| 嵌套查询 | GIN (properties->'statistics') | 30x | 避免深层嵌套 |
| 模糊搜索 | GIN (properties jsonb_trgm_ops) | 10x | 需要 pg_trgm 扩展 |
| range 范围查询 | B-Tree 表达式索引 | 5x | 仅适用于简单字段 |

---

## 附录

### A1. 操作符参考

| 操作符 | 描述 | 示例 | 索引支持 |
|--------|------|------|----------|
| `@>` | 包含 | `properties @> '{"key": "value"}'` | GIN, GiST |
| `<@` | 被包含 | `'{"a": 1}'::jsonb <@ properties` | GIN |
| `?` | 键存在 | `properties ? 'key'` | GIN |
| `?&` | 键全部存在 | `properties ?& array['key1', 'key2']` | GIN |
| `?\|` | 键之一存在 | `properties ?\| array['key1', 'key2']` | GIN |
| `->` | 数组索引/键 (返回 JSONB) | `properties->'key'` | - |
| `->>` | 数组索引/键 (返回 TEXT) | `properties->>'key'` | B-Tree, Expression |
| `#>` | 路径提取 (返回 JSONB) | `properties #>'{key,subkey}'` | Expression |
| `#>>` | 路径提取 (返回 TEXT) | `properties #>>'{key,subkey}'` | Expression |
| `#-` | 路径删除 | `properties - '{key}'` | - |
| `||` | JSONB 合并 | `properties || '{"new": "value"}'` | - |

### A2. JSONB 函数参考

| 函数 | 描述 | 返回类型 |
|------|------|---------|
| `jsonb_set(target, path, new_value)` | 设置路径值 | JSONB |
| `jsonb_insert(target, path, new_value)` | 插入路径值 | JSONB |
| `jsonb_path_exists(target, path)` | 判断路径是否存在 | BOOLEAN |
| `jsonb_path_exists_array(target, path)` | 路径存在数组 | BOOLEAN[] |
| `jsonb_path_match_array(target, path, predicates)` | 模式匹配 | BOOLEAN[] |

### A3. 参考文档

- [PostgreSQL JSONB 官方文档](https://www.postgresql.org/docs/current/datatype-json.html)
- [GIN Index Documentation](https://www.postgresql.org/docs/current/gin.html)
- [MyBatis-Plus JSONB Support](https://baomidou.com/pages/jsonb-support/)

### A4. 版本演进记录

| 版本 | 日期 | 变更 | 作者 |
|------|------|------|------|
| v1.0 | 2026-04-01 | 初始版本 | [规范作者] |

---

*本文档由[规范作者]于 2026-04-01 编写，欢迎基于本文档进行技术分享和扩展*
