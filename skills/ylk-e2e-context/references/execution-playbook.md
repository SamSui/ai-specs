---
title: YLK E2E 通用执行手册
author: 顾小宇
tags: [YLK, E2E, Playwright, CDP, Profile]
description: 单 CDP、Chrome Profile marker、浏览器内请求和多应用导航的通用操作参考。
version: v1.1
last_updated: 2026-08-14
---

# YLK E2E 通用执行手册

## 运行模型

运行文档中的 `$YLK_ROOT` 表示 YLK 项目主目录，默认值为 `~/Codes/ylk`。执行脚本时可通过 `YLK_ROOT` 覆盖该路径。

YLK E2E 公共入口默认连接本机共享 Chrome CDP：

```text
http://127.0.0.1:9225
```

Chrome 使用多个 Profile 隔离登录态。页面不是按打开顺序识别，而是由 `ylk-profile-marker` 在主世界注入：

```js
window.__YLK_PROFILE__
```

典型字段：

```js
{
  environmentId,
  environmentName,
  profileId,
  system,
  host,
  port,
  user
}
```

字段的具体取值和业务含义必须以运行时页面为准。`user` 是自动化审计字段，不是认证或授权凭据；marker 也不是安全证明，页面脚本可以读取或覆盖它。

## 连接和页面选择

优先复用公共入口：

```js
const path = require('node:path');
const {
  connectYlkBrowser,
  findYlkPage,
  findConfiguredYlkPage,
  matchesIdentity,
  navigateYlkPage,
} = require(path.resolve(
  process.env.YLK_ROOT || '.',
  'scripts/playwright-e2e/ylk-profile.cjs',
));

const browser = await connectYlkBrowser();
const { page, identity } = await findConfiguredYlkPage(
  browser,
  '目标页面',
  { system: process.env.YLK_SYSTEM },
);
```

需要显式条件时，按运行时字段筛选：

```js
const { page, identity } = await findYlkPage(
  browser,
  context => matchesIdentity(context, {
    environmentId: process.env.YLK_ENVIRONMENT_ID,
    profileId: process.env.YLK_PROFILE_ID,
    system: process.env.YLK_SYSTEM,
    host: process.env.YLK_HOST,
    port: process.env.YLK_APP_PORT,
  }),
  '目标页面',
);
```

`findYlkPage()` 的 0/1/N 规则是安全边界：

- 0 个匹配：报告 marker 缺失、环境未打开或条件错误，停止。
- 1 个匹配：使用页面并记录确认身份。
- 多个匹配：报告候选身份，继续收窄条件，禁止取第一个或按 Tab 猜测。

常用筛选变量：

```text
YLK_CDP_URL
YLK_ENVIRONMENT_ID
YLK_PROFILE_ID
YLK_SYSTEM
YLK_HOST
YLK_APP_PORT
YLK_USER
```

## 导航规则

从已确认的系统首页进入目标路径：

```js
await navigateYlkPage(page, '/target/path', { waitMs: 3000 });
```

也可以基于运行时页面 origin 构造 URL：

```js
const targetUrl = new URL('/target/path', page.url()).toString();
await page.goto(targetUrl, {
  waitUntil: 'domcontentloaded',
  timeout: 30000,
});
```

对于已经加载的 SPA，优先取得页面内部 router 并执行 `router.replace()` 或 `router.push()`，避免整页刷新丢失动态路由和应用状态。

对于 iframe 或微前端：

1. 先确认宿主页面和目标路由。
2. 等待目标 frame 出现。
3. 在目标 frame 内执行 DOM 操作和局部截图。
4. frame 不存在、加载失败或 execution context 失效时显式失败或标记环境阻塞。
5. 不要对同一个微前端 URL 重复 `goto`，避免销毁 iframe 上下文。

相对路由必须基于已确认的运行时页面的 origin，不使用历史固定 `BASE_URL`。

## 页面内请求

同源且没有额外业务 header 的查询：

```js
const result = await page.evaluate(async path => {
  const response = await fetch(path, { credentials: 'include' });
  const text = await response.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: response.status, data };
}, '/api/example');
```

浏览器原生 `fetch` 会携带同源 Cookie，但不会自动复现业务 axios 拦截器添加的全部 header。返回 401 或客户端信息缺失时：

- 优先触发真实 UI，让应用自己的请求拦截器发请求。
- 必要时从运行时页面运行时上下文派生非敏感 header。
- 用 CDP `Network.enable` 监听请求和响应，生成脱敏摘要。
- 不复制或记录 JWT、Cookie、完整 header、完整 `sessionStorage` 或密码。

不要把任意系统的 `client_id`、realm 或自定义 header 假设成通用值，必须从运行时应用上下文或实际请求契约确认。

API 取证不能替代真实 UI 操作来宣称 E2E 通过。数据库核对不是默认能力，只有实际工具存在时才可执行。

## 历史资料处理

历史 ADR、测试报告和 archive 脚本可以提供流程经验或失败经验，但不能直接作为连接规范。读取时过滤：

- 旧 CDP 端口。
- 固定用户名和固定 IP。
- 固定路由、订单号、主体 ID、金额和签名数据。
- 一次性测试夹具和临时文件路径。
- 过期的系统、Profile、环境和部署映射。

公共运行入口仍以 `scripts/playwright-e2e/` 的代码和 README 为准。数字、环境变量和页面身份应在运行时重新读取。
