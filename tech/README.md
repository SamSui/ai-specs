---
title: 技术深度规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 定位：沉淀特定技术栈的深度使用规范、最佳实践和性能基准。 - 技术选型阶段 → 阅读对应规范了解约束和最佳实践
---

# 技术深度规范

> **定位**：沉淀特定技术栈的深度使用规范、最佳实践和性能基准。  
> **适用范围**：采用对应技术栈的项目团队。

---

## 规范清单

| 规范文件 | 技术领域 | 核心内容 |
|----------|----------|----------|
| [`tech-spec-mybatis-plus.md`](tech-spec-mybatis-plus.md) | Java ORM (MyBatis-Plus) | 实体类规范、Mapper/Service 层规范、代码示例、常见问题 |
| [`tech-spec-postgresql-jsonb.md`](tech-spec-postgresql-jsonb.md) | 数据库 (PostgreSQL + JSONB) | 元数据模型设计、JSONB 基础规范、索引优化、查询最佳实践 |
| [`tech-spec-spring-boot.md`](tech-spec-spring-boot.md) | Java 后端 (Spring Boot 3.x) | 项目结构、分层规范、模块边界、异常处理、配置管理 |
| [`tech-spec-docker.md`](tech-spec-docker.md) | 容器化 (Docker/Compose) | 多阶段构建、镜像大小、Compose 分层、Flyway 迁移、安全 |
| [`tech-spec-fastapi.md`](tech-spec-fastapi.md) | Python 服务 (FastAPI) | 六层目录、Pydantic 规范、服务注册、gRPC 预留 |
| [`tech-spec-vue3.md`](tech-spec-vue3.md) | 前端 (Vue 3 + TypeScript) | 项目结构、组件规范、Pinia 状态、API 封装、E2E 友好 |

---

## 使用方式

- 技术选型阶段 → 阅读对应规范了解约束和最佳实践
- 代码审查阶段 → 对照规范检查代码是否符合标准
- 团队培训 → 作为新人上手的技术参考资料

---

## 待补充领域

以下技术规范可进一步补充：

- [ ] Playwright E2E 测试规范（已有 `specs/doc-spec-e2e.md` 覆盖 E2E 编写，但缺 Playwright 专项配置）
- [ ] gRPC 协议管理规范（proto 定义、版本兼容、代码生成）
- [ ] Redis 缓存使用规范
- [ ] 消息队列（MQ）使用规范

---

*版本: v1.0 | 最后更新: 2026-04-29*
