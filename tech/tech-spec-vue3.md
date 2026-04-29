---
title: Vue 3 + TypeScript 前端开发规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: frontend/{project}/ │   ├── api/                    # API 请求封装
---

# Vue 3 + TypeScript 前端开发规范

> **版本**: v1.0  
> **创建日期**: 2026-04-29  
> **适用范围**: 使用 Vue 3 + TypeScript + Vite 的前端项目

---

## 1. 项目结构

```
frontend/{project}/
├── src/
│   ├── api/                    # API 请求封装
│   │   ├── {module}.ts         # 按业务模块组织
│   │   └── types.ts            # API 响应类型定义
│   ├── router/                 # 路由配置
│   │   ├── index.ts
│   │   └── modules/            # 按模块拆分路由
│   ├── store/                  # Pinia 状态管理
│   │   ├── modules/
│   │   └── index.ts
│   ├── views/                  # 页面组件
│   │   └── {module}/           # 按业务模块组织
│   ├── components/             # 公共组件
│   │   ├── common/             # 通用组件
│   │   └── business/           # 业务组件
│   ├── composables/            # 组合式函数
│   ├── utils/                  # 工具函数
│   └── types/                  # 全局类型定义
├── public/
├── index.html
├── vite.config.ts
├── tsconfig.json
└── package.json
```

---

## 2. 组件规范

### 2.1 单文件组件（SFC）结构

```vue
<script setup lang="ts">
// 1. import
import { ref, computed } from "vue";
import type { Dataset } from "@/types";

// 2. props / emits 定义
const props = defineProps<{
  datasetId: string;
  readonly?: boolean;
}>();

const emit = defineEmits<{
  (e: "update", id: string): void;
  (e: "delete", id: string): void;
}>();

// 3. 响应式数据
const loading = ref(false);
const dataset = ref<Dataset | null>(null);

// 4. computed
const isValid = computed(() => !!dataset.value?.name);

// 5. methods
const handleSave = async () => {
  // ...
};
</script>

<template>
  <div class="dataset-form" data-testid="dataset-form">
    <!-- 内容 -->
  </div>
</template>

<style scoped>
/* 组件级样式 */
</style>
```

### 2.2 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 组件文件名 | PascalCase | `DatasetForm.vue` |
| 组件引用 | PascalCase | `<DatasetForm />` |
| Props | camelCase | `datasetId` |
| Emits | camelCase | `update:modelValue` |
| 事件监听 | kebab-case | `@update="handleUpdate"` |
| 目录名 | kebab-case | `dataset-form/` |

### 2.3 Props 规范

```typescript
// ✅ 正确：明确类型、默认值、必填
const props = withDefaults(
  defineProps<{
    title: string;
    pageSize?: number;
    filters?: Record<string, unknown>;
  }>(),
  {
    pageSize: 20,
    filters: () => ({}),
  }
);
```

---

## 3. 路由规范

### 3.1 路由模式

- **Hash 模式**（推荐）：`/#/{path}`，部署简单，无需服务端配置
- History 模式：需要服务端配合回退到 `index.html`

### 3.2 路由文件组织

```typescript
// router/modules/dataset.ts
export default {
  path: "/dataset",
  component: Layout,
  children: [
    {
      path: "list",
      component: () => import("@/views/dataset/list/index.vue"),
      meta: { title: "数据集列表", permission: "dataset:read" },
    },
    {
      path: "detail/:id",
      component: () => import("@/views/dataset/detail/index.vue"),
      meta: { title: "数据集详情", permission: "dataset:read" },
    },
  ],
};
```

### 3.3 动态路由

如后端下发菜单路由：

```typescript
// 登录后加载
const routes = await menuApi.getRoutes();
routes.forEach((route) => router.addRoute(route));
```

---

## 4. 状态管理（Pinia）

### 4.1 Store 组织

