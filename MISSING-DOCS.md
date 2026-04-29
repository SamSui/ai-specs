---
title: 缺失文档清单
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 说明：以下清单基于"通用 AI 经验知识库"的定位，梳理当前已存在规范之间的缺口和可补充的内容。 优先级：P0=强烈建议补充 / P1=建议补充 / P2=可选补充
---

# 缺失文档清单

> **说明**：以下清单基于"通用 AI 经验知识库"的定位，梳理当前已存在规范之间的缺口和可补充的内容。  
> **优先级**：P0=强烈建议补充 / P1=建议补充 / P2=可选补充

---

## P0 — 强烈建议补充

### 1. `skills/self-improvement/SKILL.md` — 知识洞见与自我改进技能

**缺失原因**：`workspace-structure.md` 第 121-122 行明确引用了 `skills/self-improvement/SKILL.md` 作为"洞见目录"的参考文档，但该文件不存在。

**影响**：Agent 无法学习如何整理 `.learnings/` 目录中的 ERRORS.md / LEARNINGS.md / FEATURE_REQUESTS.md。

**建议内容**：
- 如何记录和分类 Agent 的错误与纠正
- 如何从工作日志中提炼长期记忆
- 如何定期做自我复盘和总结

---

### 2. `specs/doc-spec-e2e.md` — E2E 测试编写与执行规范

**缺失原因**：现有 `doc-spec-testcase.md` 仅覆盖手动测试用例，但 `project-guide-sample.md` §7 和 `skills/milestone-spec-workflow/` 都涉及 E2E 自动化测试（Playwright），却无专门规范。

**影响**：不同项目的 E2E 测试风格、定位器规范、环境配置标准不一致。

**建议内容**：
- Playwright / Cypress 测试文件结构
- 定位器规范（data-testid vs text selector）
- E2E Session 注入与认证绕过模式
- 测试环境配置标准

---

### 3. `specs/doc-spec-adr.md` — 架构决策记录(ADR)编写规范

**缺失原因**：`workspace-structure.md` 定义了 `decisions/` 目录用于存放 ADR，且 `project-guide-sample.md` §8 提到架构决策，但无 ADR 编写标准。

**影响**：ADR 格式不统一，历史决策难以追溯。

**建议内容**：
- ADR 标准格式（背景/决策/后果/状态）
- 编号规范（ADR-NNN）
- 生命周期（提议/已接受/已废弃）

---

## P1 — 建议补充

### 4. `tech/tech-spec-spring-boot.md` — Spring Boot 3.x 项目结构规范

**缺失原因**：`tech/README.md` 已将其列入"待补充领域"。当前仅有 MyBatis-Plus 和 PostgreSQL 规范，缺少整体项目结构标准。

**建议内容**：
- 分层架构规范（Controller/Service/Mapper/Entity）
- 配置管理规范（application.yml 分层）
- 异常处理与统一响应封装
- 日志规范

---

### 5. `tech/tech-spec-vue3.md` — Vue 3 + TypeScript 前端开发规范

**缺失原因**：`tech/README.md` 已将其列入"待补充领域"。前端规范仅在 `doc-spec-api-frontend.md` 中涉及组件 API 文档，缺少开发规范。

**建议内容**：
- 目录结构标准
- 组件编写规范（Composition API）
- 状态管理规范（Pinia）
- 路由与权限规范

---

### 6. `tech/tech-spec-docker.md` — Docker / Docker Compose 部署规范

**缺失原因**：`tech/README.md` 已将其列入"待补充领域"。`project-guide-sample.md` §6 有大量部署经验，但未沉淀为独立规范。

**建议内容**：
- 多阶段构建 Dockerfile 模板
- Docker Compose 分层组织（infra/apps/test）
- 环境变量管理规范
- 网络与卷管理

---

### 7. `tech/tech-spec-fastapi.md` — FastAPI Python 服务开发规范

**缺失原因**：`tech/README.md` 已将其列入"待补充领域"。Python 算法篇落地指南中有相关内容，但未独立成规范。

**建议内容**：
- 项目结构（api/internal/model）
- Pydantic 模型规范
- 依赖注入与异常处理
- gRPC + HTTP 双协议支持

---

### 8. `specs/doc-spec-user-story.md` — 用户故事编写规范

**缺失原因**：现有规范体系缺少需求层规范。`doc-spec-api.md` 和 `doc-spec-testcase.md` 都引用了 user-stories，但无编写标准。

**建议内容**：
- 用户故事格式（作为...我想要...以便...）
- 验收标准编写规范
- 用户故事与任务卡片的映射关系

---

## P2 — 可选补充

### 9. `templates/` 目录 — 空白模板集合

**建议内容**：
- 空白任务卡片模板（仅保留章节结构，无内容）
- 空白评审报告模板
- 空白主任务清单模板
- 空白 API 文档模板

**用途**：新项目启动时可直接复制使用，降低规范 adoption 成本。

---

### 10. `samples/e2e-coverage-matrix-sample.md` — E2E 覆盖矩阵样本

**建议内容**：基于 `skills/milestone-spec-workflow/references/feature-matrix-template.md`，补充一个完整的 E2E 覆盖矩阵实例。

---

### 11. `specs/doc-spec-log.md` — 日志规范

**建议内容**：
- 日志级别使用规范（DEBUG/INFO/WARN/ERROR）
- 结构化日志格式（JSON）
- 关键业务日志埋点规范
- 日志采样与存储策略

---

## 总结

| 优先级 | 数量 | 类型 |
|--------|------|------|
| **P0** | 3 | 被现有文档明确引用但缺失 |
| **P1** | 5 | 技术栈规范 + 需求规范 |
| **P2** | 3 | 模板 + 样本 + 专项规范 |

**建议补充顺序**：P0 → P1（按技术栈优先级）→ P2。

---

*版本: v1.0 | 生成日期: 2026-04-29*
