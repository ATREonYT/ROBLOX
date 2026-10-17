# Draws the particle shapes for the girls' effects (assets/fx/*.png): white shapes with soft glowing edges on
# transparent backgrounds, so ParticleEmitter.Color tints them. Our own art (no owner kit, no invented IDs).
# The first set (heart ... shard) is soft; the anime set at the bottom is hard cel shapes (docs/vfx-guide.md section 3).
# Usage (from huzz-valley/): python3 tools/fx/make_fx.py   then python3 tools/icons/pack_images.py
# Contact sheet of every texture: python3 tools/fx/contact_sheet.py  (writes docs/previews/fx-textures.png)
import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 256  # drawn at 2x, saved at 128
OUT = 'assets/fx'
os.makedirs(OUT, exist_ok=True)

def finish(mask, name, glow=10, core=1.0):
    """mask: L image of the solid shape. Adds a soft glow halo, then saves white RGBA at 128 px."""
    halo = mask.filter(ImageFilter.GaussianBlur(glow))
    alpha = Image.new('L', mask.size)
    a, h, m = alpha.load(), halo.load(), mask.load()
    for y in range(mask.size[1]):
        for x in range(mask.size[0]):
            a[x, y] = min(255, int(m[x, y] * core + h[x, y] * 0.55))
    img = Image.new('RGBA', mask.size, (255, 255, 255, 0))
    img.putalpha(alpha)
    img = img.resize((128, 128), Image.LANCZOS)
    img.save(os.path.join(OUT, name + '.png'))

def canvas():
    return Image.new('L', (S, S), 0)

# Heart
m = canvas(); d = ImageDraw.Draw(m)
pts = []
for i in range(200):
    t = math.pi * 2 * i / 200
    x = 16 * math.sin(t) ** 3
    y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
    pts.append((S / 2 + x * 6.2, S / 2 - y * 6.2 - 6))
d.polygon(pts, fill=255)
finish(m, 'heart')

# Petal (sakura): a rounded teardrop with a notch at the tip
m = canvas(); d = ImageDraw.Draw(m)
pts = []
for i in range(200):
    t = math.pi * 2 * i / 200
    r = 70 * (1 - 0.35 * math.cos(t)) * (0.75 + 0.25 * abs(math.sin(t)))
    pts.append((S / 2 + math.sin(t) * r * 0.7, S / 2 - math.cos(t) * r))
d.polygon(pts, fill=255)
d.polygon([(S / 2 - 12, S / 2 - 100), (S / 2 + 12, S / 2 - 100), (S / 2, S / 2 - 72)], fill=0)
finish(m, 'petal')

# Star: a four-point sparkle
m = canvas(); d = ImageDraw.Draw(m)
pts = []
for i in range(8):
    a = math.pi / 4 * i - math.pi / 2
    r = 110 if i % 2 == 0 else 22
    pts.append((S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r))
d.polygon(pts, fill=255)
finish(m, 'star', glow=14)

# Feather
m = canvas(); d = ImageDraw.Draw(m)
d.ellipse((S / 2 - 34, 30, S / 2 + 34, S - 50), fill=255)
d.line((S / 2, 20, S / 2 + 6, S - 18), fill=255, width=6)
for k in range(9):
    y = 60 + k * 18
    d.line((S / 2 - 40, y + 14, S / 2, y), fill=0, width=3)
    d.line((S / 2 + 40, y + 14, S / 2, y), fill=0, width=3)
finish(m, 'feather', glow=8)

# Snowflake
m = canvas(); d = ImageDraw.Draw(m)
for k in range(6):
    a = math.pi / 3 * k
    x2, y2 = S / 2 + math.cos(a) * 100, S / 2 + math.sin(a) * 100
    d.line((S / 2, S / 2, x2, y2), fill=255, width=12)
    for f in (0.55, 0.8):
        bx, by = S / 2 + math.cos(a) * 100 * f, S / 2 + math.sin(a) * 100 * f
        for s in (-1, 1):
            b = a + s * math.pi / 4
            d.line((bx, by, bx + math.cos(b) * 26, by + math.sin(b) * 26), fill=255, width=9)
finish(m, 'snow', glow=8)

# Leaf
m = canvas(); d = ImageDraw.Draw(m)
pts = []
for i in range(200):
    t = math.pi * 2 * i / 200
    pts.append((S / 2 + math.sin(t) * 52 * abs(math.sin(t)) ** 0.3, S / 2 - math.cos(t) * 105))
d.polygon(pts, fill=255)
d.line((S / 2, S / 2 - 100, S / 2, S / 2 + 110), fill=0, width=5)
finish(m, 'leaf', glow=8)

# Bubble: a ring with a shine
m = canvas(); d = ImageDraw.Draw(m)
d.ellipse((28, 28, S - 28, S - 28), outline=255, width=14)
d.ellipse((70, 62, 104, 96), fill=255)
finish(m, 'bubble', glow=8)

# Flame: a tall ragged fire with three tongues (the main one and two smaller ones leaning out), tips up.
m = canvas(); d = ImageDraw.Draw(m)
import random
random.seed(4)
def tongue(cx, base, height, width, lean):
    pts = []
    for i in range(121):
        t = i / 120  # 0 = left foot, 0.5 = tip, 1 = right foot
        side = -1 if t < 0.5 else 1
        h = 1 - abs(t - 0.5) * 2  # 0 at the feet, 1 at the tip
        w = width * (1 - h) ** 0.8 * (1 + 0.25 * math.sin(h * 9 + side))  # ragged edges
        x = cx + side * w + lean * h * h * height
        y = base - h * height
        pts.append((x, y))
    d.polygon(pts, fill=255)
