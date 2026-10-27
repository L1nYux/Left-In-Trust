from PIL import Image
import numpy as np
b = np.asarray(Image.open(r"_build\evidence\art_review\battle_current.png").convert("RGB")).astype(int)
col = b[490:715, 880]           # vertical strip inside card 5 (right part, not covered)
s = col.sum(axis=1)
cream = np.where(s > 600)[0]
print("card5 cream strip y:", 490+cream.min(), "..", 490+cream.max(), " height:", cream.max()-cream.min()+1)
band = b[490:715, 800:915]
dark = band.sum(axis=2) < 420
rows = np.where(dark.any(axis=1))[0]
print("dark rows (art+text) y:", 490+rows.min(), "..", 490+rows.max())
txt = dark[135:,:]              # below art window
r2 = np.where(txt.any(axis=1))[0]
print("text rows y:", 490+135+r2.min(), "..", 490+135+r2.max())
print("blank under last text px:", (490+cream.max()) - (490+135+r2.max()))
