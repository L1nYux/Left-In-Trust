from pathlib import Path
import hashlib, json, re
from urllib.parse import unquote
from docx import Document

ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'_build/review'
errors=[]
original=json.loads((QA/'source_inventory.json').read_text(encoding='utf-8'))
backup_count=art_count=0
for entry in original:
    rel=Path(entry['path'])
    is_art=rel.suffix.lower() in {'.png','.jpg','.webp'}
    target=ROOT/rel if is_art else ROOT/'docs/历史/2026-10-24整理前'/rel
    if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest()!=entry['sha256']:
        errors.append('Original mismatch: '+entry['path'])
    if is_art:art_count+=1
    else:backup_count+=1

def normalized(text):
    return re.sub(r'\s+','',text.replace('\ufeff',''))
def plain(text):
    return re.sub(r'\[([^\]]+)\]\([^)]+\)',r'\1',text).replace('**','').replace('`','')
def expected(text):
    result=[]
    for line in text.splitlines():
        line=line.strip()
        if not line or line=='<!-- PAGEBREAK -->':continue
        if line.startswith('|'):
            if re.fullmatch(r'[|\s:\-]+',line):continue
            result.extend(plain(cell.strip()) for cell in line.strip('|').split('|'))
        elif line.startswith('#'):result.append(plain(line.lstrip('#').strip()))
        elif line.startswith('- '):result.append('• '+plain(line[2:]))
        else:result.append(plain(line))
    return normalized(''.join(result))
word_files=json.loads((QA/'word_outputs.json').read_text(encoding='utf-8'))
for rel in word_files:
    path=ROOT/rel
    source=path.with_suffix('.md').read_text(encoding='utf-8')
    doc=Document(path)
    actual=normalized(''.join(doc.element.body.xpath('.//w:t/text()')))
    if expected(source)!=actual:errors.append('Word text mismatch: '+rel)
mirrors=list((ROOT/'角色设定/性格').glob('*.md'))
for source in mirrors:
    mirror=ROOT/'_build/src'/source.name
    if not mirror.exists() or source.read_bytes()!=mirror.read_bytes():errors.append('Mirror mismatch: '+source.name)

current_names=['规则基准','战斗规格','Demo剧情脚本','Demo范围','决策记录','阶段交接','美术资产清单','全面审阅与修订记录','验证报告','卡牌表']
current=[ROOT/'README.md',ROOT/'总览.md',ROOT/'玩法.md',ROOT/'剧情大纲.md',ROOT/'项目推进流程与AI提示词.md',*[ROOT/'docs'/f'{name}.md' for name in current_names],*mirrors,ROOT/'_build/README.md']
link_count=0
for source in current:
    for href in re.findall(r'\[[^\]]*\]\(([^)]+)\)',source.read_text(encoding='utf-8-sig')):
        href=unquote(href.strip('<>').split('#')[0])
        if not href or re.match(r'^[a-z]+://',href):continue
        link_count+=1
        if not (source.parent/href).exists():errors.append('Broken link: '+str(source.relative_to(ROOT))+' -> '+href)
pages=json.loads((QA/'render_manifest.json').read_text(encoding='utf-8'))
for item in pages:
    if len(item['pages'])!=2:errors.append('Unexpected page count: '+item['file'])
    for rel in item['pages']:
        if not (ROOT/rel).is_file():errors.append('Missing rendered page: '+rel)
    pdf=QA/'pdf'/(Path(item['file']).stem+'.pdf')
    if pdf.stat().st_mtime<(ROOT/item['file']).stat().st_mtime:errors.append('Stale PDF: '+item['file'])
report={'originalContentFiles':len(original),'verifiedOriginalBackups':backup_count,'unchangedArtFiles':art_count,'wordTextPairs':len(word_files),'characterMirrors':len(mirrors),'currentMarkdownFiles':len(current),'localLinksChecked':link_count,'renderedDocuments':len(pages),'renderedPages':sum(len(i['pages'])for i in pages),'visualReview':'All 38 final pages inspected in this session; latest GLM replacement re-inspected. This is a recorded manual review, not an automated layout assertion.','errors':errors}
(QA/'source_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
raise SystemExit(bool(errors))
