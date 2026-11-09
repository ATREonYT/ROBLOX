"""Alignment check (container side, Pillow + numpy): draws the render's path / stone / wall-face boundaries on the
screenshot. usage: outline_overlay.py <ref.png> <render.png> <out.jpg> [width]
 cyan = orange path in the render, yellow = grey stone in the render, magenta = red-brown wall face in the render."""
import sys, numpy as np
from PIL import Image
def masks(a):
    a = a.astype(float); r, g, b = a[..., 0], a[..., 1], a[..., 2]; mx = np.maximum(np.maximum(r, g), b) + 1
    path = (r > 170) & (g / mx > 0.47) & (g / mx < 0.72) & (b / mx < 0.3)
    wall = (r > 110) & (g / mx < 0.46) & (b / mx < 0.35) & ~path
    grey = (np.abs(r - g) < 22) & (np.abs(g - b) < 26) & (r > 95) & (r < 235)
    return path, grey, wall
def edge(m):
    e = np.zeros_like(m); e[1:, :] |= m[1:, :] != m[:-1, :]; e[:, 1:] |= m[:, 1:] != m[:, :-1]; return e
def clean(m, k=2):                     # drop speckle: majority over a (2k+1)^2 box
    from numpy.lib.stride_tricks import sliding_window_view as sw
    p = np.pad(m.astype(np.uint8), k); s = sw(p, (2 * k + 1, 2 * k + 1)).sum(axis=(-1, -2)); return s > (2 * k + 1) ** 2 // 2
if __name__ == "__main__":
    ref, ren, out = sys.argv[1:4]; W = int(sys.argv[4]) if len(sys.argv) > 4 else 1500
    R = Image.open(ref).convert("RGB"); H = round(W * R.height / R.width)
    R = np.asarray(R.resize((W, H))).copy(); r = np.asarray(Image.open(ren).convert("RGB").resize((W, H)))
    for m, col in zip(masks(r), [(0, 255, 255), (255, 255, 0), (255, 0, 255)]):
        e = edge(clean(m)); e[:-1] |= e[1:]; R[e] = col
    Image.fromarray(R).save(out, quality=88)