tongue(S / 2, S - 30, 200, 62, 0.0)
tongue(S / 2 - 40, S - 40, 120, 30, -0.25)
tongue(S / 2 + 42, S - 36, 135, 30, 0.22)
d.ellipse((S / 2 - 70, S - 95, S / 2 + 70, S - 20), fill=255)
m = m.filter(ImageFilter.GaussianBlur(3))
finish(m, 'flame', glow=10)

# Wisp: a soft smoke puff
m = canvas(); d = ImageDraw.Draw(m)
for (x, y, r) in ((128, 140, 70), (90, 120, 50), (165, 115, 55), (128, 90, 45)):
    d.ellipse((x - r, y - r, x + r, y + r), fill=200)
m = m.filter(ImageFilter.GaussianBlur(18))
finish(m, 'wisp', glow=20, core=0.9)

# (Glow is drawn with the anime set below: alpha (1-r)^2.)
# Shard: a thin sharp sliver (the dark flakes that fly off the hands)
m = canvas(); d = ImageDraw.Draw(m)
d.polygon([(S / 2, 18), (S / 2 + 26, S / 2), (S / 2, S - 18), (S / 2 - 18, S / 2)], fill=255)
finish(m, 'shard', glow=4)

# ===================================================================================================================
# The anime set: hard cel shapes (docs/vfx-guide.md sections 1 and 3).
# Rules: white masks (ParticleEmitter.Color tints them); drawn at 4x and shrunk with LANCZOS (crisp, not jagged);
# 2-3 flat alpha steps (CORE 255 / BODY 170 / EDGE 110), never smooth gradients (only Glow is soft); RGB is white
# under every pixel, so no dark fringes; every flipbook frame keeps a transparent gutter; power-of-two sizes.
# ===================================================================================================================
import numpy as np
from PIL import ImageChops

K = 4
CORE, BODY, EDGE = 255, 170, 110
TAU = math.pi * 2


def save_alpha(a, name, size):
    """a: L mask drawn at K x size. Saves a white RGBA picture of size (w, h)."""
    small = a.resize(size, Image.LANCZOS)
    img = Image.new('RGBA', size, (255, 255, 255, 0))
    img.putalpha(small)
    img.save(os.path.join(OUT, name + '.png'))
    return small


def new(w, h=None):
    return Image.new('L', (w, h or w), 0)


def lighter(a, b):
    return ImageChops.lighter(a, b)


def center(a):
    """Moves the shape so its bounding box sits in the middle of the canvas (singles only, never flipbook frames)."""
    box = a.point(lambda v: 255 if v > 6 else 0).getbbox()
    if not box:
        return a
    dx = round((a.width - (box[0] + box[2])) / 2)
    dy = round((a.height - (box[1] + box[3])) / 2)
    out = new(a.width, a.height)
    out.paste(a, (dx, dy))
    return out


def arc_band(d, cx, cy, a0, a1, r_out, r_in, fill, n=360):
    """A band along a circle from angle a0 to a1 (radians, screen space). r_out(t) and r_in(t), t in 0..1 along it."""
    outer, inner = [], []
    for i in range(n + 1):
        t = i / n
        a = a0 + (a1 - a0) * t
        ro, ri = r_out(t), r_in(t)
        outer.append((cx + math.cos(a) * ro, cy + math.sin(a) * ro))
        inner.append((cx + math.cos(a) * ri, cy + math.sin(a) * ri))
    d.polygon(outer + inner[::-1], fill=fill)


def ribbon(d, pts, half, fill):
    """A stroke along pts with half-width half[i] on each side (tapers wherever half goes to 0)."""
    left, right = [], []
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[max(i - 1, 0)]
        x1, y1 = pts[min(i + 1, n - 1)]
        tx, ty = x1 - x0, y1 - y0
        ln = math.hypot(tx, ty) or 1
        nx, ny = -ty / ln, tx / ln
        x, y = pts[i]
        left.append((x + nx * half[i], y + ny * half[i]))
        right.append((x - nx * half[i], y - ny * half[i]))
    d.polygon(left + right[::-1], fill=fill)


def taper(t, peak=0.5, p=0.85):
    """0 at both ends, 1 at t = peak: the width profile of a crescent or a slash."""
    t = min(max(t, 0.0), 1.0)
    g = math.log(0.5) / math.log(peak)
    return math.sin(math.pi * t ** g) ** p


def disc(d, cx, cy, r, fill):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def ring(a, cx, cy, r_out, r_in, fill):
    """An annulus drawn over the picture a (in place) without wiping what is inside it."""
    layer = new(a.width, a.height); dl = ImageDraw.Draw(layer)
    disc(dl, cx, cy, r_out, fill)
    disc(dl, cx, cy, r_in, 0)
    a.paste(lighter(a, layer))


