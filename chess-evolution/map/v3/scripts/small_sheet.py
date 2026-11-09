"""Container-side quick sheet: screenshot | render | 50% overlay for every view, 700 px per panel.
usage: small_sheet.py <render_dir> <tag> <out.jpg>"""
import sys
from PIL import Image
d, tag, out = sys.argv[1:4]; rows = []
for n in ["treadmill", "lane", "hub", "phone"]:
    R = Image.open(f"refs/{n}.png").convert("RGB"); r = Image.open(f"{d}/{n}_{tag}.png").convert("RGB")
    w = 700; h = round(w * R.height / R.width); R, r = R.resize((w, h)), r.resize((w, h))
    row = Image.new("RGB", (w * 3 + 20, h), "white"); row.paste(R, (0, 0)); row.paste(r, (w + 10, 0))
    row.paste(Image.blend(R, r, 0.5), (2 * w + 20, 0)); rows.append(row)
s = Image.new("RGB", (rows[0].width, sum(x.height + 10 for x in rows)), "white"); y = 0
for x in rows: s.paste(x, (0, y)); y += x.height + 10
s.save(out, quality=85)
