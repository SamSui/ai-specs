---
title: E2E 测试骨架（Playwright）
author: 顾小宇
tags: [样本, 范例, E2E测试, Playwright]
description: 基于 Playwright 的标准 E2E 测试项目骨架，包含目录结构、测试配置、Page Object 模式和数据驱动测试模板。
---

# E2E 测试骨架（Playwright）

> **⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。**

---

## 技术栈

| 层级 | 技术选型 | 版本 |
|------|---------|------|
| 测试框架 | Playwright | 1.49+ |
| 语言 | TypeScript | 5.x |
| 断言 | @playwright/test 内置 | — |
| 报告 | Playwright HTML Report + Allure（可选） | 最新稳定版 |
| 容器 | Docker（测试执行环境） | 最新稳定版 |

---

## 目录结构

```
[项目根目录]/
├── playwright.config.ts             # Playwright 全局配置
├── package.json
├── tsconfig.json
├── Dockerfile                       # E2E 测试容器镜像
├── docker-compose.e2e.yml           # E2E 测试编排
│
├── src/
│   ├── config.ts                    # 环境配置（URL、超时、重试策略）
│   ├── fixtures/                    # 测试数据
│   │   ├── users.ts                 # 测试用户账号
│   │   ├── datasets.ts              # 测试数据集
│   │   └── [domain].ts              # 业务测试数据
│   │
│   ├── pages/                       # Page Object 模式
│   │   ├── BasePage.ts              # 所有页面的基类（通用方法）
│   │   ├── LoginPage.ts             # 登录页
│   │   ├── [Feature]ListPage.ts     # 列表页（CRUD 通用）
│   │   ├── [Feature]DetailPage.ts   # 详情页
│   │   └── [Feature]FormPage.ts     # 表单页（新建/编辑）
│   │
│   ├── components/                  # 可复用的 UI 组件封装
│   │   ├── DataTable.ts             # 数据表格组件
│   │   ├── Pagination.ts            # 分页组件
│   │   ├── Modal.ts                 # 弹窗组件
│   │   └── Toast.ts                 # 消息提示组件
│   │
│   ├── utils/
│   │   ├── api-helper.ts            # API 辅助（预置数据、清理）
│   │   ├── random-utils.ts          # 随机数据生成
│   │   └── screenshot-utils.ts      # 截图/录屏工具
│   │
│   └── constants/
│       ├── routes.ts                # 路由路径常量
│       ├── selectors.ts             # data-testid 定义
│       └── test-tags.ts             # 测试标签（冒烟/回归/全量）
│
├── tests/
│   ├── auth/
│   │   └── login.spec.ts            # 登录认证测试
│   │
│   ├── [业务模块A]/
│   │   ├── list.spec.ts             # 列表页测试
│   │   ├── create.spec.ts           # 新建测试
│   │   ├── edit.spec.ts             # 编辑测试
│   │   ├── delete.spec.ts           # 删除测试
│   │   └── detail.spec.ts           # 详情页测试
│   │
│   ├── [业务模块B]/
│   │   └── ...
│   │
│   └── smoke/                       # 冒烟测试套件
│       └── critical-path.spec.ts    # 核心业务流程（5-10分钟）
│
└── .env.test                        # 测试环境变量
```

---

## 关键文件模板

### 基础配置（playwright.config.ts）

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
    testDir: './tests',
    fullyParallel: true,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 2 : 0,
    workers: process.env.CI ? 1 : undefined,
    reporter: [
        ['html', { open: 'never' }],
        ['list'],
    ],
    use: {
        baseURL: process.env.FRONTEND_URL || 'http://localhost:3000',
        trace: 'on-first-retry',
        screenshot: 'only-on-failure',
        video: 'retain-on-failure',
    },
    projects: [
        { name: 'setup', testMatch: /.*\.setup\.ts/ },
        {
            name: 'chromium',
            use: { ...devices['Desktop Chrome'], storageState: '.auth/user.json' },
            dependencies: ['setup'],
        },
    ],
});
```

### 环境配置（src/config.ts）

```typescript
export const CONFIG = {
    frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3000',
    apiUrl: process.env.API_URL || 'http://localhost:8080',
    defaultTimeout: 30000,
    navigationTimeout: 10000,
    actionTimeout: 5000,
} as const;
```

### Page Object 基类（src/pages/BasePage.ts）

```typescript
import { Page, Locator, expect } from '@playwright/test';
import { CONFIG } from '../config';

export abstract class BasePage {
    readonly page: Page;
    readonly url: string;

    constructor(page: Page, url: string) {
        this.page = page;
        this.url = url;
    }

    async goto(): Promise<void> {
        await this.page.goto(this.url);
    }

    async expectLoaded(): Promise<void> {
        await expect(this.page).toHaveURL(this.url);
    }

    // 通用等待方法
    async waitForDataTestId(testId: string): Promise<Locator> {
        const locator = this.page.getByTestId(testId);
        await locator.waitFor({ timeout: CONFIG.defaultTimeout });
        return locator;
    }

    // 通用断言方法
    async expectToast(message: string): Promise<void> {
        const toast = this.page.getByTestId('toast-message');
        await expect(toast).toContainText(message);
    }
}
```

### 列表页 Page Object（src/pages/[Feature]ListPage.ts）

```typescript
import { Page, Locator } from '@playwright/test';
import { BasePage } from './BasePage';

export class FeatureListPage extends BasePage {
    readonly searchInput: Locator;
    readonly createButton: Locator;
    readonly dataTable: Locator;

    constructor(page: Page) {
        super(page, '/admin#/feature/list');
        this.searchInput = page.getByTestId('feature-search-input');
        this.createButton = page.getByTestId('feature-create-btn');
        this.dataTable = page.getByTestId('feature-data-table');
    }

    async search(keyword: string): Promise<void> {
        await this.searchInput.fill(keyword);
        await this.searchInput.press('Enter');
    }

    async clickCreate(): Promise<void> {
        await this.createButton.click();
    }

    async getRowCount(): Promise<number> {
        return await this.dataTable.locator('tbody tr').count();
    }
}
```

---

## Locator 优先级规范

E2E 测试中元素定位遵循以下优先级：

1. **data-testid**（最高优先级）
   ```html
   <button data-testid="feature-create-btn">新建</button>
   ```

2. **role + accessible name**
   ```typescript
   page.getByRole('button', { name: '新建' })
   ```

3. **placeholder / label**
   ```typescript
   page.getByPlaceholder('请输入名称')
   ```

4. **CSS 选择器**（最低优先级，仅在无其他方式时使用）

---

## 快速开始

```bash
# 1. 安装依赖
pnpm install

# 2. 安装浏览器
npx playwright install chromium

# 3. 运行全部测试
npx playwright test

# 4. 运行指定模块
npx playwright test tests/feature/

# 5. 运行冒烟测试
npx playwright test --grep @smoke

# 6. 生成报告
npx playwright show-report

# 7. 容器执行（推荐 CI）
docker compose -f docker-compose.e2e.yml up --exit-code-from e2e
```

---

## 测试标签规范

| 标签 | 含义 | 执行频率 |
|------|------|----------|
| `@smoke` | 冒烟测试（核心路径） | 每次部署 |
| `@regression` | 回归测试（全量） | 每日/每版本 |
| `@critical` | 关键业务 | 每次 PR |
| `@flaky` | 不稳定测试（需修复） | 手动 |

---

## 相关规范

- [E2E 测试编写规范](../specs/doc-spec-e2e.md)
- [前端项目骨架](./skeleton-frontend.md)
- [API 文档编写规范](../specs/doc-spec-api.md)
