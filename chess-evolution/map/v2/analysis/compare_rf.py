"""Reference Fix comparison: per view, reference | render | 50% overlay, labelled. Phone renders are full frames and
are cropped to the screenshot's box first. usage: compare_rf.py <render_dir> <tag> <out_prefix> [width]"""
import sys, os
from PIL import Image, ImageDraw, ImageFont
VIEWS = [("Hub", "ref/hub_overview.png", None), ("Treadmill", "ref/terraceA_closeup.png", None),
         ("Phone", "ref/terraceB_closeup.png", (287, 73, 1299, 471)), ("Lane", "ref/lane_view.png", None)]
d, tag, out = sys.argv[1], sys.argv[2], sys.argv[3]; Wd = int(sys.argv[4]) if len(sys.argv) > 4 else 700
try: font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
except Exception: font = ImageFont.load_default()
rows = []
for name, ref, crop in VIEWS:
    p = os.path.join(d, f"{tag}_CAM_{name}.png")
    if not os.path.exists(p): continue
    r = Image.open(p).convert("RGB")
    if crop: r = r.crop(crop)
    R = Image.open(ref).convert("RGB"); h = round(Wd * R.height / R.width)
    R = R.resize((Wd, h), Image.LANCZOS); r = r.resize((Wd, h), Image.LANCZOS); o = Image.blend(R, r, 0.5)
    row = Image.new("RGB", (Wd * 3 + 20, h + 34), "white")
    for k, (im, lab) in enumerate(((R, f"{name}: screenshot"), (r, f"{name}: Blender ({tag})"), (o, "50% overlay"))):
        row.paste(im, (k * (Wd + 10), 34)); ImageDraw.Draw(row).text((k * (Wd + 10) + 4, 6), lab, fill="black", font=font)
    o.save(f"{out}_{name}_overlay.jpg", quality=90); rows.append(row)
H = sum(r.height for r in rows); sheet = Image.new("RGB", (rows[0].width, H), "white"); y = 0
for r in rows: sheet.paste(r, (0, y)); y += r.height
sheet.save(f"{out}_sheet.jpg", quality=88); print("wrote", f"{out}_sheet.jpg", sheet.size)

def edge_overlay(ref_img, render_img):
    """Reference with the render's outlines drawn on top in magenta (reads better than a 50% blend for clay renders)."""
    import numpy as np
    from PIL import ImageFilter
    e = np.asarray(render_img.convert("L").filter(ImageFilter.FIND_EDGES)) > 18
    a = np.asarray(ref_img).copy(); a[e] = (255, 0, 220); return Image.fromarray(a)
if os.environ.get("EDGES"):
    for name, ref, crop in VIEWS:
        p = os.path.join(d, f"{tag}_CAM_{name}.png")
        if not os.path.exists(p): continue
        r = Image.open(p).convert("RGB")
        if crop: r = r.crop(crop)
        R = Image.open(ref).convert("RGB"); h = round(Wd * R.height / R.width)
        edge_overlay(R.resize((Wd, h), Image.LANCZOS), r.resize((Wd, h), Image.LANCZOS)).save(f"{out}_{name}_edges.jpg", quality=90)
