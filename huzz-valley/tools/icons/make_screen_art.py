# Cuts the pictures for the Oct 17 screens out of the owner's mockups (design/ui-oct17) into assets/art:
#   coin-pack-500/2000/5000.png  the Shop COINS cards' coin pile, bag and chest (shop-items-coins-dances.png, bottom left)
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
print('screen art made')
