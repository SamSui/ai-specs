#!/usr/bin/env python3
"""制式 docx 结构校验：分节、目录域、书签、表格版式、内容完整性。

本机通常没有 Word/LibreOffice，无法渲染验证版面，因此校验一律落在
OOXML 结构层。凡结构与已归档样板一致的，交给 Word/WPS 打开即成立。

用法：
    python3 check_docx.py <文档.docx> [对应的.md] \\
        [--tmpl-tables N] [--sections N] [--spec spec.json]
"""
import argparse
import re
import sys
import zipfile
from collections import Counter

from docx import Document
from docx.oxml.ns import qn

from _docx_spec import DEFAULT_SPEC, add_spec_arg, load_spec


def check(docx_path, md_path=None, tmpl_tables=None, sections=None, spec=None):
    spec = spec or load_spec()
    tbl_width = str(spec['tbl_width_dxa'])
    header_fill = spec['header_fill']
    toc_sz = spec['toc_sz']
    tmpl_tables = spec['tmpl_tables'] if tmpl_tables is None else tmpl_tables
    sections = spec['sections'] if sections is None else sections
    with zipfile.ZipFile(docx_path) as z:
        x = z.read('word/document.xml').decode('utf-8')
    doc = Document(docx_path)
    body = doc.element.body
    ok = True

    def report(label, passed, detail=''):
        nonlocal ok
        if passed is None:                      # 该项不适用，不计入结论
            print('  [--] %-22s %s' % (label, detail))
            return
        ok = ok and passed
        print('  [%s] %-22s %s' % ('OK' if passed else '!!', label, detail))

    print('===', docx_path.rsplit('/', 1)[-1])

    # 1. 分节数。默认 3（封面 | 签署页+修订记录 | 目录 | 正文），
    #    模板制式不同时用 --sections 调整。
    secs = [i for i, ch in enumerate(body.iterchildren())
            if ch.tag == qn('w:p') and ch.find(qn('w:pPr')) is not None
            and ch.find(qn('w:pPr')).find(qn('w:sectPr')) is not None]
    report('分节点', len(secs) == sections,
           '%s（应 %d 个；正文节 sectPr 在 body 末）' % (secs, sections))

    # 2. 每章一级标题另起页（首章紧随文档标题，不另起）
    h1 = [p for p in doc.paragraphs if p.style.name == 'Heading 1']
    brk = sum(1 for p in h1
              if p._p.find(qn('w:pPr')) is not None
              and p._p.find(qn('w:pPr')).find(qn('w:pageBreakBefore')) is not None)
    report('章分页', brk == max(len(h1) - 1, 0), '%d/%d' % (brk, max(len(h1) - 1, 0)))

    # 3. 域 begin/separate/end 三类必须等量，否则 Word 会报「错误！未找到引用源」
    fc = Counter(e.get(qn('w:fldCharType')) for e in body.iter(qn('w:fldChar')))
    report('域配对', fc['begin'] == fc['separate'] == fc['end'],
           'begin=%d separate=%d end=%d' % (fc['begin'], fc['separate'], fc['end']))

    # 4. PAGEREF 指向的书签必须都有定义，且书签落在标题段落上
    refs = set(re.findall(r'PAGEREF\s+(_Toc\d+)', x))
    defs = {b.get(qn('w:name')) for b in body.iter(qn('w:bookmarkStart'))
            if (b.get(qn('w:name')) or '').startswith('_Toc')}
    report('书签引用', not (refs - defs), '引用 %d 悬空 %s' % (len(refs), refs - defs or '无'))

    on_head = 0
    for p in doc.paragraphs:
        names = [b.get(qn('w:name')) for b in p._p.iter(qn('w:bookmarkStart'))]
        if any(n and n.startswith('_Toc') for n in names):
            if p.style.name.startswith('Heading') or p.style.name == 'Title':
                on_head += 1
    report('书签落位', on_head == len(refs), '%d/%d 在标题段落上' % (on_head, len(refs)))

    # 5. dirty 域：打开文档即重算页码。缺此标记则目录页码停留在占位值。
    #    按属性读而非字符串匹配——Word/WPS 另存后序列化形式会变（true/1）。
    dirty = sum(1 for e in body.iter(qn('w:fldChar'))
                if (e.get(qn('w:dirty')) or '').lower() in ('true', '1'))
    report('dirty 域', dirty >= len(refs) if refs else None,
           '%d 个（应 ≥ PAGEREF 数 %d）' % (dirty, len(refs)))

    # 6. 目录条目字号（宋体小四 = sz 24）
    sz = set()
    for p in doc.paragraphs:
        if p.style.name.startswith('toc'):
            for s in p._p.iter(qn('w:sz')):
                sz.add(s.get(qn('w:val')))
    report('目录字号', (sz == {toc_sz}) if sz else None,
           'sz=%s（应 %s）%s' % (sorted(sz), toc_sz,
                              '' if sz else ' 文档无目录条目，跳过'))

    # 7. 表格版式：定宽、居中、边框、表头底纹与跨页重复。
    #    模板自带表（签署栏、修订记录）按下标区分——它们在正文之前。
    bad = []
    for i, t in enumerate(doc.tables):
        if i < tmpl_tables:
            continue
        pr = t._tbl.find(qn('w:tblPr'))
        if pr is None:
            bad.append((i, 'no tblPr'))
            continue
        w = pr.find(qn('w:tblW'))
        if w is None or w.get(qn('w:w')) != tbl_width:
            bad.append((i, 'width'))
        if pr.find(qn('w:tblBorders')) is None:
            bad.append((i, 'borders'))
        tr = t._tbl.findall(qn('w:tr'))
        if tr:
            trPr = tr[0].find(qn('w:trPr'))
            if trPr is None or trPr.find(qn('w:tblHeader')) is None:
                bad.append((i, 'header-repeat'))
            tc = tr[0].find(qn('w:tc'))
            if tc is not None:
                tcPr = tc.find(qn('w:tcPr'))
                shd = tcPr.find(qn('w:shd')) if tcPr is not None else None
                if shd is None or shd.get(qn('w:fill')) != header_fill:
                    bad.append((i, 'header-fill'))
    ntbl = max(len(doc.tables) - tmpl_tables, 0)
    report('表格版式', not bad if ntbl else None,
           '正文表 %d 张，异常 %s' % (ntbl, bad or '无'))

    # 8. 与 md 对账：表格数、图片数
    if md_path:
        with open(md_path, encoding='utf-8') as f:
            md = f.read()
        # 分隔行须紧跟表头行，否则整行都是「-」的数据行会被误计
        md_lines = [l.strip() for l in md.split('\n')]
        md_tbl = sum(1 for j, l in enumerate(md_lines)
                     if j > 0 and re.match(r'^\|[-\s:|]+\|$', l)
                     and md_lines[j - 1].startswith('|')
                     and not re.match(r'^\|[-\s:|]+\|$', md_lines[j - 1]))
        md_img = len(re.findall(r'^!\[', md, re.M))
        report('表格数对账', ntbl == md_tbl, 'docx %d vs md %d' % (ntbl, md_tbl))
        report('图片数对账', len(doc.inline_shapes) == md_img,
               'docx %d vs md %d' % (len(doc.inline_shapes), md_img))

    # 9. 目录条目文本须与正文标题一致（去掉自动编号前缀后比较）
    toc_txt = [re.sub(r'\t\d+$', '', p.text).strip()
               for p in doc.paragraphs if p.style.name.startswith('toc')]
    toc_h1 = [re.sub(r'^\d+\.\s*', '', t) for t in toc_txt
              if re.match(r'^\d+\.\s', t)]
    body_h1 = [p.text.strip() for p in h1]
    report('目录↔正文', toc_h1 == body_h1,
           '一级标题 %d 条%s' % (len(toc_h1), '' if toc_h1 == body_h1 else ' 不一致'))

    return ok


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('docx', help='待校验的 docx')
    ap.add_argument('md', nargs='?', help='对应的 md，用于内容对账')
    ap.add_argument('--tmpl-tables', type=int,
                    help='模板自带的表格数（签署栏、修订记录等），'
                         '默认取制式的 tmpl_tables（%d）' % DEFAULT_SPEC['tmpl_tables'])
    ap.add_argument('--sections', type=int,
                    help='期望的分节点数，默认取制式的 sections（%d）'
                         % DEFAULT_SPEC['sections'])
    add_spec_arg(ap)
    a = ap.parse_args()
    good = check(a.docx, a.md, a.tmpl_tables, a.sections, load_spec(a.spec))
    print('\n结论：%s' % ('全部通过' if good else '存在未通过项，见上方 !! 行'))
    sys.exit(0 if good else 1)
