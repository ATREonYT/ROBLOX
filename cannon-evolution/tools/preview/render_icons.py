"""Clean icon renders for Alex's gamepass / UI art (Oct 30): every blocky cannon and every
drawn cannonball as its own transparent PNG, 3/4 view, soft shading and a chunky dark outline.
python3 tools/preview/render_icons.py cannons.json out_dir
Rendered at 4x and scaled down so edges are smooth. Studs, particles and glow are not drawn;
Alex's own imported balls (meshes) come from Studio captures instead."""
import json, math, os, sys
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from render_cannons import ORDER, faces, apply, view, LIGHT  # noqa: E402

SIZE, SS = 512, 4
OUTLINE = (30, 18, 45)

def draw(parts, size=SIZE):
    big = size * SS
    polys = []
    for p in parts:
        v, fs = faces(p["shape"], p["size"])
        wv = [apply(p["cf"], q) for q in v]
        vv = [view(q) for q in wv]
        for f in fs:
            w = [wv[i] for i in f]
            a = [w[1][k] - w[0][k] for k in range(3)]
            b = [w[2][k] - w[0][k] for k in range(3)]
            nrm = (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
            ln = math.sqrt(sum(c * c for c in nrm)) or 1
            nrm = [c / ln for c in nrm]
            if view(nrm)[2] > 0.02:
                continue
            pts = [vv[i] for i in f]
            lit = max(0, sum(nrm[k] * LIGHT[k] for k in range(3)))
            shade = 1.05 if p["neon"] else 0.72 + 0.42 * lit
            col = tuple(min(255, int(c * 255 * shade * (1.2 if p["neon"] else 1))) for c in p["color"])
            polys.append((sum(q[2] for q in pts) / len(pts), [(q[0], q[1]) for q in pts], col))
    xs = [x for _, pts, _ in polys for x, _ in pts]
    ys = [y for _, pts, _ in polys for _, y in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    sc = 0.82 * big / max(max(xs) - min(xs), max(ys) - min(ys))
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _, pts, col in sorted(polys, key=lambda t: -t[0]):
        q = [(big / 2 + (x - cx) * sc, big / 2 - (y - cy) * sc) for x, y in pts]
        d.polygon(q, fill=col + (255,), outline=tuple(max(0, c - 55) for c in col) + (255,), width=SS)
    # chunky outline round the whole shape, like Roblox simulator icons
    alpha = img.getchannel("A").filter(ImageFilter.MaxFilter(29))  # about 3.5 px at the final size
    rim = Image.new("RGBA", (big, big), OUTLINE + (0,))
    rim.putalpha(alpha)
    out = Image.alpha_composite(rim, img)
    return out.resize((size, size), Image.LANCZOS)

def ball_icon(color, band, size=SIZE):
    """A smooth shaded cannonball drawn per pixel: tilted band, soft light, a shine and the outline."""
    import numpy as np
    big = size * SS
    r = 0.4 * big
    yy, xx = np.mgrid[0:big, 0:big].astype(float)
    x, y = (xx - big / 2) / r, -(yy - big / 2 - 0.03 * big) / r
    inside = x * x + y * y <= 1
    z = np.sqrt(np.clip(1 - x * x - y * y, 0, 1))
    light = np.array([-0.45, 0.6, 0.66]); light /= np.linalg.norm(light)
    lam = np.clip(x * light[0] + y * light[1] + z * light[2], 0, 1)
    axis = np.array([0.35, 0.15, 0.92]); axis /= np.linalg.norm(axis)
    onband = np.abs(x * axis[0] + y * axis[1] + z * axis[2]) < 0.13
    base = np.where(onband[..., None], np.array(band, float), np.array(color, float))
    shade = 0.55 + 0.55 * lam
    rgb = np.clip(base * shade[..., None], 0, 255)
    spec = np.clip((x * light[0] + y * light[1] + z * light[2]), 0, 1) ** 40
    rgb = np.clip(rgb + 255 * 0.55 * spec[..., None], 0, 255)
    img = np.zeros((big, big, 4), np.uint8)
    img[..., :3] = rgb.astype(np.uint8)
    img[..., 3] = np.where(inside, 255, 0)
    im = Image.fromarray(img, "RGBA")
    d = ImageDraw.Draw(im)
    # fuse cap on top, in the band colour
    cw, ch = 0.22 * big, 0.08 * big
    top = big / 2 + 0.03 * big - r - ch * 0.4
    d.rounded_rectangle([big / 2 - cw / 2, top - ch / 2, big / 2 + cw / 2, top + ch / 2], radius=ch / 3,
                        fill=tuple(int(c * 0.9) for c in band) + (255,), outline=OUTLINE + (255,), width=3 * SS)
    alpha = im.getchannel("A").filter(ImageFilter.MaxFilter(29))
    rim = Image.new("RGBA", (big, big), OUTLINE + (0,))
    rim.putalpha(alpha)
    return Image.alpha_composite(rim, im).resize((size, size), Image.LANCZOS)

if __name__ == "__main__":
    data = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    os.makedirs(os.path.join(out, "cannons"), exist_ok=True)
    os.makedirs(os.path.join(out, "cannonballs"), exist_ok=True)
    for n in ORDER:
        if n in data:
            draw(data[n]["parts"]).save(os.path.join(out, "cannons", n.split("_", 1)[1] + ".png"))
    # the drawn balls (Alex's own balls are captured in Studio); colours from GameConfig
    DRAWN = {"Gold": ((255, 200, 40), (255, 255, 255)), "Ruby": ((225, 40, 70), (255, 170, 190)), "Frost": ((190, 235, 255), (70, 180, 255))}
    for name, (c, b) in DRAWN.items():
        ball_icon(c, b).save(os.path.join(out, "cannonballs", name + ".png"))
    print("done")
