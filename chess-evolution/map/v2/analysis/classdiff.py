"""Class-map comparison: green / orange-red / grey / other for reference and render; writes a side-by-side of the two
class maps plus a disagreement map. usage: classdiff.py ref render out [crop x0,y0,x1,y1 for the render]"""
import sys, numpy as np
from PIL import Image
def cls(a):
    a = a.astype(int); r, g, b = a[..., 0], a[..., 1], a[..., 2]; c = np.zeros(r.shape, np.uint8)
    c[(g > 150) & (g > r + 25) & (g > b + 40)] = 1                        # green
    c[(r > 120) & (r > g + 50) & (r > b + 40) & (g < 170)] = 2             # orange / red dirt and path
    c[(abs(r - g) < 22) & (abs(g - b) < 26) & (r > 95) & (r < 235)] = 3    # grey paving
    return c
ref, ren, out = sys.argv[1:4]
R = Image.open(ref).convert("RGB"); r = Image.open(ren).convert("RGB")
if len(sys.argv) > 4: r = r.crop(tuple(map(int, sys.argv[4].split(","))))
W = 600; H = round(W * R.height / R.width); R = R.resize((W, H)); r = r.resize((W, H))
a, b = cls(np.asarray(R)), cls(np.asarray(r))
pal = np.array([[60, 60, 60], [40, 220, 40], [230, 90, 30], [190, 190, 190]], np.uint8)
d = np.where((a == b), 0, 255).astype(np.uint8)
both = (a > 0) & (b > 0); agree = (a == b)[both].mean()
img = np.concatenate([pal[a], pal[b], np.stack([d] * 3, -1)], 1); Image.fromarray(img).save(out)
print(f"class agreement {agree:.3f}")
