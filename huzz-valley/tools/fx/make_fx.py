# Draws the particle shapes for the girls' effects (assets/fx/*.png): white shapes with soft glowing edges on
# transparent backgrounds, so ParticleEmitter.Color tints them. Our own art (no owner kit, no invented IDs).
# Usage (from huzz-valley/): python3 tools/fx/make_fx.py   then python3 tools/icons/pack_images.py
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

# Flame: a soft teardrop tongue (brighter core)
m = canvas(); d = ImageDraw.Draw(m)
pts = []
for i in range(200):
    t = math.pi * 2 * i / 200
    w = 60 * (1 + math.cos(t)) / 2
    pts.append((S / 2 + math.sin(t) * w * 1.1, S / 2 + 40 - math.cos(t) * 100 - (1 - math.cos(t)) * 10))
d.polygon(pts, fill=255)
m = m.filter(ImageFilter.GaussianBlur(6)).transpose(Image.FLIP_TOP_BOTTOM)  # (the tip points up)
finish(m, 'flame', glow=16)

# Wisp: a soft smoke puff
m = canvas(); d = ImageDraw.Draw(m)
for (x, y, r) in ((128, 140, 70), (90, 120, 50), (165, 115, 55), (128, 90, 45)):
    d.ellipse((x - r, y - r, x + r, y + r), fill=200)
m = m.filter(ImageFilter.GaussianBlur(18))
finish(m, 'wisp', glow=20, core=0.9)

# Glow: a round soft dot (orbs, the light under her)
m = canvas(); d = ImageDraw.Draw(m)
d.ellipse((S / 2 - 40, S / 2 - 40, S / 2 + 40, S / 2 + 40), fill=255)
m = m.filter(ImageFilter.GaussianBlur(22))
finish(m, 'glow', glow=30)
# Shard: a thin sharp sliver (the dark flakes that fly off the hands)
m = canvas(); d = ImageDraw.Draw(m)
d.polygon([(S / 2, 18), (S / 2 + 26, S / 2), (S / 2, S - 18), (S / 2 - 18, S / 2)], fill=255)
finish(m, 'shard', glow=4)
print('fx drawn:', sorted(os.listdir(OUT)))
