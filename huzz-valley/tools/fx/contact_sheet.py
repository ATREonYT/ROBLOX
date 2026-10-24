# Contact sheet of every effect texture in assets/fx (docs/previews/fx-textures.png): each one on dark navy, tinted the
# way the game does it, with the full-alpha core shown white over the colour (two stacked emitters), sheets shown
# whole with faint frame lines so the gutters can be checked. Usage (from huzz-valley/): python3 tools/fx/contact_sheet.py
import os
from PIL import Image, ImageDraw, ImageFont
import numpy as np

SRC, OUT = 'assets/fx', 'docs/previews/fx-textures.png'
BG = (12, 18, 44)
TINTS = [(160, 90, 255), (40, 220, 210), (255, 110, 170), (90, 170, 255), (120, 235, 120), (255, 170, 70)]
SHEETS = {'burst-star': 2, 'twinkle': 2, 'bolt': 2, 'flame-sheet': 4, 'shock-sheet': 4, 'slash-sheet': 4}
NEW = ['crescent', 'ring-hard', 'ring-soft', 'spark', 'swirl', 'sigil', 'crown', 'moon', 'glow', 'streak',
       'swirl-strip', 'burst-star', 'twinkle', 'bolt', 'flame-sheet', 'shock-sheet', 'slash-sheet']
T, PAD, LAB = 240, 16, 26


def pascal(stem):
    return ''.join(w.capitalize() for w in stem.split('-'))


def tinted(im, tint):
    a = np.asarray(im.convert('RGBA')).astype(np.float32)
    al = a[..., 3] / 255
    w = np.clip((a[..., 3] - 200) / 55, 0, 1)[..., None]  # the 255 core goes white, the body keeps the colour
    rgb = np.array(tint, np.float32) * (1 - w) + 255 * w
    out = np.dstack([rgb, al * 255]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')


try:
    font = ImageFont.load_default(size=16)
except TypeError:
    font = ImageFont.load_default()
names = [n[:-4] for n in sorted(os.listdir(SRC)) if n.endswith('.png')]
order = [n for n in NEW if n in names] + [n for n in names if n not in NEW]
cols = 6
cells = []  # (name, span)
for n in order:
    cells.append((n, 2 if n in SHEETS else 1))
# simple packing: singles 1x1 cells, sheets 2x2 cells
grid = {}
placed = []
for n, span in cells:
    r = 0
    while True:
        done = False
        for c in range(cols - span + 1):
            if all((r + dr, c + dc) not in grid for dr in range(span) for dc in range(span)):
                for dr in range(span):
                    for dc in range(span):
                        grid[(r + dr, c + dc)] = n
                placed.append((n, span, r, c))
                done = True
                break
        if done:
            break
        r += 1
rows = max(r for r, _ in grid) + 1
CW = T + PAD
sheet = Image.new('RGBA', (cols * CW + PAD, rows * (CW + LAB) + PAD), BG + (255,))
d = ImageDraw.Draw(sheet)
for k, (n, span, r, c) in enumerate(placed):
    im = Image.open(os.path.join(SRC, n + '.png')).convert('RGBA')
    box = span * T + (span - 1) * (PAD + LAB)
    scale = min(box / im.width, box / im.height)
    view = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    x = PAD + c * CW + (box - view.width) // 2
    y = PAD + r * (CW + LAB) + (box - view.height) // 2
    tile = (PAD + c * CW - 4, PAD + r * (CW + LAB) - 4, PAD + c * CW + box + 4, PAD + r * (CW + LAB) + box + 4)
    d.rectangle(tile, fill=(18, 26, 60, 255))
    sheet.alpha_composite(tinted(view, TINTS[k % len(TINTS)]), (x, y))
    g = SHEETS.get(n)
    if g:
        for j in range(1, g):
            d.line((x + view.width * j // g, y, x + view.width * j // g, y + view.height), fill=(70, 80, 120, 255))
            d.line((x, y + view.height * j // g, x + view.width, y + view.height * j // g), fill=(70, 80, 120, 255))
    label = '%s  %dx%d%s' % (pascal(n), im.width, im.height, '  (old)' if n not in NEW else '')
    d.text((PAD + c * CW, PAD + r * (CW + LAB) + box + 6), label, fill=(230, 235, 255, 255), font=font)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.convert('RGB').save(OUT)
print('saved', OUT, sheet.size)
