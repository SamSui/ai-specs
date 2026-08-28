---
name: ylk-migrations
description: |
  datafield-installer/init/migrations 的编写规范与三环境（ylk/ylk2/ylk3，共 11 节点）同步执行流程，覆盖新环境首次运行与 migration 文件发布后修改的补偿运行（DB 实际写入 + sqlite ledger 同步）。
  触发词：migration 补列、migration 文件编写、init-job、installed.db、hash 漂移、迁移补偿、三环境一致性、0167/0172/0174/0175 类型的编号迁移文件。
author: 顾小宇
version: v1.0
last_updated: 2026-08-21
---

# YLK Migrations

`datafield-installer` 用 `chart/files/updater/migration.py` 在 Helm `post-install,post-upgrade` hook（`df-init-job`，`hook-weight: 5`）中遍历 `init/migrations/` 按文件名排序执行迁移，并将执行结果记录进目标主机的 sqlite ledger `/mnt/data/idata/data/migration/installed.db`。本技能覆盖"写新 migration 文件"和"发布后回填/补偿三环境执行状态"两类任务，以当前 `migration.py` 源码、目标环境实际数据库和实际 ledger 内容为事实来源；不得凭文件名、commit message 或 memory 推断某环境已执行到位。

## 适用边界

- 编写新 migration 文件、只读排查 hash 漂移、比对 diff：无需额外授权，正常工作范围。
- 对已发布 migration 文件做补偿性执行（写生产/环境 MySQL、改 sqlite ledger）：必须先获得用户明确授权，且授权范围以用户指定的编号/环境为准，不自动外推到其他文件或"顺手一起修"的相邻问题（如分类分级相关内容，除非用户明确要求，否则不动）。
- 不因为"发现了另一个 hash 漂移"就自行扩大批量写库范围；发现范围外问题先报告，等用户确认。
- 涉及 idata 上游仓库：本技能所有操作只针对 datanet.wk 侧 3 套已部署环境的数据库/ledger，不涉及 idata GitLab 远端的任何写操作。

## 机制基础（先读源码，不要凭记忆）

每次涉及 migration 机制细节前，先读一遍 `datafield-installer/chart/files/updater/migration.py`，因为文件名解析正则、hash 算法、跳过逻辑都在这一个文件里，且历史上出过差异。核心事实（当前版本）：

1. **文件名格式**：`{4位数字编号}-(可选dbname-)名称(@spec_filter)?.{sh|py|my.sql|pg.sql|hive.sql|redis.lua}`。`spec_filter` 用 `&&` 分隔多个安装模式，如 `@saas&&starfish`，仅当 `$INSTALL_MODE`（小写后）命中其中之一才执行，否则直接标记跳过（不计入 ledger）。5 种模式：`normal`/`extend`/`enhanced`/`saas`/`starfish`，`saas`=中心桥、`starfish`=海星节点，两者常常成对出现在同一个 `@saas&&starfish` 文件里。
2. **hash 计算**：对文件原始字节做 `hashlib.sha256()`，与文件名一起写入 ledger 的 `migrations` 表（`filename` 唯一约束）。
3. **⚠️ 跳过陷阱（最重要的一条）**：`should_execute()` 只用 `SELECT ... WHERE status = "success"` 取「已安装」集合。
   - `filename` 在已安装集合里且 hash 一致 → 跳过（正常幂等）。
   - `filename` 在已安装集合里但 hash **不一致** → **跳过并只打一条 WARNING 日志，永远不会重新执行**。这就是"migration 文件发布后又改了内容，但已经跑过旧版本的环境不会自动补上新内容"的根因，也是本技能存在的原因。
   - `status='failed'` 的记录不计入已安装集合，所以失败重跑（下次 helm upgrade 触发 hook）会重新尝试执行，这是正常的"失败重试"路径，不需要人工介入。
   - 换句话说：**只有"从未执行成功过"和"失败过"两种情况会被 migration.py 自动补跑，"成功过但内容后来被改了"这种情况永远需要人工介入**。
