from PIL import Image
import numpy as np
b = np.asarray(Image.open(r"_build\evidence\art_review\battle_current.png").convert("RGB")).astype(int)
hits=[]
for y in range(596, 700):
    row = b[y, 812:902]
    s = row.sum(axis=1)
    if np.median(s) > 620 and s.min() < 470:
        hits.append(y)
def groups(v):
    out=[];cur=[v[0]]
    for x in v[1:]:
        if x-cur[-1]<=2: cur.append(x)
        else: out.append((cur[0],cur[-1])); cur=[x]
    out.append((cur[0],cur[-1])); return out
print("text line groups in card5:", groups(hits))
print("card5 cream ends at 694 => blank below last text:", 694 - groups(hits)[-1][1])
