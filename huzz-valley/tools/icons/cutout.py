# Turns the kit's exact-pixel icon crops (backgrounds baked in) into transparent PNGs for import.
# Flood-fills from the crop's border through pixels close to the local background colour, feathers the edge,
# then upscales 4x. This is a reconstruction of the reference pixels, not recovered original artwork.
# Usage: python3 tools/icons/cutout.py   (reads design/exact-pixel-icon-references, writes assets/icons)
import os, sys
from collections import deque
from PIL import Image, ImageFilter

SRC, DST, SCALE, TOL = 'design/exact-pixel-icon-references', 'assets/icons', 4, 70
KEEP = {'robux-mockup-not-official', 'tier-mtb', 'tier-sub3', 'tier-sub5', 'tier-stacy'}  # native or not to be used

def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a[:3], b[:3])) ** 0.5

def cut(path):
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    px = im.load()
    bg = [[False] * h for _ in range(w)]
    border = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    # Seed only from border pixels that look like the background (the icon itself often touches the crop edge).
    cols = sorted(px[b][:3] for b in border)
    med = tuple(sorted(c[i] for c in cols)[len(cols) // 2] for i in range(3))
    q = deque((x, y, px[x, y]) for x, y in border if dist(px[x, y], med) <= TOL * 1.3)
    while q:
        x, y, ref = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or bg[x][y]:
            continue
        c = px[x, y]
        if dist(c, ref) > TOL:
            continue
        bg[x][y] = True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q.append((x + dx, y + dy, ref))  # compare with the border colour it started from, so soft edges stop it
    mask = Image.new('L', (w, h), 0)
    m = mask.load()
    for x in range(w):
        for y in range(h):
            m[x, y] = 0 if bg[x][y] else 255
    big = im.resize((w * SCALE, h * SCALE), Image.LANCZOS)
    mask = mask.resize((w * SCALE, h * SCALE), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))
    big.putalpha(mask)
    box = big.getbbox()
    return big.crop(box) if box else big

os.makedirs(DST, exist_ok=True)
for name in sorted(os.listdir(SRC)):
    stem = name[:-4]
    if not name.endswith('.png') or stem in KEEP:
        continue
    cut(os.path.join(SRC, name)).save(os.path.join(DST, name))
    print('icon', stem)