4. **数据库上下文**：`_execute_sql` 只有当文件名里解析出 `dbname` 时才会 `USE` 该库；大多数实际文件名（如 `0175-v2.0.3_...@saas&&starfish.my.sql`）解析不出 `dbname`，因此**必须在 SQL 内容第一行显式写 `USE {{@MYSQL_DB_XXX}};`**，否则连不到目标库。
5. **占位符替换**：`{{@ENV_NAME}}` 或 `{{@ENV_NAME:default}}` 会在执行前用环境变量替换。逻辑库名到物理库名的映射统一定义在 `chart/values.yaml` 的 `globalEnv.MYSQL_DB_*`（如 `MYSQL_DB_ISAFESPARTA: "isafesparta"`、`MYSQL_DB_SERVICE_NODE: "df_service_node"`、`MYSQL_DB_DATAFIELD_SCJ: "datafield_scj"`），三套环境共用同一份 chart，该映射跨环境一致，不需要每个环境单独核对，但改动前仍应 `grep 'MYSQL_DB_' chart/values.yaml` 现查一遍，不要凭记忆背诵。
6. **执行时机**：`post-install,post-upgrade` hook，`hook-weight: 5`，即每次 `helm upgrade`（含日常发布）都会触发一次 migration.py 全量遍历——这意味着"发布后没生效"不需要单独触发脚本，正常走一次目标环境的 helm upgrade 即可让"从未执行过"和"曾经失败"的文件生效；只有"hash 漂移"这一种情况 helm upgrade 也救不了，必须走本技能的补偿流程。

## 编写新 migration 文件

1. **命名**：编号取当前 `init/migrations/` 下最大编号 +1（4 位数字，`ls init/migrations/ | sort` 现查，不要凭记忆推断下一个编号），按 `编号-版本_日期_中文描述(@spec_filter)?.类型` 拼，模式过滤器按实际适用范围写，不要不写（默认所有模式都跑）也不要写多余模式。
2. **DB 选择**：`my.sql` 文件第一行写 `USE {{@MYSQL_DB_XXX:default_db_name}};`，`XXX` 从 `chart/values.yaml` 现查，不要猜。
3. **幂等性**：
   - 新增列/索引用 `ALTER TABLE ... ADD COLUMN`（团队约定：未最终发版前的 migration 允许直接改文件内容；**已发版的文件改动属于本技能"补偿运行"场景，见下节**）。
   - 新增表用 `CREATE TABLE IF NOT EXISTS`。
   - 新增行用 `INSERT IGNORE INTO`，避免主键/唯一键冲突导致整个事务失败（`_execute_sql` 是单事务执行所有语句，一条失败全部回滚）。
   - 避免无条件 `DELETE`/`UPDATE`（除非确实需要且已确认不影响运行期业务数据，例如后台管理界面写入的行）。
4. **大字段**（如内嵌 base64 图片）：正常写入即可，但后续如果需要跟这个文件做 diff/补偿，参见下节"处理超大 diff"。
5. 写完后本地跑一次 `python3 -c "import re; ..."` 或直接读 `parse_filename` 的正则手工比对文件名，确认能被解析（尤其是中文名称、`&&`、`@` 符号别写错位置）。

## 已发布文件修改后的补偿运行 SOP

适用场景：`init/migrations/` 下某个编号的文件在已经有环境成功执行过之后又被修改了内容（本轮改动会导致 sha256 变化）。目标：让"内容层面"在所有该跑这个文件的主机上生效，并让 ledger 记录如实反映"这台主机现在的真实状态"。

### 第 0 步：明确范围

跟用户确认：改了哪些编号、哪些环境/主机在授权范围内、是否要排除某些不相关的历史遗留问题（例如某类业务领域的字段变更由其他人负责）。不要因为顺手发现了范围外的漂移就一起处理。

### 第 1 步：定位 stale 的 (主机, 文件) 组合

对每个目标环境的每个节点，下载 `installed.db`，用 sqlite3 精确匹配文件名（**不要用 `LIKE '%prefix%'` 模糊匹配**——同一编号常有多个 `@spec_filter` 变体共享很长的公共前缀，例如 `0174-...@normal&&extend&&enhanced.my.sql` 和 `0174-...@saas&&starfish.my.sql` 前 20+ 字符完全一样，模糊匹配会把两个不同文件的 ledger 记录混在一起产生假阳性/假阴性）比较 `hash_value` 与当前仓库文件 sha256：

```python
# 精确匹配，不要用 LIKE
cur.execute('SELECT hash_value FROM migrations WHERE filename=?', (exact_filename,))
```

同时确认每台主机的 `INSTALL_MODE`（`normal`/`extend`/`enhanced`/`saas`/`starfish`），只对 `spec_filter` 覆盖该模式的文件做比对，其余文件预期是 `NOT_RUN`（ledger 里没有该文件的行），这不是异常。

产出一份「文件 × 主机」矩阵，标注每格 `OK` / `STALE(old_hash)` / `NOT_RUN`。

### 第 2 步：从 git 历史重建增量内容

不要假设"整份新文件内容"就是需要补的内容——文件里可能混有历史上已经跑过的旧语句（改动只是措辞/注释变化）和真正新增的语句。

```bash
git log --follow --oneline -- <file>          # 枚举历史版本
git show <commit>:<file> | sha256sum          # 找到某主机记录的 stale hash 对应哪个历史 commit
git diff <old_commit> <new_commit> -- <file>  # 提取真正的增量
```

