---
title: 合并冲突解决验证协议
author: 顾小宇
tags: [AI工程化, 知识库, 指南, 合并, 审查]
description: 跨版本合并冲突解决的标准化5阶段流程和验证协议，基于 idata 2.0.3 移植经验。
---

# 合并冲突解决验证协议

> **版本**: v1.1
> **作者**: 顾小宇
> **最后更新**: 2026-06-06  (v1.1: +3 traps from workbench review)
> **状态**: ✅ 已验证（idata 2.0.3 移植，3 仓库深度审查）

---

## 目录

1. [核心原则](#核心原则)
2. [5 阶段流程](#5-阶段流程)
3. [冲突分类体系](#冲突分类体系)
4. [解决策略矩阵](#解决策略矩阵)
5. [验证检查清单](#验证检查清单)
6. [常见陷阱](#常见陷阱)
7. [确认发现](#确认发现)
8. [工具链](#工具链)

---

## 核心原则

### 1.1 设计理念

- **意图优先**: 理解两侧修改的意图，而非机械合并文本
- **可验证性**: 每个合并决策必须可追溯、可验证（`git show --remerge-diff`）
- **分离关注点**: 大部分文件（AA 类）自动合并，只集中审查冲突文件（UU/UD/DU 类）
- **覆盖率优先**: 抽查关键文件而非全部审查，用样本推断全局质量

### 1.2 适用场景

```
适用: 跨版本合并（如 idata 2.0.3 → YLK datanet 2.0.2），冲突文件 > 10 个
不适用: 3 文件以下的小规模合并
```

### 1.3 先决条件

```bash
# 1. 确认合并 commit 存在
git log --oneline --merges -5

# 2. 统计冲突规模
git show --remerge-diff <MERGE_COMMIT> | wc -l

# 3. 识别冲突文件数
git show --remerge-diff <MERGE_COMMIT> | grep -c 'remerge 冲突'
```

---

## 5 阶段流程

### Phase 1: Checkpoint -- 基准检查

```
目标: 排除基础错误，不进入深度审查就发现最显眼的问题
```

| 检查 | 命令 | 通过标准 |
|------|------|---------|
| 残留冲突标记 | `git grep -l '<<<<<<<' -- '*.java'` | 0 命中 |
| 编译状态 | `mvn compile -q 2>&1 \| tail -1` | BUILD SUCCESS |
| CRLF 污染 | `git diff --check <MERGE_COMMIT>` | 空白符合规 |

**此阶段不过，不进入 Phase 2。**

### Phase 2: Conflict Classification -- 冲突分类

```
目标: 区分自动解决和人工解决的文件，确定审查优先级
```

使用 `git show --remerge-diff` 分类：

| 分类 | 含义 | 合并方式 | 审查策略 |
|------|------|---------|---------|
| **AA** | 双方新增 (Add/Add) | 自动/策略选择 | 不抽查，信任策略 |
| **UU** | 双方修改 (Update/Update) | 手动融合 | **必须抽查** |
| **UD** | 一侧修改/一侧删除 | 策略选择 | 有选择抽查 |
| **DU** | 一侧删除/一侧修改 | 策略选择 | 有选择抽查 |

**分类命令**:
```bash
# 统计各类冲突
git show --remerge-diff <COMMIT> | grep 'remerge 冲突' | \
  sed 's/.*（\(.*\)）.*/\1/' | sort | uniq -c

# 列出所有 UU 类文件（必须审查）
git show --remerge-diff <COMMIT> | grep 'remerge 冲突（内容）' | \
  awk -F '于 ' '{print $2}' | awk -F ':' '{print $1}'
```

### Phase 3: Resolution -- 逐文件审查

```
目标: 对每个抽查文件，验证合并正确性
```

**审查深度分级**:

| 级别 | 文件数 | 方法 |
|------|--------|------|
| 轻度 | 抽查 5-8 个 | 读最终文件 + 对照 remerge-diff |
| 标准 | 抽查 8-12 个 | 读最终文件 + 读两侧原始版本 + 对照 remerge-diff |
| 深度 | 抽查 12-20 个 | 标准 + 追溯调用方 + grep 全仓引用 |

**每文件检查项**:
1. 方法完整性：方法体是否完整（无截断、无重复代码块）
2. 调用方更新：删除的方法是否有残留调用方
3. 类型一致性：字段类型变更（如 Long→String）是否有遗留转型
4. 控制流正确：条件分支是否与逻辑语义一致
5. 日志/注释一致：注释描述的语义是否匹配实际代码
6. 新增依赖：新增的 import/注入是否有对应实现类

**抽样策略**:
```
优先: UU 类 + 核心业务逻辑（Service/Controller/Entity）
次选: UU 类 + 数据结构/配置
跳过: AA 类、自动合并、仅 import 变更
```

### Phase 4: Verification -- 验证修复

```
目标: 确认修复正确且无副作用
```

**修复后验证**:

| 检查 | 命令 | 标准 |
|------|------|------|
| 旧模式残留 | `grep -c '旧模式' <file>` | 0 |
| 新修改只涉及目标行 | `git diff --stat` | 仅目标文件 |
| 无新的冲突标记 | `grep -c '<<<<<<<' <file>` | 0 |
| 相关调用方不变 | `grep -rn '方法名' -- '*java'` | 调用方列表无意外变更 |

**验证循环**:
```
Fix → grep 验证 → diff 验证 → 通过 → 提交
                                      ↓ 不通过
                                    重新 Fix
```

### Phase 5: Documentation -- 记录结果

```
目标: 生成可追溯的审查报告
```

**必须记录**:
1. 每个文件的冲突分类和解决策略
2. 发现的每个问题（文件:行 + 严重度 + 置信度 + 修复方案）
3. 确认正确的部分（正向反馈）
4. 最终判决（通过/不通过/需修订）

---

## 冲突分类体系

### 3.1 AA（双方新增）

```
场景: 两侧都新增了代码，在同一位置
策略: 按领域选择一侧全量采用，或合并两方字段
```

**典型场景**:
- 数字合约模块：idata 侧有完整 P2P 实现，YLK 侧有空壳 → 采用 idata 侧
- Entity 字段：两侧新增了不同字段 → 合并字段列表

**验证要点**:
- 未采用侧的字段/方法是否在其他文件被引用
- 采用的侧是否遗漏了导入或注解

### 3.2 UU（双方修改）

```
场景: 两侧都修改了同一段代码
策略: 理解意图 → 判断是否可以共存 → 手动融合或语义合并
```

**典型场景 1: 可以共存**（双方新增不同功能）
```
例: DataTransferServiceImpl.transferProcess（YLK 协商）
    + DataTransferServiceImpl.transferProcessHandle（idata P2P）
策略: 两个方法保留，各自承担不同职责
```

**典型场景 2: 不能共存**（双方修改同一逻辑）
```
例: OrderServiceImpl 中 deactivateTime 计算
   YLK: DateUtil.beginOfDay 凌晨对齐
   idata: 精确时间累加
策略: 选择一侧语义，确保调用方一致
```

### 3.3 UD/DU（单侧修改/删除）

```
场景: 一侧修改，另一侧删除了代码
策略: 判断删除是功能移除还是重构重写
```

**典型场景**:
- `DataStreamServiceImpl` 的 V2 方法：idata 侧删除，YLK 侧保留 → 需要验证调用方
- 环境配置：YLK 侧有本地化配置，idata 侧有通用配置 → 保留 YLK 侧

---

## 解决策略矩阵

| 冲突类型 | 意图一致 | 意图冲突 |
|---------|---------|---------|
| **UU** | 合并双方代码（如保持 YLK 方法 + 新增 idata 方法） | 选择一侧（如日期逻辑用 idata 精确累加） |
| **AA** | 合并字段/方法/导入 | 选择一侧（如数字合约全量采用 idata 侧） |
| **UD** | 保留修改侧（如果删除是误伤） | 保留删除侧（如果是有意重构） |
| **DU** | 保留修改侧（如果在用） | 保留删除侧（如果已废弃） |

**选择一侧的评判标准**:

| 标准 | 权重 | 示例 |
|------|------|------|
| 新架构一致性（与主系统方向一致） | 高 | idata 2.0.3 稳定分支 → 采用 idata 实现 |
| 运行时正确性（逻辑无明显 bug） | 高 | 日期计算不能用凌晨对齐 + 精确累加混用 |
| 本地化配置（环境/部署参数） | 中 | YLK 侧的 docker/k8s 配置保留 |
| 代码质量（哪个更简洁） | 低 | 仅当其他标准相同时考虑 |

---

## 验证检查清单

### 4.1 必须通过（P0）

```
☐ 零残留 <<<<<<< / ======= / >>>>>>> 标记
☐ 编译通过（或等价的结构完整性检查）
☐ 无单边删除的核心业务逻辑（如传输协商、交易上报）
☐ 无类型不一致导致的运行时 crash（如 Long→String 转型）
☐ 无重复代码块（单边代码被重复合并）
```

### 4.2 应该通过（P1）

```
☐ 方法体完整性（无截断、无缺失闭合括号）
☐ 内部类结构完整（每个类有正确的大括号配对 + 注解）
☐ 导入无冗余、无遗漏
☐ 删除方法的调用方已更新或注释
☐ 日志消息与实际行为一致
☐ 注释与字段类型一致
```

### 4.3 建议检查（P2）

```
☐ 冗余类型转换清理（如 String.valueOf(x) 包装已为 String 的 x）
☐ 注释描述与实际代码逻辑一致
☐ 无存量数据库 key 变更的向后兼容问题
```

---

## 常见陷阱

### 陷阱 1: 注释未随代码更新

```
症状: 代码采用了 idata 侧实现，但注释保留 YLK 侧描述
示例: deactivateTime = now.plusDays(...)  // 注释说"次日凌晨00:00:00"
影响: 误导后续维护者
检查: 逐行对比 merge 后的注释与代码逻辑是否一致
```

### 陷阱 2: 类型变更后的冗余转型

```
症状: 字段从 Long 改为 String，但调用方仍有 Long.valueOf() / .toString()
示例: connectorId: Long → String, 但有 String.valueOf(getConnectorId())
影响: 功能正确但代码混乱，暗示不完整的迁移
检查: grep -rn 'getXxx().toString()\|String.valueOf(getXxx())' 检查新旧类型
```

### 陷阱 3: 日志语义反转

```
症状: 合并后的日志描述与实际条件判断相反
示例: "跳过上报" 实际在 "非跳过" 的条件分支中
影响: 线上问题排查时日志严重误导
检查: 对每个条件判断块，验证日志消息与条件的语义关系
```

### 陷阱 4: falsy vs null 检查

```
症状: JavaScript/TypeScript 中用 !value 替代 value == null
示例: !row.editPrice 会在值为 0 时报错
影响: 有效值 0 被拒绝
检查: 对每个 !variable 检查，确认是否应该用 == null
```

### 陷阱 5: 方法删除后调用方未更新

```
症状: V2 方法被删除，但其他文件仍引用
示例: DataStreamServiceImpl.pushDataStreamV2() 被删除，PullTeeTaskScheduler 仍有调用
影响: 编译错误或运行时 NoSuchMethodError
检查: 对每个删除的方法，grep 全仓查找调用方
```

### 陷阱 6: 重复事件发布

```
症状: 合并后同一逻辑发布两次事件
示例: DATA_PRODUCT_DELIVERY 和 DELIVERY_STATUS_REPORT 看似重复
影响: 链上重复记录（如果确实是重复）
检查: 判断事件语义是否真重复（不同 event type key + 不同触发条件 = 不同事件）

```

### 陷阱 7: 括号错位导致控制流融合

```
症状: 合并后 `}  {` 之间没有分行，导致两个独立的 if 块融合为一个块
示例: WorkflowDefController.selectWorkflowDef()
  合并后: `} { vo.setName(name); }` 使 else-if 变为无条件赋值块
影响: if 条件失效、过滤逻辑短路
检查: 搜索模式 `} {` (两个闭合大括号后紧跟一个单开大括号，中间无其他代码)
```

### 陷阱 8: 复制粘贴变量名错位

```
症状: 新增方法复制自现有方法，但变量名未更新导致功能错位
示例: Snowflake.newTraceId() 复制自 nextId()，sequence 溢出时使用了
  lastTimestamp/sequence (源方法变量) 而非 traceLastTimestamp/traceSequence
影响: 生成的唯一 ID 有重复风险
检查: 比较新增方法与复制源方法，逐变量确认命名一致性
```

### 陷阱 9: 异步线程丢失 MDC 上下文

```
症状: wrapRunnable() 传递了业务 Context 但未复制 MDC 上下文到子线程
示例: Feign 调用在异步线程中 traceId 全为 null
影响: 分布式链路追踪在异步任务中完全断链
检查: 搜索 ThreadPoolExecutor/Runnable/Callable 包装器，
  确认 MDC.getCopyOfContextMap() + MDC.setContextMap() 配对


---

## 确认发现

### 6.1 datafield-bridge 审查（95 文件冲突）

| # | 文件 | 问题 | 陷阱类型 |
|---|------|------|---------|
| 1 | DataTradingServiceImpl.java:345 | 日志"跳过上报"在实际"上报"分支中 | 陷阱 3 |
| 2 | OrderServiceImpl.java:557 | 注释描述凌晨对齐，代码用精确累加 | 陷阱 1 |
| 3 | DigitalContract.java:121 | 注释说 Long，字段是 String | 陷阱 1 |
| 4 | DigitalContractPeerSyncService.java:267 | String.valueOf() 包装已为 String 的字段 | 陷阱 2 |
| 5 | DigitalContractServiceImpl.java:529/6582 | .toString() 包装 String 字段 | 陷阱 2 |
| 6 | DigitalContractConnectorCatalogService.java:103 | stream 中 String.valueOf() 冗余 | 陷阱 2 |

### 6.2 DevelopmentResourceManagement 审查（1 文件冲突）



| # | 文件 | 问题 | 陷阱类型 |

|---|------|------|---------|

| 1 | resourceConfig/index.vue:309 | !row.editPrice 拒绝 0 值 | 陷阱 4 |



### 6.4 确认正确的关键决策


| 决策 | 文件 | 验证方法 |
|------|------|---------|
| 保留 YLK 传输协商 + 新增 idata P2P | DataTransferServiceImpl.java | 两个方法均有独立调用路径 |
| originTime 语义 | OrderServiceImpl.java | timeline 使用 deactivateTime != originTime 判断 |
| publishEvent 不是重复 | DataTradingServiceImpl.java | 两个事件 key 不同，触发条件不同 |
| EvidenceContent 17 内部类完整 | EvidenceContent.java | 逐类验证大括号 + Lombok 注解 |
| V2 方法删除干净 | DataStreamServiceImpl.java | 仅 1 处注释掉的引用残留 |
| 图标导入合并正确 | resourceConfig/index.vue | 4 个图标全部有使用点 |

---

## 工具链

### 7.1 冲突分析

```bash
# 查看合并后的差异（git 如何解决冲突）
git show --remerge-diff <MERGE_COMMIT>

# 查看指定文件的 remerge-diff
git show --remerge-diff <MERGE_COMMIT> -- <file_path>

# 统计冲突类型
git show --remerge-diff <MERGE_COMMIT> | \
  grep 'remerge 冲突' | \
  sed 's/.*（\(.*\)）.*/\1/' | sort | uniq -c

# 查看两侧原始内容
git show <MERGE_COMMIT>^1:<file>  # 第一父（目标分支）
git show <MERGE_COMMIT>^2:<file>  # 第二父（源分支）
```

### 7.2 残留检查

```bash
# 冲突标记
git grep -l '<<<<<<<\|=======\|>>>>>>>' -- '*.java' '*.xml' '*.properties'

# 方法删除后残留调用方
git grep -rn 'deletedMethodName' -- '*.java' ':!target/'

# 类型变更后冗余转换
git grep -rn '\.toString()\|String\.valueOf' -- '*.java' ':!target/' | \
  grep -i 'connectorId\|fieldName'
```

### 7.3 注释一致性

```bash
# 查找注释与代码不一致的模式
# 1. 注释说"凌晨"但代码无 DateUtil
grep -rn '凌晨' -- '*.java' | while read line; do
  file=$(echo "$line" | cut -d: -f1)
  grep -q 'DateUtil.beginOfDay' "$file" || echo "MISMATCH: $line"
done
```

---

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-06-06 | 初始版本，基于 idata 2.0.3 移植经验 |
| v1.1 | 2026-06-06 | +3 traps (7:括号错位, 8:变量错位, 9:MDC丢失) + workbench 审查结果 |

## 参考资料

- `reviewer-protocol.md` -- Reviewer Subagent 23 条核心原则
- `review-report-spec.md` -- 审查报告输出格式规范
- datafield-bridge MR: http://gitlab.datanet.wk/idatafield/xty/backend/datafield-bridge/-/merge_requests/1540
