# Cuts the Shop ITEMS card pictures out of the owner's mockup (design/ui-oct17/shop-items-coins-dances.png) into
# assets/art/item-*.png, and makes the items the mockup doesn't show from the closest one (hue-shifted: only the
# trail's or the glow's colours change, the runner keeps his skin and hair).
# PLACEHOLDERS: the crops are about 230 px wide (soft on a Retina screen); swap in the owner's sharp PNGs when they come.
# Usage (from huzz-valley/): python3 tools/icons/make_item_art.py && python3 tools/icons/pack_images.py
import colorsys
import numpy as np
from PIL import Image

MOCK = Image.open('design/ui-oct17/shop-items-coins-dances.png').convert('RGB')
OUT = 'assets/art/item-%s.png'
# the mockup's ITEMS cards: left edges (x), 232 px wide; the picture sits between the slot line and the price button
CARDS = {'mint-trail': 218, 'ocean-trail': 462, 'candy-trail': 704, 'galaxy-trail': 948, 'pink-name': 1196, 'sky-name': 1438}
TOP, BOTTOM, INSET = 183, 314, 4


def feather(im, side=6, top=10):
    # soft edges, so the picture melts into the card's own fill instead of showing a box
    a = np.ones((im.height, im.width), np.float32)
    for i in range(side):
        a[:, i] *= (i + 1) / (side + 1)
        a[:, -1 - i] *= (i + 1) / (side + 1)
    for i in range(top):
        a[i, :] *= (i + 1) / (top + 1)
        a[-1 - i, :] *= (i + 1) / (top + 1)
    rgba = np.dstack([np.asarray(im, np.float32), a * 255]).astype(np.uint8)
    return Image.fromarray(rgba, 'RGBA')


def crop(key):
    x = CARDS[key]
    return MOCK.crop((x + INSET, TOP, x + 232 - INSET, BOTTOM))


def shift(im, src_hue, to_hue=None, window=50, rainbow=False):
    # moves the hues near `src_hue` (degrees) to `to_hue` (or a rainbow across the picture), fading out by `window`
    rgb = np.asarray(im, np.float32) / 255
    h, w, _ = rgb.shape
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in rgb.reshape(-1, 3)]).reshape(h, w, 3)
    d = np.abs(((hsv[..., 0] * 360 - src_hue + 180) % 360) - 180)
    weight = np.clip(1 - (d - window * 0.6) / (window * 0.4), 0, 1) * np.clip(hsv[..., 1] * 3, 0, 1)
    if rainbow:
        target = (np.tile(np.linspace(0, 300, w), (h, 1)) + 330) % 360
    else:
        target = np.full((h, w), float(to_hue))
    delta = ((target - src_hue + 180) % 360) - 180
    hsv[..., 0] = ((hsv[..., 0] * 360 + delta * weight) % 360) / 360
    out = np.array([colorsys.hsv_to_rgb(*p) for p in hsv.reshape(-1, 3)]).reshape(h, w, 3)
    return Image.fromarray((out * 255).clip(0, 255).astype(np.uint8), 'RGB')


for key in CARDS:
    feather(crop(key)).save(OUT % key)
feather(shift(crop('pink-name'), 325, 100)).save(OUT % 'lime-name')
feather(shift(crop('pink-name'), 325, rainbow=True, window=60)).save(OUT % 'rainbow-name')
feather(shift(crop('mint-trail'), 155, 28)).save(OUT % 'legend-streak')
feather(shift(crop('candy-trail'), 318, 348, window=40)).save(OUT % 'mythic-streak')
feather(shift(crop('galaxy-trail'), 275, 245, window=60)).save(OUT % 'secret-comet')

# The reward auras: our own render of them on the test avatar (docs/previews/worn-auras.png, 3 x 2 panels of 640 x 360)
WORN = Image.open('docs/previews/worn-auras.png').convert('RGB')
for key, (px, py) in {'legend-glow': (640, 0), 'mythic-blaze': (1280, 0), 'void-halo': (0, 360)}.items():
    cx, cy = px + 320, py + 165
    feather(WORN.crop((cx - 150, cy - 85, cx + 150, cy + 85)), side=12, top=12).save(OUT % key)
print('item art made')