只把 diff 中"确实新增、确实需要补跑"的语句摘出来做成独立的 delta 文件，历史上已执行过的部分（哪怕文本被重新格式化了）不要重新塞进 delta，尤其是 `DELETE`/`UPDATE` 类语句——盲目重放可能删掉/覆盖运行期间产生的真实数据。拿不准某段 diff 该不该重放时，倾向于保守（不重放），转成"只做 ledger 同步"，并在最终报告里写清楚这个判断依据。

**处理超大 diff（内嵌 base64 等）**：`git diff`/`cat`/`tail` 对含大段 base64 的文件会产生几 MB 的终端输出，不要直接打印到会话里。用 Python 按已知的文本锚点做 `content.find()`/`content.rfind()` 定位并直接写文件，不经过终端回显。

### 第 3 步：写库前必须先核验，不能盲目 apply

**这是本技能最核心的纪律**：sqlite ledger 里的 hash 漂移，不等于目标数据库真的缺这块内容。可能已经被 DBA 手工改过、被更早一次不完整的迁移应用过、或者被应用自身的后台管理界面写入过等价内容。

对每一个 stale 组合，写库前先用 `information_schema` 或等价查询核实目标对象是否已存在：

```sql
-- 列是否存在
SELECT COUNT(*) FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA='<db>' AND TABLE_NAME='<table>' AND COLUMN_NAME='<col>';
-- 表是否存在
SELECT COUNT(*) FROM information_schema.TABLES
WHERE TABLE_SCHEMA='<db>' AND TABLE_NAME='<table>';
-- 业务数据行是否已存在（且要看内容是否是"等价的新内容"还是"另一份不相关的真实业务数据"）
SELECT * FROM <table> WHERE <key_col>='<key>';
```

已经存在 → 不写库，只做 ledger 同步（见第 5 步）。真的缺 → 才执行写库（第 4 步）。

**遇到业务配置行冲突时格外小心**：如果目标行的 `config_id`/主键不同、但 `config_type` 等业务语义字段相同，且内容/更新时间显示是运行期由应用后台写入的（不是 migration 落的默认值），说明这是一条真实的、活跃维护的业务数据，盲目 `INSERT IGNORE` 罐装的 migration 默认值会造成同类型重复配置行。这种情况下不写库，只做 ledger 同步，并把判断依据记录进最终报告。

### 第 4 步：执行确认的真实缺口

```bash
kubectl exec -n default df-base-mysql-0 -- mysql -uroot -p'<password>' <dbname> -e "<SQL>"
# 或
kubectl exec -n default df-base-mysql-0 -- mysql -uroot -p'<password>' <dbname> < /tmp/delta.sql
```

mysql 客户端在 `df-base-mysql-0` StatefulSet pod 内，不在 SSH 可达的节点 OS 上；连接凭据/库名映射可用 `kubectl exec ... deploy/df-isafe-sparta -- env | grep MYSQL` 现查确认（chart 用同一份 values，三套环境的 host/port/user/password 预期一致，但每次仍应现查而非直接照抄上一次的值）。

写完后**立即用第 3 步同样的 information_schema 查询复核**，确认对象/数据确实已在目标库出现。

### 第 5 步：同步 sqlite ledger

`installed.db` 在 SSH 可达的节点文件系统上（`/mnt/data/idata/data/migration/installed.db`），节点上有 `sqlite3` CLI 和 `python3`，直接原地脚本操作，不需要下载/上传往返。每台主机生成一份专属脚本，backup → update → 读回验证：

```python
import sqlite3, shutil, datetime
DB = "/mnt/data/idata/data/migration/installed.db"
shutil.copy2(DB, f"{DB}.bak-{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}")

UPDATES = [(filename, new_hash), ...]  # 本主机实际需要更新的组合，逐台核对，不要用一份通用列表批量套用

conn = sqlite3.connect(DB)
cur = conn.cursor()
for filename, new_hash in UPDATES:
    cur.execute("SELECT hash_value, status FROM migrations WHERE filename=?", (filename,))
    row = cur.fetchone()
    if row is None:
        print("SKIP (not found):", filename); continue
    cur.execute("UPDATE migrations SET hash_value=? WHERE filename=?", (new_hash, filename))
conn.commit()
for filename, new_hash in UPDATES:
    cur.execute("SELECT hash_value FROM migrations WHERE filename=?", (filename,))
    row = cur.fetchone()
    print("VERIFY OK:" if row and row[0]==new_hash else "VERIFY FAIL:", filename)
conn.close()
```

