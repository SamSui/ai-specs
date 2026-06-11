---
title: Docker / Docker Compose 容器化规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 依赖层 → 源码层 → 运行时层 ↑        ↑         ↑
---

# Docker / Docker Compose 容器化规范

> **版本**: v1.0  
> **创建日期**: 2026-04-29  
> **适用范围**: 使用 Docker 部署的软件工程项目

---

## 1. 核心原则

### 1.1 多阶段构建

```
依赖层 → 源码层 → 运行时层
  ↑        ↑         ↑
 最稳定   经常变更   最小镜像
```

**构建顺序**：系统依赖 → 语言包依赖 → 源码 → 运行时

### 1.2 镜像大小目标

| 镜像类型 | 大小上限 | 推荐基础镜像 |
|----------|----------|-------------|
| Java 运行时 | < 400MB | `eclipse-temurin:{version}-jre` |
| Python 运行时 | < 300MB | `python:{version}-slim` |
| Node 运行时 | < 200MB | `node:{version}-alpine` |
| 前端静态资源 | < 50MB | `nginx:alpine` |

---

## 2. Dockerfile 规范

### 2.1 多阶段构建模板（Java）

```dockerfile
# 阶段一：依赖下载
FROM eclipse-temurin:21-jdk AS builder
WORKDIR /build
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2/repository \
    mvn dependency:go-offline -B

# 阶段二：编译
COPY src/ ./src/
RUN mvn package -DskipTests

# 阶段三：运行时
FROM eclipse-temurin:21-jre
COPY --from=builder /build/target/*.jar /app/app.jar
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

### 2.2 多阶段构建模板（Python）

```dockerfile
# 阶段一：依赖安装
FROM python:3.11-slim AS builder
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

# 阶段二：运行时
FROM python:3.11-slim
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY src/ /app/src/
WORKDIR /app
CMD ["python", "-m", "src.main"]
```

### 2.3 缓存复用策略

| 变更类型 | 缓存命中 | 影响范围 |
|----------|----------|----------|
| 仅依赖文件 | ✅ 依赖层复用 | 仅重 build 源码层 |
| 仅源码 | ❌ 重新编译 | 仅运行时镜像层 |
| Dockerfile 修改 | ❌ 全量重建 | 全部层 |

---

## 3. Docker Compose 分层架构

### 3.1 标准目录结构

```
deployment/
├── compose.base.yml          # 通用服务模板抽象层
├── compose.infra.yml         # 基础设施层（DB/Cache/Queue）
├── compose.backend.yml       # 后端服务层
├── compose.frontend.yml      # 前端服务层
├── compose.algo.yml          # 算法/外部服务层
├── compose.http.yml          # HTTP 反向代理层
├── compose.test.yml          # 测试服务层
├── compose.dev.yml           # 开发模式（挂载本地代码）
├── .env                      # 环境变量（敏感信息，.gitignore）
└── .env.example              # 环境变量模板（可提交）
```

### 3.2 加载顺序

```bash
COMPOSE_FILE=compose.infra.yml,compose.base.yml,compose.backend.yml,compose.frontend.yml,compose.algo.yml,compose.http.yml
```

**原则**：从下到上依赖，infra → base → 应用层 → 代理层

### 3.3 环境变量规范

```bash
# === 基础配置 ===
DATA_DIR=${PWD}/data
COMPOSE_PROJECT_NAME=[项目缩写]

# === 数据库 ===
DB_NAME=[项目数据库名]
DB_USER=[数据库用户]
DB_PASSWORD=change_me_in_production

