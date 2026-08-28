#!/usr/bin/env python3
"""制式常量：生成侧（md2docx.py）与校验侧（check_docx.py）的唯一来源。

两侧曾各写一份，改制式漏改一处就变成「生成的文档永远校验不过」，
且报错不指向根因。

换模板时用 JSON 覆盖，不必改源码：

    python3 md2docx.py --spec myspec.json ...
    python3 check_docx.py --spec myspec.json ...

JSON 只需写要改的键，其余沿用默认：

    {"tbl_width_dxa": 9072, "toc_font": "仿宋", "img_max_width_in": 5.5}
"""
import json
import sys

# 默认制式。A4 纵向、正文区宽 8856 dxa 的中文工程文档。
DEFAULT_SPEC = {
    'tbl_width_dxa': 8856,      # 表宽，与正文区等宽
    'header_fill': 'BEBEBE',    # 表头底纹
    'border_sz': '4',           # 表格线粗细（0.5pt）
    'img_max_width_in': 6.0,    # 图片最大宽度（英寸）
    'toc_font': '宋体',          # 目录条目字体
    'toc_font_cs': 'Times New Roman',
    'toc_sz': '24',             # 目录条目字号（24 = 12pt 小四）
    'toc_kern': '22',
    'body_sz': '24',           # 正文字号（24 = 12pt 小四）
    'code_font': '仿宋',          # 代码块字体（等宽字体与中文工程文档制式不符，改仿宋）
    'code_font_cs': 'Times New Roman',  # 代码块西文字体
    'code_sz_delta': -2,         # 代码块字号相对正文（-2 = 小一号，24→22 即小五与五号之间）
    'code_color': '595959',      # 代码块字色（浅于正文黑色，加强区分）
    'table_style': 'Table',     # 表格样式名，缺失时回退 Table Grid
    'date_field': '项目时间',    # 封面日期栏的键名
    'date_format': '%Y年 %m 月 %d 日',
    'cover_scan': 20,           # 封面段落扫描范围（body 前 N 个子元素）
    'tmpl_tables': 2,           # 模板自带表格数（签署栏、修订记录等）
    'sections': 3,              # 期望分节点数（四段分节 → 3 个分节符）
}


def load_spec(path=None):
    """读取制式。path 为 None 时返回默认制式的副本。"""
    spec = dict(DEFAULT_SPEC)
    if path:
        try:
            with open(path, encoding='utf-8') as f:
                override = json.load(f)
        except OSError as e:
            sys.exit('制式文件读取失败：%s' % e)
        except json.JSONDecodeError as e:
            sys.exit('制式文件不是合法 JSON：%s' % e)
        if not isinstance(override, dict):
            sys.exit('制式文件顶层须是 JSON 对象，实为 %s'
                     % type(override).__name__)
        unknown = set(override) - set(DEFAULT_SPEC)
        if unknown:
            sys.exit('未知的制式键 %s；可用键见 _docx_spec.py 的 DEFAULT_SPEC'
                     % sorted(unknown))
        spec.update(override)
    return spec


def add_spec_arg(parser):
    """给 argparse 挂 --spec 选项。"""
    parser.add_argument('--spec', metavar='spec.json',
                        help='制式覆盖文件，键见 _docx_spec.py 的 DEFAULT_SPEC')
