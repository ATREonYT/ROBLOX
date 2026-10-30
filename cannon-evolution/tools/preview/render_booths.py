"""Offline look at the training booths with their cannons: draws the parts from dump_booths.luau
as flat-shaded shapes through a perspective camera at each booth's front, one tile per booth.
python3 tools/preview/render_booths.py booths.json out.png
Only a rough stand-in for Studio: no studs, particles, labels or real lighting; neon gets a simple blur glow
to stand in for Studio's bloom."""
import json, math, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from render_cannons import faces, apply  # noqa: E402  (shape tables shared with the cannon sheet)

NAMES = {1: "Starter", 2: "Iron", 3: "Steel", 4: "Heavy", 5: "Industrial", 6: "Golden", 7: "Dragon (VIP)", 8: "Plasma"}

def sub(a, b): return [a[i] - b[i] for i in range(3)]
def dot(a, b): return sum(a[i] * b[i] for i in range(3))
def cross(a, b): return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
def norm(a):
    l = math.sqrt(dot(a, a)) or 1
    return [c / l for c in a]

LIGHT = norm([0.4, 0.85, 0.5])

def render(parts, cam, look, W, H, fov=55):
    fwd = norm(sub(look, cam))
    right = norm(cross(fwd, [0, 1, 0]))
    up = cross(right, fwd)
    f = (H / 2) / math.tan(math.radians(fov) / 2)
    polys = []
    for p in parts:
        v, fs = faces(p["shape"], p["size"])
        wv = [apply(p["cf"], q) for q in v]
        for face in fs:
            w = [wv[i] for i in face]
            # the shape tables wind faces clockwise, so this cross product points inwards
            nrm = norm(cross(sub(w[2], w[0]), sub(w[1], w[0])))
            if dot(nrm, sub(w[0], cam)) > 0:
                continue  # facing away
            rel = [sub(q, cam) for q in w]
            ds = [dot(r, fwd) for r in rel]
            if min(ds) < 0.5:
                continue
            pts = [(W / 2 + f * dot(r, right) / d, H / 2 - f * dot(r, up) / d) for r, d in zip(rel, ds)]
            shade = 1.0 if p["neon"] else 0.72 + 0.38 * max(0, dot(nrm, LIGHT))
            col = [min(255, int(c * 255 * shade * (1.3 if p["neon"] else 1))) for c in p["color"]]
            a = p["alpha"]
            depth = 1e9 + sum(ds) / len(ds) if p.get("ground") else sum(ds) / len(ds)  # ground first
            polys.append((depth, pts, tuple(col), a, p["neon"]))
    img = Image.new("RGB", (W, H), (196, 214, 238))
    d = ImageDraw.Draw(img, "RGBA")
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    g = ImageDraw.Draw(glow)
    for _, pts, col, a, neon in sorted(polys, key=lambda t: -t[0]):
        d.polygon(pts, fill=col + (int(255 * (1 - a)),), outline=tuple(max(0, c - 45) for c in col) + (int(255 * (1 - a)),))
        # neon lights up; anything drawn over it later hides its glow source
        g.polygon(pts, fill=col if neon else (0, 0, 0))
    glow = ImageChops.add(glow.filter(ImageFilter.GaussianBlur(9)), glow.filter(ImageFilter.GaussianBlur(3)))
    return ImageChops.screen(img, glow)

if __name__ == "__main__":
    data = json.load(open(sys.argv[1]))
    order = sorted((k for k in data if k != "start"), key=lambda k: data[k]["x"])
    T_W, T_H, COLS = 520, 430, 4
    rows = math.ceil(len(order) / COLS)
    sheet = Image.new("RGB", (T_W * COLS, (T_H + 34) * rows), (25, 25, 32))
    dr = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
    except OSError:
        font = None
    for i, k in enumerate(order):
        b = data[k]
        floor = min(p["cf"][1] for p in b["parts"] if p["cannon"])
        x = b["x"]
        img = render(b["parts"], [x + 6, floor + 11, -150], [x, floor + 4.5, -177], T_W, T_H)
        ox, oy = (i % COLS) * T_W, (i // COLS) * (T_H + 34)
        sheet.paste(img, (ox, oy + 34))
        dr.text((ox + 10, oy + 6), NAMES.get(int(k), k) + " booth", fill="white", font=font)
    sheet.save(sys.argv[2], quality=90)
    print("saved", sys.argv[2])
