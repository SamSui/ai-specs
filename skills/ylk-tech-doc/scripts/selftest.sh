#!/usr/bin/env bash
# 自测：用异构模板与边界文档验证 md2docx.py + check_docx.py。
# 改动脚本后跑一遍，确认通用性未退化。
#
#   ./selftest.sh <模板1.docx> [模板2.docx ...]
#
# 模板取项目中任意已定稿的制式 docx；传多份可覆盖不同封面/目录结构。

set -u
[ $# -ge 1 ] || { echo "用法：$0 <模板.docx> [模板2.docx ...]"; exit 1; }

# 模板路径先转绝对：下面要 cd 到 scripts 目录，命令行传的相对路径届时会失效。
tmpls=()
for t in "$@"; do
    [ -f "$t" ] || { echo "!! 模板不存在：$t"; exit 1; }
    tmpls+=("$(cd "$(dirname "$t")" && pwd)/$(basename "$t")")
done

cd "$(dirname "$0")" || exit 1
SCRIPTS="$PWD"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fail=0

# 用例 1：多章 + 表格 + 小节
cat > "$WORK/a.md" <<'EOF'
# 某产品 - 设计说明书

## 1. 概述

第一章正文。

### 1.1 目的

小节内容。

| 列A | 列B |
|-----|-----|
| a1 | b1 |

**表 1-1 示例表**

## 2. 结论

第二章无表无图无小节。
EOF

# 用例 2：单章 + 无表无图 + 代码块 + 各类行内标记
cat > "$WORK/b.md" <<'EOF'
# 纯文本 - 说明

## 1. 唯一章节

只有一章。

- 列表项一
- 列表项二
  - 嵌套二级
    - 嵌套三级
- 列表项三

1. 有序一
2. 有序二
   1. 嵌套有序

> 引用块

正文含 `行内代码` 和 **加粗** 与 *斜体*。

```sql
SELECT ur.id, ur.name FROM user_role ur WHERE ur.id > 0;
```

#### 四级标题

四级标题下的正文。
EOF

for tmpl in "${tmpls[@]}"; do
    name=$(basename "$tmpl")
    for c in a b; do
        out="$WORK/out_$c.docx"
        if ! python3 "$SCRIPTS/md2docx.py" "$tmpl" "$WORK/$c.md" "$out" \
             "测试项目" "设计说明书" "测试文档" >/dev/null 2>"$WORK/err"; then
            echo "!! [$name/$c] 生成失败"; cat "$WORK/err"; fail=1; continue
        fi
        if python3 "$SCRIPTS/check_docx.py" "$out" "$WORK/$c.md" >"$WORK/log" 2>&1; then
            echo "OK [$name/$c]"
        else
            echo "!! [$name/$c]"; grep '\[!!\]' "$WORK/log"; fail=1
        fi
    done
done

# 下面两项针对最后一个模板的 out_b.docx；生成阶段若已失败就没有可断言的产物
if [ ! -f "$WORK/out_b.docx" ]; then
    echo "!! 跳过内容断言：out_b.docx 未生成"
    echo "存在失败项"; exit 1
fi

# 代码块须落为等宽段落，且行首前缀完整（Word 编号列表会吞 `ur.`）
python3 - "$WORK/out_b.docx" <<'EOF' || fail=1
import sys
from docx import Document
ps = [p for p in Document(sys.argv[1]).paragraphs if 'SELECT' in p.text]
if not ps:
    sys.exit('!! 代码块丢失')
if 'ur.id' not in ps[0].text:
    sys.exit('!! 代码块行首前缀被吞')
if not (ps[0].runs and ps[0].runs[0].font.name == 'Consolas'):
    sys.exit('!! 代码块未用等宽字体')
if any(p.text.strip().startswith('`') for p in Document(sys.argv[1]).paragraphs):
    sys.exit('!! 围栏标记泄漏为正文')
print('OK [代码块渲染]')
EOF

# 列表层级须落为递进缩进，有序列表须保留原序号
python3 - "$WORK/out_b.docx" <<'EOF' || fail=1
import sys
from docx import Document
from docx.oxml.ns import qn
ind = {}
for p in Document(sys.argv[1]).paragraphs:
    t = p.text.strip()
    for key in ('嵌套三级', '嵌套二级', '列表项一', '有序二', '嵌套有序'):
        if t.endswith(key):
            e = p._p.find(qn('w:pPr')).find(qn('w:ind'))
            ind[key] = int(e.get(qn('w:left'))) if e is not None else 0
missing = [k for k in ('嵌套三级', '嵌套二级', '列表项一', '有序二') if k not in ind]
if missing:
    sys.exit('!! 列表项丢失：%s' % missing)
if not ind['列表项一'] < ind['嵌套二级'] < ind['嵌套三级']:
    sys.exit('!! 列表层级未体现为递进缩进：%s' % ind)
doc = Document(sys.argv[1])
if not any(p.text.strip().startswith('2. ') for p in doc.paragraphs):
    sys.exit('!! 有序列表序号丢失')
print('OK [列表层级]')
EOF

[ $fail -eq 0 ] && echo "全部通过" || echo "存在失败项"
exit $fail