# === 代理路由 ===
PROXY_API_PATH=/api
PROXY_API_TARGET=http://backend:8080
PROXY_FRONTEND_PATH=/admin
PROXY_FRONTEND_TARGET=http://frontend:80
```

**安全要求**：
- `.env` 包含敏感信息，必须加入 `.gitignore`
- `.env.example` 为脱敏模板，可提交至版本控制
- 生产环境密码通过 CI/CD 密钥管理注入

---

## 4. 数据与日志规范

### 4.1 数据目录

```bash
DATA_DIR=${PWD}/data
DB_DATA_DIR=${DATA_DIR}/postgres
LOG_DIR=${DATA_DIR}/logs
```

- `data/` 目录权限：`chown -R 1000:1000` 后供容器使用
- 日志按服务分子目录：`logs/{service}/`

### 4.2 维护标签

所有服务必须包含维护标签：

```yaml
services:
  [service]:
    labels:
      maintenance.inspect: "docker exec -it ${COMPOSE_PROJECT_NAME}_[service]_1 bash"
      maintenance.logs: "docker logs -f ${COMPOSE_PROJECT_NAME}_[service]_1"
      maintenance.restart: "docker compose -p ${COMPOSE_PROJECT_NAME} restart [service]"
```

---

## 5. 数据库迁移规范（Flyway）

### 5.1 文件命名

```
db/migration/
├── V001__init_schema.sql
├── V002__add_user_table.sql
└── V003__add_metadata_columns.sql
```

**规则**：
- 版本号连续无跳跃
- 文件名格式：`V{version}__{description}.sql`
- description 使用 `__` 分隔版本号和描述

### 5.2 Migration 文件结构

```sql
-- ============================================================
-- V{N}__add_{feature}_column.sql
-- 变更说明：
--   1. [具体变更描述]
--   2. [业务背景/用途]
-- 风险评估：[无数据损失可逆 / 不可逆操作]
-- Review 通过：[YYYY-MM-DD]
-- ============================================================

-- Forward: 执行变更
ALTER TABLE [表名] ADD COLUMN IF NOT EXISTS [列名] [类型];
COMMENT ON COLUMN [表名].[列名] IS '[注释]';
CREATE INDEX IF NOT EXISTS [索引名] ON [表名]([列名]);

-- Rollback: 回滚变更（注释形式）
-- DROP INDEX IF EXISTS [索引名];
-- ALTER TABLE [表名] DROP COLUMN IF EXISTS [列名];
```

### 5.3 Rollback 要求

| 场景 | 要求 |
|------|------|
| 可逆操作（ADD COLUMN / CREATE INDEX） | 必须提供完整 Rollback SQL（注释形式） |
| 不可逆操作（DROP COLUMN / DROP TABLE） | Forward 前标注"不可逆"，Rollback 注释说明"无法回滚" |
| 数据迁移 | DROP COLUMN 前必须有数据迁移脚本 |

### 5.4 合规检查

- [ ] 新增列必须有默认值或允许 NULL
- [ ] 列类型变更必须先备份数据
- [ ] 删除列/表必须有数据迁移脚本
- [ ] 外键必须先建索引
- [ ] Rollback SQL 必须存在且可执行（不可逆的除外）
- [ ] **禁止** `NOT NULL` + 无默认值组合

---

## 6. 测试容器

### 6.1 E2E 测试容器

```yaml
test-e2e:
  network_mode: host          # 访问宿主机代理
  environment:
    - TESTING_ENTRYPOINT=test-login.spec.ts
  volumes:
    - ./test-results:/app/test-results
```

### 6.2 集成测试容器

```yaml
test-integration:
  network_mode: service:backend  # 共享 backend 网络栈
  depends_on:
    - backend
    - postgres
```

---

## 7. 镜像安全

- 优先使用官方 `slim` / `alpine` 变体
- 不使用 `latest` 标签（使用固定版本）
- 定期更新基础镜像（季度安全更新）
- 不在 runtime 镜像中保留编译工具链
- 非 root 用户运行容器进程（通过 `USER` 指令或运行时配置）

---

## 8. 检查清单

- [ ] Dockerfile 使用多阶段构建
- [ ] 依赖层在 COPY 源码之前
- [ ] 镜像大小符合上限要求
- [ ] `.env` 已加入 `.gitignore`
- [ ] `.env.example` 已提供脱敏模板
- [ ] Compose 文件按分层架构组织
- [ ] 所有服务有 maintenance 标签
- [ ] Flyway Migration 含 Rollback SQL
- [ ] 运行时镜像不含构建工具链

---

*版本: v1.0 | 最后更新: 2026-04-29*
