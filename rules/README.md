---
title: 评审与角色规则
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 定位：定义代码评审的方法论原则、Reviewer Agent 协议及各角色的行为约束模板。 核心目标：确保评审质量不因 Agent 自动化而下降，建立可复现的质量保障体系。
---

# 评审与角色规则

> **定位**：定义代码评审的方法论原则、Reviewer Agent 协议及各角色的行为约束模板。  
> **核心目标**：确保评审质量不因 Agent 自动化而下降，建立可复现的质量保障体系。

---

## 文件清单

| 文件 | 用途 | 加载时机 |
|------|------|----------|
| [`review-rules.md`](review-rules.md) | 23条核心评审原则（评审的"宪法"） | 每次评审前必读 |
| [`reviewer-checklist.md`](reviewer-checklist.md) | 快速检查清单（尚未创建） | 评审时快速对照 |
| [`dev-rules-template.md`](dev-rules-template.md) | 开发工程师角色规则模板 | 调度 Developer Agent 时加载 |
| [`arch-rules-template.md`](arch-rules-template.md) | 架构师角色规则模板 | 调度 Architect Agent 时加载 |
| [`qa-rules-template.md`](qa-rules-template.md) | 测试工程师角色规则模板 | 调度 QA Agent 时加载 |

---

## 使用方式

### Reviewer 评审流程

```
Step 0: 读取 review-rules.md（23条原则）
Step 1: 读取 reviewer-protocol.md（执行协议）
Step 2: 按协议执行 7 维度检查
Step 3: 输出评审报告（遵循 doc-spec-review-report.md）
```

### 角色规则模板使用

1. 复制对应角色的 `-template.md` 到项目 `rules/` 目录
2. 替换方括号内的占位符为项目实际内容
3. 根据项目技术栈调整 Can Do / Must Not Do 清单
4. 在调度对应角色的 Subagent 时加载

---

*版本: v1.0 | 最后更新: 2026-04-29*