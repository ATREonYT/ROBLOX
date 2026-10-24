"""One row of the girls' effects tier by tier (Common, Uncommon, Rare, Epic, Legendary, Mythic), same framing.
Owner picked "Small flames" (Oct 18): Rare and Epic get small calm tongues, Legendary and up clearly bigger.
Usage (from huzz-valley/): python3 tools/fx/girl_tiers_sheet.py <stills dir from girl_tiers_scene.luau>
Writes docs/previews/girl-vfx-tiers.jpg. The stills are the scene's kept frames, in time order (one per tier).
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

TIERS = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]
CROP = (300, 40, 724, 576)  # around her, in the 1024 x 576 frame
W = 320


def main():
    src = sys.argv[1]
    files = sorted((f for f in os.listdir(src) if f.startswith("still_")), key=lambda f: int(re.findall(r"\d+", f)[0]))
    assert len(files) == len(TIERS), files
    cw, ch = CROP[2] - CROP[0], CROP[3] - CROP[1]
    h = round(W * ch / cw)
    bar = 34
    sheet = Image.new("RGB", (W * len(TIERS), h + bar), (14, 14, 20))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    for i, (name, f) in enumerate(zip(TIERS, files)):
        im = Image.open(os.path.join(src, f)).convert("RGB").crop(CROP).resize((W, h), Image.LANCZOS)
        sheet.paste(im, (i * W, bar))
        draw.text((i * W + 10, 6), name, fill=(255, 255, 255), font=font)
    out = "docs/previews/girl-vfx-tiers.jpg"
    sheet.save(out, quality=88)
    print(out)


if __name__ == "__main__":
    main()
