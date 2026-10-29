"""Draws a fit next to its clip: python3 overlay.py <config> <frames dir> <fit.json> <out.png> [every]"""
import json, sys, glob
import numpy as np
from PIL import Image
from r6fit import *
from fit_video import CONFIGS

name, d, fj, out = sys.argv[1:5]
every = int(sys.argv[5]) if len(sys.argv) > 5 else 8
C = CONFIGS[name]; F = json.load(open(fj)); W, H = F["W"], F["H"]
cam = Camera(W, H, **F["camera"]); body = Body(C["body"])
files = sorted(glob.glob(d + "/*.png"))
pal = np.array([[0, 0, 0], [150, 90, 30], [255, 0, 0], [255, 0, 255], [0, 255, 255], [160, 160, 160]], np.uint8)
tiles = []
for i in range(0, len(F["frames"]), every):
    lab = render(body, solve(np.array(F["frames"][i])), cam)
    seen, a = C["seg"](files[i], W, H)
    img = (a * 255).astype(np.uint8).copy()
    edge = (lab > 0) & ~((np.roll(lab > 0, 1, 0)) & (np.roll(lab > 0, -1, 0)) & (np.roll(lab > 0, 1, 1)) & (np.roll(lab > 0, -1, 1)))
    img[edge] = [255, 255, 0]
    tiles.append(np.concatenate([img, pal[lab]], 0))
rows = [np.concatenate(tiles[k:k + 9] + [np.zeros_like(tiles[0])] * (9 - len(tiles[k:k + 9])), 1) for k in range(0, len(tiles), 9)]
Image.fromarray(np.concatenate(rows, 0)).resize((9 * W * 2, len(rows) * H * 4)).save(out)
