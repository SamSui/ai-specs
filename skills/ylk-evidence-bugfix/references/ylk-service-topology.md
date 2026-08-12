# YLK 服务端口与部署拓扑

> **读取时机**：调查服务端口、NodePort、Compose project、`Deployment`、`StatefulSet`、Service、容器或前端入口时读取。**不能替代**：目标节点当前的 `kubectl get`、`docker compose ls`、Compose 文件、selector、Service 配置和 rollout 状态。
>
> 本文件是调查导航参考，不是实时状态。`ylk-*`、`ylk2-*`、`ylk3-*` 的历史资料呈现相近业务角色，但不得由此假定目标环境存在同一节点、workload、Compose project 或部署模型。来源：YLK project memory `ylk-platform-topology.md`、`project-mapping.md`、`tech-debt-k8s.md`，以及 2026年08月12日通过 SSH-MCP 对 `ylk2-starfish`、`ylk2-bridge-ex` 的只读 `kubectl get deploy/sts/svc` 查询和 `ylk2-region` 的只读 `docker compose ls`、compose 目录/文件查询。端口、Pod、镜像、容器状态和 Ready 状态变化时，以目标环境实时查询为准。

## 候选拓扑导航

下列为已登记的候选角色组合，仅用于目标环境完成实时核验后的导航，不构成三套环境的固定拓扑：

- `ylk-*`：区域节点 + 海星业务节点 + 数桥普通版/扩展版一/扩展版二；
- `ylk2-*`：区域节点 + 海星业务节点 + 数桥普通版/扩展版一/扩展版二；
- `ylk3-*`：区域节点 + 海星业务节点 + 数桥普通版/扩展版一/扩展版二。

本文件中的 `ylk2` 记录用于说明已核验实例。只有目标环境实时资源确认节点角色、部署模型、workload 或 Compose project 后，才可使用相应查询命令；无法确认时按阻塞协议停止，不得按模板路径、同名服务或 `ylk2` 记录继续调查。不得把 `ylk2` 的实际 NodePort 或运行状态直接复制为其他环境事实。

## 查询命令

Kubernetes 节点：

```bash
kubectl get deploy -A
kubectl get sts -A
kubectl get svc -A
kubectl get svc <service> -n <namespace> -o yaml
kubectl get deploy <deployment> -n <namespace> -o jsonpath='{.spec.template.spec.containers[*].ports}'
```

区域节点 Docker Compose：

```bash
docker compose ls
find <compose-project-dir> -maxdepth 2 -type f -print | sort
docker compose -f <compose-file> config --services
docker compose -f <compose-file> config
```

必须先从 `docker compose ls` 获取项目路径，再进入该项目目录查看 compose 文件；不得根据容器名、历史 memory 或猜测路径替代。只提取 service、`ports`、`expose`、目录和 workload 信息，不读取 `.env`、`env_file`、Secret 或密码配置。

确认服务端口时同时记录：`Service.spec.ports[].port`、`targetPort`、NodePort，或 Compose 的 `ports`/`expose`，以及对应 workload。Service/Compose service 名称与 Deployment/容器名称通常相近，但必须以 selector、Compose label 和实际配置核验。

确认服务端口时同时记录：`Service.spec.ports[].port`、`targetPort`、NodePort，以及对应 workload。`Service` 名称与 `Deployment` 通常同名，但必须以 selector 和实际 Pod 核验，不能仅凭名称推断。

## `ylk2-*` 海星业务节点：`ylk2-starfish`

