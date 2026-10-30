# Draws the faint spider web for the leaderboards' top-right corner (assets/icons/board-web.png; owner, Oct 18: "make
# them also look more like the reference ones but keep some halloween mood to it"). A corner web: threads fanning out
# from the top-right corner and sagging rings between them, thin white lines on transparent (Shared/LeaderboardLook
# lays it over the slab, see-through, so it stays a quiet touch). Drawn at 2x (300 px for a 150 px corner).
# Usage (from huzz-valley/): python3 tools/icons/make_board_web.py   (then python3 tools/icons/pack_images.py)
import math
from PIL import Image, ImageDraw

S, SS = 300, 4
big = Image.new('RGBA', (S * SS, S * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
cx, cy = S * SS, 0  # the corner the web hangs from (top-right)
R = S * SS * 0.98
angles = [math.radians(a) for a in (92, 106, 121, 136, 151, 166, 178)]  # threads (straight down round to the left)
w = int(1.6 * SS)


def at(a, r):
    return (cx + r * math.cos(a), cy + r * math.sin(a))  # (angles from +X, measured downward: 90 = straight down)


for a in angles:
    d.line([(cx, cy), at(a, R)], fill=(255, 255, 255, 200), width=w)
for k, frac in enumerate((0.22, 0.38, 0.54, 0.70, 0.86)):
    r = R * frac
    for a0, a1 in zip(angles, angles[1:]):
        p0, p1 = at(a0, r), at(a1, r)
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
        sag = r * 0.06  # the ring sags toward the corner between two threads
        ux, uy = cx - mid[0], cy - mid[1]
        n = math.hypot(ux, uy) or 1
        ctrl = (mid[0] + ux / n * sag, mid[1] + uy / n * sag)
        pts = []
        for i in range(13):
            t = i / 12
            pts.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * ctrl[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * ctrl[1] + t * t * p1[1]))
        d.line(pts, fill=(255, 255, 255, 170), width=w)
img = big.resize((S, S), Image.LANCZOS)
img.save('assets/icons/board-web.png')
print('board web', img.size)
