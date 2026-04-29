---
title: 前端项目骨架（Vue3 + TypeScript + Vite）
author: 顾小宇
tags: [样本, 范例, 前端, Vue3, TypeScript]
description: 基于 Vue3 + TypeScript + Vite 的标准前端项目骨架，包含目录结构、路由配置、状态管理和组件规范。
---

# 前端项目骨架（Vue3 + TypeScript + Vite）

> **⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。**

---

## 技术栈

| 层级 | 技术选型 | 版本 |
|------|---------|------|
| 框架 | Vue | 3.4+ |
| 语言 | TypeScript | 5.x |
| 构建工具 | Vite | 5.x |
| 路由 | Vue Router | 4.x |
| 状态管理 | Pinia | 2.x |
| UI 框架 | Element Plus / Ant Design Vue | 最新稳定版 |
| 网络请求 | Axios | 1.x |
| 测试 | Vitest + Playwright (E2E) | 最新稳定版 |

---

## 目录结构

```
[项目根目录]/
├── public/                          # 静态资源（不经过构建）
│   └── favicon.ico
├── src/
│   ├── api/                         # API 接口封装
│   │   ├── core/
│   │   │   └── request.ts           # Axios 实例配置（拦截器、错误处理）
│   │   ├── modules/
│   │   │   └── [业务域A].ts         # 按业务域组织的 API 定义
│   │   └── types/
│   │       └── response.ts          # 通用响应类型
│   │
│   ├── assets/                      # 构建资源（图片、字体、样式变量）
│   │   ├── styles/
│   │   │   ├── variables.scss       # SCSS 变量（主题色、间距）
│   │   │   └── mixins.scss          # 通用 mixins
│   │   └── images/
│   │
│   ├── components/                  # 全局通用组件
│   │   ├── common/                  # 纯展示组件（无业务逻辑）
│   │   │   └── [ComponentName]/
│   │   │       ├── index.vue
│   │   │       └── index.scss
│   │   └── business/                # 业务组件（含业务逻辑）
│   │       └── [BusinessComponent]/
│   │           ├── index.vue
│   │           └── types.ts
│   │
│   ├── composables/                 # 组合式函数（复用逻辑）
│   │   └── use[Feature].ts
│   │
│   ├── directives/                  # 自定义指令
│   │   └── permission.ts
│   │
│   ├── layouts/                     # 布局组件
│   │   ├── default.vue              # 默认布局（侧边栏 + 顶部导航）
│   │   └── blank.vue                # 空白布局（登录页等）
│   │
│   ├── router/                      # 路由配置
│   │   ├── index.ts                 # 路由实例创建
│   │   ├── guards.ts                # 路由守卫（权限、登录校验）
│   │   └── modules/                 # 按模块拆分的路由
│   │       └── [module].ts
│   │
│   ├── stores/                      # Pinia 状态管理
│   │   ├── index.ts                 # Store 实例导出
│   │   ├── modules/
│   │   │   ├── user.ts              # 用户状态
│   │   │   └── [feature].ts         # 业务状态
│   │   └── plugins/
│   │       └── persist.ts           # 状态持久化（localStorage）
│   │
│   ├── types/                       # 全局类型定义
│   │   ├── global.d.ts
│   │   └── [domain].d.ts
│   │
│   ├── utils/                       # 工具函数
│   │   ├── storage.ts               # localStorage/sessionStorage 封装
│   │   ├── validate.ts              # 表单校验规则
│   │   └── format.ts                # 日期/数字格式化
│   │
│   ├── views/                       # 页面视图
│   │   └── [业务模块]/
│   │       ├── [PageName]/
│   │       │   ├── index.vue
│   │       │   ├── components/      # 页面级子组件
│   │       │   └── types.ts
│   │       └── index.ts             # 模块导出
│   │
│   ├── App.vue
│   ├── main.ts                      # 入口文件
│   └── env.d.ts
│
├── tests/
│   ├── e2e/                         # E2E 测试（Playwright）
│   │   ├── specs/
│   │   │   └── [feature].spec.ts
│   │   └── fixtures/
│   │       └── [data].json
│   └── unit/                        # 单元测试（Vitest）
│       └── [component].spec.ts
│
├── index.html
├── package.json
├── tsconfig.json
├── vite.config.ts
├── playwright.config.ts
├── .env.development
├── .env.production
├── .env.test
├── eslint.config.js
├── prettier.config.js
└── Dockerfile
```

---

## 关键文件模板

### API 请求封装（src/api/core/request.ts）

```typescript
import axios from 'axios';

const request = axios.create({
    baseURL: import.meta.env.VITE_API_BASE_URL,
    timeout: 30000,
});

// 请求拦截器
request.interceptors.request.use((config) => {
    const token = localStorage.getItem('token');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});

// 响应拦截器
request.interceptors.response.use(
    (response) => response.data,
    (error) => {
        // 统一错误处理
        const { response } = error;
        if (response?.status === 401) {
            // 登录过期，跳转登录页
        }
        return Promise.reject(error);
    }
);

export default request;
```

### 路由守卫（src/router/guards.ts）

```typescript
import type { Router } from 'vue-router';

export function setupRouterGuards(router: Router) {
    router.beforeEach((to, from, next) => {
        // 权限校验、登录状态检查
        next();
    });
}
```

---

## 快速开始

```bash
# 1. 安装依赖
pnpm install

# 2. 启动开发服务器
pnpm dev

# 3. 构建生产包
pnpm build

# 4. 运行 E2E 测试
pnpm test:e2e
```

---

## 命名规范

| 类型 | 命名方式 | 示例 |
|------|---------|------|
| 组件文件 | PascalCase | `UserProfile.vue` |
| 组合式函数 | camelCase with `use` prefix | `useAuth.ts` |
| Store | camelCase | `userStore.ts` |
| API 模块 | camelCase | `datasetApi.ts` |
| 页面目录 | kebab-case | `user-profile/` |
| CSS 类名 | BEM | `user-profile__avatar--large` |

---

## 相关规范

- [Vue3 项目结构规范](../tech/tech-spec-vue3.md)
- [前端组件 API 规范](../specs/doc-spec-api-frontend.md)
- [E2E 测试编写规范](../specs/doc-spec-e2e.md)
