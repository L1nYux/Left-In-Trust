from pathlib import Path
import json, hashlib, re
from docx import Document

ROOT = Path(__file__).resolve().parents[2]
if (ROOT / '_build/review/source_inventory.json').exists():
    raise SystemExit('整理前清单已存在，禁止覆盖原始校验依据。当前检查请运行 audit_sources.py。')
OUT = ROOT / '_build/review/extracted'
OUT.mkdir(parents=True, exist_ok=True)
manifest = []
for p in sorted(ROOT.rglob('*')):
    if not p.is_file() or any(x in p.relative_to(ROOT).parts for x in ['_build', '.dsh', '.git']):
        continue
    if p.suffix.lower() not in ['.md', '.txt', '.docx', '.json', '.png', '.jpg', '.webp']:
        continue
    item = {'path': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size,
            'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
    if p.suffix == '.docx':
        doc = Document(p)
        # Preserve paragraph/table reading order for text review.
        parts = []
        for block in doc.element.body:
            if block.tag.endswith('}p'):
                parts.append(''.join(block.itertext()) if False else ''.join(block.xpath('.//w:t/text()')))
            elif block.tag.endswith('}tbl'):
                for row in block.xpath('./w:tr'):
                    parts.append(' | '.join(''.join(cell.xpath('.//w:t/text()')) for cell in row.xpath('./w:tc')))
        target = OUT / (p.stem + '.txt')
        target.write_text('\n'.join(parts), encoding='utf-8')
        item['extracted'] = target.relative_to(ROOT).as_posix()
        item['paragraphs'] = len(doc.paragraphs)
    manifest.append(item)
(OUT.parent / 'source_inventory.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Inventoried {len(manifest)} source files; extracted {sum("extracted" in x for x in manifest)} Word files.')