- SSH-MCP：`ylk2-starfish`；宿主机：`dfp-bridge-060-214`；SSH IP：`172.16.60.214`。
- 部署模型：Kubernetes，namespace：`default`。
- 业务入口：`df-starfish-web` NodePort `10507`；`df-starfish-gateway` NodePort `28080`。
- `df-starfish-web:10507` → `Deployment/df-starfish-web`；前端入口和 Nginx。
- `df-starfish-gateway:28080` → `Deployment/df-starfish-gateway`；Spring Cloud Gateway。
- `df-starfish-auth:29201` → `Deployment/df-starfish-auth`。
- `df-starfish-pad:29200` → `Deployment/df-starfish-pad`。
- `df-starfish-node:29204` → `Deployment/df-starfish-node`；海星主服务。
- `df-starfish-payment:29206` → `Deployment/df-starfish-payment`。
- `df-starfish-price-calculate:29205` → `Deployment/df-starfish-price-calculate`。
- `df-scj-standard:29340` → `Deployment/df-scj-standard`；同集群数桥标准服务。
- `df-scj-dataapi:6668` → `Deployment/df-scj-dataapi`。
- `df-workbench-agent:30404` → `Deployment/df-workbench-agent`。
- `df-workbench-debug-backend:30403` → `Deployment/df-workbench-debug-backend`。
- `df-workbench-running-backend:30403` → `Deployment/df-workbench-running-backend`。
- `df-workbench-local-backend:30603` → `Deployment/df-workbench-local-backend`。
- `df-workbench-trial-backend:30604` → `Deployment/df-workbench-trial-backend`。
- `df-workbench-sandbox-backend:26062` → `Deployment/df-workbench-sandbox-backend`。
- `df-workbench-local-download:29310` → `Deployment/df-workbench-local-download`。
- `df-workbench-sandbox-download:29310` → `Deployment/df-workbench-sandbox-download`。
- `df-base-bridge-agent:8088` → `Deployment/df-base-bridge-agent`，NodePort `8088`。
- `df-base-dolphinscheduler-api:12345` → `Deployment/df-base-dolphinscheduler-api`，NodePort `12345`。
- `df-base-dolphinscheduler-alert:50052` → `Deployment/df-base-dolphinscheduler-alert`。
- `df-base-dolphinscheduler-master:5678` → `Deployment/df-base-dolphinscheduler-master`。
- `df-base-dolphinscheduler-worker:1234` → `Deployment/df-base-dolphinscheduler-worker`。
- `df-base-hive:10000` → `Deployment/df-base-hive`，NodePort `10000`。
- `df-base-ldap:389` → `Deployment/df-base-ldap`。
- `df-base-ldapadmin:80` → `Deployment/df-base-ldapadmin`。
- `df-base-metastore:9083` → `Deployment/df-base-metastore`。
- `df-isafe-gateway:9095` → `Deployment/df-isafe-gateway`。
- `df-isafe-idp:8080` → `Deployment/df-isafe-idp`。
- `df-isafe-sparta:10322` → `Deployment/df-isafe-sparta`。
- `df-isafe-sparta-front:8091` → `Deployment/df-isafe-sparta-front`，NodePort `8091`。
- `df-license-client:8083` → `Deployment/df-license-client`。
- StatefulSet：`df-base-kafka`，Service `df-base-kafka:9092`，NodePort `9092`。
- StatefulSet：`df-base-minio`，Service `df-base-minio:9000`，NodePort `19000`；console `9001`，NodePort `19001`。
- StatefulSet：`df-base-mysql`，Service `df-base-mysql:3306`，NodePort `13306`。
- StatefulSet：`df-base-nacos`，Service `df-base-nacos:8848`，NodePort `18848`；gRPC `9848`，NodePort `19848`。
- StatefulSet：`df-base-redis`，Service `df-base-redis:6379`，NodePort `16379`。
- StatefulSet：`df-base-zookeeper`，Service ports `2181`、`2888`、`3888`。

## `ylk2-*` 数桥扩展版节点：`ylk2-bridge-ex`

