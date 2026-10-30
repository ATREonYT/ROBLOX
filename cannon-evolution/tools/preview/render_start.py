"""Offline look at the start of the water: your cannon, the Launch Zone and the booth row,
drawn from dump_booths.luau with render_booths' camera. Two shots side by side:
from spawn towards the cannon and the sea, and a high view over the booths.
python3 tools/preview/render_start.py booths.json out.jpg
Rough stand-in for Studio: flat floor and sea, no studs, particles or labels."""
import json, sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from render_booths import render  # noqa: E402

data = json.load(open(sys.argv[1]))
everything = [p for k in data for p in data[k]["parts"]]
W, H = 960, 600
shots = [
    ("From spawn: your cannon at the water, Launch Zone behind it", [-92, 16, -138], [-150, 9, -146]),
    ("From above: launch spot (left) and the smaller booths", [-70, 75, -95], [-85, 8, -165]),
]
sheet = Image.new("RGB", (W * len(shots), H + 40), (25, 25, 32))
dr = ImageDraw.Draw(sheet)
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
for i, (title, cam, look) in enumerate(shots):
    sheet.paste(render(everything, cam, look, W, H, fov=60), (i * W, 40))
    dr.text((i * W + 10, 8), title, fill="white", font=font)
sheet.save(sys.argv[2], quality=88)
print("saved", sys.argv[2])
