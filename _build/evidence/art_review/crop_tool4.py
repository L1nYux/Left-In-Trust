from PIL import Image
b = Image.open(r"_build\evidence\art_review\battle_current.png").convert("RGB")
b.crop((36,352,462,450)).resize((426*3,98*3), Image.LANCZOS).save(r"_build\evidence\art_review\crops\cur_plates_3x.png")
b.crop((0,676,180,706)).resize((180*4,30*4), Image.NEAREST).save(r"_build\evidence\art_review\crops\cur_footer_4x.png")
m = Image.open(r"_build\evidence\ui_map_scifi_v7.png").convert("RGB")
m.crop((20,18,420,60)).resize((400*3,42*3), Image.LANCZOS).save(r"_build\evidence\art_review\crops\map_title_3x.png")
print("ok")
