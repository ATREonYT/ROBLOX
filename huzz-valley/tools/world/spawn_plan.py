"""Where the game puts bodies, from above, before and after the Oct 19 spawn fix (owner: "make them spawn not in the
middle inside of objects and just make them spawn on open ground"; "make barriers around the spawns"; "make catchers
spawn in the middle"). Reads the JSON that tests/Spawns.spec.luau writes with SPAWN_DUMP=<file>.

    SPAWN_DUMP=/tmp/spawns.json lune run tests/Spawns.spec.luau
    python3 tools/world/spawn_plan.py /tmp/spawns.json docs/previews/spawns-one-lobby.jpg [map name]

Top left: the lobby before (his SpawnLocations as white crosses, the old random spots: red = inside something or
no floor, grey = fine). Top right: the lobby after (the spawn pad, its wooden rail in brown, the 30 spots in green,
the SpawnLocation moved onto it). Bottom: one map in front of the lobby (runners' start lines in blue, catchers in
red on the middle line, the old random catcher spots faint).
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def panel(size, centre, radius, front, parts):
    """A top-down canvas: front (the maps' side) at the bottom. Returns image, draw, and the world->pixel map."""
    W, H = size
    img = Image.new('RGB', (W, H), (40, 74, 120))
    d = ImageDraw.Draw(img)
    cx, cz = centre
    fx, fz = front
    ux, uz = -fx, -fz
    rx, rz = -uz, ux
    scale = min(W, H) / (2 * radius)

    def P(x, z):
        dx, dz = x - cx, z - cz
        return (W / 2 + (dx * rx + dz * rz) * scale, H / 2 - (dx * ux + dz * uz) * scale)

    tops = [p['top'] for p in parts] or [0]
    lo, hi = min(tops), max(tops)
    for p in sorted(parts, key=lambda p: p['top']):
        k = (p['top'] - lo) / max(1, hi - lo)
        c = tuple(min(255, int(v * (0.75 + 0.45 * k))) for v in p['rgb'])
        d.polygon([P(x, z) for x, z in p['c']], fill=c)
    return img, d, P, scale


def dot(d, xy, r, fill, outline=(20, 10, 18)):
    x, y = xy
    d.ellipse([x - r, y - r, x + r, y + r], fill=fill, outline=outline, width=2)


def cross(d, xy, r, col, width=4):
    x, y = xy
    d.line([(x - r, y - r), (x + r, y + r)], fill=(20, 10, 18), width=width + 3)
    d.line([(x - r, y + r), (x + r, y - r)], fill=(20, 10, 18), width=width + 3)
    d.line([(x - r, y - r), (x + r, y + r)], fill=col, width=width)
    d.line([(x - r, y + r), (x + r, y - r)], fill=col, width=width)


def label(d, xy, text, f, col=(255, 255, 255)):
    x, y = xy
    tw = d.textlength(text, font=f)
    d.rectangle([x - 6, y - 4, x + tw + 6, y + f.size + 6], fill=(20, 10, 18))
    d.text((x, y), text, font=f, fill=col)


def main():
    data = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    want = sys.argv[3] if len(sys.argv) > 3 else 'Halloween_Map'
    L = data['lobby']
    small, mid = font(18), font(22)
    S = 800
    radius = 80
    front = L['front']
    # the lobby panels: the plaza's middle, nudged towards the front so its front edge and the pad show
    centre = (L['cx'] + front[0] * 22, L['cz'] + front[1] * 22)

    before, bd, BP, scale = panel((S, S), centre, radius, front, data['lobbyParts'])
    bad = 0
    for x, z, ok in data['oldLobby']:
        if ok:
            dot(bd, BP(x, z), 4, (200, 200, 200), None)
    for x, z, ok in data['oldLobby']:
        if not ok:
            bad += 1
            cross(bd, BP(x, z), 6, (255, 70, 70), 3)
    for x, z in data['oldSpawns']:
        p = BP(x, z)
        if 0 <= p[0] <= S and 0 <= p[1] <= S:
            cross(bd, p, 12, (255, 255, 255), 5)
    label(bd, (16, 14), 'BEFORE: anywhere on the plaza', mid)
    label(bd, (16, 52), f"{data['oldBad']} of {data['oldTotal']} old spots inside something (red)", small, (255, 150, 150))
    label(bd, (16, 82), 'white X = his SpawnLocations', small)

    after, ad, AP, _ = panel((S, S), centre, radius, front, data['lobbyParts'])
    for p in data['rail']:
        poly = [AP(x, z) for x, z in p['c']]
        ad.line(poly + [poly[0]], fill=(20, 10, 18), width=7)
        ad.polygon(poly, fill=(190, 110, 35))
        ad.line(poly + [poly[0]], fill=(190, 110, 35), width=3)
    cx, cz = L['centre']
    ix, iz = L['inward']
    for x, z in data['padSpots']:
        dot(ad, AP(x, z), 6, (90, 224, 122))
    cross(ad, AP(cx, cz), 12, (255, 255, 255), 5)
    tip = AP(cx + ix * 26, cz + iz * 26)
    ad.line([AP(cx + ix * 12, cz + iz * 12), tip], fill=(255, 255, 255), width=4)
    label(ad, (16, 14), 'AFTER: one spawn pad, rail on 3 sides', mid)
    label(ad, (16, 52), '30 spots, all open ground (green), 12 inside the rail', small, (150, 255, 170))
    label(ad, (16, 82), 'brown = wooden rail (+ invisible wall, players only)', small)
    label(ad, (16, 112), 'arrow = open side, into the plaza', small)

    # the map panel
    m = next((m for m in data['maps'] if m['name'] == want), data['maps'][0])
    pts = m['lineA'] + m['lineB'] + m['catchers']
    mx, mz = m['mid']
    far = max(((x - mx) ** 2 + (z - mz) ** 2) ** 0.5 for x, z in pts) + 30
    MW, MH = 2 * S, 760
    mapimg, md, MP, _ = panel((MW, MH), (mx, mz), max(far, 60) * 0.56, front, data['lobbyParts'] + m['parts'])
    for x, z, ok in m['oldCatchers']:
        dot(md, MP(x, z), 3, (255, 170, 170) if ok else (255, 60, 60), None)
    for x, z in m['lineA'] + m['lineB']:
        dot(md, MP(x, z), 7, (90, 170, 255))
    for i, (x, z) in enumerate(m['catchers']):
        dot(md, MP(x, z), 9, (235, 50, 50))
    label(md, (16, 14), f"{m['name'].replace('_', ' ')}: catchers start in the middle, facing the runners", mid)
    label(md, (16, 52), 'red = 8 catchers on the middle line   blue = 12 runners on each start line', small)
    label(md, (16, 82), f"faint pink = old random catcher spots (all were open, but scattered over 40 studs)", small, (255, 190, 190))

    W = 2 * S + 12
    LH = 640  # (the lobby panels' empty sea below the plaza's front edge, cut off)
    before, after = before.crop((0, 0, S, LH)), after.crop((0, 0, S, LH))
    img = Image.new('RGB', (W, 56 + LH + 12 + MH + 50), (20, 14, 26))
    img.paste(before, (0, 56))
    img.paste(after, (S + 12, 56))
    img.paste(mapimg, (6, 56 + LH + 12))
    d = ImageDraw.Draw(img)
    d.text((20, 14), 'Spawns on open ground, one lobby (his place, measured offline)', font=font(26), fill=(255, 255, 255))
    d.text((20, img.height - 38), 'From above, the maps side at the bottom. Drawn from tests/Spawns.spec.luau on places/HUSSANIME.rbxl.',
           font=small, fill=(230, 230, 230))
    img.save(out, quality=90)
    print('saved', out)


if __name__ == '__main__':
    main()
