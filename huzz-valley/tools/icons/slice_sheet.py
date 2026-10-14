# Cuts the owner's sharp icon sheet (design/icons-hd/owner-icon-sheet.webp, 7 x 4 icons on a see-through
# background) into one PNG per icon in assets/icons, replacing the small kit crops with the same names.
# Pixels are kept exactly as drawn; each icon is only trimmed to its own edges. Nothing is redrawn or resized.
# Usage (from huzz-valley/): python3 tools/icons/slice_sheet.py
from PIL import Image

SHEET, DST = 'design/icons-hd/owner-icon-sheet.webp', 'assets/icons'
# Sheet order, left to right, top to bottom. A list saves one icon under several names. plus-tile, arrow-next,
# play-tile, monitor-small and social-chat have no slot in the game yet. The plus buttons keep the kit's bare white
# plus (currency-plus), because the sheet's plus is a whole purple tile and would sit as a box inside the button.
NAMES = [
    ['shop-cart', 'collection-book', 'tier-crown', 'dances-note', 'rewards-trophy', 'settings-gear', 'main-menu-lines'],
    ['currency-coin', 'currency-gem', 'plus-tile', 'close', 'arrow-next', 'play-tile', 'gift-action'],
    ['inventory-visibility', 'envelope', ['companion-effects', 'players'], 'monitor', 'audio-speaker', 'audio-music', 'audio-waveform'],
    ['controls-dash', 'controls-keyboard', 'monitor-small', 'chat-benefit', 'social-chat', 'check-owned', 'vip-crown'],
]

im = Image.open(SHEET).convert('RGBA')
w, h = im.size
a = im.load()
# Every separate blob of visible pixels belongs to the icon whose grid centre is nearest.
CX = [130, 355, 572, 785, 995, 1200, 1410]
CY = [295, 505, 725, 915]
boxes = {}
seen = bytearray(w * h)
for sy in range(h):
    for sx in range(w):
        if seen[sy * w + sx] or a[sx, sy][3] <= 8:
            continue
        stack, x0, y0, x1, y1 = [(sx, sy)], sx, sy, sx, sy
        seen[sy * w + sx] = 1
        while stack:
            x, y = stack.pop()
            x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and a[nx, ny][3] > 8:
                    seen[ny * w + nx] = 1
                    stack.append((nx, ny))
        if (x1 - x0) * (y1 - y0) < 9:
            continue  # stray specks
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        c = min(range(7), key=lambda i: abs(CX[i] - mx))
        r = min(range(4), key=lambda i: abs(CY[i] - my))
        b = boxes.get((r, c), (x0, y0, x1, y1))
        boxes[(r, c)] = (min(b[0], x0), min(b[1], y0), max(b[2], x1), max(b[3], y1))
for r, names in enumerate(NAMES):
    for c, name in enumerate(names):
        x0, y0, x1, y1 = boxes[(r, c)]
        icon = im.crop((x0, y0, x1 + 1, y1 + 1))
        for n in name if isinstance(name, list) else [name]:
            icon.save(f'{DST}/{n}.png')
        print(name, icon.size)
