from pathlib import Path
import importlib.util,os,json,tempfile
ROOT=Path(__file__).resolve().parents[2];QA=ROOT/'_build/review'
RUNTIME=Path('C:/Users/Lenovo/.cache/codex-runtimes/codex-primary-runtime')
RENDERER=Path('C:/Users/Lenovo/.codex/plugins/cache/openai-primary-runtime/documents/26.1022.11436/skills/documents/render_docx.py')
os.environ['PATH']=str(RUNTIME/'dependencies/native/poppler/Library/bin')+os.pathsep+os.environ['PATH']
(QA/'tmp').mkdir(exist_ok=True);tempfile.tempdir=str(QA/'tmp')
spec=importlib.util.spec_from_file_location('renderer',RENDERER);renderer=importlib.util.module_from_spec(spec);spec.loader.exec_module(renderer)
# Windows runtime.json explicitly has libreOfficeVersion:null. Use a read-only,
# hidden Word PDF export, then the packaged renderer's Poppler rasterization.
def existing_pdf(doc_path,user_profile,convert_tmp_dir,stem,verbose=False):
    pdf=QA/'pdf'/(stem+'.pdf')
    if not pdf.exists()or pdf.stat().st_mtime<Path(doc_path).stat().st_mtime:raise RuntimeError('Missing or stale PDF '+str(pdf))
    return str(pdf),'Native Word read-only export; no bundled LibreOffice on Windows'
renderer.convert_to_pdf=existing_pdf
manifest=[]
for rel in json.loads((QA/'word_outputs.json').read_text(encoding='utf-8')):
    src=ROOT/rel;pages=renderer.rasterize(str(src),str(QA/'render'/src.stem),100,False,False)
    manifest.append({'file':rel,'pages':[str(Path(p).relative_to(ROOT))for p in pages]})
    print(src.stem,len(pages),flush=True)
(QA/'render_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
