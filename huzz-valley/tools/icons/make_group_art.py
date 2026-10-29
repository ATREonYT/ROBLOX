# The FREE SPINS (group) window's pictures, cut from the owner's picture (design/owner-oct23/group-reward-ref2.png,
# Oct 23 19:33: "please use the reference to make the group join ui"). Stand-ins until he sends them as transparent
# PNGs (sharper, and without the bits of the window behind them):
#   group-backdrop.png  the scenery behind everything, softly blurred (the wheel, tiles, words and buttons the game
#                       draws itself sit on top of where his were)
#   group-pair.png      the girl hugging the player (left), edges faded into the backdrop
#   group-fighter.png   the player with the red katana (right), edges faded into the backdrop
# Writes assets/art/; then run tools/icons/pack_images.py. Usage (from huzz-valley/): python3 tools/icons/make_group_art.py
import numpy as np
from PIL import Image, ImageFilter

SRC = 'design/owner-oct23/group-reward-ref2.png'
im = Image.open(SRC).convert('RGB')

# the window's body in his picture (under the header, inside the blue rim)
body = im.crop((92, 205, 1318, 945))
back = body.filter(ImageFilter.GaussianBlur(22))
back = back.resize((512, round(512 * back.height / back.width)), Image.LANCZOS)
back.save('assets/art/group-backdrop.png')


def cut(box, fade, name, size, erase=()):
    """box in his picture; fade = (left, top, right, bottom) px of soft edge (0 = a hard edge on the window's rim);
    erase = rectangles of his picture (x0, y0, x1, y1) taken out, softly: his words and buttons next to the figure."""
    part = im.crop(box).convert('RGBA')
    w, h = part.size
    a = np.ones((h, w), np.float32)
    xs, ys = np.arange(w)[None, :], np.arange(h)[:, None]
    l, t, r, b = fade
    if l: a *= np.clip(xs / l, 0, 1)
    if t: a *= np.clip(ys / t, 0, 1)
    if r: a *= np.clip((w - 1 - xs) / r, 0, 1)
    if b: a *= np.clip((h - 1 - ys) / b, 0, 1)
    for x0, y0, x1, y1 in erase:
        gx, gy = xs + box[0], ys + box[1]
        dx = np.maximum(np.maximum(x0 - gx, gx - x1), 0)
        dy = np.maximum(np.maximum(y0 - gy, gy - y1), 0)
        a *= np.clip(np.maximum(dx, dy) / 24, 0, 1)
    arr = np.array(part)
    arr[..., 3] = (a ** 1.5 * 255).astype(np.uint8)
    out = Image.fromarray(arr, 'RGBA')
    out.thumbnail((size, size), Image.LANCZOS)
    out.save('assets/art/' + name)
    print('wrote', name, out.size)


cut((92, 255, 445, 800), (0, 40, 60, 50), 'group-pair.png', 384, [(330, 675, 2000, 2000), (170, 790, 2000, 2000)])
cut((995, 380, 1318, 860), (60, 50, 0, 50), 'group-fighter.png', 384, [(0, 675, 1125, 725), (0, 790, 1245, 2000)])
print('wrote group-backdrop.png', back.size)
