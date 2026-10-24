from pathlib import Path
import re,json,sys
from docx import Document
from docx.shared import Pt,Cm,RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
ROOT=Path(__file__).resolve().parents[2]
def font(style,size,bold=False):
    style.font.name='Microsoft YaHei';style.font.size=Pt(size);style.font.bold=bold;style.font.color.rgb=RGBColor(0,0,0)
    style.element.get_or_add_rPr().get_or_add_rFonts().set(qn('w:eastAsia'),'微软雅黑')
def plain(t):
    t=re.sub(r'\[([^\]]+)\]\([^)]+\)',r'\1',t)
    return t.replace('**','').replace('`','')
def build(src):
    doc=Document();sec=doc.sections[0];sec.page_width=Cm(21);sec.page_height=Cm(29.7)
    sec.top_margin=Cm(1.8);sec.bottom_margin=Cm(1.8);sec.left_margin=Cm(2);sec.right_margin=Cm(2)
    font(doc.styles['Normal'],10.5);p=doc.styles['Normal'].paragraph_format;p.line_spacing=1.08;p.space_after=Pt(3)
    font(doc.styles['Title'],22,True);doc.styles['Title'].paragraph_format.space_after=Pt(12)
    for name,size in [('Heading 1',15),('Heading 2',12),('Heading 3',11)]:
        font(doc.styles[name],size,True);doc.styles[name].paragraph_format.space_before=Pt(7);doc.styles[name].paragraph_format.space_after=Pt(4)
    for style in doc.styles:
        for border in style.element.xpath('.//w:pBdr'):border.getparent().remove(border)
    lines=src.read_text(encoding='utf-8').splitlines();i=0;break_before=False
    while i<len(lines):
        line=lines[i].strip();i+=1
        if not line:continue
        if line=='<!-- PAGEBREAK -->':break_before=True;continue
        if line.startswith('|'):
            rows=[line]
            while i<len(lines)and lines[i].strip().startswith('|'):rows.append(lines[i].strip());i+=1
            parsed=[[plain(x.strip())for x in l.strip('|').split('|')]for l in rows if not re.fullmatch(r'[|\s:\-]+',l)]
            table=doc.add_table(rows=0,cols=len(parsed[0]));table.autofit=False
            for j,row in enumerate(parsed):
                cells=table.add_row().cells
                for k,t in enumerate(row):
                    cells[k].text=t
                    for p in cells[k].paragraphs:
                        p.paragraph_format.space_after=Pt(3);p.paragraph_format.space_before=Pt(3)
                        for r in p.runs:r.font.size=Pt(9.5);r.font.bold=j==0
                    tcPr=cells[k]._tc.get_or_add_tcPr();shd=OxmlElement('w:shd');shd.set(qn('w:fill'),'E8EDF2'if j==0 else ('F7F8FA'if j%2==0 else 'FFFFFF'));tcPr.append(shd)
                if j==0:
                    rep=OxmlElement('w:tblHeader');table.rows[-1]._tr.get_or_add_trPr().append(rep)
                keep=OxmlElement('w:cantSplit');table.rows[-1]._tr.get_or_add_trPr().append(keep)
            borders=OxmlElement('w:tblBorders')
            for edge in ['top','left','bottom','right','insideH','insideV']:
                item=OxmlElement(f'w:{edge}');item.set(qn('w:val'),'single');item.set(qn('w:sz'),'4');item.set(qn('w:color'),'D9D9D9');borders.append(item)
            table._tbl.tblPr.append(borders)
            # The character table has a short name, a long personality, a medium role.
            widths=[2.4,9.5,5.1]if len(parsed[0])==3 else [17/len(parsed[0])]*len(parsed[0])
            for row in table.rows:
                for c,w in zip(row.cells,widths):c.width=Cm(w)
            doc.add_paragraph();continue
        level=len(line)-len(line.lstrip('#'))
        if level:
            title=plain(line[level:].strip());para=doc.add_paragraph(title,'Title'if level==1 else f'Heading {min(level-1,3)}')
            if break_before:para.paragraph_format.page_break_before=True;break_before=False
            continue
        if line.startswith('- '):
            doc.add_paragraph('• '+plain(line[2:]));continue
        doc.add_paragraph(plain(line))
    doc.core_properties.title=plain(lines[0].lstrip('# '));doc.core_properties.subject='未尽之托 当前设计文档';doc.core_properties.author='';doc.core_properties.keywords='v0.5'
    target=src.with_suffix('.docx');doc.save(target);return target
sources=[ROOT/'总览.md',ROOT/'玩法.md',*sorted((ROOT/'角色设定/性格').glob('*.md'))]
manifest=[str(s.with_suffix('.docx').relative_to(ROOT))for s in sources]
for s in sources:
    if len(sys.argv)==1 or s.stem in sys.argv[1:]:build(s)
(ROOT/'_build/review/word_outputs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('Updated',len(manifest),'Word documents')
