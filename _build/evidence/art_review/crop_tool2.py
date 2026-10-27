from PIL import Image, ImageEnhance
import os
out = r"_build\evidence\art_review\crops"
im = Image.open(r"_build\evidence\ui_compact_battle_v7.png").convert("RGB")
# card bottoms only (cream area)
c = im.crop((350,620,945,710)).resize((595*4,90*4), Image.LANCZOS)
c.save(os.path.join(out,"card_bottom_zoom.png"))
# extreme contrast stretch to reveal faint text
from PIL import ImageOps
g = ImageOps.autocontrast(c, cutoff=1)
ImageEnhance.Contrast(g).enhance(2.0).save(os.path.join(out,"card_bottom_contrast.png"))
print("ok")
