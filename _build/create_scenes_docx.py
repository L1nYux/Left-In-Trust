# -*- coding: utf-8 -*-
import zipfile
import re
import html
from xml.sax.saxutils import escape

def md_to_docx(md_path, template_docx, output_docx):
    with open(md_path, 'r', encoding='utf-8') as f:
        md_text = f.read()

    lines = md_text.splitlines()

    # We will build body XML elements
    body_xml = []

    def make_run(text, bold=False, italic=False, color=None, size_pt=None, font="微软雅黑"):
        r_pr = ["<w:rPr>"]
        r_pr.append(f'<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:eastAsia="{font}"/>')
        if bold:
            r_pr.append("<w:b/>")
        if italic:
            r_pr.append("<w:i/>")
        if color:
            r_pr.append(f'<w:color w:val="{color}"/>')
        if size_pt:
            r_pr.append(f'<w:sz w:val="{int(size_pt * 2)}"/><w:szCs w:val="{int(size_pt * 2)}"/>')
        r_pr.append("</w:rPr>")
        
        # xml escape text, but handle spaces
        escaped_t = escape(text)
        space_attr = ' xml:space="preserve"' if (escaped_t.startswith(' ') or escaped_t.endswith(' ')) else ''
        t_el = f'<w:t{space_attr}>{escaped_t}</w:t>'
        return f"<w:r>{''.join(r_pr)}{t_el}</w:r>"

    def parse_inline(text, base_size=10.5, base_color="333333"):
        # simple markdown inline parser for bold **text**, code `code`, italic *text*
        runs = []
        tokens = re.split(r'(\*\*[^*]+\*\*|`[^`]+`|\*[^*]+\*)', text)
        for token in tokens:
            if not token:
                continue
            if token.startswith('**') and token.endswith('**'):
                content = token[2:-2]
                runs.append(make_run(content, bold=True, color=base_color, size_pt=base_size))
            elif token.startswith('`') and token.endswith('`'):
                content = token[1:-1]
                runs.append(make_run(content, bold=False, color="C4622D", size_pt=base_size*0.95, font="Consolas"))
            elif token.startswith('*') and token.endswith('*'):
                content = token[1:-1]
                runs.append(make_run(content, bold=False, italic=True, color="555555", size_pt=base_size))
            else:
                runs.append(make_run(token, bold=False, color=base_color, size_pt=base_size))
        return "".join(runs)

    def make_paragraph(runs_xml, align="left", space_before=100, space_after=100, line_rule="auto", line=280, bg_color=None):
        p_pr = ["<w:pPr>"]
        if align != "left":
            p_pr.append(f'<w:jc w:val="{align}"/>')
        p_pr.append(f'<w:spacing w:before="{space_before}" w:after="{space_after}" w:line="{line}" w:lineRule="{line_rule}"/>')
        if bg_color:
            p_pr.append(f'<w:shd w:val="clear" w:color="auto" w:fill="{bg_color}"/>')
        p_pr.append("</w:pPr>")
        return f"<w:p>{''.join(p_pr)}{runs_xml}</w:p>"

    def make_heading(text, level):
        sizes = {1: 18, 2: 14, 3: 12, 4: 11}
        colors = {1: "1A365D", 2: "2B6CB0", 3: "2D3748", 4: "4A5568"}
        space_befores = {1: 300, 2: 240, 3: 180, 4: 140}
        space_afters = {1: 150, 2: 120, 3: 80, 4: 60}
        
        runs = [make_run(text, bold=True, color=colors.get(level, "2D3748"), size_pt=sizes.get(level, 11))]
        return make_paragraph("".join(runs), space_before=space_befores.get(level, 150), space_after=space_afters.get(level, 100))

    in_code_block = False
    code_lines = []
    in_table = False
    table_rows = []

    def flush_table():
        if not table_rows:
            return ""
        # Build table XML
        tbl_xml = ["<w:tbl>"]
        tbl_pr = """<w:tblPr>
            <w:tblW w:w="5000" w:type="pct"/>
            <w:jc w:val="center"/>
            <w:tblBorders>
                <w:top w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
                <w:bottom w:val="single" w:sz="6" w:space="0" w:color="A0AEC0"/>
                <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
                <w:insideV w:val="none"/>
                <w:left w:val="none"/>
                <w:right w:val="none"/>
            </w:tblBorders>
        </w:tblPr>"""
        tbl_xml.append(tbl_pr)

        is_header = True
        for row in table_rows:
            tbl_xml.append("<w:tr>")
            for cell in row:
                tbl_xml.append("<w:tc>")
                tc_pr = ["<w:tcPr>"]
                if is_header:
                    tc_pr.append('<w:shd w:val="clear" w:color="auto" w:fill="EDF2F7"/>')
                tc_pr.append('<w:tcMar><w:top w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tcMar>')
                tc_pr.append("</w:tcPr>")
                tbl_xml.append("".join(tc_pr))
                
                # cell text
                cell_runs = parse_inline(cell.strip(), base_size=9.5, base_color="1A202C" if is_header else "2D3748")
                p = make_paragraph(cell_runs, space_before=40, space_after=40)
                tbl_xml.append(p)
                tbl_xml.append("</w:tc>")
            tbl_xml.append("</w:tr>")
            is_header = False
        tbl_xml.append("</w:tbl>")
        tbl_xml.append(make_paragraph("", space_before=60, space_after=60))
        return "".join(tbl_xml)

    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Code block
        if line.strip().startswith("```"):
            if in_code_block:
                in_code_block = False
                # emit code box
                box_runs = []
                for cl in code_lines:
                    escaped_cl = escape(cl)
                    space_attr = ' xml:space="preserve"'
                    t_el = f'<w:t{space_attr}>{escaped_cl}</w:t>'
                    r = f'<w:r><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:eastAsia="Consolas"/><w:sz w:val="18"/><w:szCs w:val="18"/><w:color w:val="2D3748"/></w:rPr>{t_el}</w:r>'
                    p = make_paragraph(r, space_before=20, space_after=20, bg_color="F7FAFC", line=220)
                    body_xml.append(p)
                code_lines = []
            else:
                if in_table:
                    body_xml.append(flush_table())
                    in_table = False
                    table_rows = []
                in_code_block = True
                code_lines = []
            i += 1
            continue

        if in_code_block:
            code_lines.append(line)
            i += 1
            continue

        # Table
        if line.strip().startswith("|") and line.strip().endswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            # check if it is divider row
            if all(re.match(r'^:?-+:?$', c) for c in cells):
                pass # skip divider
            else:
                table_rows.append(cells)
                in_table = True
            i += 1
            continue
        else:
            if in_table:
                body_xml.append(flush_table())
                in_table = False
                table_rows = []

        stripped = line.strip()
        if not stripped:
            i += 1
            continue

        # Headings
        if stripped.startswith("#### "):
            body_xml.append(make_heading(stripped[5:], 4))
        elif stripped.startswith("### "):
            body_xml.append(make_heading(stripped[4:], 3))
        elif stripped.startswith("## "):
            body_xml.append(make_heading(stripped[3:], 2))
        elif stripped.startswith("# "):
            body_xml.append(make_heading(stripped[2:], 1))
        elif stripped.startswith("---"):
            # horizontal rule
            r = make_run("―" * 45, color="CBD5E0", size_pt=9)
            body_xml.append(make_paragraph(r, align="center", space_before=150, space_after=150))
        elif stripped.startswith("> "):
            # blockquote
            quote_text = stripped[2:].strip()
            runs = parse_inline(quote_text, base_size=10, base_color="4A5568")
            body_xml.append(make_paragraph(runs, space_before=60, space_after=60, bg_color="EDF2F7"))
        elif stripped.startswith("- ") or stripped.startswith("* "):
            bullet_text = stripped[2:].strip()
            # bullet point
            b_run = make_run("•  ", bold=True, color="2B6CB0", size_pt=10.5)
            content_runs = parse_inline(bullet_text, base_size=10.5)
            body_xml.append(make_paragraph(b_run + content_runs, space_before=40, space_after=40))
        elif re.match(r'^\d+\.\s+', stripped):
            num_match = re.match(r'^(\d+\.)\s+(.*)', stripped)
            num_str = num_match.group(1)
            content = num_match.group(2)
            n_run = make_run(num_str + " ", bold=True, color="2B6CB0", size_pt=10.5)
            content_runs = parse_inline(content, base_size=10.5)
            body_xml.append(make_paragraph(n_run + content_runs, space_before=40, space_after=40))
        else:
            runs = parse_inline(stripped, base_size=10.5)
            body_xml.append(make_paragraph(runs, space_before=60, space_after=60))

        i += 1

    if in_table:
        body_xml.append(flush_table())

    # Build final document.xml
    new_doc_xml = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas" 
