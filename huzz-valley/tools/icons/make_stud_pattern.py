# Draws the studded panel texture (assets/icons/stud-pattern.png), owner's call: "not separated studs, the whole
# thing to have a studded background, everywhere in the UI". One tile = one raised square stud (a Roblox brick top
# seen from above): a soft face, a light top-left edge, a dark bottom-right edge and a faint shadow, on transparent.
# It's white/black with alpha so Kit.studPattern can lay it over any colour (ImageColor3 white, ImageTransparency
# sets how strong). Tiled at 24 reference px; drawn at 4x for Retina screens.
# Usage (from huzz-valley/): python3 tools/icons/make_stud_pattern.py   (then pack_images.py)
from PIL import Image, ImageDraw, ImageFilter

T = 96  # tile px (24 reference px at 4x)
SS = 4
big = Image.new('RGBA', (T * SS, T * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
u = T * SS / 24.0  # one reference px


def rr(x0, y0, x1, y1, fill, r=3.2):
    d.rounded_rectangle((x0 * u, y0 * u, x1 * u, y1 * u), radius=r * u, fill=fill)


# Oct 21 (owner: "work more on the stud texture, check the other references"): his reference shop's studs are soft
# rounded squares that nearly fill the tile (a thin seam between them), lit on top, a soft shade along the bottom.
rr(2.0, 3.2, 22.6, 23.4, (0, 0, 0, 60), r=4.5)          # shade, a little down
rr(1.6, 1.6, 22.0, 22.0, (255, 255, 255, 70), r=4.5)    # light rim along the top-left
rr(2.2, 2.2, 22.2, 22.2, (0, 0, 0, 55), r=4.5)          # dark rim along the bottom-right
rr(2.2, 2.2, 21.6, 21.6, (255, 255, 255, 34), r=4.2)    # the face
rr(4.5, 3.4, 19.0, 6.4, (255, 255, 255, 40), r=1.5)     # soft light across the top
img = big.resize((T, T), Image.LANCZOS)
img.save('assets/icons/stud-pattern.png')
print('stud pattern', img.size)
