# Cuts the pictures for the Oct 17 screens out of the owner's mockups (design/ui-oct17) into assets/art:
#   coin-pack-500/2000/5000.png  the Shop COINS cards' coin pile, bag and chest (shop-items-coins-dances.png, bottom left)
#   dance-fx-glow/core.png       the DANCES cards' glowing notes and sparkles (drawn here, see below)
# PLACEHOLDERS: the crops are about 280 px wide, soft on a Retina screen; swap in the owner's sharp PNGs when they come.
# The mockup bakes each card's title into its picture; the title's box is painted over from the rows just above and
# below it (the card glow is smooth there), so our own title can sit on top without a ghost.
# Usage (from huzz-valley/): python3 tools/icons/make_screen_art.py && python3 tools/icons/pack_images.py
import numpy as np
from PIL import Image, ImageFilter

SHOP = Image.open('design/ui-oct17/shop-items-coins-dances.png').convert('RGB')
OUT = 'assets/art/%s.png'


def feather(im, left=0, right=0, top=0, bottom=0):
    # soft edges, so a picture melts into the card's own fill instead of showing a box
    a = np.ones((im.height, im.width), np.float32)
    for n, sl in ((left, lambda i: (slice(None), i)), (right, lambda i: (slice(None), -1 - i)),
                  (top, lambda i: (i, slice(None))), (bottom, lambda i: (-1 - i, slice(None)))):
        for i in range(n):
            a[sl(i)] *= (i + 1) / (n + 1)
    rgba = np.dstack([np.asarray(im.convert('RGB'), np.float32), a * 255]).astype(np.uint8)
    return Image.fromarray(rgba, 'RGBA')


def erase(im, box, pad=6):
    # paints over a baked-in title: each column is blended from the row above the box to the row below it
    x0, y0, x1, y1 = box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad
    a = np.asarray(im, np.float32).copy()
    above, below = a[y0 - 1, x0:x1], a[y1 + 1, x0:x1]
    for y in range(y0, y1 + 1):
        t = (y - y0 + 1) / (y1 - y0 + 2)
        a[y, x0:x1] = above * (1 - t) + below * t
    out = Image.fromarray(a.clip(0, 255).astype(np.uint8), 'RGB')
    soft = out.filter(ImageFilter.GaussianBlur(3)).crop((x0 - 4, y0 - 4, x1 + 4, y1 + 4))
    out.paste(soft.crop((4, 4, soft.width - 4, soft.height - 4)), (x0, y0))
    return out


# COINS cards (mockup px): the inside of each card's lavender rim, down to the price button; title boxes measured
# from the white glyphs (x0, y0, x1, y1).
COIN_TOP, COIN_BOTTOM = 510, 723
COINS = {
    '500': ((40, 318), (113, 527, 243, 546)),
    '2000': ((336, 618), (402, 526, 543, 546)),
    '5000': ((635, 914), (705, 525, 840, 544)),
}
for key, ((x0, x1), title) in COINS.items():
    clean = erase(SHOP, title)
    feather(clean.crop((x0, COIN_TOP, x1, COIN_BOTTOM)), left=1, right=1, top=1, bottom=5).save(OUT % ('coin-pack-' + key))

# DANCES cards (made by us, after the mockup's glowing notes): white shapes the game tints with each dance's colour.
#   dance-fx-glow.png  the soft glow (floor light, halos round two music notes and four sparkles), tinted full colour
#   dance-fx-core.png  the crisp notes and sparkles on top, tinted a lighter shade
from PIL import ImageDraw


def star(d, cx, cy, r, w):
    # a four point sparkle
    d.polygon([(cx, cy - r), (cx + w, cy - w), (cx + r, cy), (cx + w, cy + w), (cx, cy + r), (cx - w, cy + w), (cx - r, cy), (cx - w, cy - w)], fill=255)


def note(h, beamed):
    # a music note h px tall, drawn from shapes (a tilted round head, a thin stem, a flag or a beam to a second note)
    im = Image.new('L', (round(h * (1.0 if beamed else 0.7)), h), 0)
    d = ImageDraw.Draw(im)
    hw, hh, stem = h * 0.30, h * 0.22, max(2, round(h * 0.07))
    heads = [(hw * 0.55, h - hh * 0.6)] + ([(im.width - hw * 0.5, h - hh * 0.6 - h * 0.12)] if beamed else [])
    for x, y in heads:
        head = Image.new('L', (round(hw * 1.4), round(hw * 1.4)), 0)
        ImageDraw.Draw(head).ellipse((head.width / 2 - hw / 2, head.height / 2 - hh / 2, head.width / 2 + hw / 2, head.height / 2 + hh / 2), fill=255)
        head = head.rotate(25, resample=Image.BICUBIC)
        im.paste(255, (round(x - head.width / 2), round(y - head.height / 2)), head)
        d.rectangle((x + hw / 2 - stem, h * 0.08 + (y - heads[0][1]), x + hw / 2, y - hh * 0.1), fill=255)
    x0 = heads[0][0] + hw / 2
    if beamed:
        x1 = heads[1][0] + hw / 2
        d.polygon([(x0 - stem, h * 0.06), (x1, h * 0.06 - h * 0.12), (x1, h * 0.06 - h * 0.12 + h * 0.13), (x0 - stem, h * 0.19)], fill=255)
    else:
        d.polygon([(x0 - stem, h * 0.08), (x0 + h * 0.10, h * 0.20), (x0 + h * 0.22, h * 0.38), (x0 + h * 0.13, h * 0.46), (x0 + h * 0.14, h * 0.34), (x0, h * 0.27)], fill=255)
    return im


FX_W, FX_H, SS = 360, 220, 4
core = Image.new('L', (FX_W * SS, FX_H * SS), 0)
d = ImageDraw.Draw(core)
for cx, cy, h, rot, beamed in ((0.17, 0.30, 0.34, 10, True), (0.84, 0.52, 0.32, -8, False)):
    n = note(round(h * FX_H * SS), beamed).rotate(rot, expand=True, resample=Image.BICUBIC)
    core.paste(255, (round(cx * FX_W * SS - n.width / 2), round(cy * FX_H * SS - n.height / 2)), n)
for cx, cy, r in ((0.30, 0.62, 0.050), (0.70, 0.20, 0.045), (0.10, 0.70, 0.030), (0.90, 0.25, 0.030)):
    star(d, cx * FX_W * SS, cy * FX_H * SS, r * FX_H * SS * 1.6, r * FX_H * SS * 0.28)
core = core.resize((FX_W, FX_H), Image.LANCZOS)
floor = Image.new('L', (FX_W, FX_H), 0)
ImageDraw.Draw(floor).ellipse((FX_W * 0.2, FX_H * 0.84, FX_W * 0.8, FX_H * 0.98), fill=200)
glow = np.maximum(np.asarray(core.filter(ImageFilter.GaussianBlur(7)), np.float32) * 1.6,
                  np.asarray(floor.filter(ImageFilter.GaussianBlur(9)), np.float32))
for name, alpha in (('dance-fx-glow', glow), ('dance-fx-core', np.asarray(core, np.float32))):
    a = np.clip(alpha, 0, 255).astype(np.uint8)
    Image.fromarray(np.dstack([np.full_like(a, 255)] * 3 + [a]), 'RGBA').save(OUT % name)
print('screen art made')
