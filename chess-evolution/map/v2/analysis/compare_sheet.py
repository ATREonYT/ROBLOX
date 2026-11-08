"""Side-by-side and 50% overlay sheet: python3 analysis/compare_sheet.py <render_dir> <tag> <out.jpg>"""
import sys
from PIL import Image, ImageDraw, ImageFont
rd, tag, out = sys.argv[1:4]
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
pairs = [("hub_overview", "HubRef", "Hub"), ("terraceA_closeup", "TerraceA", "Treadmill stand"),
         ("terraceB_closeup", "TerraceB", "Phone stand"), ("lane_view", "LaneHigh", "Stage lane")]
W = 740; rows = []
for ref, cam, label in pairs:
    a = Image.open(f"ref/{ref}.png").convert("RGB"); h = int(W * a.height / a.width); a = a.resize((W, h))
    b = Image.open(f"{rd}/{tag}_CAM_{cam}.png").convert("RGB").resize((W, h))
    r = Image.new("RGB", (3 * W + 40, h + 40), (250, 250, 250)); d = ImageDraw.Draw(r)
    for k, (im, t) in enumerate(((a, f"Screenshot: {label}"), (b, "Blender v7"), (Image.blend(a, b, 0.5), "50% overlay"))):
        r.paste(im, (10 + k * (W + 10), 36)); d.text((10 + k * (W + 10), 6), t, fill=(20, 20, 20), font=F)
    rows.append(r)
s = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)), (250, 250, 250)); y = 0
for r in rows: s.paste(r, (0, y)); y += r.height
s.save(out, quality=86); print(s.size)
