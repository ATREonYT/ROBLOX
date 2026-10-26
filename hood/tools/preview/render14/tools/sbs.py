# sbs.py <ours.png> <reference image> <out.jpg> [left label] [right label]: one side-by-side, both cropped to 16:10.
import sys
from PIL import Image, ImageDraw, ImageFont
a, b, out = sys.argv[1:4]
la = sys.argv[4] if len(sys.argv) > 4 else 'ours'
lb = sys.argv[5] if len(sys.argv) > 5 else 'reference'
try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 24)
except Exception: font = ImageFont.load_default()
W, H = 800, 500
row = Image.new('RGB', (2 * W + 4, H), (20, 20, 24))
for i, (p, lab) in enumerate([(a, la), (b, lb)]):
    im = Image.open(p).convert('RGB'); iw, ih = im.size; r = min(iw / W, ih / H); cw, ch = int(W * r), int(H * r)
    im = im.crop(((iw - cw) // 2, (ih - ch) // 2, (iw - cw) // 2 + cw, (ih - ch) // 2 + ch)).resize((W, H))
    d = ImageDraw.Draw(im); d.rectangle((0, 0, W, 32), fill=(0, 0, 0)); d.text((8, 3), lab, fill=(255, 255, 255), font=font)
    row.paste(im, (i * (W + 4), 0))
row.save(out, quality=88); print('wrote', out)
