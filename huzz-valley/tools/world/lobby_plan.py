"""Top-down plan of one lobby from tools/world/lobby_dump.luau's JSON: every part drawn from above in its own
colour (lowest first, so the highest surface wins), the leaderboards as thick bars with their stat and the way they
face, the avatar stands as rings with their knife, the spawn as a cross.

    python3 huzz-valley/tools/world/lobby_plan.py <dump.json> <out.jpg> [title]

The picture is drawn as the owner sees the lobby from its front (the side with the round stand pads), house at the
top. Shading: higher surfaces are drawn a little lighter so the terraces read as steps.
"""
import json
import math
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def main():
    data = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else 'Lobby plan'
    cx, cz, r = data['cx'], data['cz'], data['radius']
    W = 1400
    margin = 70
    scale = (W - 2 * margin) / (2 * r)
    H = W + 120
    # the front (stand pads) at the bottom: the owner's screenshot looks from the front at the house
    front = data.get('front', [0, -1])
    fx, fz = front
    # screen up = away from the front; screen right = the viewer's right looking at the house
    ux, uz = -fx, -fz
    rx, rz = -uz, ux  # (the viewer's right, standing at the front looking at the house: matches his screenshot)

    def P(x, z):
        dx, dz = x - cx, z - cz
        sx = dx * rx + dz * rz
        sy = dx * ux + dz * uz
        return (W / 2 + sx * scale, 60 + (W - 2 * margin) / 2 + margin - sy * scale)

    img = Image.new('RGB', (W, H), (40, 74, 120))  # the sea
    d = ImageDraw.Draw(img)
    parts = [p for p in data['parts'] if p['t'] < 0.95 and p['kind'] not in ('board', 'stand')]
    tops = [p['top'] for p in parts] or [0]
    lo, hi = min(tops), max(tops)
    for p in sorted(parts, key=lambda p: p['top']):
        k = (p['top'] - lo) / max(1, hi - lo)
        c = tuple(min(255, int(v * (0.75 + 0.45 * k))) for v in p['rgb'])
        poly = [P(x, z) for x, z in p['c']]
        d.polygon(poly, fill=c)
    # labels
    small, big = font(18), font(22)
    colours = {'VIP': (255, 120, 230), 'DancePack': (120, 220, 255)}
    stands = []
    for L in data['labels']:
        x, y = P(L['x'], L['z'])
        if L['kind'] == 'board':
            lx, lz = L['lx'], L['lz']
            # the slab: 14 studs wide across its facing
            ax, az = -lz, lx
            a = P(L['x'] - ax * 7, L['z'] - az * 7)
            b = P(L['x'] + ax * 7, L['z'] + az * 7)
            d.line([a, b], fill=(20, 10, 18), width=12)
            d.line([a, b], fill=(170, 120, 150), width=8)
            tip = P(L['x'] + lx * 9, L['z'] + lz * 9)
            d.line([(x, y), tip], fill=(255, 255, 255), width=3)
            text = L['text'].upper()
            tw = d.textlength(text, font=big)
            d.rectangle([x - tw / 2 - 6, y - 40, x + tw / 2 + 6, y - 14], fill=(20, 10, 18))
            d.text((x - tw / 2, y - 39), text, font=big, fill=(255, 255, 255))
        elif L['kind'] == 'stand':
            col = colours.get(L.get('pass'), (255, 255, 255))
            d.ellipse([x - 15, y - 15, x + 15, y + 15], fill=(20, 10, 18), outline=col, width=4)
            tip = P(L['x'] + L['lx'] * 7, L['z'] + L['lz'] * 7)
            d.line([(x, y), tip], fill=col, width=3)
            stands.append(L)
            n = str(len(stands))
            tw = d.textlength(n, font=small)
            d.text((x - tw / 2, y - 11), n, font=small, fill=(255, 255, 255))
        elif L['kind'] == 'spawn':
            d.line([(x - 10, y - 10), (x + 10, y + 10)], fill=(255, 255, 255), width=4)
            d.line([(x - 10, y + 10), (x + 10, y - 10)], fill=(255, 255, 255), width=4)
            d.text((x + 12, y - 10), 'spawn', font=small, fill=(255, 255, 255))
    # the stands' knives, listed (numbers on the rings)
    if stands:
        lines = []
        for i, L in enumerate(stands):
            name = ''.join((' ' + ch if ch.isupper() and j else ch) for j, ch in enumerate(L['text'])).replace('Dragons', "Dragon's")
            lines.append((f"{i + 1}  {name}  ({'Dance Pack' if L.get('pass') == 'DancePack' else L.get('pass')})", colours.get(L.get('pass'), (255, 255, 255))))
        bw = max(d.textlength(t, font=small) for t, _ in lines) + 24
        bx, by = W - bw - 16, H - 70 - 26 * len(lines) - 40
        d.rectangle([bx, by, bx + bw, by + 34 + 26 * len(lines)], fill=(20, 10, 18))
        d.text((bx + 12, by + 8), 'Avatar stands (Game Pass knife)', font=small, fill=(255, 255, 255))
        for i, (t, c) in enumerate(lines):
            d.text((bx + 12, by + 34 + 26 * i), t, font=small, fill=c)
    # title and key
    d.rectangle([0, 0, W, 56], fill=(20, 14, 26))
    d.text((20, 14), title, font=font(26), fill=(255, 255, 255))
    d.rectangle([0, H - 60, W, H], fill=(20, 14, 26))
    key = 'From above: front (stand pads) at the bottom, house at the top. Bars = leaderboards (white line = the way they face).'
    d.text((20, H - 44), key, font=font(18), fill=(230, 230, 230))
    img.save(out, quality=90)
    print('saved', out)


if __name__ == '__main__':
    main()
