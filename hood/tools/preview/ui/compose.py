# compose.py: one side-by-side picture, the owner's mockup on the left and our windows (shoot.sh's PNGs) in a 2x2 on
# the right, each with a caption.
#   python3 -I hood/tools/preview/ui/compose.py <mockup.png> <out.jpg> <shop.png> <rebirth.png> <shoes.png> <worlds.png>
import sys, os
from PIL import Image, ImageDraw, ImageFont

mock, out, shots = sys.argv[1], sys.argv[2], sys.argv[3:7]
here = os.path.dirname(os.path.abspath(__file__))
font_path = os.path.join(here, '..', 'render14', 'fonts', 'Montserrat-Variable.ttf')
H = 1080
CAP = 54
GAP = 12
m = Image.open(mock).convert('RGB')
mw = round(m.width * H / m.height)
m = m.resize((mw, H), Image.LANCZOS)
cw, ch = 960, 540
W = mw + GAP + 2 * cw + GAP
canvas = Image.new('RGB', (W, H + CAP), (16, 20, 38))
draw = ImageDraw.Draw(canvas)
try:
    font = ImageFont.truetype(font_path, 34)
    font.set_variation_by_axes([900])
except Exception:
    font = ImageFont.load_default()
canvas.paste(m, (0, CAP))
draw.text((16, 8), "Owner's mockup (Oct 27)", font=font, fill=(255, 214, 64))
x0 = mw + GAP
draw.text((x0 + 16, 8), 'Ours, rendered offline (Shop, Rebirth / Shoes, World)', font=font, fill=(255, 255, 255))
for i, p in enumerate(shots):
    x = x0 + (i % 2) * (cw + GAP)
    y = CAP + (i // 2) * ch
    if p.startswith('note:'):
        # a slot with no picture says why, instead of showing an empty screen
        draw.rectangle((x, y, x + cw - 1, y + ch - 1), fill=(30, 36, 64))
        draw.multiline_text((x + 40, y + ch // 2 - 60), p[5:].replace('|', '\n'), font=font, fill=(255, 214, 64), spacing=12)
        continue
    im = Image.open(p).convert('RGB').resize((cw, ch), Image.LANCZOS)
    canvas.paste(im, (x, y))
canvas.save(out, quality=88)
print('wrote', out, canvas.size)
