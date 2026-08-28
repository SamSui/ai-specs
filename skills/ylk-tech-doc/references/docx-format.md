# 制式 docx OOXML 参考

从参考样板提取的结构细节。`md2docx.py` 已实现全部要点，本文用于排查异常或适配新模板。

## 文档骨架

body 元素序列（下标为样板实测值，随封面内容微调）：

```
idx 0–17    封面（Title 段 + 项目信息段）
idx 18      [分节] 段落 pPr/sectPr
idx 19–25   签署页（表格：编制/审核/标审/质量/批准）+ 修订记录表
idx 26      [分节] 段落 pPr/sectPr
idx 27–5x   目录（TOC 域）
idx 5x      [分节] 段落 pPr/sectPr —— 正文页码自此重编
idx 5x+     正文
body 末     sectPr（正文节）
```

分节点判定：`w:p/w:pPr/w:sectPr` 存在即为分节段落。正文节的 sectPr 挂在 body 末尾。

## 页面参数（正文节 sectPr）

| 属性 | 值 |
|------|-----|
| `w:pgSz` | w=11906 h=16838（A4 纵向） |
| `w:pgMar` | top=1440 bottom=1440 left=1797 right=1797 |
| `w:docGrid` | linePitch=326 |

## 样式集

| 样式 | 字体 | 字号 | 加粗 | 段间距 |
|------|------|------|------|--------|
| Title | Arial | 16pt | 是 | — |
| Heading 1 | 黑体 | 15pt | 是 | before/after 6pt |
| Heading 2 | 黑体 | 14pt | 否 | — |
| Heading 3 | 黑体 | 14pt | 是 | — |
| Body Text | Times New Roman | 12pt | 否 | after 6pt |
| Caption | — | 10.5pt | — | — |
| Normal | Times New Roman | 12pt | 否 | — |
| Compact | 基于 Body Text | — | — | before/after 36（表格单元格用） |
| toc 1 | 无 rPr，继承 Normal | — | — | — |
| toc 2 | — | — | — | `w:ind left=420 leftChars=200` |
| 目次 | 黑体 | sz=32 | — | — |

## 表格

`tblPr` 子元素顺序不可乱（schema 有序）：

```xml
<w:tblPr>
  <w:tblW w:w="8856" w:type="dxa"/>
  <w:jc w:val="center"/>
  <w:tblBorders>  <!-- top/left/bottom/right/insideH/insideV 均 sz=4 single -->
  <w:tblLayout w:type="autofit"/>
  <w:tblCellMar>  <!-- top=0 left=108 bottom=0 right=108 -->
</w:tblPr>
```

- `tblGrid` 按列数均分 8856。
- 每行 `trPr`：`trHeight`（atLeast）+ `jc=center`；**首行额外加 `tblHeader`** 实现跨页重复表头。
- 首行每格 `tcPr`：`shd fill="BEBEBE"` + `vAlign=center`；run 加粗、段落居中。
- 数据行：`run.bold = None`（不是 False，避免覆盖样式）、左对齐。
- 单元格段落一律 `Compact` 样式 + `spacing line=240 lineRule=auto` + 缩进清零。

> 样板中术语表首列加粗、主线表首列不加粗，判定为**手工编辑残留而非制式**，统一按「数据行不加粗」处理。

## 目录域

整体是一个 TOC 域，内部每个条目又是一个 HYPERLINK 域，条目内还嵌一个 PAGEREF 域：

```xml
<!-- 首个 toc 段落承载 TOC 域 -->
<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>
<w:r><w:instrText xml:space="preserve">TOC \o "1-2" \h \u </w:instrText></w:r>
<w:r><w:fldChar w:fldCharType="separate"/></w:r>

<!-- 每个条目一个独立段落，样式 toc 1 / toc 2 -->
  <w:r><w:fldChar w:fldCharType="begin"/></w:r>
  <w:r><w:instrText xml:space="preserve"> HYPERLINK \l _Toc1001 </w:instrText></w:r>
  <w:r><w:fldChar w:fldCharType="separate"/></w:r>
  <w:r><w:t>1. 引言</w:t></w:r>
  <w:r><w:tab/></w:r>
    <w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>
    <w:r><w:instrText xml:space="preserve"> PAGEREF _Toc1001 \h </w:instrText></w:r>
    <w:r><w:fldChar w:fldCharType="separate"/></w:r>
    <w:r><w:t>1</w:t></w:r>            <!-- 占位，打开文档时重算 -->
    <w:r><w:fldChar w:fldCharType="end"/></w:r>
  <w:r><w:fldChar w:fldCharType="end"/></w:r>   <!-- 闭合 HYPERLINK -->

<!-- TOC 域的 end 追加在最后一个条目段落末尾 -->
<w:r><w:fldChar w:fldCharType="end"/></w:r>
```

要点：

- 条目段落 `pPr` 需带制表位：`w:tab val=right leader=dot pos=8640`。
- 条目 run 的 rPr：宋体（ascii/hAnsi/eastAsia 均为「宋体」，cs=Times New Roman）+ `kern=22` + `sz=24` + `szCs=24`。
- **begin/separate/end 三类 fldChar 必须等量**，否则 Word 报「错误！未找到引用源」。
- 书签 `_TocXXXX` 由 `bookmarkStart/bookmarkEnd` 包裹标题段落，id 从 1000 起编避开模板既有书签。
- 重建目录时，首个 toc 段落只保留最外层 TOC 域的 begin / instrText(含 'TOC') / separate 三个 run，其余 run 与所有 `w:hyperlink` 元素必须删净，否则残留旧文档的标题文本。

## 页码更新

- `word/settings.xml` 写 `<w:updateFields w:val="true"/>`。
- 所有域的 begin 加 `w:dirty="true"` —— 比 updateFields 更强制，WPS 打开即重算。
- 占位值 `1` 只是缓存，Word/WPS 更新域后覆盖为真实值。人工打开保存一次即固化。

## 分页

每章一级标题另起页，用 `w:pageBreakBefore`（追加到 Heading 1 段落的 pPr）。首章紧随文档标题，不加。

> 样板中有用 `w:br type="page"` 手工分页的，效果等同；选 `pageBreakBefore` 是因为由脚本自动生成，章节增删不会错位。
