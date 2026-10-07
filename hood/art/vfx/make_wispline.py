"""wispline.png: 16 different thin smoke strands (4x4 sheet, one static strand per frame) for the treadmills' x999.

The reference's x999 smoke is dark with thin white line work: short broken strokes, S-curves and open arcs,
not one curl repeated. Each frame here is its own strand: S-curves, open arcs, forks without a curl, broken
dashes, and three that end in a loose open hook (none closed). Every strand is drawn like the other smoke
sheets ("inked smoke"): two bright edge lines and a soft body between them at a third of their opacity, tapered
at both ends. The edge lines stop short of the tips, so no outline closes into a ring, and a short dash is a
single tapered line. The emitter picks one random frame per particle (Grid4x4, Framerate 0, StartRandom: the `aura`
recipe) and animates it with Size and a gentle rotation instead of frames.

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
HALF_W = 3.5  # body half-width at the thickest point, px (the two edges read as one line at particle size)
LINE_R = 1.45  # edge-line radius, px
BODY = 1 / 3  # body opacity relative to the lines


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


def fit(strokes):
    xs = [p[0] for s in strokes for p in s]
    ys = [p[1] for s in strokes for p in s]
    sc = 0.86 / max(max(xs) - min(xs), max(ys) - min(ys))
    ox, oy = 0.5 - (max(xs) + min(xs)) / 2 * sc, 0.5 - (max(ys) + min(ys)) / 2 * sc
    return [[(x * sc + ox, y * sc + oy) for x, y in s] for s in strokes]


def splat(buf, x, y, r, v):
    x0, x1 = int(max(0, x - r - 2)), int(min(buf.shape[1], x + r + 3))
    y0, y1 = int(max(0, y - r - 2)), int(min(buf.shape[0], y + r + 3))
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = np.sqrt((xx - x) ** 2 + (yy - y) ** 2)
    a = np.clip(r + 0.6 - d, 0, 1) * v  # anti-aliased disc
    np.maximum(buf[y0:y1, x0:x1], a, out=buf[y0:y1, x0:x1])


def draw(strokes):
    n = CELL - 2 * PAD
    lines, body = np.zeros((CELL, CELL)), np.zeros((CELL, CELL))
    for stroke in fit(strokes):
        m = len(stroke)
        short = m < 50  # a dash: one tapered line, no outline
        for i in range(1, m):
            t = i / (m - 1)
            x, y = PAD + stroke[i][0] * n, PAD + stroke[i][1] * n
            px, py = PAD + stroke[i - 1][0] * n, PAD + stroke[i - 1][1] * n
            dx, dy = x - px, y - py
            l = math.hypot(dx, dy) or 1
            nx, ny = -dy / l, dx / l
            w = HALF_W * taper(t)
            vis = taper(t) ** 0.35
            edges = 0.14 < t < 0.86  # open at both tips
            steps = max(1, int(l * 2))
            for k in range(steps):
                f = k / steps
                cx, cy = px + dx * f, py + dy * f
                if short:
                    splat(lines, cx, cy, LINE_R * (0.6 + 0.6 * taper(t)), vis)
                    continue
                splat(body, cx, cy, max(0.6, w), BODY * vis)
                if edges:
                    for side in (-1, 1):
                        splat(lines, cx + nx * w * side, cy + ny * w * side, LINE_R, vis)
    alpha = np.maximum(lines, body)
    lum = np.where(alpha > 0, 0.82 + 0.18 * np.clip(lines / (alpha + 1e-6), 0, 1), 1)
    return alpha, lum


def main():
    rng = random.Random(4242)
    makers = [s_curve] * 4 + [arc] * 4 + [fork] * 3 + [dashes] * 2 + [hook] * 3
    sheet = np.zeros((CELL * 4, CELL * 4, 4), dtype=np.uint8)
    for f, make in enumerate(makers):
        alpha, lum = draw(turn(make(rng), rng.uniform(-0.7, 0.7)))
        gx, gy = (f % 4) * CELL, (f // 4) * CELL
        g = (lum * 255).round().astype(np.uint8)
        sheet[gy:gy + CELL, gx:gx + CELL, 0] = g
        sheet[gy:gy + CELL, gx:gx + CELL, 1] = g
        sheet[gy:gy + CELL, gx:gx + CELL, 2] = g
        sheet[gy:gy + CELL, gx:gx + CELL, 3] = (np.clip(alpha, 0, 1) * 255).round().astype(np.uint8)
    Image.fromarray(sheet, 'RGBA').save(os.path.join(HERE, 'wispline.png'), optimize=True)


if __name__ == '__main__':
    main()
