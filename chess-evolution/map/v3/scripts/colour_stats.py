"""Phase 2/5 colour check (container side): per view and per surface class, the mean screenshot colour vs the mean
render colour over pixels where both agree on the class (so HUD, props and players drop out).
usage: colour_stats.py <render_dir> <tag>"""
import sys, numpy as np
from PIL import Image
VIEWS = ["hub", "treadmill", "phone", "lane"]
def cls(a):
    a = a.astype(float); r, g, b = a[..., 0], a[..., 1], a[..., 2]; mx = a.max(-1) + 1; c = np.zeros(r.shape, np.uint8)
    c[(g > 150) & (g > r + 25) & (g > b + 40)] = 1                                               # grass / leaves
    c[(r > 170) & (g / mx > 0.47) & (g / mx < 0.72) & (b / mx < 0.35)] = 2                       # orange path
    c[(r > 110) & (g / mx < 0.46) & (b / mx < 0.35) & (c != 2)] = 3                              # red-brown wall
    c[(np.abs(r - g) < 22) & (np.abs(g - b) < 26) & (r > 95) & (r < 235)] = 4                    # grey stone
    c[(b > 180) & (g > 170) & (r < 160)] = 5                                                     # water / sky cyan
    return c
NAMES = {1: "grass", 2: "path", 3: "wall", 4: "stone", 5: "cyan"}
d, tag = sys.argv[1], sys.argv[2]
for v in VIEWS:
    R = np.asarray(Image.open(f"refs/{v}.png").convert("RGB").resize((754, 429 if v != "phone" else 296)))
    try: r = np.asarray(Image.open(f"{d}/{v}_{tag}.png").convert("RGB").resize((R.shape[1], R.shape[0])))
    except FileNotFoundError: continue
    a, b = cls(R), cls(r); both = (a > 0) & (b > 0); agree = (a == b)[both].mean()
    out = []
    for k, n in NAMES.items():
        m = (a == k) & (b == k)
        if m.sum() < 200: continue
        cr, cn = R[m].mean(0).astype(int), r[m].mean(0).astype(int)
        out.append(f"{n} ref {tuple(cr)} ren {tuple(cn)} d {tuple(cn - cr)}")
    print(f"{v}: class agreement {agree:.3f}\n   " + "\n   ".join(out))
