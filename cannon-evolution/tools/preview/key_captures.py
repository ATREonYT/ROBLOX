"""Turn Studio screen captures of Alex's cannonballs (shot on a dark backdrop) into clear 512 px PNGs
with the same dark outline as render_icons.py. Usage: python3 key_captures.py OUT_DIR Name=capture.jpg[:disc] ..."""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUTLINE = (25, 15, 40)
SIZE = 512


def key(path, disc=False):
    img = Image.open(path).convert("RGB")
    a = np.asarray(img).astype(float)
    # background: the dark vignette, a smooth quadratic fitted to the pixels far from the ball
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = (xx - w / 2) / w, (yy - h / 2) / h
    basis = np.stack([np.ones_like(u), u, v, u * u, v * v, u * v], -1).reshape(-1, 6)
    far = (np.hypot(xx - w / 2, yy - h / 2) > 0.42 * h).reshape(-1)
    bg = np.empty_like(a)
    for c in range(3):
        col = a[..., c].reshape(-1)
        keep = far.copy()
        for _ in range(3):  # ignore Studio's thin lines and other outliers
            coef = np.linalg.lstsq(basis[keep], col[keep], rcond=None)[0]
            keep &= np.abs(col - basis @ coef) < 6
        bg[..., c] = (basis @ coef).reshape(h, w)
    diff = np.abs(a - bg).max(axis=2)
    alpha = np.clip((diff - 7) / 20, 0, 1)
    # drop Studio's thin selection and gizmo lines: open the mask, then grow it back a little
    m = Image.fromarray((alpha > 0.3).astype(np.uint8) * 255)
    m = m.filter(ImageFilter.MinFilter(7)).filter(ImageFilter.MaxFilter(11))
    # anything the outside can't reach is inside the ball (dark patches on Neon and Hacker)
    filled = m.copy()
    ImageDraw.floodfill(filled, (0, 0), 128)
    inside = np.asarray(filled) != 128
    alpha = np.where(inside, np.maximum(alpha, (np.asarray(m) == 0) & inside), 0).astype(float)
    if disc:  # a ball with a dark patch on its rim (Neon): use the round outline of everything that showed
        ys, xs = np.nonzero(alpha > 0.5)
        cx, cy, r = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2, (xs.max() - xs.min() + ys.max() - ys.min()) / 4
        alpha = np.clip(r - np.hypot(xx - cx, yy - cy) + 0.5, 0, 1)
    fg = np.where(alpha[..., None] > 0.02, (a - bg * (1 - alpha[..., None])) / np.maximum(alpha[..., None], 0.02), 0)
    out = np.dstack([np.clip(fg, 0, 255), alpha * 255]).astype(np.uint8)
    ys, xs = np.nonzero(alpha > 0.05)
    cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
    half = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2 / 0.86
    im = Image.fromarray(out, "RGBA").crop((int(cx - half), int(cy - half), int(cx + half), int(cy + half)))
    im = im.resize((SIZE * 2, SIZE * 2), Image.LANCZOS)
    rim = Image.new("RGBA", im.size, OUTLINE + (0,))
    rim.putalpha(im.getchannel("A").point(lambda v: 255 if v > 60 else 0).filter(ImageFilter.MaxFilter(9)))
    return Image.alpha_composite(rim, im).resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    for arg in sys.argv[2:]:
        name, path = arg.split("=", 1)
        disc = path.endswith(":disc")
        key(path.removesuffix(":disc"), disc).save(f"{sys.argv[1]}/{name}.png")
