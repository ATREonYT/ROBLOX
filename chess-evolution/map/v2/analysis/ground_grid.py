"""Overlay a world ground grid (studs) on hub_overview.png using a homography from the path crossing.
The crossing square is 11 x 11 studs (9 orange + 1 brown edge each side, counted on terraceA_closeup)."""
import numpy as np, sys
from PIL import Image, ImageDraw
def H_from(src, dst):
    A = []
    for (x, y), (u, v) in zip(src, dst):
        A += [[x, y, 1, 0, 0, 0, -u*x, -u*y, -u], [0, 0, 0, x, y, 1, -v*x, -v*y, -v]]
    _, _, V = np.linalg.svd(np.array(A)); return V[-1].reshape(3, 3)
def proj(H, x, y):
    p = H @ np.array([x, y, 1.0]); return p[0]/p[2], p[1]/p[2]
world = [(-5.5, 5.5), (5.5, 5.5), (5.5, -5.5), (-5.5, -5.5)]
pix = [tuple(map(float, a.split(","))) for a in sys.argv[1:5]] if len(sys.argv) > 4 else [(1540,695),(1635,745),(1580,805),(1482,750)]
H = H_from(world, pix); Hi = np.linalg.inv(H)
im = Image.open("ref/hub_overview.png").convert("RGB"); d = ImageDraw.Draw(im)
R = range(-100, 101, 10)
for x in R:
    pts = [proj(H, x, y) for y in np.linspace(-90, 120, 60)]
    pts = [p for p in pts if -2000 < p[0] < 5000 and -2000 < p[1] < 4000]
    d.line(pts, fill=(255, 0, 255) if x else (255, 255, 0), width=3)
for y in range(-90, 121, 10):
    pts = [proj(H, x, y) for x in np.linspace(-100, 100, 60)]
    pts = [p for p in pts if -2000 < p[0] < 5000 and -2000 < p[1] < 4000]
    d.line(pts, fill=(0, 255, 255) if y else (255, 255, 0), width=3)
for x in range(-100, 101, 20):
    for y in range(-80, 121, 20):
        u, v = proj(H, x, y)
        if 0 < u < im.width and 0 < v < im.height: d.text((u+4, v+2), f"{x},{y}", fill=(255, 255, 255))
im.save(sys.argv[5] if len(sys.argv) > 5 else "/tmp/claude-0/crops/grid.png")
np.save("analysis/H_hub.npy", H)
