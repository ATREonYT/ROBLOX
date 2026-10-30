"""Offline look at the blocky cannons: draws the parts from dump_cannons.luau as flat-shaded
boxes, wedges and simple cylinders/balls in a 3/4 view, one tile per cannon.
python3 tools/preview/render_cannons.py cannons.json out.png
Only a rough stand-in for Studio: no studs, particles, bloom or real lighting."""
import json, math, sys
from PIL import Image, ImageDraw, ImageFont

data = json.load(open(sys.argv[1]))
ORDER = ["Cannon01_Starter", "Cannon02_Iron", "Cannon03_Steel", "Cannon04_Heavy", "Cannon06_Industrial",
         "Cannon05_Golden", "Cannon19_Dragon", "Cannon09_Plasma", "Cannon07_Twin", "Cannon08_Rotary",
         "Cannon21_Toy", "Cannon22_Candy", "Cannon11_Frost", "Cannon12_Inferno", "Cannon13_Toxic",
         "Cannon23_Pumpkin", "Cannon24_Pirate", "Cannon14_Thunder", "Cannon10_Reactor", "Cannon25_Shark",
         "Cannon26_Robot", "Cannon15_Quantum", "Cannon27_Rainbow", "Cannon30_Galaxy", "Cannon31_Hacker"]
names = [n for n in ORDER if n in data]

def mat(cf):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
    return (x, y, z), ((r00, r01, r02), (r10, r11, r12), (r20, r21, r22))

def apply(cf, v):
    p, r = mat(cf)
    return tuple(p[i] + r[i][0] * v[0] + r[i][1] * v[1] + r[i][2] * v[2] for i in range(3))

def faces(shape, s):
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    if shape == "Wedge":
        # Roblox wedge: slope rises from front-bottom (-Z) to back-top (+Z)
        v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (-hx, hy, hz), (hx, hy, hz)]
        return v, [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    if shape == "Cylinder":
        n = 12
        v = []
        for sx in (-hx, hx):
            for i in range(n):
                a = 2 * math.pi * i / n
                v.append((sx, math.cos(a) * hy, math.sin(a) * hz))
        f = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
        for i in range(n):
            j = (i + 1) % n
            f.append((i, j, n + j, n + i))
        return v, f
    if shape == "Ball":
        n, m = 10, 6
        v = []
        for a in range(m + 1):
            th = math.pi * a / m
            for b in range(n):
                ph = 2 * math.pi * b / n
                v.append((math.sin(th) * math.cos(ph) * hx, math.cos(th) * hy, math.sin(th) * math.sin(ph) * hz))
        f = []
        for a in range(m):
            for b in range(n):
                c = (b + 1) % n
                f.append((a * n + b, a * n + c, (a + 1) * n + c, (a + 1) * n + b))
        return v, f
    v = [(sx * hx, sy * hy, sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    return v, [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]

# view: barrel (+Z) towards the viewer's right, seen from the front and a little above
YAW, PITCH = math.radians(-125), math.radians(22)
def view(p):
    x, y, z = p
    x, z = x * math.cos(YAW) - z * math.sin(YAW), x * math.sin(YAW) + z * math.cos(YAW)
    y, z = y * math.cos(PITCH) - z * math.sin(PITCH), y * math.sin(PITCH) + z * math.cos(PITCH)
    return x, y, z
LIGHT = tuple(c / math.sqrt(0.16 + 0.64 + 0.2025) for c in (0.4, 0.8, 0.45))

def render(parts, size):
    polys = []
    for p in parts:
        v, fs = faces(p["shape"], p["size"])
        wv = [apply(p["cf"], q) for q in v]
        vv = [view(q) for q in wv]
        for f in fs:
            pts = [vv[i] for i in f]
            w = [wv[i] for i in f]
            a = [w[1][k] - w[0][k] for k in range(3)]
            b = [w[2][k] - w[0][k] for k in range(3)]
            nrm = (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
            ln = math.sqrt(sum(c * c for c in nrm)) or 1
            nrm = [c / ln for c in nrm]
            vn = view(nrm)
            if vn[2] > 0.02:
                continue  # facing away
            depth = sum(q[2] for q in pts) / len(pts)
            shade = 1.0 if p["neon"] else 0.75 + 0.35 * max(0, sum(nrm[k] * LIGHT[k] for k in range(3)))
            col = tuple(min(255, int(c * 255 * shade * (1.25 if p["neon"] else 1))) for c in p["color"])
            polys.append((depth, [(q[0], q[1]) for q in pts], col))
    xs = [x for _, pts, _ in polys for x, _ in pts]
    ys = [y for _, pts, _ in polys for _, y in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    sc = 0.8 * size / max(max(xs) - min(xs), max(ys) - min(ys))
    img = Image.new("RGB", (size, size), (196, 190, 236))
    d = ImageDraw.Draw(img)
    for depth, pts, col in sorted(polys, key=lambda t: -t[0]):
        q = [(size / 2 + (x - cx) * sc, size / 2 - (y - cy) * sc) for x, y in pts]
        d.polygon(q, fill=col, outline=tuple(max(0, c - 40) for c in col))
    return img

T, COLS = 300, 5
rows = math.ceil(len(names) / COLS)
sheet = Image.new("RGB", (T * COLS, (T + 30) * rows), (25, 25, 32))
dr = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
except OSError:
    font = None
for i, n in enumerate(names):
    x, y = (i % COLS) * T, (i // COLS) * (T + 30)
    sheet.paste(render(data[n]["parts"], T), (x, y + 30))
    dr.text((x + 8, y + 5), n.split("_", 1)[1] + "  (" + str(data[n]["particlesPerSecond"]) + " fx/s)", fill="white", font=font)
sheet.save(sys.argv[2])
print("saved", sys.argv[2])
