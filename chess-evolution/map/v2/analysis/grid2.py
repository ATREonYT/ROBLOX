import numpy as np, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, "analysis"); from cam import project
x0, y0, x1, y1, step = map(int, sys.argv[1:6]); z = float(sys.argv[6]); out = sys.argv[7]
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
im = Image.open("ref/hub_overview.png").convert("RGB").crop((x0, y0, x1, y1))
s = 1300/im.width; im = im.resize((1300, int(im.height*s))); d = ImageDraw.Draw(im)
T = lambda p: [((u-x0)*s, (v-y0)*s) for u, v in p]
for gx in range(-140, 141, step):
    d.line(T(project([(gx, gy, z) for gy in np.linspace(-130, 140, 100)])), fill=(255,255,0) if gx % 20 == 0 else (255,0,255), width=1)
for gy in range(-130, 141, step):
    d.line(T(project([(gx, gy, z) for gx in np.linspace(-140, 140, 100)])), fill=(255,255,0) if gy % 20 == 0 else (0,255,255), width=1)
for gx in range(-140, 141, 20):
    for gy in range(-120, 141, 20):
        (u, v), = T(project([(gx, gy, z)]))
        if 0 < u < 1300 and 0 < v < im.height: d.text((u+3, v+1), f"{gx},{gy}", fill=(255,255,255), font=F, stroke_width=2, stroke_fill=(0,0,0))
im.save(out)