```typescript
// store/modules/dataset.ts
import { defineStore } from "pinia";
import { ref, computed } from "vue";

export const useDatasetStore = defineStore("dataset", () => {
  // State
  const list = ref<Dataset[]>([]);
  const loading = ref(false);

  // Getters
  const total = computed(() => list.value.length);

  // Actions
  const fetchList = async (params: QueryParams) => {
    loading.value = true;
    try {
      const res = await datasetApi.list(params);
      list.value = res.data;
    } finally {
      loading.value = false;
    }
  };

  return { list, loading, total, fetchList };
});
```

### 4.2 使用规范

- 使用 Setup Store 语法（Composition API 风格）
- Store 按业务域拆分，不集中在单一文件
- Action 负责异步操作，State 和 Getters 保持纯净

---

## 5. API 封装规范

### 5.1 请求封装

```typescript
// utils/request.ts
import axios from "axios";

const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 30000,
  withCredentials: true,  // Cookie+Session 模式必须设置
});

// 响应拦截：统一处理错误码
request.interceptors.response.use(
  (response) => {
    const { code, message } = response.data;
    if (code !== 0) {
      return Promise.reject(new Error(message));
    }
    return response.data.data;
  },
  (error) => {
    // 处理 HTTP 错误
    return Promise.reject(error);
  }
);
```

### 5.2 API 模块

```typescript
// api/dataset.ts
import request from "@/utils/request";
import type { Dataset, DatasetDTO } from "./types";

export const datasetApi = {
  list: (params: PageParams) => request.get<Page<Dataset>>("/datasets", { params }),
  create: (data: DatasetDTO) => request.post<Dataset>("/datasets", data),
  update: (id: string, data: DatasetDTO) => request.put<Dataset>(`/datasets/${id}`, data),
  delete: (id: string) => request.delete(`/datasets/${id}`),
};
```

**约束**：
- API 函数使用对象组织（`datasetApi.list()`）
- 返回类型使用泛型明确
- 前端 Axios 必须设置 `withCredentials: true`（Cookie+Session 模式）

---

## 6. E2E 友好规范

### 6.1 data-testid 属性

所有可交互元素必须添加 `data-testid`：

```vue
<template>
  <el-table data-testid="dataset-table">
    <el-table-column>
      <template #default="{ row }">
        <el-button 
          data-testid="dataset-btn-edit"
          @click="handleEdit(row)"
        >
          编辑
        </el-button>
      </template>
    </el-table-column>
  </el-table>
</template>
```

### 6.2 命名规则

```
{页面}-{元素类型}-{动作/含义}
```

| 元素类型 | 示例 |
|----------|------|
| 表格 | `dataset-table` |
| 输入框 | `dataset-input-search` |
| 按钮 | `dataset-btn-search`, `dataset-btn-edit` |
| 表单 | `dataset-form` |
| 分页 | `dataset-pagination` |

---

## 7. TypeScript 规范

### 7.1 类型定义

```typescript
// types/dataset.ts
export interface Dataset {
  id: string;
  name: string;
  description?: string;
  fileCount: number;
  size: number;
  createdAt: string;
  status: DatasetStatus;
}

export type DatasetStatus = "active" | "archived" | "processing";

export interface Page<T> {
  list: T[];
  total: number;
  pageNum: number;
  pageSize: number;
}
```

### 7.2 禁用 any

- 禁止在业务代码中使用 `any`
- 对第三方库缺失类型时使用 `// @ts-expect-error` 并注释原因
- 全局类型定义放在 `src/types/` 目录

---

## 8. 检查清单

- [ ] 组件使用 `<script setup lang="ts">`
- [ ] Props 有明确类型定义和默认值
- [ ] 路由按业务模块拆分
- [ ] Pinia Store 按业务域组织
- [ ] API 封装返回类型明确
- [ ] Axios 配置 `withCredentials: true`（如使用 Cookie+Session）
- [ ] 可交互元素有 `data-testid`
- [ ] 禁用 `any`，类型定义完整

---

*版本: v1.0 | 最后更新: 2026-04-29*
