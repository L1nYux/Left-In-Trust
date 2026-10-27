from PIL import Image
import os
src = r"_build\evidence\ui_compact_battle_v7.png"
out = r"_build\evidence\art_review\crops"
im = Image.open(src).convert("RGB")
print(im.size)
regions = {
 "cards_row": (350,485,945,715,3),
 "cards_left": (5,525,255,705,4),
 "title_topleft": (0,0,230,80,5),
 "enemy_intent": (740,50,1280,210,3),
 "actors_row": (40,100,470,450,3),
 "enemy_full": (770,90,1210,450,2),
 "bottom_bar": (0,640,1280,720,4),
 "right_pause": (1180,10,1280,90,5),
}
for name,(x1,y1,x2,y2,scale) in regions.items():
    c = im.crop((x1,y1,x2,y2))
    c = c.resize((int(c.width*scale), int(c.height*scale)), Image.LANCZOS)
    p = os.path.join(out, name+".png")
    c.save(p)
    print(name, c.size, p)
