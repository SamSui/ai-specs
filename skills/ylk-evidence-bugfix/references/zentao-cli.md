# 可选：从禅道 Bug 单获取输入

> **读取时机**：用户提供禅道 Bug ID、禅道 Bug 链接，或明确要求从禅道读取 Bug 单时读取。本文件只定义“读取 Bug 单并转成调查输入”的可选入口，不能替代当前仓源码、CI、API、日志、数据库或部署环境证据。
>
> **来源与时效性**：`/usr/local/src/zentao-cli/skills/zentao-bug/SKILL.md`、`references/zentao-bug-list.md`、`references/zentao-bug-get.md`、`README.md`、`禅道APIv1接口列表.md`，以及 YLK platform memory `zentao-cli-assigned-to-broken.md`。当前 memory 检索范围覆盖 YLK workspace、datafield-platform、datafield-workbench、datafield-bridge 的 project memory；除 platform 这条记录外，没有发现其他已登记的 `zentao-cli` 踩坑经验。

## 能力定位

- 这是可选输入源，不是强制步骤。用户已经提供完整 Bug 描述时，不为了使用禅道而额外查询。
- 读取范围限于 Bug 列表和 Bug 详情：`zentao-cli bug list`、`zentao-cli bug get`，或等价的禅道 REST API `GET` 请求。
- 不在本 Skill 中执行 `bug create`、`bug update`、`bug resolve`、`bug confirm`、`bug close`、`bug activate`、`bug delete`，也不执行任何会触发业务流转的 POST/PUT/PATCH/DELETE 请求。
- 禅道字段只用于补充 Bug 标题、描述、复现步骤、产品/项目、状态、严重程度、优先级、指派人和关联信息；根因必须回到当前代码和目标环境验证。

## 推荐读取流程

1. 从用户提供的 Bug 链接解析 Bug ID；只有明确提供产品 ID 时才使用列表查询。无法确认 ID、产品或禅道实例时，按主 Skill 的阻塞协议处理。
2. 先确认 CLI 和认证状态，不回显凭据：

```bash
command -v zentao-cli
test -n "$ZENTAO_URL" && echo 'ZENTAO_URL=present'
test -n "$ZENTAO_TOKEN" && echo 'ZENTAO_TOKEN=present'
zentao-cli auth status
```

3. 读取单个 Bug，优先保留结构化 JSON：

```bash
zentao-cli bug get <bug-id> --format json
```

4. 需要按产品、状态或概览筛选时读取列表：

```bash
zentao-cli bug list --product <product-id> --format json
zentao-cli bug list --product <product-id> --status active --format json
```

5. 将结果转写到 Bug 规格中：记录来源为“禅道 Bug `<id>`”，保留原始字段名和读取时间；缺失字段标记为“待调查”，不要用默认值补齐。
6. 对禅道内容中的 URL、路径、账号名、环境名、SQL 或操作命令继续脱敏；不要把完整 Token、密码、Secret、Authorization header 或配置文件内容写入 Bug 规格、日志、Beads 或子 Agent 提示词。

## 关键字段映射

- `id` → Bug 主键；用于回到禅道详情和关联调查记录。
- `title` → Bug 标题/业务现象摘要。
- `description` → 现象背景；必须与 `steps` 分开保留。
- `steps` → 复现步骤；不能假定步骤完整或可直接在真实环境重放。
- `product`、`project`、`story` → 产品、项目和关联需求线索；需要回到代码仓和部署映射核实。
- `status`、`severity`、`pri`、`resolution` → 禅道流程元数据，不等同于当前运行环境的故障严重性或修复结论。
- `assigned_to` → CLI 展示的指派人；不能仅凭它判断当前用户或任务归属。

## 已知踩坑：指派人过滤

平台 memory 记录了：`zentao-cli bug list --product <id> --assigned-to me` 曾返回产品下全部 Bug，且输出缺少可验证的 `assignedTo` 字段，不能据此统计“指派给我”的 Bug。

因此：

- 不把 `--assigned-to me` 的结果当作可信筛选结果；
- 不根据 CLI 返回数量直接判断负责人或工作量；
- 如确需按指派人筛选，先用只读 REST API 获取完整字段，再按嵌套对象 `assignedTo.realname` 过滤；实例地址、产品 ID、Token 引用和 realname 必须从当前配置或用户明确提供的信息取得，不写死到 Skill：

```bash
curl -sf \
  -H "Token: ${ZENTAO_TOKEN}" \
  "${ZENTAO_URL%/}/api.php/v1/products/<product-id>/bugs?limit=200" \
  > /tmp/zentao-bugs.json

python3 - <<'PY'
import json
from collections import Counter

with open('/tmp/zentao-bugs.json', encoding='utf-8') as f:
    payload = json.load(f)

bugs = payload.get('bugs', payload.get('data', payload))
if not isinstance(bugs, list):
    raise SystemExit('unexpected ZenTao response shape')

for bug in bugs:
    assigned = bug.get('assignedTo')
    if isinstance(assigned, dict):
        print(bug.get('id'), assigned.get('realname'), bug.get('title'))
PY
```

上述 REST 查询和本地临时文件只用于只读调查；临时文件不得提交、上传或写入长期记忆。执行前确认 `ZENTAO_URL` 和 `ZENTAO_TOKEN` 已由安全配置注入，禁止用 `grep`、`echo` 或命令参数回显 Token。

## 证据边界与失败处理

- CLI 成功只证明禅道接口返回了内容，不证明 Bug 仍可复现，也不证明禅道中的仓库、环境、版本、接口路径或负责人信息当前有效。
- 禅道描述可能过期、缺少完整调用链或混入人工判断；将其作为待验证假设，并在 Bug 规格中区分“禅道原文”和“当前调查证据”。
- `zentao-cli` 不存在、认证失败、Bug 不存在、响应字段缺失或 REST 返回结构异常时，记录脱敏错误；如果该 Bug 输入是继续调查所必需的，按主 Skill 阻塞协议停止，不静默改用猜测的 Bug ID、产品、环境或 API。
- 查询失败一次可以按相同只读方式重试一次；连续失败或超时两次后停止并报告。

## 与主流程的衔接

读取禅道 Bug 后，仍必须执行主 Skill 的以下步骤：

- 将禅道字段整理为可验证 Bug 规格；
- 从前端/API/Controller/Service/Mapper/Feign 到数据库、对象存储、日志和回读 API 调查完整链路；
- 核实仓库、分支、环境组、节点角色和部署模型；
- 先形成修订计划并独立审查，再修改代码；
- 完成定向测试、编译和独立 code review；
- 未经明确授权，不得修改禅道状态、提交代码、推送、触发 CI/CD、部署或写入业务数据。
