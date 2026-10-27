from PIL import Image
import os
out = r"_build\evidence\art_review\crops"
os.makedirs(out, exist_ok=True)
b = Image.open(r"_build\evidence\art_review\battle_current.png").convert("RGB")
b.crop((14,10,150,56)).resize((136*8,46*8), Image.NEAREST).save(os.path.join(out,"cur_title_8x.png"))
b.crop((352,506,600,700)).resize((248*4,194*4), Image.LANCZOS).save(os.path.join(out,"cur_card12_4x.png"))
b.crop((352,506,952,700)).resize((600*2,194*2), Image.LANCZOS).save(os.path.join(out,"cur_cards_row_2x.png"))
print("ok")
