"""World ground grid (z = h) over a crop of hub_overview.png. args: x0 y0 x1 y1 step z out"""
import numpy as np, sys
from PIL import Image, ImageDraw, ImageFont
H = np.load("analysis/H_hub.npy")
x0, y0, x1, y1, step = map(int, sys.argv[1:6]); z = float(sys.argv[6]); out = sys.argv[7]
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
def proj(x, y):
    p = H @ np.array([x, y, 1.0]); return p[0]/p[2], p[1]/p[2]
im = Image.open("ref/hub_overview.png").convert("RGB").crop((x0, y0, x1, y1))
s = 1300 / im.width; im = im.resize((1300, int(im.height*s))); d = ImageDraw.Draw(im)
T = lambda p: ((p[0]-x0)*s, (p[1]-y0)*s)
for gx in range(-120, 121, step):
    d.line([T(proj(gx, gy)) for gy in np.linspace(-110, 130, 80)], fill=(255,0,255) if gx % 20 else (255,255,0), width=1)
for gy in range(-110, 131, step):
    d.line([T(proj(gx, gy)) for gx in np.linspace(-120, 120, 80)], fill=(0,255,255) if gy % 20 else (255,255,0), width=1)
for gx in range(-120, 121, 20):
    for gy in range(-110, 131, 20):
        u, v = T(proj(gx, gy))
        if 0 < u < 1300 and 0 < v < im.height: d.text((u+3, v+1), f"{gx},{gy}", fill=(255,255,255), font=F, stroke_width=2, stroke_fill=(0,0,0))
im.save(out)
