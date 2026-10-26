"""The ability card and dash bar next to the owner's pictures b and c (design/owner-oct19), same size and framing:
his picture on top, ours under it, both lined up on the bar's outline box and drawn at his pixels (ours scaled so
its bar is his 886 px). Also prints where each piece of text sits in both (in his pixels, from the bar's top-left),
so "matches" is measured, not eyeballed.
Usage (from huzz-valley/tools/preview, after shots.sh <dir> power-bar power-bar-catcher):
  python3 side_by_side_bar.py <dir> <out.png>"""
import sys
from PIL import Image, ImageDraw

D = '../../design/owner-oct19/'
SHOTS, OUT = sys.argv[1], sys.argv[2]
PAIRS = [('pic-b-catcher-bar.png', 'power-bar-catcher.png', 'catcher (pic b)'), ('pic-c-runner-bar.png', 'power-bar.png', 'runner (pic c)')]


def bar_box(im):
    """The bar's black outline box: the widest run of near-black pixels on a row in the bottom third."""
    w, h = im.size
    px = im.load()
    best = None
    for y in range(h * 2 // 3, h):
        run, start = 0, 0
        for x in range(w):
            r, g, b = px[x, y][:3]
            if r + g + b < 90:  # (ours is drawn at 0.8: its 1 px outline comes out dark, not black)
                if run == 0:
                    start = x
                run += 1
                if run > 300 and (best is None or run > best[2] or (run == best[2] and y < best[1])):
                    best = (start, y, run)
            else:
                run = 0
    return best  # (left, top, width)


def boxes(im, ox, oy, k):
    """Bright text boxes over the bar (white/grey/green), in his pixels from the bar's top-left."""
    px = im.load()
    w, h = im.size
    out = {}
    regions = {'key line': (-55, -34, 300, 600), 'state': (-26, -6, 0, 300), 'help': (-26, -4, 600, 886)}
    for name, (y0, y1, x0, x1) in regions.items():
        xs, ys = [], []
        for y in range(int(oy + y0 * k), int(oy + y1 * k)):
            for x in range(int(ox + x0 * k), min(w, int(ox + x1 * k))):
                r, g, b = px[x, y][:3]
                if (r > 200 and g > 200 and b > 200) or (g > 220 and r < 130):
                    xs.append(x); ys.append(y)
        if xs:
            out[name] = (round((min(xs) - ox) / k), round((min(ys) - oy) / k), round((max(xs) - ox) / k), round((max(ys) - oy) / k))
    return out


rows = []
for theirs, ours, title in PAIRS:
    a = Image.open(D + theirs).convert('RGB')
    b = Image.open(SHOTS + '/' + ours).convert('RGB')
    ab, bb = bar_box(a), bar_box(b)
    k = bb[2] / ab[2]  # our pixels per his pixel
    # crop ours to his framing (his picture's size around his bar), then scale to his pixels
    left = bb[0] - ab[0] * k
    top = bb[1] - ab[1] * k
    crop = b.crop((int(left), int(top), int(left + a.width * k), int(top + a.height * k))).resize(a.size, Image.LANCZOS)
    print(f'{title}: his bar {ab}, ours {bb} (scale {k:.3f})')
    tb, ob = boxes(a, ab[0], ab[1], 1), boxes(b, bb[0], bb[1], k)
    for name in tb:
        print(f'  {name:9s} his {tb[name]}  ours {ob.get(name)}')
    rows.append((title, a, crop))

W = max(r[1].width for r in rows)
H = sum(r[1].height * 2 + 60 for r in rows)
sheet = Image.new('RGB', (W, H), (24, 24, 28))
d = ImageDraw.Draw(sheet)
y = 0
for title, a, crop in rows:
    d.text((8, y + 6), f'{title}: his picture', fill=(255, 255, 255))
    sheet.paste(a, (0, y + 24)); y += a.height + 24
    d.text((8, y + 6), f'{title}: ours (same scale and framing)', fill=(255, 255, 255))
    sheet.paste(crop, (0, y + 24)); y += crop.height + 36
sheet.save(OUT)
print('wrote', OUT)
