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


rr(4.6, 5.2, 21.4, 22.0, (0, 0, 0, 70))          # shadow, down-right
rr(3.0, 3.0, 20.0, 20.0, (255, 255, 255, 120))     # light rim (top-left edge shows)
rr(3.8, 3.8, 20.6, 20.6, (0, 0, 0, 90))            # dark rim (bottom-right edge shows)
rr(3.8, 3.8, 19.8, 19.8, (255, 255, 255, 38))      # the face
rr(6.0, 5.4, 15.0, 7.0, (255, 255, 255, 60), r=0.8)  # a little glint along the top
img = big.resize((T, T), Image.LANCZOS)
img.save('assets/icons/stud-pattern.png')
print('stud pattern', img.size)
