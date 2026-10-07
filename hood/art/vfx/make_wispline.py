"""wispline.png: the wisp flipbook (wisp.png, 4x4 OneShot) as line work, for the treadmills' x999 smoke.

wisp.png draws each tendril as two bright edge lines round a soft grey body (make_aura_textures.js stores how
much of a pixel is line in its grey level: 0.78 = all body, 1.0 = all line). Stacked, the bodies make an
opaque white blanket; the reference's x999 smoke is dark with thin white lines. This keeps the lines and cuts
the body to a third of its opacity. Only the treadmills use it (key `wispline`); everything else keeps `wisp`.

Run:  python3 make_wispline.py   (needs Pillow; reads and writes next to this file)
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
BODY_KEEP = 1 / 3  # opacity kept where a pixel is all body


def smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def main():
    src = Image.open(os.path.join(HERE, 'wisp.png')).convert('RGBA')
    out = Image.new('RGBA', src.size)
    sp, op = src.load(), out.load()
    w, h = src.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a == 0:
                op[x, y] = (255, 255, 255, 0)
                continue
            line = smooth(0.25, 0.75, (r / 255 - 0.78) / 0.22)  # 0 = body, 1 = edge line
            keep = BODY_KEEP + (1 - BODY_KEEP) * line
            op[x, y] = (255, 255, 255, round(a * keep))
    out.save(os.path.join(HERE, 'wispline.png'), optimize=True)


if __name__ == '__main__':
    main()
