"""wispline.png: 16 different thin smoke strands (4x4 sheet, one static strand per frame) for the treadmills' x999.

The reference's x999 smoke is dark with thin white line work: single soft lines, broken, swelling and thinning
like ink, some bright and some barely there; not one curl repeated and not double-railed tubes. Each frame here is
its own strand: S-curves, open arcs, forks without a curl, broken dashes, and three that end in a loose open hook
(none closed). Every stroke is ONE centre line: an anti-aliased core of radius 1.1 x w(t) px with a soft glow
(0.28 x a gaussian, sigma 2.6 px) round it, where w(t) = taper(t) x (0.6 + 0.7 x smooth noise) varies along the
stroke. Strokes longer than 120 px are broken by 1-2 gaps; strands are fitted at a random 55-86% of the frame
(half of them short); a frame's strength is x1.0 (frames 0-3), x0.7 (4-11) or x0.45 (12-15), so the lines range
from bright to barely there. The emitter picks one random frame per particle (Grid4x4, Framerate 0,
StartRandom: the `aura` recipe) and animates it with Size and a gentle rotation instead of frames.

Only the treadmills use it (key `wispline`); everything else keeps `wisp`.
Run:  python3 make_wispline.py   (needs numpy and Pillow; writes next to this file)
"""
import math
import os
import random

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CELL, PAD = 256, 10  # frame size and the empty border that keeps mip filtering inside a frame
CORE = 1.1  # core radius per unit of width, px
GLOW, GLOW_SIGMA = 0.28, 2.6  # soft glow round the core: peak alpha and gaussian sigma, px
STRENGTH = [1.0] * 4 + [0.7] * 8 + [0.45] * 4  # per frame


def taper(t):
    return math.sin(math.pi * min(1.0, max(0.0, t))) ** 0.7


def s_curve(rng):
    amp, waves, tilt = rng.uniform(0.07, 0.15), rng.uniform(0.8, 1.4), rng.uniform(-0.25, 0.25)
    ph = rng.uniform(0, 2 * math.pi)
    return [[(0.5 + tilt * (t - 0.5) + amp * math.sin(2 * math.pi * waves * t + ph), 0.92 - 0.84 * t) for t in np.linspace(0, 1, 160)]]


def arc(rng):
    r, span = rng.uniform(0.38, 0.6), math.radians(rng.uniform(50, 85))
    a0 = rng.uniform(-0.3, 0.3) + math.pi * (0.5 if rng.random() < 0.5 else -0.5) - span / 2
    cx = 0.5 - r * math.cos(a0 + span / 2)
    cy = 0.5 - r * math.sin(a0 + span / 2) * 0.0
    pts = [(cx + r * math.cos(a0 + span * t), 0.5 + r * math.sin(a0 + span * t) - r * math.sin(a0 + span / 2)) for t in np.linspace(0, 1, 160)]
    return [pts]


def fork(rng):
    main = s_curve(rng)[0]
    i = int(len(main) * rng.uniform(0.35, 0.5))
    bx, by = main[i]
    ang = math.atan2(main[i + 1][1] - by, main[i + 1][0] - bx) + rng.choice([-1, 1]) * rng.uniform(0.45, 0.7)
    side = 1 if ang > math.atan2(main[i + 1][1] - by, main[i + 1][0] - bx) else -1
    length, bend = rng.uniform(0.26, 0.36), side * rng.uniform(0.2, 0.6)  # bends further away, never back across
    branch = [(bx + length * t * math.cos(ang + bend * t * t), by + length * t * math.sin(ang + bend * t * t)) for t in np.linspace(0, 1, 90)]
    return [main, branch]


def dashes(rng):
    main = s_curve(rng)[0]
    out, i, n = [], 0, len(main)
    while i < n:
        seg = int(n * rng.uniform(0.14, 0.24))
        out.append(main[i:i + seg])
        i += seg + int(n * rng.uniform(0.06, 0.12))
    return [s for s in out if len(s) > 8]


def hook(rng):
    # An S-curve whose top end turns into a loose, open hook (at most ~200 degrees, never closed).
    pts, x, y, th = [], 0.5 + rng.uniform(-0.1, 0.1), 0.92, -math.pi / 2 + rng.uniform(-0.3, 0.3)
    turn = rng.choice([-1, 1]) * math.radians(rng.uniform(150, 200))
    for t in np.linspace(0, 1, 180):
        pts.append((x, y))
        k = turn * 3.2 * max(0.0, t - 0.55) / 0.45 * 2.2 + math.sin(t * 5) * 0.6
        th += k * 0.0056
        x += math.cos(th) * 0.0056
        y += math.sin(th) * 0.0056
    return [pts]


