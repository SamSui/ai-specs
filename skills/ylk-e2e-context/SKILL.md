---
name: ylk-e2e-context
description: |
  面向 YLK workspace 的通用 Playwright/CDP E2E 背景与执行技能。用于给接口取证、页面操作、跨系统联动、业务流程验证、E2E 脚本适配或测试失败分析注入浏览器 Profile、页面 marker、SPA/iframe 导航、浏览器内请求、证据留存和副作用控制知识；优先复用现有 E2E 入口，不写临时裸 CDP 操作或复制凭据。
  触发词：YLK E2E、Playwright、CDP 浏览器、浏览器身份、Profile marker、浏览器 fetch、带 token 的 curl、跨系统联动、页面自动化、E2E 适配、E2E 失败分析。
author: 顾小宇
version: v1.1
last_updated: 2026-08-14
---

# YLK E2E Context

本 Skill 只提供 YLK 浏览器自动化基础设施的通用上下文，不描述任何特定 ADR、业务产品、订单、资源、接口或金额。它负责页面定位、导航、请求取证、证据边界和副作用控制，不替代业务测试规范、Bug 修复流程或交付流程。

路径约定：`YLK_ROOT` 表示 YLK 项目主目录，默认值为 `~/Codes/ylk`。以下文档中的 `$YLK_ROOT` 均指向该目录。

## Source Of Truth

按以下优先级确认事实：

1. 运行时浏览器页面和可复核的环境状态。
2. `$YLK_ROOT/scripts/playwright-e2e/` 中的公共入口、README 和测试框架实现。
3. Agent memory、Beads memory 和项目 `CLAUDE.md/AGENTS.md`。
4. ADR、历史报告和 archive 脚本，仅作为经验参考。

历史资料中的端口、用户名、IP、路由、业务对象和一次性数据不能覆盖运行时事实。发现冲突时，报告冲突并以运行时代码和可复核环境证据为准。

## 适用边界

- **背景注入**：用户要求补充 YLK E2E、浏览器环境、页面自动化、跨系统测试或历史经验时，读取本 Skill 的 references。
- **接口取证**：用户想用带认证信息的命令行请求查询已登录系统时，优先在正确的已登录页面内发起同源请求或通过真实 UI 触发请求。
- **页面操作**：用户要求点击、输入、导航、筛选、确认或验证页面时，复用现有 E2E 入口和公共页面选择器。
- **跨系统联动**：用户要求在多个前端、节点或微应用之间完成流程时，按页面身份分步执行并逐步核对结果。
- **脚本适配**：用户要求保留原测试语义、只移除硬编码时，修改现有 E2E 脚本，不用一次性 Node 片段替代正式入口。

执行 E2E 时识别并记录实际发生的业务副作用，以及尚未执行的步骤。

## 强制规则

### 1. 单 CDP，先选 Profile 再选页面

公共入口默认连接本机 CDP：

```text
http://127.0.0.1:9225
```

必须使用 `chromium.connectOverCDP()`，优先复用：

```js
const {
  connectYlkBrowser,
  findYlkPage,
  findConfiguredYlkPage,
  matchesIdentity,
  navigateYlkPage,
} = require('$YLK_ROOT/scripts/playwright-e2e/ylk-profile.cjs');
```

页面主世界由 `ylk-profile-marker` 注入：

```js
const identity = await page.evaluate(() => window.__YLK_PROFILE__ ?? null);
```

页面选择必须使用 marker 中的稳定字段，例如环境、应用系统、Profile、host 和 port。匹配结果必须严格为 1 个：

- 0 个：报告 marker 缺失、环境未打开或筛选条件错误，停止该分支。
- 1 个：使用该页面并记录确认身份。
- 多个：报告候选身份，缩小筛选范围，禁止猜测。

禁止根据 BrowserContext 序号、Tab 顺序、窗口标题、水印文字、旧 CDP 端口或固定用户名判断身份。marker 中的 `user` 只用于审计和可选筛选，不是认证或授权依据。

### 2. 页面导航必须尊重应用类型

- 从自动打开的系统首页进入目标路由：使用公共导航 helper 或运行时页面 origin。
- 已加载的 SPA 页面：优先使用页面内部 router，避免整页刷新破坏动态路由和登录态。
- iframe 或微前端页面：先确认宿主页面，再定位目标 frame；frame 不存在或执行上下文失效时必须显式失败或标记为环境阻塞。
- 不对同一个微前端 URL 无意义地重复 `goto`，避免销毁 iframe execution context。
- 相对路由基于已确认的运行时页面的 origin 构造，不回退到历史固定 `BASE_URL`。
- 记录截图时区分宿主页面和嵌入页面，不能把宿主壳页误当成业务内容页。

### 3. 浏览器内请求优先于手工复制凭据

当任务是“命令行请求需要 token/header”时，先判断接口是否能从已登录页面同源访问：

```js
const result = await page.evaluate(async ({ path, init }) => {
  const response = await fetch(path, {
    credentials: 'include',
    ...init,
    headers: { ...(init?.headers || {}) },
  });
  const text = await response.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: response.status, data };
}, { path: '/api/example', init: { method: 'GET' } });
```

浏览器原生 `fetch` 会携带同源 Cookie，但不会自动复现业务 axios 拦截器添加的全部 header。若返回 401 或缺少客户端信息：