- SSH-MCP：`ylk2-bridge-ex`；宿主机：`dfp-bridge-000-191`；SSH IP：`172.16.0.192`。
- 部署模型：Kubernetes，namespace：`default`；另有 `prifield` namespace 的隐私计算相关部署。
- 业务入口：`df-scj-web` NodePort `10588`；`df-scj-gateway` NodePort `28080`。
- `df-scj-web:10588` → `Deployment/df-scj-web`。
- `df-scj-gateway:28080` → `Deployment/df-scj-gateway`。
- `df-scj-auth:29080` → `Deployment/df-scj-auth`。
- `df-scj-standard:29340` → `Deployment/df-scj-standard`。
- `df-scj-dataapi:6668` → `Deployment/df-scj-dataapi`。
- `df-scj-classify:29300` → `Deployment/df-scj-classify`。
- `df-scj-classify-job:29320` → `Deployment/df-scj-classify-job`。
- `df-scj-modelserve:29330` → `Deployment/df-scj-modelserve`。
- `df-workbench-agent:30404` → `Deployment/df-workbench-agent`。
- `df-workbench-local-backend:30603` → `Deployment/df-workbench-local-backend`。
- `df-workbench-local-download:29310` → `Deployment/df-workbench-local-download`。
- `df-workbench-local-worker:8081`，Jupyter `8082` → `Deployment/df-workbench-local-worker`。
- `df-workbench-sandbox-backend:26062` → `Deployment/df-workbench-sandbox-backend`。
- `df-workbench-sandbox-download:29310` → `Deployment/df-workbench-sandbox-download`。
- `df-base-bridge-agent:8088` → `Deployment/df-base-bridge-agent`，NodePort `8088`。
- `df-base-dolphinscheduler-api:12345` → `Deployment/df-base-dolphinscheduler-api`，NodePort `12345`。
- `df-base-dolphinscheduler-alert:50052` → `Deployment/df-base-dolphinscheduler-alert`。
- `df-base-dolphinscheduler-master:5678` → `Deployment/df-base-dolphinscheduler-master`。
- `df-base-dolphinscheduler-worker:1234` → `Deployment/df-base-dolphinscheduler-worker`。
- `df-base-hive:10000` → `Deployment/df-base-hive`，NodePort `10000`。
- `df-base-ldap:389`、`df-base-ldapadmin:80`、`df-base-metastore:9083` → 对应同名 `Deployment`。
- `df-isafe-gateway:9095`、`df-isafe-idp:8080`、`df-isafe-sparta:10322` → 对应同名 `Deployment`。
- `df-isafe-sparta-front:8091` → `Deployment/df-isafe-sparta-front`，NodePort `8091`。
- `df-license-client:8083` → `Deployment/df-license-client`。
- StatefulSet：`df-base-kafka`，Service `9092`，NodePort `9092`。
- StatefulSet：`df-base-minio`，Service `9000`，NodePort `19000`；console `9001`，NodePort `19001`。
- StatefulSet：`df-base-mysql`，Service `3306`，NodePort `13306`。
- StatefulSet：`df-base-postgresql`，Service `5432`，NodePort `15432`。
- StatefulSet：`df-base-nacos`，Service `8848`，NodePort `18848`；gRPC `9848`，NodePort `19848`。
- StatefulSet：`df-base-redis`，Service `6379`，NodePort `16379`。
- StatefulSet：`df-base-zookeeper`，Service ports `2181`、`2888`、`3888`。
- `prifield` namespace：`https-nginx-deployment`、`kuscia-autonomy-deployment`、`prifield-core-deployment`、`prifield-fl-deployment`、`prifield-query-deployment`、`prifield-resource-deployment`、`prifield-secure-deployment`、`prifield-sync-deployment`；其 Service/NodePort 需按隐私计算任务实时查询。

## `ylk2-*` 区域节点：`ylk2-region`

- SSH-MCP：`ylk2-region`；宿主机：`df-prev-060-208`；SSH IP：`172.16.60.208`。
- 部署模型：Docker Compose，不能按 Kubernetes 的 `Deployment`/`StatefulSet` 语义查询。
- `docker compose ls` 已确认以下真实项目目录：
  - `region-platform` → `/mnt/data/srv/region-platform/docker-compose.yml`
  - `df-isafe` → `/mnt/data/srv/df-isafe/docker-compose.yml`
  - `df-support` → `/mnt/data/srv/df-support/docker-compose.yml`
  - `df-tee` → `/mnt/data/srv/df-tee/docker-compose.yml`
  - `df-chain-submitter` → `/mnt/data/srv/chain/df-chain-submitter/docker-compose.yml`
  - `df-upgrade` → `/mnt/data/srv/df-upgrade/docker-compose.yml`
  - `x9-chain` / `idatatestchain-*` → `/mnt/data/srv/chain/x9-chain` 和 `/mnt/data/srv/chain/x9-chain-single-node`，属于 ChainMaker 支撑组件，按任务需要调查。
