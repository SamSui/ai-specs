---
title: 部署骨架（Docker Compose 多阶段架构）
author: 顾小宇
tags: [样本, 范例, 部署, Docker, 容器化]
description: 基于 Docker Compose 的标准多阶段部署骨架，包含基础设施层、应用服务层和反向代理层的完整编排配置。
---

# 部署骨架（Docker Compose 多阶段架构）

> **⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。**

---

## 技术栈

| 层级 | 技术选型 | 用途 |
|------|---------|------|
| 反向代理 | Caddy / Nginx | SSL 终止、路由分发、静态资源服务 |
| 前端 | 构建后的静态文件 | Vue3 SPA |
| 后端 | Spring Boot + Java 21 | 业务 API 服务 |
| 算法 | FastAPI + Python 3.11 | 算法计算服务 |
| 数据库 | PostgreSQL 15 | 主数据库 |
| 缓存 | Redis（可选） | 会话、缓存、队列 |
| 对象存储 | MinIO（可选） | 文件、图片存储 |
| 迁移 | Flyway | 数据库版本管理 |

---

## 目录结构

```
[部署目录]/
├── compose.yml                      # 生产环境主编排
├── compose.dev.yml                  # 开发环境编排
├── compose.test.yml                 # 测试环境编排（含 E2E）
├── .env.example                     # 环境变量模板
├── Makefile                         # 常用命令封装
│
├── caddy/
│   ├── Caddyfile                    # Caddy 反向代理配置
│   └── Dockerfile
│
├── backend/
│   └── Dockerfile                   # 后端多阶段构建
│
├── frontend/
│   └── Dockerfile                   # 前端构建 + 静态服务
│
├── algo/
│   └── Dockerfile                   # 算法服务构建
│
├── db/
│   ├── init/                        # 初始化脚本
│   │   └── 01-create-databases.sql
│   └── migrations/                  # Flyway 迁移脚本（V{N}__{描述}.sql）
│       ├── V1__init_schema.sql
│       └── V2__add_feature_X.sql
│
├── e2e/
│   └── Dockerfile                   # E2E 测试执行环境
│
└── scripts/
    ├── deploy.sh                    # 一键部署脚本
    ├── backup.sh                    # 数据备份脚本
    └── health-check.sh              # 健康检查脚本
```

---

## 关键文件模板

### 生产编排（compose.yml）

```yaml
name: [项目缩写]

services:
  # ---- 基础设施层 ----
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - backend

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    networks:
      - backend

  # ---- 应用服务层 ----
  backend:
    build:
      context: ../backend
      dockerfile: Dockerfile
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/${DB_NAME}
      SPRING_DATASOURCE_USERNAME: ${DB_USER}
      SPRING_DATASOURCE_PASSWORD: ${DB_PASSWORD}
      SPRING_REDIS_HOST: redis
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - backend

  algo:
    build:
      context: ../algo
      dockerfile: Dockerfile
    environment:
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - backend

  # ---- 前端静态资源 ----
  frontend:
    build:
      context: ../frontend
      dockerfile: Dockerfile
    networks:
      - backend

  # ---- 反向代理层（对外唯一入口）----
  caddy:
    build:
      context: ./caddy
      dockerfile: Dockerfile
    ports:
      - "80:80"
      - "443:443"
    environment:
      FRONTEND_URL: http://frontend:80
      BACKEND_URL: http://backend:8080
      ALGO_URL: http://algo:8080
    depends_on:
      - backend
      - algo
      - frontend
    networks:
      - backend

volumes:
  postgres_data:
  redis_data:

networks:
  backend:
    driver: bridge
```

### Caddyfile 模板

```caddy
{
    auto_https off  # 生产环境开启
}

:80 {
    # 健康检查
    respond /health 200

    # API 路由 → 后端
    handle_path /api/* {
        reverse_proxy {$BACKEND_URL}
    }

    # 算法路由 → 算法服务
    handle_path /algo/* {
        reverse_proxy {$ALGO_URL}
    }

    # 静态资源 → 前端
    handle {
        reverse_proxy {$FRONTEND_URL}
    }
}
```

### 环境变量模板（.env.example）

```bash
# 数据库
DB_USER=[项目缩写]_user
DB_PASSWORD=change_me_in_production
DB_NAME=[项目缩写]_db

# 外部访问地址
FRONTEND_URL=http://localhost:3000
BACKEND_URL=http://localhost:8080
ALGO_URL=http://localhost:8081

# 日志级别
LOG_LEVEL=info

# JWT 密钥（生产环境必须修改）
JWT_SECRET=change_me_in_production
```

### 后端 Dockerfile（多阶段）

```dockerfile
# ---- Builder ----
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY pom.xml .
COPY app-bootstrap/ ./app-bootstrap/
COPY module-core/ ./module-core/
COPY module-domain-*/ ./module-domain-*/
RUN ./mvnw clean package -DskipTests

# ---- Runtime ----
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/app-bootstrap/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## 部署分层启动顺序

```
第 1 层: 基础设施（infra）
  └── postgres, redis

第 2 层: 基础服务（base）
  └── Flyway 数据库迁移

第 3 层: 后端服务（backend）
  └── Spring Boot 应用

第 4 层: 前端服务（frontend）
  └── Vue3 静态资源

第 5 层: 算法服务（algo）
  └── FastAPI 算法服务

第 6 层: 代理层（http）
  └── Caddy 反向代理
```

---

## 快速开始

```bash
# 1. 复制环境变量
 cp .env.example .env
# 编辑 .env 填入实际值

# 2. 启动全部服务
 docker compose up -d

# 3. 查看日志
 docker compose logs -f backend

# 4. 健康检查
 curl http://localhost/health

# 5. 停止服务
 docker compose down

# 6. 数据持久化清理（危险！）
 docker compose down -v
```

---

## 数据库迁移规范

- **命名格式**: `V{N}__{description}.sql`
- **版本号**: 由 CI 流水线自动分配，禁止手动修改
- **原则**: 每个迁移脚本必须可重复执行（幂等）
- **禁止**: 在生产环境直接修改已应用的迁移脚本

---

## 相关规范

- [Docker 容器化规范](../tech/tech-spec-docker.md)
- [E2E 测试编写规范](../specs/doc-spec-e2e.md)
- [后端项目骨架](./skeleton-backend.md)
- [前端项目骨架](./skeleton-frontend.md)
- [算法服务骨架](./skeleton-algo.md)