1. 优先触发真实 UI，让应用自己的请求拦截器发起请求。
2. 或从运行时页面运行时上下文派生非敏感 header，在页面内请求。
3. 需要调查请求契约时，用 CDP `Network` 监听并生成脱敏摘要。
4. 不要把 JWT、Cookie、完整 `sessionStorage`、完整请求 header 复制到对话、文件、Beads 或证据报告。

API 调用用于取证和状态核对，不能替代真实 UI 操作来宣称 E2E 通过。数据库证据不是默认能力；只有实际工具存在时，才可以进行只读 DB 核对。

### 4. 跨系统流程按阶段闭环

跨页面、跨应用或跨用户流程先建立抽象流程表：

```text
业务动作 -> 操作页面/身份 -> 请求或事件 -> 目标页面/系统 -> 可观察结果 -> 证据
```

每个阶段都执行：

1. 确认页面身份和运行时路由。
2. 执行真实 UI 操作，必要时用页面内请求辅助读取状态。
3. 等待 DOM、路由、消息、网络响应或下一页面等可观察结果。
4. 用 API 或可用的只读数据源核对操作前后关键字段和跨系统状态。
5. 记录阶段结果后再决定是否进入下一阶段。

页面身份必须逐阶段重新确认，不因前一阶段使用了某个 Profile 就默认沿用。不同角色、环境和应用必须依据运行时 marker 分别选择页面。

流程中应记录每个阶段实际发生的副作用、外部依赖和未执行步骤。现有 runner 没有通用的副作用 deny-list、confirm hook 或 dry-run 机制；本 Skill 只要求结果表达准确，不把文档约定描述成代码能力。

### 5. 数据依赖与代码缺陷分开判断

遇到页面无数据、按钮不可用、列表为空、请求失败或状态不符时，先区分：

- 环境/登录态：CDP 连接失败、marker 缺失、认证过期或页面被重定向。
- 页面实现：路由、DOM、事件、iframe、请求或响应错误。
- 测试数据：前置对象、状态、权限或配置不满足要求。
- 外部流程：异步任务、人工审核、第三方回调或客户端未完成。

报告必须写明“E2E 失败，原因为数据依赖”“环境阻塞，未能完成验证”或“实现缺陷”，不能把未执行、弱断言或数据阻塞写成通过。

## 可复用应用模式

### 模式 A：认证请求转浏览器取证

选择唯一 Profile 页面后，在页面上下文内执行同源查询或由真实 UI 触发请求。只返回脱敏状态、业务字段和响应摘要。

### 模式 B：固定脚本改为环境自适应

扫描脚本中的旧 CDP 端口、固定 IP、固定用户名、固定 URL、Tab 序号和标题判断。将身份选择迁移到公共页面选择器，将导航改为运行时页面 origin 或应用 router，保留原测试步骤和断言语义。

### 模式 C：跨页面 UI 联动

将人工流程拆成可观察阶段。每阶段使用对应身份的确认页面，读取 DOM/API 状态后再进入下一阶段；对写入、审批、签署、支付、交付或导出等动作记录实际结果、外部依赖和未执行步骤。

### 模式 D：真实 UI + 状态源双向验证

UI 证明用户路径真实可用，API 或可用的只读数据源证明关键字段、状态、时间、金额、规格或对象 ID 正确。不要只看页面提示或 HTTP 200。

### 模式 E：失败证据收集

每条用例至少保留步骤、明确的 `passed/reason`、脱敏网络摘要、失败现场截图，以及实际确认的 marker 身份字段。证据不包含令牌。

## 与其他 YLK Skills 的关系

- **E2E 背景、浏览器操作、跨系统联动** → 本 Skill
- **从 Bug 单只读定位代码链路** → `ylk-zentao-bug-analysis`
- **实施 Bug 修复、补测试、部署验证** → `ylk-evidence-bugfix`
- **架构决策、知识沉淀和验证归档** → `ylk-adr`
- **commit、push、CI/CD、部署** → `ylk-delivery`

本 Skill 不负责新增业务测试设计、Bug 修复、架构决策或交付操作；出现这些需求时转交对应 Skill。

## 完成前自检

- [ ] 使用配置的 CDP 和公共页面选择器，没有引入旧端口或裸 WebSocket CDP。
- [ ] 页面身份来自 marker，匹配结果严格为 1 个。
- [ ] 没有把固定用户名、Tab 顺序、标题或水印当作身份依据。
- [ ] 相对路由基于已确认的运行时页面，SPA/iframe 使用正确导航方式。
- [ ] API 请求未泄露 JWT、Cookie、完整 sessionStorage 或完整 header。
- [ ] UI 操作与 API/只读数据核对边界清楚，没有 API-only 假 E2E。
- [ ] 数据依赖、环境阻塞、实现缺陷和未执行项已区分。
- [ ] 已记录实际发生的写入、审批、签署、支付、交付、删除和部署副作用，以及未执行步骤。
- [ ] Skill 或报告中没有混入特定 ADR、业务产品、订单、资源、金额或一次性环境数据。

## References

按场景读取：

- 连接、Profile marker、导航和浏览器内请求 → [execution-playbook.md](references/execution-playbook.md)
- 证据、跨系统核对、数据夹具和副作用控制 → [evidence-and-side-effects.md](references/evidence-and-side-effects.md)
- 公共脚本入口 → `$YLK_ROOT/scripts/playwright-e2e/README.md`
- 页面选择实现 → `$YLK_ROOT/scripts/playwright-e2e/ylk-profile.cjs`
