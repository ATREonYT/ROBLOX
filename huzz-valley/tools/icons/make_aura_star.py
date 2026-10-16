# A STAND-IN Aura star (assets/icons/aura-star.png) until the owner sends their own art (a see-through PNG of the
# star from their Aura sheet; a white version for the colour variants). White with a soft glow, so the game can
# tint it any colour (ImageColor3). Shape from the owner's sheet: a four-point crystal star, tall and narrow.
# Usage (from huzz-valley/): python3 tools/icons/make_aura_star.py   (then pack_images.py)
from PIL import Image, ImageDraw, ImageFilter
import math

S, SS = 256, 4
big = Image.new('RGBA', (S * SS, S * SS), (0, 0, 0, 0))
cx = cy = S * SS / 2

def star(rx, ry, inner, fill, d):
    pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        if i % 2 == 0:
            r = (ry if i % 4 == 0 else rx)
        else:
            r = inner
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(pts, fill=fill)

u = S * SS / 256
glow = Image.new('RGBA', big.size, (0, 0, 0, 0))
star(70 * u, 118 * u, 30 * u, (255, 255, 255, 150), ImageDraw.Draw(glow))
glow = glow.filter(ImageFilter.GaussianBlur(18 * u))
big = Image.alpha_composite(big, glow)
d = ImageDraw.Draw(big)
star(56 * u, 104 * u, 20 * u, (235, 235, 245, 255), d)       # the crystal
star(36 * u, 74 * u, 12 * u, (255, 255, 255, 255), d)        # its bright core
# a facet line down the middle, slightly darker, so it reads as a crystal
d.line((cx, cy - 104 * u, cx, cy + 104 * u), fill=(205, 205, 222, 255), width=int(3 * u))
d.line((cx - 56 * u, cy, cx + 56 * u, cy), fill=(215, 215, 230, 255), width=int(2 * u))
img = big.resize((S, S), Image.LANCZOS)
img.save('assets/icons/aura-star.png')
print('aura star', img.size)

# The orbit ring round a star (assets/icons/aura-ring.png): a thin tilted ellipse, bright at the front, fading
# at the back, so a slowly turning pair of them reads as rings circling the star (the sheet's swirls).
R = 256
big = Image.new('RGBA', (R * SS, R * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
c = R * SS / 2
for i in range(360):
    a0, a1 = math.radians(i), math.radians(i + 1.2)
    alpha = int(60 + 195 * (0.5 + 0.5 * math.sin(math.radians(i))))  # bright along the bottom (front) half
    rx, ry = 118 * SS, 36 * SS
    p0 = (c + math.cos(a0) * rx, c + math.sin(a0) * ry)
    p1 = (c + math.cos(a1) * rx, c + math.sin(a1) * ry)
    d.line((p0, p1), fill=(255, 255, 255, alpha), width=int(3.2 * SS))
ring = big.filter(ImageFilter.GaussianBlur(1.2 * SS)).resize((R, R), Image.LANCZOS)
ring.save('assets/icons/aura-ring.png')
print('aura ring', ring.size)