def sheet(name, grid, frame, gutter, frame_fn):
    """A flipbook: grid x grid frames of `frame` px, each drawn at K x by frame_fn(i, n, C) on a C x C canvas."""
    n = grid * grid
    out = new(frame * grid)
    for i in range(n):
        f = frame_fn(i, n, frame * K).resize((frame, frame), Image.LANCZOS)
        arr = np.asarray(f)
        g = gutter - 2
        edge = max(arr[:g].max(), arr[-g:].max(), arr[:, :g].max(), arr[:, -g:].max())
        if edge > 3:
            print('  warning: %s frame %d touches its gutter (alpha %d)' % (name, i + 1, edge))
        out.paste(f, ((i % grid) * frame, (i // grid) * frame))
    img = Image.new('RGBA', out.size, (255, 255, 255, 0))
    img.putalpha(out)
    img.save(os.path.join(OUT, name + '.png'))


# --- crescent (512): a big tapered moon-slash, bright along its outer edge, 2 thin speed arcs inside ---------------
def crescent():
    C = 512 * K
    a = new(C); d = ImageDraw.Draw(a)
    cx, cy, R = C * 0.40, C / 2, C * 0.47
    a0, a1 = math.radians(-100), math.radians(100)
    arc_band(d, cx, cy, a0, a1, lambda t: R, lambda t: R - R * 0.27 * taper(t), BODY)
    arc_band(d, cx, cy, a0 + 0.05, a1 - 0.05, lambda t: R, lambda t: R - R * 0.12 * taper(t, p=0.7), CORE)
    for rr, span, w, v in ((0.64, 62, 0.035, 153), (0.53, 46, 0.026, 102)):
        arc_band(d, cx, cy, math.radians(-span), math.radians(span), lambda t, rr=rr: R * rr,
                 lambda t, rr=rr, w=w: R * rr - R * w * taper(t), v)
    save_alpha(center(a), 'crescent', (512, 512))


# --- rings (512) -----------------------------------------------------------------------------------------------------
def ring_hard():
    C = 512 * K
    a = new(C); d = ImageDraw.Draw(a)
    h = C / 2
    ring(a, h, h, h * 0.95, h * 0.85, CORE)
    ring(a, h, h, h * 0.79, h * 0.77, 200)
    save_alpha(a, 'ring-hard', (512, 512))


def ring_soft():
    """Sharp inner edge, 3 flat steps fading outward: a wave front."""
    C = 512 * K
    a = new(C); d = ImageDraw.Draw(a)
    h = C / 2
    for r, v in ((0.95, 55), (0.90, EDGE), (0.85, BODY), (0.80, CORE)):
        disc(d, h, h, h * r, v)
    disc(d, h, h, h * 0.70, 0)
    save_alpha(a, 'ring-soft', (512, 512))


# --- burst star (2x2 sheet, 512): 4 spiky impact stars ----------------------------------------------------------------
def burst_frame(i, n, C):
    rnd = random.Random(31 + i * 7)
    a = new(C); d = ImageDraw.Draw(a)
    h = C / 2
    R = h - 12 * K
    spikes = rnd.choice((10, 11, 12, 13, 14))
    rot = rnd.random() * TAU
    body, core = [], []
    for k in range(spikes):
        ang = rot + TAU * k / spikes + math.radians(rnd.uniform(-5, 5))
        tip = R * (rnd.uniform(0.55, 1.0) if k % 2 else rnd.uniform(0.82, 1.0))
        mid = ang + TAU / spikes / 2
        body += [(h + math.cos(ang) * tip, h + math.sin(ang) * tip),
                 (h + math.cos(mid) * R * 0.17, h + math.sin(mid) * R * 0.17)]
        core += [(h + math.cos(ang) * tip * 0.52, h + math.sin(ang) * tip * 0.52),
                 (h + math.cos(mid) * R * 0.12, h + math.sin(mid) * R * 0.12)]
    d.polygon(body, fill=BODY)
    d.polygon(core, fill=CORE)
    disc(d, h, h, R * 0.25, CORE)
    return a


# --- twinkle (2x2 sheet, 256): 4-point sparkles with concave sides, different arm lengths -----------------------------
def twinkle_frame(i, n, C):
    a = new(C); d = ImageDraw.Draw(a)
    h = C / 2
    R = h - 10 * K
    lv, lh = ((1.0, 0.72), (0.86, 0.86), (1.0, 0.5), (0.78, 1.0))[i]

    def star(sv, sh, p, fill):
        pts = []
        for k in range(240):
            t = TAU * k / 240
            c, s = math.cos(t), math.sin(t)
            pts.append((h + math.copysign(abs(c) ** p, c) * R * sh, h + math.copysign(abs(s) ** p, s) * R * sv))
        d.polygon(pts, fill=fill)

    star(lv, lh, 3.2, BODY)
    star(lv * 0.62, lh * 0.62, 3.6, CORE)
    disc(d, h, h, R * 0.10, CORE)
    return a


# --- spark (256): a thin diamond needle (VelocityParallel + Squash) ------------------------------------------------------
def spark():
    C = 256 * K
    a = new(C); d = ImageDraw.Draw(a)
    h = C / 2
    top, bot = 8 * K, C - 8 * K
    L = bot - top
    wy = top + L * 0.38
    w = L * 0.06
    d.polygon([(h, top), (h + w, wy), (h, bot), (h - w, wy)], fill=BODY)
    d.polygon([(h, top + L * 0.08), (h + w * 0.45, wy), (h, top + L * 0.80), (h - w * 0.45, wy)], fill=CORE)
    save_alpha(a, 'spark', (256, 256))


# --- swirl (512): 3 log-spiral strokes, thin at the centre, pointed at the outer end -------------------------------------
def swirl():
    C = 512 * K
    a = new(C); d = ImageDraw.Draw(a)
    core = new(C); dc = ImageDraw.Draw(core)
    h = C / 2
    R = h * 0.95
    span = 1.2 * TAU
    r0 = R * 0.10
    b = math.log(0.93 / 0.10) / span
    for arm in range(3):
        rot = TAU * arm / 3
        pts, half, halfc = [], [], []
        for k in range(301):
            t = k / 300
            th = span * t
            r = r0 * math.exp(b * th)
            pts.append((h + math.cos(th + rot) * r, h + math.sin(th + rot) * r))
            wv = R * 0.075 * (t ** 1.2) * min(1.0, (1 - t) / 0.18) ** 0.8
            half.append(wv)
            halfc.append(wv * 0.42)
        ribbon(d, pts, half, BODY)
        ribbon(dc, pts, halfc, CORE)
    save_alpha(center(lighter(a, core)), 'swirl', (512, 512))


# --- swirl strip (256x64): tileable diagonal stripes for Beams ------------------------------------------------------------
def swirl_strip():
    W, H = 256, 64
    w4, h4 = W * K * 3, H * K * 3  # draw 3x3 tiles, shrink, keep the middle one: tiles seamlessly both ways
    y, x = np.mgrid[0:h4, 0:w4]
    P = 64 * K
    s = (x + y) % P
    a = np.zeros((h4, w4), np.uint8)
    a[(s < 22 * K)] = CORE
    a[(s >= 28 * K) & (s < 36 * K)] = EDGE
    big = Image.fromarray(a, 'L').resize((W * 3, H * 3), Image.LANCZOS)
    small = big.crop((W, H, W * 2, H * 2))
    img = Image.new('RGBA', (W, H), (255, 255, 255, 0))
    img.putalpha(small)
    img.save(os.path.join(OUT, 'swirl-strip.png'))


# --- flame sheet (4x4 OneShot, 1024): a cel flame tongue rising, splitting late, shrinking to a wisp ---------------------
def tongue_pts(cx, yc, W, H, sway, phase, amp, lean=0.0):
    """Bulb of radius W centred at (cx, yc), a wavy tongue H tall above it. Returns the outline."""
    pts = []
    for k in range(61):  # bulb bottom, left to right
        t = math.pi - math.pi * k / 60
        pts.append((cx + math.cos(t) * W, yc + math.sin(t) * W))
    right, left = [], []
    for k in range(1, 121):
        u = k / 120
        y = yc - u * H
        xc = cx + sway * u * u * H + lean * u * H
        env = W * (1 - u) ** 1.35
        wr = env * (1 + amp * math.sin(TAU * (1.7 * u - phase)) * math.sin(math.pi * u))
        wl = env * (1 + amp * math.sin(TAU * (1.7 * u - phase) + 2.4) * math.sin(math.pi * u))
        right.append((xc + wr, y))
        left.append((xc - wl, y))
    return pts + right + left[::-1]


def flame_frame(i, n, C):
    a = new(C); d = ImageDraw.Draw(a)
    core = new(C); dc = ImageDraw.Draw(core)
    t = i / (n - 1)
    cx = C / 2
    grow = min(1.0, 0.4 + 0.6 * i / 3)
    rise = 34 * K * t
    W = 46 * K * grow
    H = 112 * K * grow
    yc = C - 12 * K - W - 6 * K - rise
    sway = 0.18 * math.sin(TAU * (t * 1.2 + 0.1))
    phase = t * 2.2
    if i >= 13:  # the wisp: thin, small, curling, no core
        k = (i - 12) / 3
        W *= 0.46 - 0.2 * k
        H *= 0.80 - 0.2 * k
        yc -= 36 * K * k
        sway = 0.22 + 0.16 * k
    elif i >= 10:  # the split: the tongue gets shorter and its tip breaks off and floats up
        k = (i - 9) / 3
        H *= 1 - 0.42 * k
        W *= 1 - 0.15 * k
    d.polygon(tongue_pts(cx, yc, W, H, sway, phase, 0.30), fill=BODY)
    if i < 12:  # two small side tongues flicking up and out
        for side, ph in ((-1, 0.0), (1, 0.45)):
            hs = H * (0.36 + 0.12 * math.sin(TAU * (t * 1.6 + ph)))
            ws = W * 0.36
            bx = cx + side * W * 0.78
            by = yc - W * 0.25
            d.polygon(tongue_pts(bx, by, ws, hs, 0.0, phase + ph, 0.15, lean=side * 0.28), fill=BODY)
    if 10 <= i <= 14:  # the broken-off tip, floating up clear of the body and shrinking
        k = (i - 9) / 5
        fw = (11 * (1 - 0.6 * k) + 3) * K
        tip_y = 40 * K + fw * 2.6 + 24 * K * (1 - k)
        d.polygon(tongue_pts(cx + 0.18 * 112 * K, tip_y, fw, fw * 2.6, 0.1, phase, 0.1), fill=BODY)
    if i < 13:  # the white-hot core sits low in the bulb
        kc = 1.0 if i < 10 else 1 - (i - 9) / 4
        dc.polygon(tongue_pts(cx, yc + W * 0.18, W * 0.52 * kc, H * 0.5 * kc, sway * 0.6, phase + 0.2, 0.22),
                   fill=CORE)
    return lighter(a, core)


# --- shock sheet (4x4 OneShot, 1024): a ring flying out and thinning, then breaking into 3 arcs -------------------------
def shock_frame(i, n, C):
    a = new(C); d = ImageDraw.Draw(a)
    h = C / 2
    R = h - 12 * K
    t = i / (n - 1)
    e = 1 - (1 - t) ** 2.2
    r = R * (0.2 + 0.75 * e) / 0.95
    th = R * (0.18 * (1 - t) ** 1.15 + 0.02 * t)
    if i < 12:
        ring(a, h, h, r, r - th, BODY)
        ring(a, h, h, r, r - th * 0.38, CORE)
    else:
        k = i - 11
        gap = math.radians(14 + 18 * k)
        rot = math.radians(20 + 7 * k)
        for j in range(3):
            a0 = rot + TAU * j / 3 + gap / 2
            a1 = rot + TAU * (j + 1) / 3 - gap / 2
            arc_band(d, h, h, a0, a1, lambda u: r, lambda u: r - th * taper(u, p=0.5), BODY)
            arc_band(d, h, h, a0, a1, lambda u: r, lambda u: r - th * 0.38 * taper(u, p=0.5), CORE)
    return a


# --- slash sheet (4x4 OneShot, 1024): a crescent sweeping 0 -> 200 degrees, then breaking into speed lines ---------------
def slash_frame(i, n, C):
    a = new(C); d = ImageDraw.Draw(a)
    core = new(C); dc = ImageDraw.Draw(core)
    h = C / 2
    R = h - 12 * K
    cy = h + R * 0.25  # the arc runs over the top (150 -> 350 degrees), so its circle sits low to fill the frame
    start = math.radians(150)
    sweep = math.radians(200)
    if i < 10:
        x = (i + 1) / 10
        head = start + sweep * (1 - (1 - x) ** 2)
        tail = start + max(0.0, head - start - math.radians(150))
        W = R * (0.10 + 0.14 * min(1.0, i / 3))
        arc_band(d, h, cy, tail, head, lambda u: R, lambda u: R - W * taper(u, 0.72), BODY)
        arc_band(dc, h, cy, tail, head, lambda u: R, lambda u: R - W * 0.42 * taper(u, 0.72, 0.6), CORE)
    else:
        k = (i - 9) / 6  # 1/6 .. 1
        head = start + sweep + math.radians(18) * k
        tail = start + math.radians(50) + math.radians(120) * k
        if i < 12:  # the crescent thins out
            W = R * 0.24 * (1 - 0.55 * (i - 9))
            arc_band(d, h, cy, tail, head, lambda u: R, lambda u: R - W * taper(u, 0.72), BODY)
            arc_band(dc, h, cy, tail, head, lambda u: R, lambda u: R - W * 0.42 * taper(u, 0.72, 0.6), CORE)
        for j, (dr, off, ln) in enumerate(((0.0, 0.0, 1.0), (0.085, 0.10, 0.75), (0.17, 0.22, 0.55), (0.25, 0.05, 0.4))):
            if i < 11 and j == 0:
                continue
            rr = R * (1 - dr)
            span = (head - tail) * ln * (1 - 0.45 * k)
            h1 = head - math.radians(4) - (head - tail) * off * (1 - k)
            w = R * (0.055 - 0.008 * j) * (1 - 0.45 * k)
            arc_band(d, h, cy, h1 - span, h1, lambda u, rr=rr: rr, lambda u, rr=rr, w=w: rr - w * taper(u, 0.75),
                     BODY if j else CORE)
    return lighter(a, core)


# --- bolt (2x2 sheet, 512): midpoint-displacement lightning with a fork; white core, 50% body --------------------------------
def bolt_path(rnd, p0, p1, depth, disp, lo, hi):
    pts = [p0, p1]
    for _ in range(depth):
        nxt = [pts[0]]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            mx, my = (x0 + x1) / 2, (y0 + y1) / 2
            dx, dy = x1 - x0, y1 - y0
            ln = math.hypot(dx, dy) or 1
            o = rnd.uniform(-disp, disp)
            mx = min(max(mx - dy / ln * o, lo), hi)
            my = my + dx / ln * o * 0.3
            nxt += [(mx, my), (x1, y1)]
        pts = nxt
        disp *= 0.52
    return pts


def bolt_frame(i, n, C):
    rnd = random.Random(101 + i * 13)
    body = new(C); db = ImageDraw.Draw(body)
    core = new(C); dc = ImageDraw.Draw(core)
    lo, hi = 22 * K, C - 22 * K
    top, bot = 16 * K, C - 16 * K
    main = bolt_path(rnd, (C / 2 + rnd.uniform(-30, 30) * K, top), (C / 2 + rnd.uniform(-40, 40) * K, bot),
                     5, C * 0.16, lo, hi)
    paths = [(main, 9 * K, 3 * K)]
    for f in range(1 + (i % 2)):
        j = rnd.randint(len(main) * 3 // 10, len(main) * 6 // 10)
        x0, y0 = main[j]
        side = rnd.choice((-1, 1)) if f == 0 else -side
        end = (min(max(x0 + side * C * rnd.uniform(0.22, 0.32), lo), hi), min(y0 + C * rnd.uniform(0.25, 0.35), bot))
        paths.append((bolt_path(rnd, (x0, y0), end, 4, C * 0.07, lo, hi), 6 * K, 2 * K))
    for pts, wb, wc in paths:
        db.line(pts, fill=128, width=wb, joint='curve')
        dc.line(pts, fill=CORE, width=wc, joint='curve')
        for (x, y), w, dd, v in ((pts[0], wb, db, 128), (pts[-1], wb, db, 128), (pts[0], wc, dc, CORE), (pts[-1], wc, dc, CORE)):
            disc(dd, x, y, w / 2, v)
    return lighter(body, core)


# --- streak (256x64): a tapered line with two thin side stripes, for trails ---------------------------------------------------
def streak():
    W, H = 256 * K, 64 * K
    a = new(W, H); d = ImageDraw.Draw(a)
    cy = H / 2
    x0, x1 = 8 * K, W - 8 * K

    def line(y, hw, length, fill, start=0.0):
        top, bot = [], []
        xs = x0 + (x1 - x0) * start
        xe = xs + (x1 - xs) * length
        for k in range(101):
            u = k / 100
            x = xs + (xe - xs) * u
            w = hw * (1 - u) ** 0.9 * min(1.0, u / 0.04) ** 0.5
            top.append((x, y - w)); bot.append((x, y + w))
        d.polygon(top + bot[::-1], fill=fill)

    line(cy, 13 * K, 1.0, BODY)
    line(cy, 5 * K, 0.85, CORE)
    for s in (-1, 1):
        line(cy + s * 21 * K, 2.6 * K, 0.62, EDGE, start=0.06)
    save_alpha(a, 'streak', (256, 64))


# --- sigil (512): two rings, 8 ticks, a 6-point star; hard 2-tone -------------------------------------------------------------
def sigil():
    C = 512 * K
    a = new(C); d = ImageDraw.Draw(a)
    h = C / 2
    R = h * 0.95
    star = []
    for k in range(6):
        ang = -math.pi / 2 + TAU * k / 6
        star.append((h + math.cos(ang) * R * 0.80, h + math.sin(ang) * R * 0.80))
    tri1, tri2 = star[0::2], star[1::2]
    d.polygon(tri1, fill=EDGE)
    d.polygon(tri2, fill=EDGE)
    lw = round(R * 0.026)
    for tri in (tri1, tri2):
        d.line(tri + [tri[0], tri[1]], fill=CORE, width=lw, joint='curve')
    ring(a, h, h, R * 0.32, R * 0.32 - lw, CORE)
    ring(a, h, h, R, R * 0.95, CORE)
    ring(a, h, h, R * 0.87, R * 0.87 - R * 0.022, CORE)
    for k in range(8):
        ang = TAU * k / 8 - math.pi / 2
        hw = math.radians(1.6)
        d.polygon([(h + math.cos(ang + s * hw) * rr, h + math.sin(ang + s * hw) * rr)
                   for s, rr in ((-1, R * 0.86), (1, R * 0.86), (1, R * 0.96), (-1, R * 0.96))], fill=CORE)
        mid = ang + TAU / 16
        disc(d, h + math.cos(mid) * R * 0.915, h + math.sin(mid) * R * 0.915, R * 0.012, BODY)
    save_alpha(a, 'sigil', (512, 512))


# --- crown (256): five points with ball tips, a band, gems punched out at low alpha ---------------------------------------
def crown():
    C = 256 * K
    a = new(C); d = ImageDraw.Draw(a)
    P = lambda x, y: (x * C, y * C)
    tips = [(0.15, 0.34), (0.325, 0.25), (0.5, 0.15), (0.675, 0.25), (0.85, 0.34)]
    body = [P(0.19, 0.70), P(*tips[0])]
    for (xa, ya), (xb, yb) in zip(tips, tips[1:]):
        body += [P((xa + xb) / 2, 0.52), P(xb, yb)]
    body += [P(0.81, 0.70)]
    d.polygon(body, fill=CORE)
    for x, y in tips:
        disc(d, x * C, y * C, 0.048 * C, CORE)
    d.rounded_rectangle((*P(0.16, 0.66), *P(0.84, 0.84)), radius=0.03 * C, fill=CORE)
    for x, y in tips[1:4]:  # cel shade: the right half of each inner point a step darker
        d.polygon([P(x, y + 0.05), P(x + 0.07, 0.52), P(x, 0.60)], fill=205)
    d.rectangle((*P(0.16, 0.645), *P(0.84, 0.665)), fill=EDGE)  # the line between band and points
    for x in (0.31, 0.5, 0.69):
        disc(d, x * C, 0.75 * C, 0.036 * C, EDGE)
    d.polygon([P(0.5, 0.37), P(0.545, 0.46), P(0.5, 0.55), P(0.455, 0.46)], fill=EDGE)  # centre gem
    save_alpha(center(a), 'crown', (256, 256))


# --- moon (256): a crescent moon, bright core inside a darker rim ----------------------------------------------------------
def moon():
    C = 256 * K
    a = new(C); d = ImageDraw.Draw(a)
    h = C / 2
    R = C * 0.44
    off = (C * 0.20, -C * 0.13)
    rim = C * 0.035
    disc(d, h, h, R, BODY)
    disc(d, h + off[0], h + off[1], R * 0.86, 0)
    core = new(C); dc = ImageDraw.Draw(core)
    disc(dc, h, h, R - rim, CORE)
    disc(dc, h + off[0], h + off[1], R * 0.86 + rim, 0)
    a = lighter(a, core)
    save_alpha(center(a.rotate(-12, resample=Image.BICUBIC)), 'moon', (256, 256))


# --- glow (256): the one soft texture, alpha (1-r)^2, used faint behind things ----------------------------------------------
def glow():
    N = 256
    y, x = np.mgrid[0:N, 0:N]
    r = np.hypot(x - (N - 1) / 2, y - (N - 1) / 2) / (N / 2 - 2)
    al = (np.clip(1 - r, 0, 1) ** 2 * 255).round().astype(np.uint8)
    img = Image.new('RGBA', (N, N), (255, 255, 255, 0))
    img.putalpha(Image.fromarray(al, 'L'))
    img.save(os.path.join(OUT, 'glow.png'))

# --- beam glow (256 x 64): soft across, the same all along (a Beam wraps it every TextureLength without beads, unlike the
# round Glow). The Secret cutscene's light beams, slashes and pillar glow -------------------------------------------------------
def beam_glow():
    W, H = 256, 64
    v = np.abs(np.arange(H) - (H - 1) / 2) / (H / 2)
    al = (np.clip(1 - v, 0, 1) ** 2 * 255).round().astype(np.uint8)
    img = Image.new('RGBA', (W, H), (255, 255, 255, 0))
    img.putalpha(Image.fromarray(np.repeat(al[:, None], W, axis=1), 'L'))
    img.save(os.path.join(OUT, 'beam-glow.png'))

# --- The Secret cutscene's second set (owner, Oct 17: "make the cutscene look one to one as the reference"; beats in
# docs/secret-beats.md). Soft where the reference glows, numpy-drawn. --------------------------------------------------------
def _save_np(al, name):
    al = (np.clip(al, 0, 1) * 255).round().astype(np.uint8)
    img = Image.new('RGBA', (al.shape[1], al.shape[0]), (255, 255, 255, 0))
    img.putalpha(Image.fromarray(al, 'L'))
    img.save(os.path.join(OUT, name + '.png'))


# beam ladder (256 x 64, wraps along a Beam): a soft band with four glowing blocks across it, like the reference's
# 1.6 s "ladder" beam
def beam_ladder():
    W, H = 256, 64
    y, x = np.mgrid[0:H, 0:W]
    v = np.abs(y - (H - 1) / 2) / (H / 2)
    band = np.clip(1 - v, 0, 1) ** 2 * 0.55
    u = (x % 64) / 64
    block = ((u > 0.18) & (u < 0.5) & (v < 0.82)).astype(float)
    rim = ((u > 0.12) & (u < 0.56) & (v < 0.92)).astype(float) * 0.55
    core = ((u > 0.24) & (u < 0.44) & (v < 0.6)).astype(float)
    al = np.maximum(band, np.maximum(rim * 0.65, np.maximum(block * 0.8, core)))
    _save_np(al, 'beam-ladder')


# lightning (512 x 64, wraps along a Beam): a jagged white line with a glow, both ends at the middle so it tiles
def lightning():
    W, H = 512, 64
    rnd = random.Random(31)
    pts = [(0.0, 0.0), (1.0, 0.0)]
    disp = 0.95
    for _ in range(7):
        nxt = [pts[0]]
        for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
            nxt += [((u0 + u1) / 2, (v0 + v1) / 2 + rnd.uniform(-disp, disp)), (u1, v1)]
        pts = nxt
        disp *= 0.55
    xs = np.arange(W) / (W - 1)
    centre = np.interp(xs, [p[0] for p in pts], [p[1] for p in pts])
    centre = np.clip(centre, -0.7, 0.7)
    y = np.arange(H)[:, None]
    dist = np.abs((y - (H - 1) / 2) / (H / 2) - centre[None, :])
    al = np.maximum(np.clip(1 - dist / 0.09, 0, 1), np.clip(1 - dist / 0.55, 0, 1) ** 2 * 0.5)
    _save_np(al, 'lightning')


# nebula (256): a soft cloud of light, for big slow haze in the night sky and the pink burst cloud
def nebula():
    N = 256
    rnd = np.random.default_rng(5)
    y, x = np.mgrid[0:N, 0:N] / (N - 1) * 2 - 1
    al = np.zeros((N, N))
    for _ in range(18):
        cx, cy = rnd.uniform(-0.55, 0.55, 2)
        r = rnd.uniform(0.15, 0.35)
        al += np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (2 * r * r)) * rnd.uniform(0.2, 0.45)
    img = Image.fromarray((rnd.random((N // 16, N // 16)) * 255).astype(np.uint8), 'L').resize((N, N), Image.BICUBIC)
    noise = np.asarray(img.filter(ImageFilter.GaussianBlur(8))) / 255
    fall = np.clip(1 - np.hypot(x, y), 0, 1)
    _save_np(np.clip(al, 0, 0.85) * (0.4 + 0.6 * noise) * fall * 1.2, 'nebula')


# crystal (128): a long faceted shard, one side a step brighter (the reference's floating crystals)
def crystal():
    C = 128 * K
    a = new(C); d = ImageDraw.Draw(a)
    h = C / 2
    top, bot, w = C * 0.06, C * 0.94, C * 0.17
    left = [(h, top), (h - w, C * 0.36), (h - w * 0.8, C * 0.7), (h, bot)]
    right = [(h, top), (h + w, C * 0.36), (h + w * 0.8, C * 0.7), (h, bot)]
    d.polygon(left, fill=BODY)
    d.polygon(right, fill=CORE)
    d.line([(h - w, C * 0.36), (h, C * 0.42), (h + w, C * 0.36)], fill=EDGE, width=2 * K)
    halo = a.filter(ImageFilter.GaussianBlur(6 * K)).point(lambda v: int(v * 0.6))
    save_alpha(lighter(a, halo), 'crystal', (128, 128))


# bokeh (128): a soft out-of-focus mote, a little brighter at the rim
def bokeh():
    N = 128
    y, x = np.mgrid[0:N, 0:N]
    r = np.hypot(x - (N - 1) / 2, y - (N - 1) / 2) / (N / 2 - 3)
    disc_ = np.clip((1 - r) / 0.12, 0, 1)
    rim = np.exp(-((r - 0.86) ** 2) / 0.004) * 0.35
    _save_np(disc_ * 0.6 + rim, 'bokeh')


# star flare (256): a four-point lens flare, long thin spikes and a bright core (the reference's 2.75 s and 12 s)
def star_flare():
    N = 256
    y, x = np.mgrid[0:N, 0:N] / (N - 1) * 2 - 1
    r = np.hypot(x, y)
    spikes = np.exp(-np.abs(y) / 0.012) * np.clip(1 - np.abs(x), 0, 1) ** 1.6 + np.exp(-np.abs(x) / 0.012) * np.clip(1 - np.abs(y), 0, 1) ** 1.6
    d1, d2 = np.abs(x - y) / 1.414, np.abs(x + y) / 1.414
    diag = (np.exp(-d1 / 0.01) + np.exp(-d2 / 0.01)) * np.clip(1 - r / 0.55, 0, 1) ** 2 * 0.6
    core = np.clip(1 - r / 0.22, 0, 1) ** 2 + np.clip(1 - r / 0.08, 0, 1)
    _save_np(spikes + diag + core, 'star-flare')


# rays (512): light rays bursting out from the middle, uneven widths and lengths, fading outwards
def rays():
    N = 512
    rnd = random.Random(12)
    y, x = np.mgrid[0:N, 0:N] / (N - 1) * 2 - 1
    r = np.hypot(x, y)
    ang = np.arctan2(y, x)
    al = np.zeros((N, N))
    for _ in range(26):
        a0 = rnd.uniform(-math.pi, math.pi)
        wid = rnd.uniform(0.012, 0.05)
        ln = rnd.uniform(0.55, 1.0)
        da = np.abs((ang - a0 + math.pi) % TAU - math.pi)
        al = np.maximum(al, np.clip(1 - da / wid, 0, 1) * np.clip(1 - r / ln, 0, 1) * np.clip(r / 0.08, 0, 1))
    _save_np(al, 'rays')


# --- butterfly (2x2 sheet, 256): seen from above, one wing beat (open, half, edge-on, half). Owner's Oct 17 VFX
# reference (design/vfx/ref3): blue butterflies drift round the Secret girl after she lands ----------------------------------
def butterfly_frame(i, n, C):
    a = new(C); d = ImageDraw.Draw(a)
    h = C / 2
    sx = (1.0, 0.62, 0.22, 0.62)[i]  # how wide the wings look as they beat

    def wing(cx, cy, rx, ry, ang, fill):
        pts = []
        for k in range(120):
            t = TAU * k / 120
            x, y = math.cos(t) * rx, math.sin(t) * ry
            ca, sa = math.cos(ang), math.sin(ang)
            pts.append((h + (cx + x * ca - y * sa) * sx, h + cy + x * sa + y * ca))
        d.polygon(pts, fill=fill)

    for side in (-1, 1):
        wing(side * C * 0.21, -C * 0.10, C * 0.22, C * 0.15, side * -0.55, BODY)  # upper wings
        wing(side * C * 0.15, C * 0.13, C * 0.13, C * 0.10, side * 0.6, BODY)    # lower wings
        wing(side * C * 0.22, -C * 0.11, C * 0.12, C * 0.07, side * -0.55, CORE)  # bright inner panes
        wing(side * C * 0.15, C * 0.13, C * 0.06, C * 0.05, side * 0.6, CORE)
    d.ellipse((h - C * 0.022, h - C * 0.20, h + C * 0.022, h + C * 0.22), fill=CORE)  # body
    for side in (-1, 1):  # antennae
        d.line([(h, h - C * 0.19), (h + side * C * 0.07 * sx, h - C * 0.30)], fill=CORE, width=int(C * 0.012))
    return a


crescent(); ring_hard(); ring_soft(); spark(); swirl(); swirl_strip(); streak(); sigil(); crown(); moon(); glow(); beam_glow()
beam_ladder(); lightning(); nebula(); crystal(); bokeh(); star_flare(); rays()
sheet('burst-star', 2, 256, 10, burst_frame)
sheet('twinkle', 2, 128, 8, twinkle_frame)
sheet('bolt', 2, 256, 10, bolt_frame)
sheet('flame-sheet', 4, 256, 10, flame_frame)
sheet('shock-sheet', 4, 256, 10, shock_frame)
sheet('slash-sheet', 4, 256, 10, slash_frame)
sheet('butterfly', 2, 256, 10, butterfly_frame)
print('fx drawn:', sorted(os.listdir(OUT)))
