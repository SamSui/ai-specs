---
title: 通用文档编写规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 定位：定义跨项目通用的文档格式标准，确保文档的一致性、完整性和可读性。 1. 复制需要的规范到项目 specs/ 目录
---

# 通用文档编写规范

> **定位**：定义跨项目通用的文档格式标准，确保文档的一致性、完整性和可读性。  
> **适用对象**：所有使用 AI Agent 协作开发的项目团队。

---

## 规范清单

| 规范文件 | 用途 | 适用阶段 |
|----------|------|----------|
| [`doc-spec-readme.md`](doc-spec-readme.md) | 子项目 README.md 编写标准 | 项目初始化 |
| [`doc-spec-api.md`](doc-spec-api.md) | 后端 API 文档编写标准 | 接口设计 |
| [`doc-spec-api-frontend.md`](doc-spec-api-frontend.md) | 前端组件 API 文档编写标准 | 组件开发 |
| [`doc-spec-testcase.md`](doc-spec-testcase.md) | 测试用例文档编写标准 | 测试设计 |
| [`task-card-format-spec.md`](task-card-format-spec.md) | 任务卡片编写标准 | 任务拆分与调度 |
| [`master-task-list-format-spec.md`](master-task-list-format-spec.md) | 主任务清单编写标准 | 里程碑规划 |
| [`review-report-spec.md`](review-report-spec.md) | 评审报告编写标准 | 代码评审 |
| [`reviewer-protocol.md`](reviewer-protocol.md) | Reviewer Agent 执行协议 | 质量保障 |
| [`doc-spec-e2e.md`](doc-spec-e2e.md) | E2E 测试编写与执行标准 | 自动化测试 |
| [`doc-spec-adr.md`](doc-spec-adr.md) | 架构决策记录(ADR)编写标准 | 架构决策 |
| [`doc-spec-user-story.md`](doc-spec-user-story.md) | 用户故事编写标准 | 需求分析 |
| [`doc-spec-error-codes.md`](doc-spec-error-codes.md) | 错误码编写标准 | API 设计 |
| [`tech-debt-log-template.md`](tech-debt-log-template.md) | 技术债务台账模板 | 技术债务跟踪 |

---

## 使用方式

### 新项目引入

1. 复制需要的规范到项目 `specs/` 目录
2. 根据项目实际情况调整适用范围、对齐文档等字段
3. 在 `AGENTS.md` 中声明遵循的规范

### Agent 引用

在任务卡片中引用规范：

```markdown
## Reference
- 文档规范 → `{知识库路径}/specs/doc-spec-readme.md`
- 评审协议 → `{知识库路径}/specs/reviewer-protocol.md`
```

---

## 规范之间的关系

```
项目启动
  ├── doc-spec-readme.md → 定义项目手册格式
  ├── doc-spec-api.md + doc-spec-api-frontend.md → 定义接口文档格式
  ├── task-card-format-spec.md → 拆分任务到 Subagent
  ├── master-task-list-format-spec.md → 汇总里程碑任务
  ├── doc-spec-testcase.md → 定义测试用例格式
  └── review-report-spec.md + reviewer-protocol.md → 评审产出物
```

---

*版本: v1.0 | 最后更新: 2026-04-29*
