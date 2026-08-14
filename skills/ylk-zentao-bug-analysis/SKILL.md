---
name: ylk-zentao-bug-analysis
description: |
  面向 YLK workspace 的禅道 Bug 只读分析技能。从禅道 Bug 单出发，定位截图对应的平台/界面/前端路由/后端接口，追踪前端展示逻辑与后端返回字段逻辑的完整链路，判断问题是否已被指定 ADR 或修复版本覆盖。输出格式为用户故事：背景、现状、影响范围、解决方案，每个问题精确到平台、界面、路由、组件、API 路径、代码行号。
  触发词：禅道bug分析、bug截图分析、bug链路追踪、ADR覆盖判断、bug详情分析、bug根因链路。
author: 顾小宇
version: v1.1
last_updated: 2026-08-14
---

# 禅道 Bug 分析

从禅道 Bug 单出发，做只读代码调查，输出结构化用户故事。核心价值：把模糊的 Bug 截图翻译成"哪个平台、哪个界面、哪条路由、哪个组件、哪个 API、哪行代码"的精确定位，并判断当前代码版本是否已覆盖。

## 适用边界

- **只读调查** → 不修改业务代码、禅道数据、数据库或部署环境
- **输入** → 禅道 Bug ID / 链接 / 截图，或用户直接描述的现象
- **输出** → 用户故事格式的分析报告，精确到平台、界面、路由、组件、API、代码行号
- **不做** → 不修复代码、不提交、不推送、不部署、不写数据库。如需修复，移交 `ylk-evidence-bugfix` Skill
- **依赖** → 可选读取 `ylk-evidence-bugfix` 的 [zentao-cli.md](../ylk-evidence-bugfix/references/zentao-cli.md) 获取禅道 Bug 数据

## 与其他 Skill 的关系

- **获取禅道 Bug 详情和截图** → 本 Skill + `ylk-evidence-bugfix/references/zentao-cli.md`
- **追踪跨仓调用链和根因** → 本 Skill（只读分析）
- **判断 ADR 覆盖范围** → 本 Skill
- **实施修复** → `ylk-evidence-bugfix`
- **授权后交付** → `ylk-delivery`

## Blocker & Escalation Protocol

**STOP and report when** (any one triggers):

- 禅道 API 连续 2 次调用失败或超时
- 无法确认截图对应的平台或路由（grep 无结果）
- 任务范围超出只读分析，需要修改代码或数据
- 不确定当前分支是否包含修复代码

**NEVER do these when blocked**:

- ❌ 凭记忆或推测填写平台、路由、API 路径或代码行号
- ❌ 跳过截图定位，直接假设 Bug 所在链路
- ❌ 把不同链路的修复混为一谈（如数桥登记详情已修不等于中心平台上架记录已修）
- ❌ 输出 Token、密码或敏感配置
- ❌ 在未验证的情况下声称"已解决"

**Instead, do this**:

1. Stop immediately — do not attempt workarounds
2. Report: what failed + what you tried + impact scope
3. Wait for owner to decide the path forward
4. 无法区分链路时，明确标注"待人工确认"，不自行合并

**Self-check** (before completing any analysis):

- 每个 Bug 的平台、界面、路由、组件、API 路径是否都有 grep 确认？
- 是否有凭记忆而非命令确认的内容？
- 是否把不同链路的修复混为一谈？
- 存量数据是否单独说明了？

**Fallback**: 情况不在列表中但感觉不对 → 同样协议，STOP and report。"Not in list" ≠ permission to proceed。

## 强制流程

### 1. 获取 Bug 输入

用户提供禅道 Bug ID 时，按以下顺序获取：

```bash
# 确认 CLI 可用
command -v zentao-cli
zentao-cli auth status

# 读取 Bug 详情（JSON 格式保留完整字段）
zentao-cli bug get <bug-id> --format json > /tmp/bug-<id>.json

# 读取截图（从 steps HTML 中提取 file-read 引用）
python3 -c "
import json
bug = json.load(open('/tmp/bug-<id>.json'))
steps = bug.get('steps', '')
import re
imgs = re.findall(r'file-read-(\d+\.\w+)', steps)
print('截图文件:', imgs)
"
```

CLI 分页限制为 100 条，批量导出需直接调用 REST API：

```bash
curl -sf -H "Token: ${ZENTAO_TOKEN}" \
  "${ZENTAO_URL%/}/api.php/v1/bugs?product=<pid>&project=<projid>&status=all&page=1&limit=100" \
  > /tmp/bugs-page-1.json
```

**已知限制**（来自 `ylk-evidence-bugfix` 踩坑记录）：

- `--assigned-to` 参数不可靠，不能据此判断"指派给我的 Bug"
- CLI 固定分页 100 条，与网页统计可能不一致
- `user me` 可能报 `missing field id`，改用 `user list` 确认账号

### 2. 截图定位

对每张截图，逐一确认：