**每台主机的 `UPDATES` 列表要单独核对，不要复制一份模板改改就全量套用**——批量操作前先在一台主机手动验证一遍逻辑无误，再套到其余主机；即便如此，最后仍要做第 6 步的全量复核，因为"复制模板时漏填一项"这种遗漏本身也可能在单机验证阶段被掩盖（本轮就出现过 11 台里有一台的模板漏了一个应该更新的编号，直到最终复核才发现）。

### 第 6 步：全环境最终一致性复核

补偿完成后重新下载全部目标主机的 `installed.db`（下载前确认本地目标目录已存在，SSH 工具对不存在的本地父目录会直接报 `LOCAL_PATH_NOT_ALLOWED`），用精确文件名匹配（同第 1 步的告诫）批量核对，产出「文件 × 主机」矩阵，确认零 `STALE` 残留后才能宣布任务完成。这一步不是可选项——即便前面每台主机都各自做过读回验证，也必须有一次独立的、覆盖全部目标主机和全部目标文件的最终扫描，因为单机验证只能证明"这台主机这次改的几行没问题"，证明不了"清单本身是完整的"。

## 三环境 / 11 节点速查

三套环境：`ylk`、`ylk2`、`ylk3`，共 11 个 SSH 可达节点。安装模式（`INSTALL_MODE`）与节点的对应关系每次涉及批量操作前用 `kubectl get deploy -o yaml | grep INSTALL_MODE` 或直接查 SSH 连接名现核对一遍，不要直接照搬历史结论（环境可能新增/下线节点）：

| 环境 | 节点角色 | 典型安装模式 |
|---|---|---|
| ylk | bridge-nm / bridge-ex / bridge-ex2 | extend |
| ylk | starfish | saas |
| ylk2 | bridge-nm / bridge-ex / bridge-ex2 | extend |
| ylk2 | starfish | saas |
| ylk3 | bridge-ex / bridge-ex2 | extend |
| ylk3 | starfish | saas |

只有 `starfish` 节点是 `saas` 模式，其余全部 `extend`；`@saas&&starfish` 类文件只在 3 个 starfish 节点上跑，其余节点预期是 `NOT_RUN` 而非 `STALE`。

## 常见陷阱（踩过的坑，不要重复）

1. **hash 漂移 ≠ DB 真实缺口**：多数情况下目标库内容已经通过其他途径正确，直接盲写会产生重复列/重复行/重复索引报错，甚至覆盖运行期真实业务数据。永远先 `information_schema` 核验再决定写不写。
2. **文件名模糊匹配前缀碰撞**：同编号不同 `@spec_filter` 变体常共享很长公共前缀（如 `0174-...normal&&extend&&enhanced` vs `0174-...saas&&starfish`），SQL 查询/grep 用 `LIKE '%前缀%'` 会把两个文件的 ledger 记录错配，产出假阳性 `STALE`。必须精确匹配完整文件名。
3. **批量脚本先单机验证再全量跑**：`for host in ...` 循环里变量作用域污染、模板复制时漏填某一项，这类问题只有全量最终复核才能兜住，单机验证通过不代表批量清单本身完整。
4. **超大 base64 文件不要整段打印**：用 Python `find`/`rfind` 定位提取，直接写文件，不经终端回显。
5. **SSH/下载工具的本地路径限制**：`upload`/`download` 工具要求本地父目录已存在，且路径必须在允许范围内（不能用系统 `/tmp`），操作前用 `mkdir -p` 提前建好目标目录，用工作区内的路径而不是任意本地路径。
6. **确认工具参数名**：不同 MCP 工具的参数命名不一致（例如某些 SSH 执行工具用 `cmdString` 而非 `command`），首次调用报 `Invalid arguments` 时先用 `ToolSearch` 查真实 schema，不要凭记忆或别的工具的参数名硬猜。
7. **不要因为一次成功的批量操作就假设清单完整**：本轮曾在 11 台主机的模板脚本里漏掉一台该更新的一项，直到独立的最终复核才发现——教训是"逐台生成、逐台核对"不能省，"全量复核"更不能省。

## 完成标准

补偿运行任务在以下条件全部满足前不算完成：

1. 用户授权范围内的每个编号、每台目标主机都有明确结论（`已写库` / `已确认无需写库仅同步ledger` / `不在授权范围未处理`）。
2. 每次实际写库都有写库前后的 `information_schema` 核验证据。
3. 每台主机的 ledger 更新都有 backup 路径和读回验证输出。
4. 有一次覆盖全部目标主机 × 全部目标文件的独立最终复核，且结果为零 `STALE` 残留（`NOT_RUN` 需能用安装模式解释，不是异常）。
5. 范围外内容（用户明确排除的编号/领域）确认未被触碰。
6. 已向用户报告：哪些主机发生了真实 DB 写入、哪些是纯 ledger 同步、任何"判断不写库"的业务数据冲突场景及其依据。
