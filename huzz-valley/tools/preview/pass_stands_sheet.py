"""The Game Pass stands before and after (owner, Oct 19 evening: "make the gamepass characters look better without
that green circle on the bottom, and add some vfx"): his screenshot, ours as it was (the green disc, the plain
stand-ins), ours now with his model (KnifeDress) and ours now with the switch off (the stand-ins), same framing.
Stills from tools/preview/motion3d/stand_knives_scene.luau with STAND_SET=pass2 (MOTION3D_KEEP dirs):
  before: STAND_LOOK=old KNIFE_MODE=standin; now: KNIFE_MESHES=...; switch off: KNIFE_MODE=standin.
Usage (from huzz-valley/): python3 tools/preview/pass_stands_sheet.py <before.png> <now.png> <switch-off.png> <out.jpg>
"""
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 792, 392
LABEL = 34
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def tile(path, label, colour):
    im = Image.open(path).convert("RGB")
    im = im.resize((W, int(im.height * W / im.width)), Image.LANCZOS)
    if im.height > H:  # (same framing: keep the bottom, like his screenshot)
        im = im.crop((0, im.height - H, W, im.height))
    out = Image.new("RGB", (W, H + LABEL), "#20202c")
    out.paste(im, (0, LABEL))
    d = ImageDraw.Draw(out)
    try:
        f = ImageFont.truetype(FONT, 20)
    except OSError:
        f = ImageFont.load_default()
    d.text((10, 6), label, fill=colour, font=f)
    return out


def main():
    before, now, off, out = sys.argv[1:5]
    tiles = [
        tile("design/owner-oct19/1840-pass-stands.png", "His Studio, Oct 19 18:40", "#ffffff"),
        tile(before, "Ours before: green disc, plain stand-ins (today's pose)", "#ff9a8a"),
        tile(now, "Now: no disc, aura in the knife's colours, his model", "#7dff9a"),
        tile(off, "Now, mesh switch off: same aura, stand-ins cut from his .glb", "#ffe28a"),
    ]
    sheet = Image.new("RGB", (W * 2 + 8, (H + LABEL) * 2 + 8), "#101018")
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 2) * (W + 8), (i // 2) * (H + LABEL + 8)))
    sheet.save(out, quality=88)
    print("sheet ->", out)


main()
