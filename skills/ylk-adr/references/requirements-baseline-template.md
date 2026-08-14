---
title: 需求基线模板
author: 顾小宇
tags: [需求基线, 模板, Beads, 任务拆分]
description: 需求基线、Beads 父子 issue 拆分与调查清单模板。
version: v1.0
last_updated: 2026-08-14
---

# 需求基线模板

`CURRENT_TASKS.md` 的历史价值不只在进度，还在于把需求、代码落点、项目认知和测试用例放在同一基线中。新任务不再用它做进度看板；基线变化进入 Beads issue，稳定业务认知进入 ADR 或 Beads memory，经验和踩坑也必须保留并迁移。

## Beads 父 issue 描述建议

```text
背景：
影响范围：
成功标准：
涉及仓库/分支：
需求来源：

用户故事：
- US-01 ...

前端入口与代码落点：
- 页面/路由/API：
- 宿主/微前端关系：

后端入口与代码落点：
- Gateway/Controller：
- Service/Feign/RPC：
- Mapper/表/对象存储：

验证范围：
- P0：
- P1：
- P2：

不在范围：
- 不修改的仓库：
- 不处理的历史缺陷：
- 不执行的数据修复/部署动作：
```

父 issue 创建后立即拆分子 issue，使用 `bd update <id> --claim` 标记实际开始的工作。不要等调查完成后才补任务树。

## 子 issue 建议

按交付结果拆分，不按文件机械拆分：

- 需求与仓库调查。
- 调用链和数据契约核查。
- ADR 草拟与独立审查。
- 后端实施与单测/编译。
- 前端实施与 lint/typecheck/build。
- 跨系统 API/DB 验证。
- E2E、部署和回归。
- 独立 code review。
- 文档索引、结果报告和 memory 收官。

用 `bd dep add <issue-id> <dependency-id>` 表达先后关系，用 `bd update <issue-id> --notes "<text>"` 追加新证据、阻塞和判断变化。

## 调查清单

- **用户故事** → 角色、目标、触发条件、预期结果。
- **页面** → 前端应用、路由、组件、宿主和微前端方式。
- **API** → 方法、路径、请求字段、响应字段、认证头；认证值只记录字段名，不记录真实值。
- **后端** → Gateway、Controller、Service、Feign/RPC、异步任务。
- **数据** → 表、列、JSON、缓存、对象路径、读写方。
- **跨仓** → 仓库、模块、分支、产物、部署组件。
- **现状** → 已实现、部分实现、缺失、历史行为。
- **证据** → 代码、git、SQL、日志、API、测试、部署；敏感内容先脱敏。
- **边界** → 不改项、技术债务、环境/数据依赖和需 Owner 决策项。

## 迁移历史 CURRENT 内容

从历史 `CURRENT_TASKS.md` / `CURRENT_E2E.md` 读取内容时分类处理：

- 当前待办、进度、阻塞、轮次 → 更新到对应 Beads issue。
- 稳定项目认知、已确认环境矩阵、仓库拓扑 → 设计阶段即可写入 Beads memory（使用 `bd remember`）。
- 可重复经验和踩坑 → 原则上在获得实施授权并进入实施阶段后写入 Beads memory（使用 `bd remember`），带适用范围和处理方式。
- 稳定架构规则 → 写入 ADR，并按需用 `bd remember` 建索引性记忆。
- 本轮最终结果和验证事实 → 写入 `result.md` 或 `HANDOVER.md`。
- 一次性截图、逐步日志和已失效状态 → 保留历史文件作参考，不继续扩写。

**禁止**把“取消过程文件”理解成“删除其知识”；先完成分类迁移，再决定旧文件是否仅保留、归档或由用户另行处理。
