---
title: 新机器初始化清单
author: 顾小宇
tags: [新机器, 初始化, 工具链, SSH-MCP]
description: 新机器或 Skill 迁移时的安装自检、workspace 获取与访问核验初始化清单。
version: v1.0
last_updated: 2026-08-14
---

# 新机器初始化清单

> 来源与时效性：见 [来源与时效性](sources-and-freshness.md)。**读取时机**：新机器、Skill 迁移、SSH-MCP/工具链变化或连接映射缺失时读取。本文件只定义初始化过程；当前机器的 Playwright/CDP 配置写入同级 `../custom.md`，通用 SSH-MCP IP 和环境矩阵见 [YLK 环境访问与节点矩阵](ylk-environment-access.md)。**不能替代**：当前 SSH-MCP `list-servers`、目标节点只读探测和 Owner 对环境决策的明确回答。

## 1. 安装与能力自检

1. 确认 Claude Code 能发现用户级 Skill，并检查是否可调用独立 Agent、`AskUserQuestion` 与 SSH MCP：

```bash
claude --version
find ~/.claude/skills/ylk-evidence-bugfix -maxdepth 2 -type f -print
```

2. 无独立 reviewer/executor 时，开始前说明无法满足独立计划审查和 code review 门禁。
3. 安装或配置 `kubectl`、SSH MCP、`glab` 与数据库只读访问；凭据通过密码管理、SSH agent、`~/.ssh/config`、`glab` host config、环境变量或 secret manager 注入。
4. 不得把 Token、密码、私钥、完整 JDBC URL、K8s Secret 内容或 CI variable 写进 Skill、`custom.md`、Git、Beads 或对话。

## 2. 获取 workspace 与资料

1. 获取 YLK workspace 与所需子仓。
2. 在 workspace 根确认 `CLAUDE.md`、`AGENTS.md`、`docs/README.md` 和 `.beads/`。
3. 执行：

```bash
bd where
bd prime
bd memories
```

`bd where` 未找到数据库时，确认 workspace 根或 `BEADS_DIR`；NEVER 在子仓随意 `bd init` 新建孤立数据库。

## 3. 创建或维护本机配置与通用环境 reference

`custom.md` 是 `ylk-evidence-bugfix` 目录内的本机私有 overlay，只维护当前机器的 Playwright/CDP 调试端口。三套环境的 SSH-MCP IP、五节点矩阵、部署模型和通用访问规则维护在 [YLK 环境访问与节点矩阵](ylk-environment-access.md)。

新机器 bootstrap 时，先读取该 reference，再用 SSH-MCP `list-servers` 更新其中的连接和 IP；不得把不同环境或不同节点混用。

**先自动收集，不猜测：**

```bash
git remote get-url origin | sed -E 's#(https?://)[^/@]+@#\1<redacted>@#'
kubectl get deploy -A 2>/dev/null
```

可用 SSH MCP 时，以只读 `hostname`、`command -v kubectl`、`command -v docker`、`docker compose ls` 或 `kubectl get deploy -A` 识别环境角色和部署模型。通用连接、IP 和五节点矩阵记录在 `ylk-environment-access.md`；`custom.md` 只记录本机 Playwright/CDP 端口。

**需要 Owner 决策或提供信息时：**必须调用 `interview` Skill 的 `AskUserQuestion`，不使用自然语言猜测式追问。问题正文必须包含：

- 问题：待确认的一个环境配置项；
- 背景：它影响的调查或回归范围；
- 原因：当前无法从只读证据获取的内容；
- 建议：推荐的最小配置；
- 适用规范：`ylk-evidence-bugfix` 的“启动与本机配置”；若无 0 号文档，明确写“无项目 0 号文档，使用本 Skill”；
- 交付验收：必须或可选；
- 过度设计：是或否及理由。

不要用 AskUserQuestion 收集秘密字面量。需要凭据时，让 Owner 在本机既有秘密管理或环境变量中配置，并只记录其**引用名**。

## 4. 启动时必须核对

任何调查前：

```bash
pwd
git status --short --branch
git remote get-url origin | sed -E 's#(https?://)[^/@]+@#\1<redacted>@#'
git branch --show-current
```

远程动作前，以 `ylk-environment-access.md` 中选定的 SSH-MCP connection 验证 `hostname; date -Is`。数据库查询前说明环境、数据库、表、样例主键和字段，只执行只读查询；不得夹带 `INSERT`、`UPDATE`、`DELETE`、DDL 或业务触发接口。

## 5. 适配未知子项目

先从当前仓的 CI、README 与项目根读取真实构建/部署信息。多模块 Maven 必须从主项目根执行 `./mvnw -pl <module> -am ...`，不得进入子模块运行 Maven。具体优先级和命令规则见 [SKILL.md](../SKILL.md#maven-构建发现与执行规则)。实际目录、模块、JDK、profile 与部署方式以当前仓 CI 和环境为准。
