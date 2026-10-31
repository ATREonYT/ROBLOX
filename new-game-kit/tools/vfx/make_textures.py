#!/usr/bin/env python3
"""New Game Kit: make our own VFX textures (vault note 17 §4). No downloads, no copied art.

    python3 tools/vfx/make_textures.py            (from the kit folder)

Writes white/greyscale PNGs with real alpha into assets/vfx/ (tint them in Roblox with Color, so one
texture serves every rarity and accent colour), plus assets/vfx/_sheet.png to look at them all.
Flipbooks are 1024 px Grid4x4 (16 frames of 256 px) with an 8 px clear gutter in each cell; set
FlipbookLayout = Grid4x4, FlipbookMode = OneShot for bursts, Loop for the flame.

The owner uploads the folder (Studio > Asset Manager > Bulk Import) and sends back the ids; never
invent ids. Until then the kit modules use Roblox's built-in textures.

Every texture is deterministic (fixed seeds), so re-running gives the same files.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "vfx")


def grid(n):
    """Coordinates from -1..1 for an n x n image (x right, y down), radius and angle."""
    c = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(c, c)
    return x, y, np.hypot(x, y), np.arctan2(y, x)


def save(alpha, name, rgb=None):
    """alpha: float array 0..1. rgb: optional float array (n, n, 3) 0..1 (defaults to white).
    Clear pixels get the colour of the nearest visible pixel (alpha bleed) so edges never fringe."""
    a = np.clip(alpha, 0, 1)
    n = a.shape[0]
    col = np.ones((n, n, 3)) if rgb is None else np.clip(rgb, 0, 1)
    if rgb is not None:
        # cheap alpha bleed: blur colour weighted by alpha, use it where alpha is ~0
        from PIL import ImageFilter
        w = Image.fromarray((a * 255).astype(np.uint8))
        acc = []
        for i in range(3):
            ch = Image.fromarray((col[..., i] * a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))
            acc.append(np.asarray(ch, dtype=float))
        wb = np.asarray(w.filter(ImageFilter.GaussianBlur(6)), dtype=float) + 1e-3
        bled = np.stack([c / wb for c in acc], -1)
        mask = (a < 0.02)[..., None]
        col = np.where(mask, np.clip(bled, 0, 1), col)
    img = np.dstack([col, a[..., None]])
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))
    return name


def value_noise(n, cells, seed, octaves=4, tile=True):
    """Fractal value noise that tiles (wraps) so it scrolls with no seam."""
    rng = np.random.default_rng(seed)
    total = np.zeros((n, n))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        k = cells * 2 ** o
        lattice = rng.random((k, k))
        u = np.arange(n) / n * k
        i0 = np.floor(u).astype(int)
        f = u - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % k if tile else np.minimum(i0 + 1, k - 1)
        a = lattice[np.ix_(i0 % k, i0 % k)]
        b = lattice[np.ix_(i0 % k, i1)]
        c = lattice[np.ix_(i1, i0 % k)]
        d = lattice[np.ix_(i1, i1)]
        fx, fy = f[None, :], f[:, None]
        total += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
        norm += amp
        amp *= 0.5
    return total / norm


def posterize(a, steps=(0.0, 0.55, 1.0), edges=(0.15, 0.55)):
    """Anime cel look: hard steps instead of a soft fade."""
    out = np.zeros_like(a)
    for s, e in zip(steps[1:], edges):
        out = np.where(a >= e, s, out)
    return out


# --- single textures -------------------------------------------------------------------------

def glow(n=256):
    _, _, r, _ = grid(n)
    return save((1 - np.clip(r, 0, 1)) ** 2.5, "glow_soft")


def ring(n=512, width=0.08, broken=False):
    _, _, r, t = grid(n)
    a = np.exp(-(((r - 0.72) / width) ** 2))
    a = np.maximum(a, 0.35 * np.exp(-(((r - 0.62) / (width * 2.2)) ** 2)) * (r < 0.72))  # soft inner glow
    if broken:
        noise = value_noise(n, 3, 7)
        brk = np.interp((t + math.pi) / (2 * math.pi), np.linspace(0, 1, n), noise[n // 2])
        a *= np.clip((brk - 0.35) * 3, 0, 1)
    return save(a, "ring_broken" if broken else "ring")


def star(n=256, points=4):
    _, _, r, t = grid(n)
    spike = np.abs(np.cos(t * points / 2)) ** 18
    shape = np.clip(1 - r / (0.18 + 0.82 * spike), 0, 1)
    core = (1 - np.clip(r / 0.25, 0, 1)) ** 2
    return save(np.clip(shape ** 1.5 + core, 0, 1), f"star{points}")


def spark(n=256):
    x, y, _, _ = grid(n)
    a = np.exp(-(x / 0.07) ** 2) * np.clip(1 - np.abs(y) ** 1.6, 0, 1)
    a = np.maximum(a, np.exp(-(x / 0.025) ** 2) * (np.abs(y) < 0.95))
    return save(np.clip(a, 0, 1), "spark_streak")


def puff(n=256, seed=3):
    _, _, r, _ = grid(n)
    noise = value_noise(n, 4, seed)
    a = np.clip((0.78 + 0.35 * (noise - 0.5)) - r, 0, 1) * 4
    shade = 0.75 + 0.25 * (1 - np.clip((np.arange(n)[:, None] / n), 0, 1))  # lighter on top
    rgb = np.dstack([shade * np.ones((n, n))] * 3)
    return save(posterize(np.clip(a, 0, 1)), "puff_cel", rgb)


def slash(n=512):
    """A crescent slash: streaks drawn straight, bent into an arc (code version of Polar Coordinates)."""
    _, _, r, t = grid(n)
    rng = np.random.default_rng(11)
    a = np.zeros((n, n))
    ang = (t + math.pi) / (2 * math.pi)  # 0..1 around
    arc = np.clip((ang - 0.25) / 0.45, 0, 1)  # 162 degree arc
    taper = np.sin(arc * math.pi) ** 0.8 * (ang > 0.25) * (ang < 0.70)
    for _ in range(7):
        r0 = 0.55 + rng.random() * 0.33
        w = 0.008 + rng.random() * 0.03
        a = np.maximum(a, (0.45 + 0.55 * rng.random()) * np.exp(-((r - r0) / w) ** 2))
    a = np.maximum(a, np.exp(-((r - 0.82) / 0.03) ** 2))  # one bright leading edge
    return save(a * taper, "slash_arc")


def noise_tile(n=256):
    return save(np.clip((value_noise(n, 4, 21, 5) - 0.3) * 1.8, 0, 1), "noise_tile")


def beam_core(w=256, h=64):
    y = (np.arange(h) + 0.5) / h * 2 - 1
    profile = np.maximum(np.exp(-(y / 0.55) ** 2) * 0.6, np.exp(-(y / 0.12) ** 2))
    return save_strip(np.tile(profile[:, None], (1, w)), "beam_core")


def save_strip(alpha, name):
    a = np.clip(alpha, 0, 1)
    img = np.dstack([np.ones(a.shape + (3,)), a[..., None]])
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))
    return name


# --- flipbooks (1024 px, Grid4x4, 256 px cells, 8 px gutter) ---------------------------------

def flipbook(frame_fn, name, cells=4, size=1024, gutter=8, rgb=False):
    cell = size // cells
    inner = cell - 2 * gutter
    sheet_a = np.zeros((size, size))
    sheet_c = np.ones((size, size, 3))
    for i in range(cells * cells):
        k = i / (cells * cells - 1)
        out = frame_fn(inner, k)
        a, c = (out if isinstance(out, tuple) else (out, None))
        row, colm = divmod(i, cells)
        y0, x0 = row * cell + gutter, colm * cell + gutter
        sheet_a[y0:y0 + inner, x0:x0 + inner] = a
        if c is not None:
            sheet_c[y0:y0 + inner, x0:x0 + inner] = c
    return save(sheet_a, name, sheet_c if rgb else None)


def fb_shockwave(n, k):
    _, _, r, _ = grid(n)
    radius = 0.15 + 0.75 * (1 - (1 - k) ** 3)  # Expo-ish out: fast then slow
    width = 0.10 * (1 - k) + 0.02
    return np.exp(-(((r - radius) / width) ** 2)) * (1 - k) ** 0.8


def fb_puff(n, k):
    """Cel smoke puff: pops up fast, then holes open in it until it is gone (no linear fade)."""
    _, _, r, _ = grid(n)
    shape = value_noise(n, 4, 5)
    holes = value_noise(n, 8, 9, 3)
    size = 0.3 + 0.55 * (1 - (1 - min(1.0, k * 2.5)) ** 3)  # reaches full size in the first 40%
    body = np.clip(((size + 0.3 * (shape - 0.5)) - r) * 6, 0, 1)
    eaten = holes < (k ** 1.6) * 1.15  # dissolve threshold rises with age
    a = np.where(eaten, 0.0, body)
    return posterize(a * (1 - 0.35 * k))


def fb_flame(n, k):
    """Looping anime flame: tongues rise; frame 0 and 15 line up (k wraps)."""
    x, y, _, _ = grid(n)
    phase = k * 2 * math.pi
    tongues = 0.55 + 0.25 * np.sin(x * 9 + phase * 2) + 0.15 * np.sin(x * 17 - phase * 3)
    height = (1 - (y + 1) / 2)  # 1 at top, 0 at bottom
    body = np.clip(1 - np.abs(x) * 1.6, 0, 1) * np.clip(tongues - height * 1.1 + 0.25, 0, 1) * 3
    return posterize(np.clip(body, 0, 1), steps=(0.0, 0.6, 1.0), edges=(0.2, 0.6))


def contact_sheet(names):
    thumbs = []
    for nme in names:
        im = Image.open(os.path.join(OUT, nme + ".png")).convert("RGBA")
        im.thumbnail((200, 200))
        bg = Image.new("RGBA", (220, 240), (40, 44, 60, 255))
        bg.alpha_composite(im, ((220 - im.width) // 2, 10))
        ImageDraw.Draw(bg).text((8, 220), nme, fill=(230, 230, 230, 255), font=ImageFont.load_default())
        thumbs.append(bg)
    cols = 5
    rows = math.ceil(len(thumbs) / cols)
    sheet = Image.new("RGBA", (cols * 220, rows * 240), (30, 32, 44, 255))
    for i, t in enumerate(thumbs):
        sheet.alpha_composite(t, ((i % cols) * 220, (i // cols) * 240))
    sheet.convert("RGB").save(os.path.join(OUT, "_sheet.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    names = [
        glow(), ring(), ring(broken=True), star(points=4), star(points=6), spark(), puff(), slash(), noise_tile(), beam_core(),
        flipbook(fb_shockwave, "fb_shockwave_4x4"),
        flipbook(fb_puff, "fb_puff_cel_4x4"),
        flipbook(fb_flame, "fb_flame_loop_4x4"),
    ]
    contact_sheet(names)
    print(f"[VfxTextures] wrote {len(names)} textures to {OUT}")


if __name__ == "__main__":
    main()
