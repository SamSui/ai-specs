# 本机 Playwright 调试配置

本文件是 `ylk-evidence-bugfix` 的本机私有 overlay，只记录当前机器的 Playwright/CDP 调试端口。需要浏览器调试或本机 MCP 端口时读取；环境组、SSH-MCP IP、节点角色、部署拓扑和通用调查规则见 [YLK 环境访问与节点矩阵](references/ylk-environment-access.md)。本文件不能替代实时浏览器进程检查。

## 当前机器 Playwright 调试端口

- `mcp__playwright-9228` → CDP endpoint `http://127.0.0.1:9228`
- `mcp__playwright-9229` → CDP endpoint `http://127.0.0.1:9229`
- `mcp__playwright-9231` → CDP endpoint `http://127.0.0.1:9231`
- 长期运行 Chromium → remote debugging port `9235`，当前监听 `127.0.0.1:9235`
- `mcp__chrome-devtools` → 独立 DevTools MCP，不在当前 Playwright CDP 端口矩阵中

端口属于本机调试工具，不是 YLK 业务环境端口；不能把 `9228`、`9229`、`9231` 或 `9235` 当作远程服务端口。

## 私有文件规则

- 本文件不可复制到项目仓库、Beads、测试、Issue、对话或子 Agent 提示词。
- NEVER 在本文件写入或回显 Token、密码、私钥、完整连接串、K8s Secret、CI variables 或数据库凭据。
- 若 Skill 被复制到 Git 仓库，必须将 `custom.md` 加入该仓 `.gitignore`，并在提交前确认 `git check-ignore -v custom.md`。
