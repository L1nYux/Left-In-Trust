from PIL import Image
import numpy as np, colorsys

def lum(c):
    r,g,b = [v/255 for v in c[:3]]
    f = lambda x: x/12.92 if x <= 0.03928 else ((x+0.055)/1.055)**2.4
    return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b)

def contrast(a,b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la,lb), min(la,lb)
    return (hi+0.05)/(lo+0.05)

def px(im, x, y):
    return tuple(int(v) for v in im.getpixel((x,y))[:3])

def region_stats(im, box, label):
    a = np.asarray(im.crop(box).convert("RGB")).astype(int)
    flat = a.reshape(-1,3)
    med = np.median(flat, axis=0)
    print(f"{label}: median={tuple(int(v) for v in med)} mean={tuple(int(v) for v in flat.mean(axis=0))}")

b = Image.open(r"_build\evidence\art_review\battle_current.png").convert("RGB")
print("== battle_current ==")
for x,y,l in [(600,20,"top-center bg"),(300,700,"bottom bg"),(200,60,"left bg near title"),(1150,660,"bottom right bg")]:
    print(f"  {l} @({x},{y}) = {px(b,x,y)}")
# title text: brightest pixels in title box
a = np.asarray(b.crop((14,10,150,56))).astype(int).reshape(-1,3)
lums = a.sum(axis=1)
idx = np.argsort(lums)[-200:]
txt = a[idx].mean(axis=0)
bgc = np.asarray(b.crop((160,20,340,40))).astype(int).reshape(-1,3)
bgmed = np.median(bgc, axis=0)
print("  title text approx color =", tuple(int(v) for v in txt), " local bg =", tuple(int(v) for v in bgmed),
      " contrast =", round(contrast(txt, bgmed),2))
# card face colors
print("  card1 cream @(400,660) =", px(b,400,660), " card2 cream @(520,660) =", px(b,520,660))
print("  card name color (card2 darkest in name box) =", end=" ")
a = np.asarray(b.crop((478,632,590,652))).astype(int).reshape(-1,3)
print(tuple(int(v) for v in a[np.argsort(a.sum(axis=1))[:100]].mean(axis=0)))

# glow / red dominance
arr = np.asarray(b).astype(int)
R,G,B = arr[:,:,0],arr[:,:,1],arr[:,:,2]
red = (R>120)&((R-np.maximum(G,B))>45)
print(f"  red-dominant pixels: {red.mean()*100:.1f}% of frame")
bright = (arr.max(axis=2)>235)
print(f"  near-white (>=236) pixels: {bright.mean()*100:.1f}%")
warm = (arr.max(axis=2)>200)&red
print(f"  warm+red-hot pixels: {warm.mean()*100:.1f}%")
# right side red band share
print(f"  red pixels in x>742: {red[:,742:].mean()*100:.1f}%")

print("== map_identity_v2_student(现有实机) ==")
m = Image.open(r"_build\evidence\ui_map_scifi_v7.png").convert("RGB")
for x,y,l in [(100,600,"bg"),(300,200,"paper"),(1200,400,"bg right"),(600,124,"title text zone")]:
    print(f"  {l} @({x},{y}) = {px(m,x,y)}")
a = np.asarray(m.crop((30,22,300,52))).astype(int).reshape(-1,3)
print("  map title darkest:", tuple(int(v) for v in a[np.argsort(a.sum(axis=1))[:200]].mean(axis=0)))
print("  contrast dark text vs paper =", round(contrast(px(m,320,200), (48,59,56)),2))

for name in ["result_win_current","result_loss_current"]:
    im = Image.open(rf"_build\evidence\art_review\{name}.png").convert("RGB")
    arr = np.asarray(im).astype(int)
    bg = np.median(arr.reshape(-1,3), axis=0)
    print(f"== {name} == bg={tuple(int(v) for v in bg)}")
    a = arr.reshape(-1,3); l = a.sum(axis=1)
    print("   brightest 300 px mean:", tuple(int(v) for v in a[np.argsort(l)[-300:]].mean(axis=0)))
    nonbg = (np.abs(arr-bg).sum(axis=2) > 40)
    print(f"   non-bg (ink) coverage: {nonbg.mean()*100:.2f}%")

ov = Image.open(r"_build\evidence\art_review\map_current.png").convert("RGB")
print("== story overlay ==")
print("  modal bg @(700,470) =", px(ov,700,470), " body text contrast vs modal =", round(contrast((242,240,238), px(ov,700,470)),2))
print("  speaker 'Claude' color @ approx (230,196) =", px(ov,230,196))
