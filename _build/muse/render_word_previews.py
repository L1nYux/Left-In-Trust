from pathlib import Path
import importlib.util
import os
import shutil
from PIL import Image, ImageOps, ImageDraw

root = Path(__file__).resolve().parents[2]
runtime = Path('C:/Users/Lenovo/.cache/codex-runtimes/codex-primary-runtime')
renderer_path = Path('C:/Users/Lenovo/.codex/plugins/cache/openai-primary-runtime/documents/26.1020.11127/skills/documents/render_docx.py')
spec = importlib.util.spec_from_file_location('renderer', renderer_path)
renderer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(renderer)
os.environ['PATH'] = str(runtime / 'dependencies/native/poppler/Library/bin') + os.pathsep + os.environ['PATH']

# Native Word has already exported these PDFs. Keep the packaged renderer's
# PDF-to-PNG pipeline; replace only its unavailable LibreOffice conversion.
def word_pdf(doc_path, user_profile, convert_tmp_dir, stem, verbose=False):
    return str(root / '_build/muse' / (stem + '.pdf')), 'Exported through Microsoft Word'

renderer.convert_to_pdf = word_pdf
for stem in ['16_Muse', '00_索引', '11_Llama']:
    out = root / '_build/muse' / ('render_' + stem)
    paths = renderer.rasterize(str(root / '角色设定/性格' / (stem + '.docx')), str(out), 140, False, False)
    print(stem, len(paths), 'pages')
    for offset in range(0, len(paths), 2):
        imgs = [Image.open(p).convert('RGB') for p in paths[offset:offset + 2]]
        canvas = Image.new('RGB', (sum(im.width for im in imgs), max(im.height for im in imgs) + 35), '#dedede')
        draw = ImageDraw.Draw(canvas)
        x = 0
        for n, im in enumerate(imgs):
            draw.text((x + 12, 8), f'{stem} page {offset+n+1}', fill='black')
            canvas.paste(im, (x, 35))
            x += im.width
        canvas.save(out / f'spread-{offset//2+1}.png')