def turn(strokes, ang):
    c, s_ = math.cos(ang), math.sin(ang)
    return [[(0.5 + (x - 0.5) * c - (y - 0.5) * s_, 0.5 + (x - 0.5) * s_ + (y - 0.5) * c) for x, y in s] for s in strokes]


def fit(strokes, size):
    xs = [p[0] for s in strokes for p in s]
    ys = [p[1] for s in strokes for p in s]
    sc = size / max(max(xs) - min(xs), max(ys) - min(ys))
    ox, oy = 0.5 - (max(xs) + min(xs)) / 2 * sc, 0.5 - (max(ys) + min(ys)) / 2 * sc
    return [[(x * sc + ox, y * sc + oy) for x, y in s] for s in strokes]


def disc(buf, x, y, r, v):
    x0, x1 = int(max(0, x - r - 2)), int(min(buf.shape[1], x + r + 3))
    y0, y1 = int(max(0, y - r - 2)), int(min(buf.shape[0], y + r + 3))
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = np.sqrt((xx - x) ** 2 + (yy - y) ** 2)
    np.maximum(buf[y0:y1, x0:x1], np.clip(r + 0.5 - d, 0, 1) * v, out=buf[y0:y1, x0:x1])  # anti-aliased disc


def glow(buf, x, y, v):
    r = 3 * GLOW_SIGMA
    x0, x1 = int(max(0, x - r)), int(min(buf.shape[1], x + r + 1))
    y0, y1 = int(max(0, y - r)), int(min(buf.shape[0], y + r + 1))
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    g = GLOW * np.exp(-((xx - x) ** 2 + (yy - y) ** 2) / (2 * GLOW_SIGMA ** 2)) * v
    np.maximum(buf[y0:y1, x0:x1], g, out=buf[y0:y1, x0:x1])


def smooth_noise(rng, knots=6):
    vals = [rng.random() for _ in range(knots + 1)]
    def f(t):
        u = min(max(t, 0.0), 1.0) * knots
        i = min(int(u), knots - 1)
        k = u - i
        k = k * k * (3 - 2 * k)
        return vals[i] * (1 - k) + vals[i + 1] * k
    return f


def draw(strokes, rng, size, strength):
    n = CELL - 2 * PAD
    alpha = np.zeros((CELL, CELL))
    for stroke in fit(strokes, size):
        pts = [(PAD + x * n, PAD + y * n) for x, y in stroke]
        seglen = [math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]) for i in range(1, len(pts))]
        total = sum(seglen) or 1
        # Breaks: 1-2 gaps of 6-14 px somewhere between a quarter and four fifths of the way along.
        gaps = []
        if total > 120:
            for _ in range(rng.choice([1, 2])):
                at, gl = rng.uniform(0.25, 0.8) * total, rng.uniform(6, 14)
                gaps.append((at, at + gl))
        noise = smooth_noise(rng)
        run = 0.0
        for i in range(1, len(pts)):
            (px, py), (x, y) = pts[i - 1], pts[i]
            l = seglen[i - 1]
            steps = max(1, int(l * 2))
            for k in range(steps):
                f = k / steps
                s_ = run + l * f
                if any(a <= s_ <= b for a, b in gaps):
                    continue
                t = s_ / total
                w = taper(t) * (0.6 + 0.7 * noise(t))
                cx, cy = px + (x - px) * f, py + (y - py) * f
                disc(alpha, cx, cy, max(0.35, CORE * w), strength)
                glow(alpha, cx, cy, strength * taper(t) ** 0.5)
            run += l
    return np.clip(alpha, 0, 1)


def main():
    rng = random.Random(4242)
    makers = [s_curve] * 4 + [arc] * 4 + [fork] * 3 + [dashes] * 2 + [hook] * 3
    rng.shuffle(makers)  # so every kind of strand gets bright, mid and faint frames
    sheet = np.zeros((CELL * 4, CELL * 4, 4), dtype=np.uint8)
    for f, make in enumerate(makers):
        strokes = turn(make(rng), rng.uniform(-0.7, 0.7))
        alpha = draw(strokes, rng, rng.uniform(0.55, 0.86), STRENGTH[f])
        gx, gy = (f % 4) * CELL, (f // 4) * CELL
        sheet[gy:gy + CELL, gx:gx + CELL, :3] = 255
        sheet[gy:gy + CELL, gx:gx + CELL, 3] = (alpha * 255).round().astype(np.uint8)
    Image.fromarray(sheet, 'RGBA').save(os.path.join(HERE, 'wispline.png'), optimize=True)


if __name__ == '__main__':
    main()
