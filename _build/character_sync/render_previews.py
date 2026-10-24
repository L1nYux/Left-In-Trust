from pathlib import Path
import os, importlib.util, json, sys, tempfile
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'_build/character_sync'
RUNTIME=Path('C:/Users/Lenovo/.cache/codex-runtimes/codex-primary-runtime')
RENDERER=Path('C:/Users/Lenovo/.codex/plugins/cache/openai-primary-runtime/documents/26.1022.11436/skills/documents/render_docx.py')
os.environ['PATH']=str(RUNTIME/'dependencies/native/poppler/Library/bin')+os.pathsep+os.environ['PATH']
(QA/'tmp').mkdir(exist_ok=True)
tempfile.tempdir=str(QA/'tmp')
spec=importlib.util.spec_from_file_location('docx_renderer',RENDERER)
renderer=importlib.util.module_from_spec(spec)
spec.loader.exec_module(renderer)

# The runtime manifest has no bundled LibreOffice on Windows. PDFs are exported
# read-only by hidden Microsoft Word; use the skill renderer for rasterization.
def word_pdf(doc_path,user_profile,convert_tmp_dir,stem,verbose=False):
    pdf=QA/'pdf'/(stem+'.pdf')
    if not pdf.exists(): raise FileNotFoundError(pdf)
    if pdf.stat().st_mtime < Path(doc_path).stat().st_mtime:
        raise RuntimeError('PDF export is older than DOCX: '+stem)
    return str(pdf),'Native Microsoft Word read-only export'
renderer.convert_to_pdf=word_pdf

manifest=[]
for f in sorted((ROOT/'角色设定/性格').glob('*.docx')):
    if len(sys.argv)>1 and f.stem not in sys.argv[1:]: continue
    folder=QA/'render'/f.stem
    pages=renderer.rasterize(str(f),str(folder),96,False,False)
    for offset in range(0,len(pages),2):
        imgs=[Image.open(p).convert('RGB') for p in pages[offset:offset+2]]
        canvas=Image.new('RGB',(sum(im.width for im in imgs),max(im.height for im in imgs)+24),'#dedede')
        draw=ImageDraw.Draw(canvas); x=0
        for n,im in enumerate(imgs):
            draw.text((x+8,4),f'{f.stem} page {offset+n+1}',fill='black')
            canvas.paste(im,(x,24)); x+=im.width
        canvas.save(folder/f'spread-{offset//2+1}.png')
    manifest.append({'file':f.name,'pages':len(pages),'spreads':(len(pages)+1)//2})
    print(f.stem,len(pages),'pages',flush=True)
manifest_path=QA/'render_manifest.json'
if len(sys.argv)>1 and manifest_path.exists():
    previous=json.loads(manifest_path.read_text(encoding='utf-8'))
    updated={item['file']:item for item in previous}
    updated.update({item['file']:item for item in manifest})
    manifest=sorted(updated.values(),key=lambda item:item['file'])
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