- **这是哪个平台** → 根据界面布局、菜单、功能名称判断：中心系统 / 海星门户 / 区域前端 / 数桥前端
- **这是哪个界面** → 根据页面标题、Tab 名称、功能区域判断
- **前端路由** → `grep -rn` 搜索路由定义，确认 `path` 和 `name`
- **哪个组件渲染** → 从路由 `component` 字段追踪到 `.vue` 文件
- **展示了哪些字段** → 从组件模板中提取 `v-bind`、`{{ }}`、`:data` 绑定

定位命令模板：

```bash
# 搜索路由定义
grep -rn '<关键词>' src/router/routes/ --include='*.ts'

# 搜索组件引用
grep -rn '<组件名>' src/ --include='*.vue' --include='*.ts'

# 搜索 API 调用
grep -rn '<API路径片段>' src/api-keys/ src/api/ --include='*.ts'
```

### 3. 前端展示逻辑追踪

对截图中每个异常字段，追踪其从 API 响应到 DOM 渲染的完整路径：

```text
API 响应字段 -> 前端变量绑定 -> 模板渲染 -> 用户看到的内容
```

必须记录的各层信息：

- **API 调用** → 函数名、HTTP 方法、URL 路径（含 gateway prefix）
- **响应取值** → `res.data.xxx.yyy` 的完整取值路径
- **变量绑定** → 组件 props / ref / computed 的名称
- **模板渲染** → `{{ }}` 或 `v-bind` 所在文件和行号
- **兜底逻辑** → `v-if` / `v-else` / 默认值 / 空值处理

### 4. 后端接口逻辑追踪

从前端 API 调用路径反查后端完整链路：

```text
前端 API 调用 -> gateway prefix -> Controller @Mapping -> Service 方法 -> 组装/翻译/转换逻辑
```

必须记录的各层信息：

- **前端 API** → 函数名、HTTP 方法、URL（如 `GET /serviceNode/product/publish/approve/$glm_5.2_ark_toC`）
- **Gateway 前缀** → 如 `/serviceNode` -> platform, `/regionNode` -> regional
- **Controller** → 类名、方法名、`@GetMapping`/`@PostMapping` 路径
- **Service** → 实现类名、方法名、行号范围
- **组装逻辑** → 字段来源、合并/覆盖条件、翻译/转换函数
- **持久化** → 数据库表、字段名、是否自动回填

追踪命令模板：

```bash
# 搜索 Controller 映射
grep -rn '@.*Mapping.*<路径片段>' --include='*.java' <backend-repo>/

# 搜索 Service 实现
grep -rn 'public.*<方法名>' --include='*.java' <backend-repo>/

# 搜索字段组装逻辑
grep -n '<字段名>\|set<字段名>\|get<字段名>' --include='*.java' <service-impl-file>
```

### 5. ADR 覆盖判断

对每个 Bug，对照指定 ADR 的修复项逐条判断，每条 Bug 最终结论为以下之一：

| ADR 修复项 | 代码是否已实现 | 链路是否覆盖 | 存量数据是否回填 |
|---|---|---|---|
| D-xx: 修复描述 | ✅/❌ + 代码位置 | ✅/❌ + 原因 | ✅/❌ |

判断规则：

1. **代码已实现** → 在当前分支找到对应修改，记录文件和行号
2. **链路是否覆盖** → Bug 截图对应的链路是否经过修复代码。同一仓库不同链路（如登记详情 vs 版本历史）可能一个已修一个未修
3. **存量数据** → ADR 明确声明不自动回填的，存量错误记录判定为未覆盖
4. **字典值对齐** → 协议发送值与区域字典值不一致时，即使翻译函数存在，实际展示仍可能回退原值

最终结论：

- **已解决** → 代码已修 + 链路已覆盖 + 无存量问题
- **部分解决** → 协议层已修但展示层未覆盖，或部分链路已修其他未修
- **未解决** → 代码未实现或链路完全未覆盖

## 输出格式

### 用户故事模板

