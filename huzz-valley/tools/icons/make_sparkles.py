# The sparkles round the owner's crates on Shop > CRATES (his crate shop mockup, Oct 20,
# design/owner-oct20/0348-crate-shop-mockup.png): a tall diamond (the Storm Vault's orange, cyan and yellow ones, the
# Beast Chest's magenta ones) and a thin 4-point star (the Dojo Chest's white ones). Drawn white with a lighter core
# and a soft glow, so one picture of each serves every colour (ImageColor3 tints it, Screens/Shop SPARKLES).
# Usage (from huzz-valley/): python3 tools/icons/make_sparkles.py && python3 tools/icons/pack_images.py
from PIL import Image, ImageDraw, ImageFilter

N = 256  # drawn at 4x, saved at 256 px (the owner's Mac is Retina)
BIG = N * 4


def finish(shape, core, path):
    glow = shape.filter(ImageFilter.GaussianBlur(BIG * 0.03))
    alpha = Image.eval(glow, lambda v: int(v * 0.55))
    alpha = Image.composite(shape, alpha, shape)  # the shape itself solid, the glow round it soft
    # colour: white core, the rest a light grey, so a tint shows a lighter middle like the mockup's facets
    lum = Image.new('L', (BIG, BIG), 205)
    lum.paste(255, mask=core.filter(ImageFilter.GaussianBlur(BIG * 0.01)))
    im = Image.merge('RGBA', (lum, lum, lum, alpha)).resize((N, N), Image.LANCZOS)
    im.save(path)


def diamond():
    shape, core = Image.new('L', (BIG, BIG), 0), Image.new('L', (BIG, BIG), 0)
    c, hw, hh = BIG / 2, BIG * 0.27, BIG * 0.46  # tall: about 0.59 as wide as high
    ImageDraw.Draw(shape).polygon([(c, c - hh), (c + hw, c), (c, c + hh), (c - hw, c)], fill=255)
    k = 0.5
    ImageDraw.Draw(core).polygon([(c, c - hh * k), (c + hw * k, c), (c, c + hh * k), (c - hw * k, c)], fill=255)
    finish(shape, core, 'assets/icons/sparkle-diamond.png')


def star():
    shape, core = Image.new('L', (BIG, BIG), 0), Image.new('L', (BIG, BIG), 0)
    c, r, w = BIG / 2, BIG * 0.46, BIG * 0.07  # long thin points, pinched waist
    pts = []
    for i in range(4):
        import math
        a = math.pi / 2 * i
        pts.append((c + math.cos(a) * r, c - math.sin(a) * r))
        b = a + math.pi / 4
        pts.append((c + math.cos(b) * w, c - math.sin(b) * w))
    ImageDraw.Draw(shape).polygon(pts, fill=255)
    ImageDraw.Draw(core).ellipse((c - w * 1.6, c - w * 1.6, c + w * 1.6, c + w * 1.6), fill=255)
    finish(shape, core, 'assets/icons/sparkle-star.png')


diamond()
star()
print('sparkle-diamond.png, sparkle-star.png')
