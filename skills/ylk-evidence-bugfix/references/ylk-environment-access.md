---
title: YLK 环境访问与节点矩阵
author: 顾小宇
tags: [YLK, 环境访问, SSH-MCP, 节点矩阵]
description: YLK 环境组、SSH-MCP IP 基线与节点角色的访问核验规则。
version: v1.0
last_updated: 2026-08-14
---

# YLK 环境访问与节点矩阵

> **读取时机**：选择 YLK 环境、节点角色、SSH-MCP connection、区域/海星/数桥部署模型或远程调查入口时读取。**不能替代**：当前 `list-servers`、目标节点 `hostname`/时间核验、实时 K8s/Compose 资源和运行日志。
>
> 本文件是当前机器已登记的环境导航参考，不是当前实时状态。下列环境组、节点角色和部署模型只是候选基线；IP、连接状态、hostname、节点数量、部署模型、部署版本和服务状态需要在使用前重新核验。

## 已登记环境与候选节点角色

当前登记的环境通常按以下角色命名；这不是目标环境必然存在的节点清单，也不能证明其部署模型：

- `region`：区域节点候选角色；
- `starfish`：海星业务节点候选角色；
- `bridge-nm`：数桥连接器普通版候选角色；
- `bridge-ex`：数桥连接器扩展版一候选角色；
- `bridge-ex2`：数桥连接器扩展版二候选角色。

环境组和角色必须同时匹配。禁止把某组的连接、数据库、日志、K8s context、API 地址或业务数据用于另一组调查。

## 当前机器 SSH-MCP IP 基线

以下内容来自当前机器的 SSH-MCP server 配置。SSH 端口均为 `22`；连接状态不能从该表推断。

### `ylk-*`

- `ylk-region` → `100.100.59.250`
- `ylk-starfish` → `100.100.59.82`
- `ylk-bridge-nm` → `100.100.59.232`
- `ylk-bridge-ex` → `100.100.59.130`
- `ylk-bridge-ex2` → `100.100.59.111`

### `ylk2-*`

- `ylk2-region` → `172.16.60.208`
- `ylk2-starfish` → `172.16.60.214`
- `ylk2-bridge-nm` → `172.16.0.191`
- `ylk2-bridge-ex` → `172.16.0.192`
- `ylk2-bridge-ex2` → `172.16.60.194`

### `ylk3-*`

- `ylk3-region` → `172.16.60.130`
- `ylk3-starfish` → `172.16.60.131`
- `ylk3-bridge-nm` → 当前 SSH-MCP 配置未发现，标记为待配置
- `ylk3-bridge-ex` → `172.16.60.132`
- `ylk3-bridge-ex2` → `172.16.60.133`

## 启动前访问核验

选择目标环境和节点后，先核对连接名与节点角色，再执行只读身份检查：

```text
SSH-MCP execute: connectionName=<环境组-角色>
command: hostname; date -Is; command -v kubectl; command -v docker
```

禁止仅依据 IP、历史 memory、容器名或 URL 判断当前目标。连接失败、节点角色不明、部署模型变化或缺少节点映射时，按 [新机器初始化](new-machine-bootstrap.md) 的 `interview` 规则处理。

## 部署模型与调查入口

- 仅在目标节点已核验为 Docker Compose 后，执行 `docker compose ls`，从输出取得真实 Compose project 的 `CONFIG FILES` 路径，再进入对应目录查看 compose 文件和项目结构。
- 仅在目标节点已核验为 Kubernetes 后，按 `kubectl get deploy -A`、`kubectl get sts -A`、`kubectl get svc -A` 调查；不能把 Compose 语义套到 Kubernetes 节点，反之亦然。
- 未确认部署模型时，NEVER 假定 Kubernetes、Docker Compose、systemd 或裸进程。
- 服务端口只从目标节点当前 Service、Compose `ports`/`expose`、应用非敏感配置或指定容器监听中确认；不能从其他环境复制端口。
- 服务端口和 workload 详细参考见 [YLK 服务端口与部署拓扑](ylk-service-topology.md)。

## 安全与提交边界

- 本 reference 可以记录通用拓扑和当前机器 SSH-MCP 的非秘密连接信息，但不得记录 Token、密码、私钥、完整连接串、K8s Secret、CI variables 或数据库凭据。
- 只记录秘密引用名，例如环境变量名、`glab` host profile、SSH-MCP connection name、密码管理条目名或数据库只读 profile 名。
- 数据库、MinIO、Nacos、网关地址和认证信息必须从目标环境运行时配置、secret reference 或安全凭据配置获取，不从其他环境复制。
- 远程调查默认只读。数据库写入、数据重放、重新登记/上架、对象删除、commit、push、pipeline 和部署必须单独获得明确授权。

## 维护规则

- 连接、IP、节点角色或部署模型变化时更新本文件；更新前重新执行 SSH-MCP `list-servers`，不凭历史记录修改。
- 三套环境只共享拓扑结构和服务角色，不共享实际端口、NodePort、镜像版本、容器状态或业务数据。
- 新机器 bootstrap 时若缺少连接或 Owner 决策，必须使用 `interview` Skill 的 `AskUserQuestion`，每个问题包含问题、背景、原因、建议、适用规范、交付验收和过度设计七项。
