# YLK 架构与部署背景

> 来源与时效性：见 [来源与时效性](sources-and-freshness.md)。**读取时机**：需要识别 YLK 节点角色、仓库职责、业务主链、网关模型或部署语义时读取。本文件是架构导航，不是当前环境的权威清单；当前环境组、SSH-MCP IP 和节点选择见 [YLK 环境访问与节点矩阵](ylk-environment-access.md)，当前服务端口和 workload 映射见 [YLK 服务端口与部署拓扑](ylk-service-topology.md)。

本文件只提供 YLK 的候选节点角色、仓库职责和常见业务链路。只有当前 Bug 的入口、代码引用、配置或环境证据命中对应角色时，才加载并验证该链路；不得从仓库名称、历史拓扑或业务主链推断实际调用关系。事实来源优先级：当前仓库的 `CLAUDE.md`/`AGENTS.md`、workspace `CLAUDE.md`、`docs/adr-arch/019-workspace-repository-topology-and-naming.md`、`docs/handovers/tee-trusted-sandbox-handover.md`、`datafield-installer` 的 Helm values/部署脚本，以及目标环境的实际资源。文档可能过期，执行前必须以代码和环境验证。

## 命名

| 内部名 | 国标/工程角色 | 主要仓库 |
|---|---|---|
| 数桥 | 接入连接器 / Connector | `datafield-bridge`、`data-bridge-frontend` |
| 海星/中心桥 | 业务功能节点 / Business Function Node | `datafield-platform`、`center-system-frontend`、`starfish-home-frontend` |
| 基础支撑平台 | 区域功能节点 / Regional Function Node | `regional-backend`、`regional-frontend`、`regional-deployment` |
| 开发平台 | 工作流与计算环境 | `datafield-workbench`、`datafield-sandbox`、`data-develop-frontend`、`DevelopmentResourceManagement` |
| iSafe | 身份认证与授权 | `isafesparta-srv`、`isafe_keycloak_auth`、`isafe-frontend` |
| DPP | AI 智慧治理/数据预处理平台 | `aiwg2`，与数桥双向 REST 集成 |

避免臆造名称。正式文档采用“内部产品名 / 节点角色”双名表达。

## 核心仓库与常见调查入口

| 领域 | 后端 | 前端 | 调查方向 |
|---|---|---|---|
| 数据产品登记、上架、审核 | `datafield-platform` | `center-system-frontend`、`starfish-home-frontend` | 审核详情本地镜像、登记/上架分支、区域标识解析 |
| 数据接入、产品登记、连接器协议 | `datafield-bridge` | `data-bridge-frontend` | 标准服务、文件 Base64 转换、下游区域协议 |
| 区域登记/审核 | `regional-backend` | `regional-frontend` | 区域产品表、标识解析、审核流程 |
| 工作流、任务和结果表 | `datafield-workbench` | `data-develop-frontend` | workflow 路由、结果表、环境分支 |
| 沙箱资源、动态 Pod | `datafield-sandbox` | `DevelopmentResourceManagement` | Sandbox API、K8s Pod 生命周期、资源配额 |
| 安装和发布 | `datafield-installer` | — | Helm values、服务名、镜像、部署模式、migration |

## 运行与部署模型

```text
浏览器
  → APISIX 网关
  → iSafe / 数桥 / workbench / sandbox / 海星 / DPP 等服务
  → MySQL、Redis、MinIO、Nacos、K8s、ChainMaker、外部身份服务
```

- `datafield-installer` 是部署语义的重要来源；其 Helm values、serviceNames、交付物和 deployment 名称通常比 README 更可靠。部分后端服务可能以外挂 JAR 交付、镜像仅提供运行时基础层；必须以目标仓当前 `.gitlab-ci.yml` 的 job 依赖和实际 workload 确认，不能由镜像 tag 推断业务代码版本。
- YLK 子项目的后端技术栈、文件存储方式与前端集成方式并不统一；Spring Boot/Maven、对象存储、Vue/Vite、CI ZIP 组装、micro-app iframe 等均仅为候选实现，必须从目标仓代码、CI 和环境确认。
- 网关完整路径通常形如 `/prod-api/{gateway-prefix}/{controller-prefix}`，但必须从网关路由与前端 API 定义核实。

## 六条常见业务主链

1. 身份认证 → 数据资源登记 → 数据产品登记 → 数据产品上架 → 审核/门户展示。
2. 数据接入 → 同步/采样 → 数据资源绑定 → 数据产品登记。
3. 下单 → 合约协商 → 支付 → 控制指令生成。
4. 数据交付 → 数桥/工作台/沙箱 → 下载或计算环境。
5. 沙箱资源申请 → K8s 动态 Pod → 回收/状态回调。
6. DPP 从数桥读取数据源 → 治理 → 回写 refined 数据。

跨仓排查应首先确认当前 Bug 属于哪条主链，再补充实际调用边；不要仅按仓库名称猜调用关系。

## 环境调查原则

- 机器别名、IP、数据库连接、namespace、deployment 名称均是环境特定信息，必须从新机器 SSH config、部署文档、CI variables 或实际 K8s 资源获取。
- 已知环境别名只是历史惯例，不可在新机器直接假定可用。
- 先按目标环境实际部署模型确认 workload：

```text
Kubernetes：查询 Deployment/StatefulSet/Service，并通过 selector 找实例。
Docker Compose：查询 Compose project、service 和配置。
其他模型：使用对应平台的只读资源查询。
```

- 不得假设 `app=<service>`；Kubernetes 仅在确认目标为 K8s 后，再查询 selector：

```bash
kubectl get deploy <deployment> -n <namespace> -o jsonpath='{.spec.selector.matchLabels}'
```

- MinIO、数据库、Nacos 地址以运行时配置、K8s Secret/ConfigMap 或 target environment 配置为准；不要用源码的默认 IP 直接判断真实部署。