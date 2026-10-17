# Removes the baked-in background from the kit's icon crops (design/exact-pixel-icon-references) and writes them
# to assets/icons. The icon pixels are kept exactly as they are: same size, nothing redrawn or upscaled. Only the
# background around the icon (flood-filled from the crop's edges) becomes transparent, with a soft 1 px edge.
# Usage (from huzz-valley/): python3 tools/icons/clear_background.py
import os
from collections import deque
from PIL import Image

SRC, DST, TOL = 'design/exact-pixel-icon-references', 'assets/icons', 62
SKIP = {'robux-mockup-not-official', 'tier-mtb', 'tier-sub3', 'tier-sub5', 'tier-stacy'}
# White icons that fill their crop: only the single main edge colour is background, and thin parts are kept.
ONE_BACKGROUND = {'envelope', 'lock', 'controls-keyboard', 'audio-waveform', 'shirt-benefit', 'sneaker'}
KEEP_THIN = {'audio-waveform', 'controls-keyboard', 'controls-menu'}
# Crops whose second background colour covers only a small share of the edge.
EDGE_SHARE = {'currency-gem': 0.04, 'currency-coin': 0.04}


def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a[:3], b[:3])) ** 0.5


def clear(path, stem):
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    px = im.load()
    border = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    # The background colours: the common colours along the crop's edge (a crop can straddle two backgrounds).
    counts = {}
    for b in border:
        c = tuple(v // 24 for v in px[b][:3])
        counts[c] = counts.get(c, 0) + 1
    share = EDGE_SHARE.get(stem, 0.12)
    refs = [tuple(v * 24 + 12 for v in c) for c, n in counts.items() if n >= len(border) * share]
    if stem in ONE_BACKGROUND:
        cols = [px[b][:3] for b in border]
        refs = [tuple(sorted(c[i] for c in cols)[len(cols) // 2] for i in range(3))]
    bg = [[False] * h for _ in range(w)]
    # seed only from edge pixels that look like a background colour (icons often touch the crop edge)
    q = deque((x, y, px[x, y]) for x, y in border if min(dist(px[x, y], r) for r in refs) <= TOL)
    while q:
        x, y, ref = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or bg[x][y] or dist(px[x, y], ref) > TOL:
            continue
        bg[x][y] = True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q.append((x + dx, y + dy, ref))
    # Thin slivers along the crop's edge (a neighbour's outline, an underline) are not part of the icon.
    seen = [[False] * h for _ in range(w)]
    for sx in range(w):
        for sy in range(h):
            if bg[sx][sy] or seen[sx][sy]:
                continue
            comp, stack = [], [(sx, sy)]
            seen[sx][sy] = True
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not bg[nx][ny] and not seen[nx][ny]:
                        seen[nx][ny] = True
                        stack.append((nx, ny))
            xs, ys = [c[0] for c in comp], [c[1] for c in comp]
            thin = min(max(xs) - min(xs), max(ys) - min(ys)) <= 3
            edge = min(xs) <= 3 or min(ys) <= 3 or max(xs) >= w - 4 or max(ys) >= h - 4
            if thin and edge and stem not in KEEP_THIN:
                for x, y in comp:
                    bg[x][y] = True
    out = im.copy()
    o = out.load()
    for x in range(w):
        for y in range(h):
            if bg[x][y]:
                o[x, y] = (0, 0, 0, 0)
            else:
                n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= x + dx < w and 0 <= y + dy < h and bg[x + dx][y + dy])
                if n >= 2:  # outermost icon pixel next to cleared background: soften it
                    r, g, b, a = o[x, y]
                    o[x, y] = (r, g, b, int(a * 0.6))
    box = out.getbbox()
    return out.crop(box) if box else out


os.makedirs(DST, exist_ok=True)
for name in sorted(os.listdir(SRC)):
    if name.endswith('.png') and name[:-4] not in SKIP:
        clear(os.path.join(SRC, name), name[:-4]).save(os.path.join(DST, name))
