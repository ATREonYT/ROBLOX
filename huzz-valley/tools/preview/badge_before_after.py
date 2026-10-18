"""The Index window before and after the rarity badge fix (docs/previews/index-badge-fixed.jpg).
Rows are shots.sh screens with long names and every rarity (index-girls-common, index-girls, index-girls-uncommon,
index-girls-scrolled), rendered from the old code (before) and the new (after). Usage:
  python3 badge_before_after.py <beforeDir> <afterDir> <out.jpg>
"""
import sys
from PIL import Image, ImageDraw, ImageFont

ROWS = [
    ("index-girls-common", "Akane, COMMON (the owner's screenshot)"),
    ("index-girls", "Kurumi Tokisaki, LEGENDARY (owned, equipped)"),
    ("index-girls-uncommon", "Uncommon Girl 10, UNCOMMON (owned)"),
    ("index-girls-scrolled", "scrolled: Rem RARE, Uncommon Girl 10, Zero Two EPIC"),
]
SCALE = 0.5

def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/{name}", size)

def main(before, after, out):
    w, h = int(1536 * SCALE), int(700 * SCALE)
    pad, head, cap = 10, 40, 24
    sheet = Image.new("RGB", (pad + 2 * (w + pad), head + len(ROWS) * (h + cap + pad)), (18, 20, 34))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 10), "BEFORE", fill=(255, 120, 130), font=font(20, True))
    d.text((pad * 2 + w, 10), "AFTER", fill=(110, 236, 140), font=font(20, True))
    for r, (name, label) in enumerate(ROWS):
        y = head + r * (h + cap + pad)
        d.text((pad, y), label, fill=(235, 235, 245), font=font(15, True))
        for c, src in enumerate((before, after)):
            im = Image.open(f"{src}/{name}.png").convert("RGB").resize((w, h), Image.LANCZOS)
            sheet.paste(im, (pad + c * (w + pad), y + cap))
    sheet.save(out, quality=86)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
