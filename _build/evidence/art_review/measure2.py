from PIL import Image
import numpy as np
b = np.asarray(Image.open(r"_build\evidence\art_review\battle_current.png").convert("RGB")).astype(int)
# card 1 region approx x 362..494, y 512..697
sub = b[505:705, 360:496]
# dark text pixels
dark = sub.sum(axis=2) < 300
rows = np.where(dark.any(axis=1))[0]
print("card1 dark-row span (image y):", 505+rows.min(), 505+rows.max())
# cream card body: find rows where median brightness > 200 across x
med = np.median(sub.sum(axis=2), axis=1)
cream = np.where(med > 600)[0]
print("cream rows:", 505+cream.min(), "..", 505+cream.max())
# locate art window: rows with high variance
var = sub.reshape(sub.shape[0],-1).var(axis=1)
print("high-variance (art) rows:", 505+np.where(var>3000)[0].min(), "..", 505+np.where(var>3000)[0].max())
# text rows only below art
below = dark[125:,:]
r2 = np.where(below.any(axis=1))[0]
print("text rows below art (y):", 505+125+r2.min(), "..", 505+125+r2.max())
print("card bottom ~", 505+cream.max(), "=> blank under last text:", 505+cream.max()-(505+125+r2.max()))
