---
title: 经验样本
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 定位：去项目化后的项目文档范例，供新项目参考结构和方法论。 使用说明：核心方法论可复用，项目专属内容已替换为占位符。复制后按需修改。
---

# 经验样本

> **定位**：去项目化后的项目文档范例，供新项目参考结构和方法论。  
> **使用说明**：核心方法论可复用，项目专属内容已替换为占位符。复制后按需修改。

---

## 样本清单

| 样本文件 | 内容 | 适用场景 |
|----------|------|----------|
| [`project-guide-sample.md`](project-guide-sample.md) | 项目开发者手册（完整版） | 新项目编写开发者手册时参考结构 |
| [`modular-monolith-guide-sample.md`](modular-monolith-guide-sample.md) | 模块化单体 Java 落地指南 | Java 后端项目架构重构参考 |
| [`modular-monolith-algo-guide-sample.md`](modular-monolith-algo-guide-sample.md) | 模块化单体 Python 算法篇 | Python 算法服务接入参考 |
| [`e2e-coverage-matrix-sample.md`](e2e-coverage-matrix-sample.md) | E2E 测试覆盖矩阵 | 验收阶段梳理测试覆盖度 |

---

## 使用方式

1. **复制到项目**：将需要的样本复制到项目对应目录
2. **替换占位符**：将所有 `[方括号]` 内的占位符替换为项目实际内容
3. **删减调整**：删除与当前项目无关的章节，补充项目专属内容
4. **声明来源**：在文档头部或底部注明"基于 [知识库名称] 样本修改"

---

## 注意事项

- ⚠️ 样本中的技术栈（Spring Boot / Vue 3 / FastAPI）仅为示例，实际项目按需调整
- ⚠️ 人员组织、团队角色为示例，替换为实际团队信息
- ⚠️ 目录结构、端口号、路径等均为占位符，必须替换

---

*版本: v1.0 | 最后更新: 2026-04-29*