xmlns:mo="http://schemas.microsoft.com/office/mac/office/2008/main" 
xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" 
xmlns:mv="urn:schemas-microsoft-com:mac:vml" 
xmlns:o="urn:schemas-microsoft-com:office:office" 
xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" 
xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" 
xmlns:v="urn:schemas-microsoft-com:vml" 
xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing" 
xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" 
xmlns:w10="urn:schemas-microsoft-com:office:word" 
xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" 
xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" 
xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml" 
xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" 
xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk" 
xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml" 
xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" mc:Ignorable="w14 w15 wp14">
<w:body>
{''.join(body_xml)}
<w:sectPr>
    <w:pgSz w:w="11906" w:h="16838"/>
    <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
    <w:cols w:space="708"/>
    <w:docGrid w:linePitch="360"/>
</w:sectPr>
</w:body>
</w:document>"""

    # Re-pack docx
    with zipfile.ZipFile(template_docx, 'r') as zin:
        with zipfile.ZipFile(output_docx, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                if item.filename == 'word/document.xml':
                    zout.writestr(item, new_doc_xml.encode('utf-8'))
                else:
                    zout.writestr(item, zin.read(item.filename))
    print(f"Successfully created: {output_docx}")

if __name__ == '__main__':
    md_to_docx(
        'D:/MyPros/AI游戏/docs/精细化战斗场景设计方案.md',
        'D:/MyPros/AI游戏/总览.docx',
        'D:/MyPros/AI游戏/docs/精细化战斗场景设计方案.docx'
    )
