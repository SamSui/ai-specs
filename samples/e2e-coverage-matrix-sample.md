---
title: E2E 测试覆盖报告 V2
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 日期: 2026-04-26 依据: M3.2 全量三端审计 + M3.2 验收清单
---

# E2E 测试覆盖报告 V2

**版本**: v2.0
**日期**: 2026-04-26
**依据**: M3.2 全量三端审计 + M3.2 验收清单

---

## 一、设计原则

### 1.1 测试分层

```
Browser E2E（Playwright）  ← 用户真实操作，验证UI交互
    ↓
API E2E（Playwright request） ← 验证后端API契约，不依赖UI
```

### 1.2 覆盖范围

| 层级 | 覆盖范围 | 文件前缀 |
|------|---------|---------|
| 基座能力 | 登录、菜单、权限、系统配置 | test-m27-* / test-system-api |
| **数据集治理闭环** | 数据集CRUD → 数据源接入 → 治理配置 → ETL执行 → 算法调用 → 报告生成 | test-loop-* |
| **演示大厅** | 文本/图像/音频/视频/元数据提取 | test-demo-hall |
| **算法注册** | Registry服务发现 + 算法直调链路 | test-algo-registry |

### 1.3 旧版E2E归档

以下E2E脚本已归档到 `tests/e2e/archived/`，原因：

| 归档文件 | 归档原因 |
|---------|---------|
| test-m2-*.spec.ts（6个） | API路径与后端实际路径不一致，需重建 |
| test-m3-*.spec.ts | 路径错误+架构变更，需重建 |
| test-us-*.spec.ts（8个） | 基于旧版前端逻辑，需按新架构重建 |
| test-f*.spec.ts（2个） | 直调Python端点，违反FE→BE→Registry→AL架构 |
| debug-*.spec.ts（4个） | 调试脚本，无需保留 |

---

## 二、新版E2E清单

### 2.1 基座能力（保留不动）

| 文件 | 场景数 | 覆盖内容 | 状态 |
|------|--------|---------|------|
| `test-m27-login.spec.ts` | 5 | 用户登录/Session管理 | ✅ 已有 |
| `test-m27-system-admin.spec.ts` | 8 | 菜单管理/权限配置/角色管理 | ✅ 已有 |
| `test-system-api.spec.ts` | 31 | 系统管理API（auth/users/roles/menus/dicts/configs）| ✅ 已有 |

### 2.2 数据集治理闭环（新写）

| 文件 | 场景数 | 覆盖内容 | 对应验收清单 |
|------|--------|---------|------------|
| `test-loop-dataset.spec.ts` | 7 | 数据集CRUD + 列表/详情/删除 | P0-5 |
| `test-loop-datasource.spec.ts` | 8 | 数据源列表/创建/测试连接/启动同步/SyncTask | P0-3+P2 |
| `test-loop-governance.spec.ts` | 6 | 治理配置8项 + 保存 + 持久化验证 | P0-6+P5 |
| `test-loop-etl.spec.ts` | 9 | ETL流水线创建/步骤配置/执行/SyncRecord | P0-1+P0-2+P6 |
| `test-loop-quality-report.spec.ts` | 10 | 治理报告Tab/步骤汇总/异常/去重/导出（无六维度/对比报告）| P0-4+P4+P7 |
| `test-loop-metadata-scan.spec.ts` | 5 | 元数据扫描触发/状态查询/文件元数据更新获取 | P0-03 |

**闭环链路覆盖**: ✅ 全链路 7个节点全覆盖

### 2.3 演示大厅（新写）

| 文件 | 场景数 | 覆盖内容 | 对应验收清单 |
|------|--------|---------|------------|
| `test-demo-hall.spec.ts` | 17 | 文本处理(含P5三项配置)/图像/音频/视频/元数据提取 | P1-3~P1-7+P3 |

### 2.4 算法服务（新写）

| 文件 | 场景数 | 覆盖内容 | 对应验收清单 |
|------|--------|---------|------------|
| `test-algo-registry.spec.ts` | 12 | Registry注册/服务发现/5个算法直调/text-purify 4项子能力 | P0-1+P1-1+P1-2 |

---

## 三、覆盖率矩阵

| 验收清单节点 | E2E覆盖文件 | 场景数 |
|------------|-----------|--------|
| 数据集创建 | test-loop-dataset | 7 |
| 数据源接入 | test-loop-datasource | 8 |
| 治理配置（8项） | test-loop-governance | 6 |
| ETL执行 | test-loop-etl | 9 |
| 算法调用（Registry）| test-algo-registry | 12 |
| 质量报告 | test-loop-quality-report | 10 |
| 演示大厅-文本 | test-demo-hall | 6 |
| 演示大厅-图像 | test-demo-hall | 2 |
| 演示大厅-音视频 | test-demo-hall | 4 |
| 演示大厅-元数据 | test-demo-hall | 2 |
| 元数据扫描 | test-loop-metadata-scan | 5 |
| **总计** | **7个新文件** | **~71** |

---

## 四、fixme预期（部署后需验证）

| fixme场景 | 根因 | 预计解决方式 |
|---------|------|------------|
| 演示大厅页面路由不存在 | FE路由未创建 | FE补充demo-hall路由 |
| DemoController端点404 | P3 DemoController未部署 | 部署验证 |
| 质量报告API返回500 | P4修复未生效 | 重新编译+部署 |
| RegistryController需认证 | @PreAuthorize拦截 | 调整安全配置或携带Token |
| text-purify子能力返回原文本 | AL算法未实现 | 补充Python算法 |
| ETL流水线页面不存在 | 前端无ETL Tab | FE创建ETL管理页面 |

---

## 五、运行方式

```bash
cd tests/e2e

# 全部E2E（基座 + 闭环 + 演示大厅 + 算法）
npx playwright test

# 仅数据集治理闭环
npx playwright test test-loop-*.spec.ts

# 仅演示大厅
npx playwright test test-demo-hall.spec.ts

# 仅算法Registry
npx playwright test test-algo-registry.spec.ts

# 仅基座能力
npx playwright test test-m27-*.spec.ts test-system-api.spec.ts
```

---

## 六、编写规范（遵守）

来自 `deployment/LEARNING.md` + 工程实践：

### 选择器优先级（强制）
1. `getByRole(role, { name })` — P0，最稳定
2. `getByTestId(testId)` — P1，需前端配合
3. `getByLabel(label)` — P2
4. `page.locator('css')` — P3，仅兜底

### 禁止选择器
- `.el-card`, `.el-form`, `.el-table`（Element Plus内部class，重构易变）
- `.system-config`, `.dataset-list`（语义模糊）
- XPath绝对路径

### 等待规范
```typescript
// ✅ 正确
await page.waitForLoadState('domcontentloaded')
await page.waitForTimeout(6000)  // SPA动态路由加载
await page.waitForTimeout(2000)  // 普通操作后等待

// ❌ 禁止
await page.waitForLoadState('networkidle')  // SPA永不完成
```

### fixme规范
```typescript
test.fixme('原因说明', async ({ page }) => {
  // 如果修复后，取消skip直接运行
})
```

---

*报告生成：[架构师]*
*生成时间：2026-04-26 10:52*
