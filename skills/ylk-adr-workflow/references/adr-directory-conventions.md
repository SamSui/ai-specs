# ADR 目录约定

## 适用范围

本规则适用于 YLK workspace 根目录的 `docs/adr-*` 文档组。YLK 按领域组织 ADR，不强制使用单一 `docs/adr/` 目录。

## 主题目录

优先阅读根 `docs/README.md` 再选择目录：

- **`docs/adr-resource-mgmt-deviation-fix/`** → 资源管理、计费、生命周期、跨仓纠偏和 E2E 证据。
- **`docs/adr-adapt-ylk/`** → 适配专项、版本演进和跨仓改造。
- **`docs/adr-metrics/`** → 指标、Prometheus、监控和网关路由维度。
- **`docs/adr-arch/`** → workspace 拓扑、命名和稳定架构事实。
- **`docs/adr-partner-api/`** → 合作方接口技术方案和外部接入指南。

已有主题可以容纳时，不新建近义目录。新主题必须有稳定领域边界，不能只因为一次 task 或一个仓库创建目录。

## 编号与索引

ADR 编号在 workspace 范围内连续。新建前执行：

```bash
rg -n '^\| *[0-9]+ *\|' docs/README.md docs/adr-*/README.md
find docs -path '*/adr-*/*.md' -type f | sort
```

确认以下事项：

- 根 `docs/README.md` 当前最大编号。
- 主题 README 是否已有相同决策或可扩展 ADR。
- 新 ADR 的标题、领域、涉及仓库、状态和关联关系。

创建或修改后同步更新：

- 根 `docs/README.md` 总索引。
- 主题 `README.md` 索引。
- 主题 README 的关系图、覆盖范围或收官状态（该组已有这些结构时）。
- ADR 正文的关联 ADR。

## 文件分工

| 内容 | 唯一承载载体 | 说明 |
|------|--------------|------|
| 稳定背景、范围、重大决策、跨仓契约、替代方案、后果，以及直接解释本次偏离或后续维护的认知/踩坑 | `NNN-title.md` | 用任务前视角书写；不写会话、Skill、文档整理或 CI/CD 过程。 |
| 主题索引、领域关系、偏离总览、FIX 映射、实现/验证状态汇总、输入主题覆盖映射 | 主题 `README.md` 或偏离矩阵 | 参考 `adr-resource-mgmt-deviation-fix` 的颗粒度；不复制敏感环境信息。 |
| 当前进展、待办、阻塞、负责人、验证轮次 | Beads issue | 不是 ADR 正文或 README 的日常看板。 |
| 提交、测试、CI/CD、部署、E2E、失败证据、阶段交付 | `result.md` | 仅在已实施或交付时维护。 |
| 分支、文件、部署及验证入口的交接信息 | `HANDOVER.md` | 不重复 ADR 决策。 |
| 可复用项目认知、经验、踩坑、用户长期规则 | Beads memory | 使用 `bd remember` 写入、`bd memories` 检索。 |
| `tasks/` 历史文件 | 仅作参考 | 新任务不继续在其中维护过程信息。 |

不要把一次性进度日志继续堆入 ADR 正文。与本次决策直接相关、能够解释偏离或约束后续维护的稳定认知、经验和踩坑必须进入 ADR，并按跨任务复用价值同步 Beads memory；当前进展、阻塞和验证轮次进入 Beads issue。

## 日期与状态

ADR 元数据统一使用下列日期，避免事后归档造成时间倒置：

- **创建日期**：作出或拟定该决策的日期；后补文档应使用可核实的最早决策日期，无法确认时标明“待核实”，不得伪造。
- **归档日期**：ADR 文本首次完成归档的日期；纯设计 ADR 可以为空。
- **最后核验日期**：最新实现或验证证据的日期；没有实际证据时留空。

`accepted` 只表示决策被采纳，不表示实现、测试或部署完成。主题 README 的 FIX 表必须分列实现状态与验证状态；不得把“已完成”作为两者的替代词。任何归档或核验日期均不得早于它引用的提交、测试或环境证据。

## 参考样本

重点参考：

- `docs/adr-resource-mgmt-deviation-fix/README.md` → 完整索引、用户故事、测试用例、偏离和 FIX 映射。
- `008-e2e-framework-cdp-playwright.md` → 测试架构决策和证据原则。
- `012-final-deviation-fix.md` → 多项偏离、已修/不修/技术债务的处理。
- `result.md` → 跨 MR、跨仓、编译、单测、部署和 E2E 的最终报告。

参考这些文档的结构和判断规则，不复制历史账号、密码、IP、Token、分支状态或一次性测试数据。