```markdown
## 用户故事：<问题域名称>

---

### 背景

<角色>是<项目>的<角色描述>。工作流程是：
1. <步骤1>
2. <步骤2> -> 经<仓库>处理
3. <步骤3> -> 在<平台>查看

<ADR 或修复版本>的目标是<修复目标>。

---

### 问题N：<Bug 标题>（Bug <ID>）

#### <角色>看到了什么

<用自然语言描述截图中可见的异常现象>

#### 哪个平台、哪个界面

- **平台** → <前端仓库名>
- **界面** → <菜单路径 -> 页面/弹窗名称>
- **前端路由** → `<路由路径>`
- **前端组件** → `<组件文件路径>`
- **展示字段** → `<变量绑定路径>`（<文件名>:<行号>）

#### 前端逻辑

<贴出关键代码片段，标注文件和行号>

#### 后端接口

- **前端 API 调用** → `<函数名>()` -> `<HTTP 方法> <URL>`
- **后端 Controller** → `<类名>.<方法名>()` -> `@<Mapping>("<路径>")`
- **后端 Service** → `<实现类名>.<方法名>()`（:<行号>）
- **组装逻辑** → <字段来源、合并/覆盖/翻译逻辑>

#### 根因

<分析根因，贴出关键代码，标注文件和行号>

#### 结论

```text
协议层：<已修复/未修复>
展示层：<已覆盖/未覆盖>（原因）
存量数据：<自动回填/不回填>
最终：<已解决/部分解决/未解决>
```

---

### 影响范围

- **用户角色** → <受影响角色>
- **涉及平台** → <平台列表>
- **后端仓库** → <仓库列表>
- **前端仓库** → <仓库列表>
- **数据范围** → <新数据/存量数据影响>

---

### 解决方案

#### 第一层：<优先级最高的问题>

- <修复项> → <仓库> / <文件:行号> / <修复内容>

#### 第二层：<次优先级问题>

- <修复项> → <仓库> / <文件:行号> / <修复内容>

---

### 一句话总结

> <用一句话概括核心问题和建议>
```

## 质量要求

### 必须做到

1. **每个 Bug 都有平台、界面、路由、组件、API 路径** — 不允许只写"前端展示有问题"
2. **代码引用必须标注文件路径和行号** — 如 `registerInfo.vue:139`，可点击跳转
3. **后端链路必须从 Controller 追踪到 Service 组装逻辑** — 不允许只写"后端返回错误"
4. **ADR 覆盖判断必须区分协议层和展示层** — 协议层已修不等于展示层已覆盖
5. **存量数据必须单独说明** — 不能默认代码修复后存量数据自动正确

### 禁止

1. 禁止凭记忆推断路由、API 路径或代码行号 — 必须 `grep` 确认
2. 禁止把不同链路的修复混为一谈 — 如数桥登记详情已修不等于中心平台上架记录已修
3. 禁止输出 Token、密码或敏感配置
4. 禁止修改任何代码或数据
5. 禁止在未验证的情况下声称"已解决"

## 禅道配置参考

配置文件位于 `/home/openclaw/Codes/ylk/.zentao-cli/config.toml`，结构为 `[default]` 节点：

```toml
[default]
url = "http://172.16.16.1:81/zentao"
token = "<redacted>"
product_id = 50
project_id = 102
account = "guxy"
```

读取配置时注意：

```python
import tomllib
with open('.zentao-cli/config.toml', 'rb') as f:
    cfg = tomllib.load(f).get('default', {})  # 不是 cfg.get('url')
```

## 常见跨仓链路速查

### 中心系统审核详情链路

```text
center-system-frontend
  路由: /audit/product/audit/:id/:productId
  组件: views/audit/productRelease/detail/index.vue
  API:  GET /serviceNode/product/publish/approve/$glm_5.2_ark_toC
        POST /serviceNode/product/regist/detail
        POST /serviceNode/product/publish/detail

datafield-platform
  Controller: DataProductController @RequestMapping("/product")
  Service:    DataProductPublishApproveServiceImpl.approveDetail()
              DataProductRegisterServiceImpl.registDetail()
```

### 海星门户上架记录链路

```text
starfish-home-frontend
  路由: /serviceCenter/dataRegistrationManagement/dataProductRegister/index
  组件: components/release/listTable.vue -> register/versionDialog.vue
  API:  POST /serviceNode/product/history/record

datafield-platform
  Controller: DataProductController @PostMapping("/history/record")
  Service:    DataProductHistoryRecordServiceImpl.registerHistoryRecordInfo()
              DataProductRegisterServiceImpl.compareFile() / extractFileNameSafe()
```

### 区域前端版本管理链路

```text
regional-frontend
  路由: /dataSource -> dataProductIndex
  组件: register/index.vue -> registerRecord.vue -> versionCompare.vue
  API:  POST /regionNode/data-product/dataProductVersionHistory
        POST /regionNode/data-product/register-detail

regional-backend
  Controller: DataProductController @RequestMapping("/data-product")
  Service:    DataProductRegisterServiceImpl.queryProductVersionHistory()
              DataProductRegisterServiceImpl.getRegisterDetail()
              DataProductRegisterServiceImpl.detailDataProductRegisterAudit()
```

### 数桥登记详情链路

```text
datafield-bridge
  Controller: DataProductController (scj-standard)
  Service:    DataProductRegisterServiceImpl (scj-standard)
  工具:       MinioUtil.resolveDataSampleFileName()
```

## 完成自检

1. 每个 Bug 是否都标注了平台、界面、路由、组件、API 路径？
2. 每个代码引用是否都有文件路径和行号？
3. 后端链路是否从 Controller 追踪到了 Service 组装逻辑？
4. ADR 覆盖判断是否区分了协议层和展示层？
5. 是否有不同链路被混为一谈的情况？
6. 存量数据是否单独说明了？
7. 是否有凭记忆而非 grep 确认的内容？
