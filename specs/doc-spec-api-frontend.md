---
title: 前端组件 API 文档编写规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 创建日期: 2026-04-01 规范前端子项目 API.md 的编写格式，确保：
---

# 前端组件 API 文档编写规范

**版本**: v1.0  
**创建日期**: 2026-04-01  
**维护人**: [架构师]

---

## 📋 1. 文档目的

规范前端子项目 API.md 的编写格式，确保：
- 可复用组件定义清晰、完整
- Props/Events/Slots 接口统一
- 与业务需求对齐
- 便于组件复用和前端团队协作

---

## 📁 2. 文档位置

每个前端子项目根目录下创建 `API.md`：

```
{项目根目录}/
├── frontend/
│   ├── {前端项目A}/API.md      # 例如：管理控制台
│   ├── {前端项目B}/API.md      # 例如：演示大厅
│   └── {前端项目C}/API.md      # 例如：监控中心
```

---

## 📝 3. 文档结构

每个前端 API.md 必须包含以下章节：

### 3.1 项目概述（必填）

```markdown
# {子项目名} - 前端组件 API 文档

**版本**: v1.0-MVP  
**创建日期**: 2026-04-01  
**对齐文档**: PRD §X.X, requirements-spec §X.X, user-stories US-XX

## 📋 1. 项目定位

{200 字以内，说明本子项目的职责和对外提供的组件能力}
```

### 3.2 组件总览（必填）

```markdown
## 📊 2. 组件总览

### 2.1 核心组件列表

| 组件名 | Props | Events | Slots | 对应需求 | 优先级 |
|--------|-------|--------|-------|---------|--------|
| DataIngestion | fileSources, config | upload-success, upload-error | default, header | 需求 1.1 | P0 |
| StandardizationConfig | configRules | config-change | default | 需求 1.2 | P0 |
| ... | ... | ... | ... | ... | ... |

**总计**: X 个核心组件（P0: X 个，P1: X 个，P2: X 个）
```

### 3.3 组件详情（必填）

每个组件单独一节，按以下模板编写：

```markdown
## 📌 3. 组件详情

### 3.X {组件名称}

**组件职责**: {100 字以内，说明组件职责和使用场景}

**对应需求**: 
- PRD v1.2 §X.X
- requirements-spec v2.2 §X.X
- user-stories v1.1 US-XX

#### Props

| 参数名 | 类型 | 必填 | 默认值 | 说明 | 示例 |
|--------|------|------|--------|------|------|
| datasetId | String | 是 | - | 数据集 ID | "ds_001" |
| filters | Object | 否 | {} | 过滤条件 | {status: "active"} |
| pageSize | Number | 否 | 20 | 每页数量 | 20 |

#### Events

| 事件名 | 参数 | 触发时机 | 说明 |
|--------|------|----------|------|
| row-click | {row, index} | 点击行 | 行点击事件 |
| filter-change | {filters} | 过滤条件变更 | 触发数据重新加载 |

#### Slots

| 插槽名 | 作用域 | 默认内容 | 说明 |
|--------|--------|----------|------|
| default | - | 表格主体 | 主内容区 |
| actions | {row} | 操作按钮 | 行操作按钮区 |

#### 使用示例

```vue
<template>
  <DataList
    :dataset-id="'ds_001'"
    :page-size="20"
    @row-click="handleRowClick"
    @filter-change="handleFilterChange"
  >
    <template #actions="{ row }">
      <el-button @click="handleEdit(row)">编辑</el-button>
    </template>
  </DataList>
</template>

<script setup>
const handleRowClick = ({ row, index }) => {
  console.log('Clicked:', row)
}

const handleFilterChange = (filters) => {
  console.log('Filters changed:', filters)
}
</script>
```

#### 依赖组件

- `Element Plus` - UI 组件库
- `el-table` - 表格组件
- `el-pagination` - 分页组件

---

## 🎯 4. 编写要求

### 4.1 必须对齐的文档

编写 API.md 前必须阅读：
1. ✅ `specs/prd.md` - 理解产品需求和菜单功能
2. ✅ `specs/requirements-spec.md` - 理解功能规格
3. ✅ `specs/user-stories.md` - 理解用户场景
4. ✅ `specs/architecture-design.md` - 理解前端技术架构

### 4.2 组件定义原则

1. **单一职责**: 一个组件只负责一个功能领域
2. **Props 命名**: 使用小驼峰，类型明确
3. **Events 命名**: 使用 kebab-case，语义化
4. **Slots 命名**: 使用小写，描述插槽内容

### 4.3 组件分类

| 分类 | 说明 | 示例 |
|------|------|------|
| **业务组件** | 封装业务逻辑的组件 | DataIngestion, TaskMonitor |
| **展示组件** | 纯展示功能，无业务逻辑 | DataTable, Chart |
| **容器组件** | 管理状态和布局 | PageContainer, FormDialog |

### 4.4 优先级定义

| 优先级 | 说明 | 占比要求 |
|--------|------|---------|
| **P0** | MVP 核心组件，必须实现 | ≥60% |
| **P1** | 重要组件，建议实现 | ≥30% |
| **P2** | 优化组件，可选实现 | ≤10% |

---

## ✅ 5. 检查清单

编写完成后自检查：

- [ ] 组件总览表完整（组件名/Props/Events/Slots/需求/优先级）
- [ ] 每个组件有对应需求文档引用
- [ ] 每个组件有 Props 定义表
- [ ] 每个组件有 Events 事件表
- [ ] 每个组件有 Slots 插槽表
- [ ] 每个组件有使用示例代码
- [ ] 每个组件有依赖组件说明
- [ ] 组件分类清晰

---

## 📊 6. 示例参考

完整示例参考：
- `[项目]/frontend/{前端项目A}/API.md`（管理控制台组件示例）
- `[项目]/frontend/{前端项目B}/API.md`（演示组件示例）
- `[项目]/frontend/{前端项目C}/API.md`（监控组件示例）

---

## 🔄 与后端 API.md 的区别

| 维度 | 后端 API.md | 前端 API.md |
|------|------------|-------------|
| 核心对象 | HTTP 接口 | Vue 组件 |
| 通信方式 | Request/Response | Props/Events/Slots |
| 协议 | RESTful | Vue 组件 API |
| 调用方 | 前端 / 外部系统 | 父组件 / 页面 |

---

**最后更新**: 2026-04-01  
**状态**: ✅ 规范已定义，可开始编写