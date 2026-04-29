---
title: E2E 测试编写与执行规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 宿主机 localhost:{port} └── 反向代理（Caddy/Nginx）
---

# E2E 测试编写与执行规范

> **版本**: v1.0  
> **创建日期**: 2026-04-29  
> **适用范围**: 使用 Playwright 进行端到端测试的项目团队

---

## 1. 测试架构

### 1.1 典型部署架构

```
宿主机 localhost:{port}
  └── 反向代理（Caddy/Nginx）
        ├── /api/*   → 后端服务:{backend_port}
        ├── /admin/* → 前端静态资源:{frontend_port}
        └── /demo/*  → 演示服务:{demo_port}

test-e2e 容器（network_mode: host 或共享网络）
  └── Playwright Chromium 访问 http://localhost:{port}
```

**关键点**：
- E2E 容器通过反向代理访问前后端，模拟真实用户路径
- `network_mode: host` 模式下，容器内 `localhost:{port}` = 宿主机代理

### 1.2 测试分层

| 测试类型 | 覆盖范围 | 执行方式 | 定位 |
|----------|----------|----------|------|
| **单元测试** | 函数/组件 | 本地/CI 快速执行 | 开发阶段 |
| **集成测试** | 模块间接口 | Docker Compose | 构建阶段 |
| **E2E 测试** | 完整用户流程 | Docker Compose + Playwright | 验收阶段 |

---

## 2. 测试文件规范

### 2.1 文件命名

```
tests/e2e/
├── test-{module}-{feature}.spec.ts    # 模块级测试
├── test-loop-{business-flow}.spec.ts  # 业务流程闭环测试
└── README.md                           # 测试目录说明
```

**命名规则**：
- `test-` 前缀 + 模块名 + 功能名
- 业务流程测试使用 `test-loop-` 前缀
- 必须 `.spec.ts` 结尾

### 2.2 文件头部注释

每个测试文件头部必须说明：

```typescript
/**
 * 测试范围: {功能描述}
 * 关键决策: {关联的架构决策/需求编号}
 * 维护人: [测试负责人]
 */
```

---

## 3. Locator 规范

### 3.1 优先级

```
1. data-testid（首选）→ 最稳定，不受文案变更影响
2. role + name → ARIA 语义
3. 文本内容 → 作为兜底
4. ❌ 避免 CSS 选择器/XPath → 易因样式变更失效
```

### 3.2 data-testid 命名规范

```
{页面}-{元素类型}-{动作/含义}
```

| 页面 | data-testid 示例 |
|------|-----------------|
| 数据集列表 | `dataset-table`, `dataset-input-search`, `dataset-btn-search` |
| 系统配置 | `config-page`, `config-btn-save`, `config-btn-reset`, `config-input-*` |
| 表单 | `form-input-{fieldName}`, `form-btn-submit`, `form-btn-cancel` |

**规则**：
- 全部小写，kebab-case
- 全局唯一，同一页面内不重复
- 前端组件必须声明 `data-testid`，禁止 E2E 侧硬编码选择器

### 3.3 Locator 来源

所有前端元素 Locator 必须先查项目 `specs/FE-ROUTES.md`（或等效文档）中定义的 Locator 清单：

```
SPEC-ROUTES.md 定义的 Locator > 硬编码选择器
```

发现差异立即上报更新。

---

## 4. API 端点规范

### 4.1 端点来源

所有 API 端点必须查项目 `specs/BE-APIS.md`（或等效文档）：

```
specs/BE-APIS.md 定义的端点 > 前端代码中的调用路径
```

### 4.2 断言规范

```typescript
// ✅ 正确：验证状态码 + 响应体结构
const response = await request.get('/api/v1/datasets');
expect(response.status()).toBe(200);
const body = await response.json();
expect(body.code).toBe(0);
expect(body.data).toBeInstanceOf(Array);

// ❌ 错误：只验证状态码
expect(response.ok()).toBeTruthy();

// ❌ 错误：硬编码断言具体数据值（易因测试数据变化失败）
expect(body.data[0].name).toBe('特定数据集名称');
```

---

## 5. 测试环境配置

### 5.1 Playwright 配置要点

```typescript
// config.ts
export default defineConfig({
  testDir: './e2e',
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://localhost',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
```

### 5.2 认证绕过模式

E2E 测试不应依赖真实登录流程，推荐以下方式：

```typescript
// 方式一：通过 API 提前创建会话 Cookie
await page.context().addCookies([{
  name: 'JSESSIONID',
  value: await createTestSession(),
  domain: 'localhost',
  path: '/',
}]);

// 方式二：通过特殊 Header 注入虚拟身份
// 后端在 test profile 下识别 X-E2E-SESSION 并构造虚拟用户
```

### 5.3 环境变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `E2E_BASE_URL` | 测试目标地址 | `http://localhost` |
| `TESTING_ENTRYPOINT` | 指定运行的测试文件 | `test-login.spec.ts` |
| `SPRING_PROFILES_ACTIVE` | 后端测试 profile | `test` |

---

## 6. 常见陷阱

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `waitForLoadState("networkidle")` 卡住 | SPA 中该方法永不完成 | 改用 `domcontentloaded` 或自定义等待条件 |
| 前端 404 | 静态资源未构建或容器未启动 | 检查前端容器日志和 dist 目录 |
| API 404 | 后端路由变更未同步 | 对照 `BE-APIS.md` 更新测试 |
| 测试不稳定（flaky）| 异步数据加载未等待 | 使用 `await expect(locator).toBeVisible()` 代替 `sleep` |

---

## 7. 检查清单

- [ ] 所有 Locator 使用 `data-testid` 或语义化选择器
- [ ] 所有 API 端点与 `BE-APIS.md` 对齐
- [ ] 每个测试有独立的测试数据准备和清理
- [ ] 不使用 `waitForTimeout` / `sleep` 进行等待
- [ ] 测试失败时自动生成截图和 trace
- [ ] 新增/修改测试后，在 CI 中全量运行验证

---

*版本: v1.0 | 最后更新: 2026-04-29*