- `region-platform` Compose services：`svc-auth`、`svc-region-node`、`gateway`、`web`、`algorithm-sdm`、`node_exporter`、`json-exporter`、`prometheus`、`grafana`。
  - 已在 compose `ports` 中明确声明：`node_exporter 9101:9100`、`json-exporter 7979:7979`、`prometheus 9092:9090`、`grafana 3002:3000`。
  - `svc-auth`、`svc-region-node`、`gateway`、`web`、`algorithm-sdm` 未在当前 compose 顶层 `ports`/`expose` 查询结果中声明宿主机映射；业务端口需继续从该项目的非敏感应用配置或容器内指定服务监听核验，不能凭海星 K8s 端口推断。
- `df-isafe` Compose services：`idp`、`gateway`、`sparta`、`sparta-front`。当前 compose 项目已确认运行；端口映射需以 `/mnt/data/srv/df-isafe/docker-compose.yml` 和 `docker compose config` 的非敏感端口段落为准，本次未将未明确读取的端口写成事实。
- `df-support` Compose services：`zookeeper`、`mysql`、`redis`、`minio`、`nacos`、`kafka-ui`、`kafka-exporter`、`kafka`、`mongodb`。当前 compose 项目已确认运行；端口映射需以 `/mnt/data/srv/df-support/docker-compose.yml` 的非敏感端口段落为准。
- `df-tee` Compose service：`capsule-manager-sim`。当前 compose 项目已确认运行；端口映射需以 `/mnt/data/srv/df-tee/docker-compose.yml` 的非敏感端口段落为准。
- `df-chain-submitter` Compose service：`df-chain-submitter`。项目路径 `/mnt/data/srv/chain/df-chain-submitter/docker-compose.yml`，当前运行；端口映射需以该 compose 文件的非敏感端口段落为准。
- `df-upgrade` Compose services：`upgrade-web`、`upgrade-backend`、`chart`、`registry`。项目路径 `/mnt/data/srv/df-upgrade/docker-compose.yml`，当前运行；端口映射需以该 compose 文件的非敏感端口段落为准。历史 memory 仅确认 `upgrade-backend` 采用 Compose，不能代替当前文件查询。
- 区域节点不存在 Kubernetes `Deployment`/`StatefulSet` 对应物；这里的 workload 关系应记录为 `compose project → service → container`。

## `ylk-*` 记忆基线

来源 memory：`~/.claude/projects/-home-openclaw-Codes-ylk-datafield-workbench/memory/ylk-platform-topology.md`。

- SSH 节点：`ylk-starfish`、`ylk-bridge-ex`、`ylk-bridge-nm`、`ylk-region`；完整 IP 和五节点矩阵见 [YLK 环境访问与节点矩阵](ylk-environment-access.md)。
- `ylk-starfish` 业务入口：`df-starfish-web:10507`、`df-starfish-gateway:28080`。
- 记忆中已登记的 Deployment：`df-starfish-node`、`df-starfish-pad`、`df-starfish-payment`、`df-starfish-gateway`、`df-starfish-web`、`df-scj-standard`、`df-scj-dataapi`、四类 workbench backend/download、`df-workbench-agent`、`df-workbench-sandbox-backend`。
- 该部分是历史拓扑基线，未在本次重新连接 `ylk-*` 节点核验；端口和部署变更以实际节点查询为准。

## `ylk-*`、`ylk3-*` 环境实例

- `ylk-*` 和 `ylk3-*` 的历史资料可作为候选角色导航；Kubernetes 或 Docker Compose 均须由目标节点实时资源确认。
- 目标区域节点仅在 `docker compose ls` 确认对应 project 后，才可继续调查 `region-platform`、`df-isafe`、`df-support`、`df-tee`、`df-chain-submitter` 或 `df-upgrade`；不得以此列表推定项目路径、服务名或目录结构。
- `ylk3-*` 当前只确认 SSH-MCP 已配置部分连接名，未连接核验服务端口、workload 或部署模型。
- 三套环境的节点角色、部署模型、实际端口、NodePort、容器状态、镜像版本和 workload 状态均不得互相复制；候选角色仅在实时核验后使用。
