#!/usr/bin/env python3
"""Builds src/ReplicatedStorage/MTL/Config/AmbientMap.lua from the survey dumps in tools/survey/*.json
(tools/SurveyHoodLife.lua: roads, buildings, misc; tools/DressHoodLife.lua: dress = vignette seats, wire spans).
Positions only (StreamingEnabled can't hide them). Re-run any time the survey changes:
    python3 tools/build_ambient_map.py
Traffic loops are listed by street names below (the hood grid), so lanes always sit on real asphalt."""
import json, math, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
SURVEY = os.path.join(HERE, 'survey')
OUT = os.path.join(HERE, '..', 'src', 'ReplicatedStorage', 'MTL', 'Config', 'AmbientMap.lua')
SPAWN = (-1432.0, -368.0)

def load(name):
    p = os.path.join(SURVEY, name + '.json')
    return json.load(open(p)) if os.path.exists(p) else None

roads, buildings, misc, dress = load('roads'), load('buildings'), load('misc'), load('dress')
rng = random.Random(1977)

def dist(a, b): return math.hypot(a[0] - b[0], a[1] - b[1])

# ------------------------------------------------------------------ streets
# strip: x, topY, z, width, length, yawDeg, name. Its axis (local Z) = (sin yaw, cos yaw).
strips = [dict(x=a[0], y=a[1], z=a[2], w=a[3], L=a[4], yaw=a[5], name=a[6]) for a in roads['A']]
for s in strips:
    r = math.radians(s['yaw']); s['dx'], s['dz'] = math.sin(r), math.cos(r)

def street(name):
    return [s for s in strips if s['name'] == name and s['L'] > 1]

def line_cross(s, t):
    """intersection of the centre lines of strips s and t (None if parallel)"""
    den = s['dx'] * t['dz'] - s['dz'] * t['dx']
    if abs(den) < 0.2: return None
    qx, qz = t['x'] - s['x'], t['z'] - s['z']
    u = (qx * t['dz'] - qz * t['dx']) / den
    return (s['x'] + s['dx'] * u, s['z'] + s['dz'] * u)

def corner(a_name, b_name):
    """crossing point of two streets: use the strips of each that come closest to each other"""
    best = None
    for s in street(a_name):
        for t in street(b_name):
            p = line_cross(s, t)
            if not p: continue
            # how far the crossing is outside each strip (0 = inside)
            def out(st):
                along = (p[0] - st['x']) * st['dx'] + (p[1] - st['z']) * st['dz']
                return max(0, abs(along) - st['L'] / 2)
            score = out(s) + out(t)
            if best is None or score < best[0]:
                best = (score, p, s, t)
    if not best or best[0] > 80:
        raise SystemExit('no crossing for %s x %s (%s)' % (a_name, b_name, best and best[0]))
    return best[1], best[2], best[3]

# closed loops round blocks near spawn, as a ring of streets: corner i = crossing of ring[i] and ring[i+1]
LOOPS = [
    ['Liberty Blvd', 'Flagler St W', 'NW 10 Ave', 'Liberty Ave'],
    ['NW 17 Ave', 'Flagler St W', 'Liberty Blvd', 'Liberty Ave'],
    ['Liberty Blvd', 'NW 71 St', 'NW 10 Ave', 'Flagler St W'],
    ['NW 17 Ave', 'Liberty Ave', 'Railroad Ave', 'Flagler St W'],
    ['Liberty Blvd', 'North Ave W', 'NW 10 Ave', 'NW 71 St'],
]

def offset_ring(pts, d):
    """offsets a closed polygon to the RIGHT of travel by d (right-hand traffic). Right of (dx, dz) = (-dz, dx)
    in Roblox's x/z (north = -Z, east = +X: driving north (0,-1), right is east (+1, 0))."""
    n = len(pts)
    lines = []
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        dx, dz = b[0] - a[0], b[1] - a[1]
        m = math.hypot(dx, dz); dx, dz = dx / m, dz / m
        rx, rz = -dz, dx
        lines.append(((a[0] + rx * d[i], a[1] + rz * d[i]), (dx, dz)))
    out = []
    for i in range(n):
        (p, u), (q, v) = lines[i - 1], lines[i]
        den = u[0] * v[1] - u[1] * v[0]
        if abs(den) < 1e-6:
            out.append(q); continue
        t = ((q[0] - p[0]) * v[1] - (q[1] - p[1]) * v[0]) / den
        out.append((p[0] + u[0] * t, p[1] + u[1] * t))
    return out

lanes = []
for ring in LOOPS:
    pts, widths, ys = [], [], []
    for i in range(len(ring)):
        p, s, t = corner(ring[i], ring[(i + 1) % len(ring)])
        pts.append(p); ys.append((s['y'] + t['y']) / 2)
    # edge i runs along street ring[i+1] (from corner i to corner i+1)
    for i in range(len(ring)):
        widths.append(max(s['w'] for s in street(ring[(i + 1) % len(ring)])))
    y = round(sum(ys) / len(ys), 2)
    for direction in (1, -1):
        p2 = pts if direction == 1 else list(reversed(pts))
        w2 = widths if direction == 1 else list(reversed(widths[:-1])) + [widths[-1]]
        if direction == -1:
            # reversed ring: edge i goes from corner n-1-i to n-2-i, i.e. along original edge n-2-i
            n = len(pts); w2 = [widths[(n - 2 - i) % n] for i in range(n)]
        off = offset_ring(p2, [w * 0.17 for w in w2])
        # make sure the offset went to the right: the ring must get bigger for a clockwise ring etc. Sanity check:
        # every offset corner must stay within 30 studs of its source corner
        assert all(dist(a, b) < 30 for a, b in zip(off, p2)), ring
        # add mid-edge points so long edges still sample well, flag the corners
        dense, corners = [], []
        for i in range(len(off)):
            a, b = off[i], off[(i + 1) % len(off)]
            dense.append(a); corners.append(len(dense))
            L = dist(a, b)
            k = int(L // 60)
            for j in range(1, k + 1):
                f = j / (k + 1)
                dense.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
        lanes.append(dict(y=y, pts=dense, corners=corners, ring=ring))

# ------------------------------------------------------------------ sidewalks -> walks
walks = []
side = [dict(x=a[0], y=a[1], z=a[2], w=a[3], L=a[4], yaw=a[5]) for a in roads['S']]
for s in side:
    r = math.radians(s['yaw']); dx, dz = math.sin(r), math.cos(r)
    rx, rz = -dz, dx
    # curb side = towards the nearest asphalt centre line
    best = min(strips, key=lambda t: dist((t['x'], t['z']), (s['x'], s['z'])))
    sgn = 1 if (best['x'] - s['x']) * rx + (best['z'] - s['z']) * rz > 0 else -1
    off = max(0.0, s['w'] / 2 - 2.75) * sgn
    cx, cz = s['x'] + rx * off, s['z'] + rz * off
    half = s['L'] / 2 - 3
    if half < 8: continue
    a = (cx - dx * half, cz - dz * half); b = (cx + dx * half, cz + dz * half)
    walks.append(dict(y=s['y'], pts=[a, b], d=dist(((a[0]+b[0])/2, (a[1]+b[1])/2), SPAWN)))
walks.sort(key=lambda w: w['d'])

# ------------------------------------------------------------------ spots
spots = []  # (kind, x, y, z, yawDeg, n, pose)
def yaw_of(nx, nz):  # yaw so that the spot's LookVector = (nx, nz): look = -Z rotated -> (-sin, -cos)
    return math.degrees(math.atan2(-nx, -nz))
def add(kind, x, y, z, nx, nz, n=None, pose=None):
    spots.append([kind, round(x, 1), round(y, 2), round(z, 1), round(yaw_of(nx, nz), 1), n, pose])

lamps = [l for l in roads['L']]
# corners: the 4 sidewalk corners of every crossing on the loops (plus a few side streets)
crossings = set()
for ring in LOOPS:
    for i in range(len(ring)):
        crossings.add(tuple(sorted((ring[i], ring[(i + 1) % len(ring)]))))
crossings |= {('Liberty Blvd', 'NW 58 Alley'), ('NW 10 Ave', 'NW 58 Alley'), ('Liberty Blvd', 'NW 66 Alley')}
corner_pts = []
for a, b in sorted(crossings):
    try:
        p, s, t = corner(a, b)
    except SystemExit:
        continue
    for sa in (-1, 1):
        for sb in (-1, 1):
            # step out along each street's cross axis: half the other street's width + 6 lands on the corner sidewalk
            ox = -s['dz'] * sa * (s['w'] / 2 + 6) + -t['dz'] * sb * (t['w'] / 2 + 6)
            oz = s['dx'] * sa * (s['w'] / 2 + 6) + t['dx'] * sb * (t['w'] / 2 + 6)
            corner_pts.append((p[0] + ox, p[1] + oz, (s['y'] + t['y']) / 2 + 0.6, p))
rng.shuffle(corner_pts)
for i, (x, z, y, p) in enumerate(corner_pts):
    if i % 3 == 0:
        add('Corner', x, y, z, p[0] - x, p[1] - z, rng.randint(2, 4))
    elif i % 3 == 1:
        add('Lean', x, y, z, p[0] - x, p[1] - z, None, 'Lean')
# under street lights (the night crowd): one Lean per lamp near spawn, 2 studs off the pole
for l in sorted(lamps, key=lambda l: dist((l[0], l[2]), SPAWN))[:40]:
    near = min(strips, key=lambda t: dist((t['x'], t['z']), (l[0], l[2])))
    nx, nz = near['x'] - l[0], near['z'] - l[2]
    m = math.hypot(nx, nz) or 1
    # stand on the building side of the pole, facing the street
    add('Lean', l[0] - nx / m * 2, 2.9, l[2] - nz / m * 2, nx, nz, None, rng.choice(['Lean', 'Phone', 'Cross']))

HOMES = {'House', 'Apartments', 'AbandonedHouse', 'MidRise'}
ac_spots, win_all = [], []
for b in buildings:
    yaw = math.radians(b['yaw'])
    fx, fz = -math.sin(yaw), -math.cos(yaw)  # footprint front (-Z of the pivot frame)
    c = (b['x'], b['z'])
    for dx_, dy_, dz_ in b['doors']:
        ox, oz = dx_ - c[0], dz_ - c[1]
        if ox * fx + oz * fz <= 0: continue  # back doors stay quiet
        if b['name'] in HOMES:
            # sit on the stoop: one step out from the door, facing the street
            add('Stoop', dx_ + fx * 2.0, dy_ - 1.2, dz_ + fz * 2.0, fx, fz, None, rng.choice(['Sit', 'SitPhone', 'SitSlump']))
        elif b['name'] == 'Shops' and not any(sp[0] == 'Lean' and dist((sp[1], sp[3]), (dx_, dz_)) < 12 for sp in spots):
            tx, tz = -fz, fx
            sgn = rng.choice([-1, 1])
            add('Lean', dx_ + fx * 1.4 + tx * 3.2 * sgn, dy_, dz_ + fz * 1.4 + tz * 3.2 * sgn, fx, fz, None, rng.choice(['Lean', 'Phone']))
    if b['name'] in HOMES and not b['doors'] and b['win']:
        # no door parts on homes: the stoop sits at the middle of the facade (plane of the front windows)
        front = [w for w in b['win'] if (w[0] - c[0]) * fx + (w[2] - c[1]) * fz > 2]
        if front:
            depth = max((w[0] - c[0]) * fx + (w[2] - c[1]) * fz for w in front)
            low = min(w[1] - w[5] / 2 for w in front)
            # the ground floor's sill is ~3 studs over the floor; sit one step below the floor line
            floor = min(b['y'], low - 3)
            sx, sz = c[0] + fx * (depth + 2.2), c[1] + fz * (depth + 2.2)
            add('Stoop', sx, floor, sz, fx, fz, None, rng.choice(['Sit', 'SitPhone', 'SitSlump']))
    for a in (b.get('ac') or [])[:1]:
        ac_spots.append(a)
    if b['name'] in HOMES or b['name'] == 'Shops':
        for w in b['win']:
            win_all.append((w, b['name']))

for a in sorted(ac_spots, key=lambda a: dist((a[0], a[2]), SPAWN))[:24]:
    add('AC', a[0], a[1], a[2], 0, -1)

# window radios: 10 home windows near spawn, at least 45 studs apart
radios = []
for w, kind in sorted(win_all, key=lambda t: dist((t[0][0], t[0][2]), SPAWN)):
    if kind in HOMES and w[1] < 30 and all(dist((w[0], w[2]), (r[0], r[2])) > 45 for r in radios):
        radios.append(w)
    if len(radios) >= 10: break
# where players spend their first minutes: always a radio within ~40 studs of spawn and of the Food Mart door
# (no hood window is that close: the radio then sits on the nearest building's wall facing the spot, and the Food Mart
# gets a store radio just inside its door)
extra = [('Window', -1442.0, 7.0, -318.0, 0, 1)]  # Food Mart store radio
for target in (SPAWN,):
    if not any(dist((w[0], w[2]), target) < 40 for w in radios):
        near = [w for w, _ in win_all if dist((w[0], w[2]), target) < 45]
        if near:
            radios.insert(0, min(near, key=lambda w: dist((w[0], w[2]), target)))
        else:
            b = min(buildings, key=lambda b: dist((b['x'], b['z']), target))
            dx, dz = target[0] - b['x'], target[1] - b['z']
            m = math.hypot(dx, dz) or 1
            # 30 studs from the spot toward that building: the music drifts over from the block
            extra.append(('Window', target[0] - dx / m * 30, b['y'] + 6, target[1] - dz / m * 30, dx / m, dz / m))
for k, x, y, z, nx, nz in extra:
    add(k, x, y, z, nx, nz)
for w in radios:
    r = math.radians(w[3])
    add('Window', w[0], w[1], w[2], math.sin(r), math.cos(r))

# pigeons: shop fronts near spawn (Food Mart, Burger Shack...), Liberty Park, a few street trees
pig = [(-1442, 3, -322), (-1442, 3, -452), (-1580, 3, -200), (-1015, 3, -452)]
plants = sorted(roads['Plants'], key=lambda p: dist((p[0], p[2]), SPAWN))
for p in plants[:40:4]:
    pig.append((p[0] + 3, p[1] if p[1] > 1 else 2.9, p[2] + 3))
for x, y, z in pig:
    add('Pigeons', x, 2.9 if y < 4 else y, z, 0, -1)

# gulls over the canal; zones: canal, alleys, the underpass meet spot
add('Gulls', -1162, 0.4, -420, 0, -1)
zones = []
for cname, cx, cy, cz, sx, sz in misc['canal']:
    for k in (-1, 0, 1):
        zones.append(['Canal', cx, cy + 2, cz + k * sz / 3, 30])
for s in strips:
    if 'Alley' in s['name'] and s['L'] > 20:
        n = max(1, int(s['L'] // 40))
        for j in range(n):
            f = (j + 0.5) / n - 0.5
            zones.append(['Alley', s['x'] + s['dx'] * s['L'] * f, s['y'], s['z'] + s['dz'] * s['L'] * f, 13])
zones.insert(0, ['Underpass', -1176, -6, -540, 26])

# power-line spans between neighbouring poles on the same street (DressHoodLife strings wires on them)
poles = roads['P']
spans, used = [], set()
for i, a in enumerate(poles):
    for j, b in enumerate(poles):
        if j <= i: continue
        d = dist((a[0], a[2]), (b[0], b[2]))
        if 45 < d < 95 and abs(((a[3] - b[3]) + 180) % 360 - 180) < 6:
            # the span must run along the pole line's street (roughly parallel to a nearby strip)
            spans.append((a, b, d))
spans.sort(key=lambda s: dist(((s[0][0] + s[1][0]) / 2, (s[0][2] + s[1][2]) / 2), SPAWN))
wire_spans = []
for a, b, d in spans:
    key_a, key_b = tuple(a[:3]), tuple(b[:3])
    if key_a in used and key_b in used: continue
    wire_spans.append([round(v, 1) for v in (a[0], a[1] - 2.6, a[2], b[0], b[1] - 2.6, b[2])])
    used.add(key_a); used.add(key_b)
    if len(wire_spans) >= 40: break
for s in wire_spans[:24]:
    mx, my, mz = (s[0] + s[3]) / 2, (s[1] + s[4]) / 2 - 1.2, (s[2] + s[5]) / 2  # the sag
    add('Wire', mx, my, mz, s[3] - s[0], s[5] - s[2])

# DressHoodLife's own seats (vignettes) + sound spots
if dress:
    for s in dress.get('spots', []):
        s = list(s) + [None] * (7 - len(s))
        s[5] = s[5] or None
        s[6] = s[6] or None
        spots.append(s[:7])

# night windows: the 600 closest to spawn
win_all.sort(key=lambda t: dist((t[0][0], t[0][2]), SPAWN))
windows = [w for w, _ in win_all[:600]]

# ------------------------------------------------------------------ write Luau
def num(v):
    if v is None: return 'nil'
    if isinstance(v, str): return json.dumps(v)
    r = round(v, 2)
    return str(int(r)) if r == int(r) else str(r)
def arr(a): return '{ ' + ', '.join(num(v) for v in a) + ' }'
def pts(ps): return '{ ' + ', '.join('{ %s, %s }' % (num(p[0]), num(p[1])) for p in ps) + ' }'

L = []
L.append('--!strict')
L.append('-- GENERATED by tools/build_ambient_map.py from the survey (tools/SurveyHoodLife.lua). Do not edit by hand:')
L.append('-- change the survey or the builder and re-run it. Positions only (StreamingEnabled-safe). North = -Z, street y = 2.')
L.append('--   Lanes   closed loops of lane centre points {x, z} (right-hand traffic); corners = indices of turning points')
L.append('--   Walks   sidewalk lines 2.75 studs in from the curb')
L.append('--   Spots   { kind, x, y, z, yawDeg, n?, pose? }  kinds: Stoop Corner Lean Bench Vignette:<id> Pigeons Window')
L.append('--           (music) Wire (perch) Gulls AC Dog Ball Grill')
L.append('--   Windows { x, y, z, yawDeg, width, height }  outer face of the glass, facing out (night glow)')
L.append('--   Lamps   street light positions   Zones { kind, x, y, z, radius }   Spans power-line spans (DressHoodLife)')
L.append('return {')
L.append('\tLanes = {')
for l in lanes:
    L.append('\t\t{ y = %s, loop = true, corners = %s, pts = %s }, -- %s' % (num(l['y']), arr(l['corners']), pts(l['pts']), ' / '.join(l['ring'])))
L.append('\t},')
L.append('\tWalks = {')
for w in walks:
    L.append('\t\t{ y = %s, pts = %s },' % (num(w['y']), pts(w['pts'])))
L.append('\t},')
L.append('\tSpots = {')
for s in spots:
    L.append('\t\t%s,' % arr(s))
L.append('\t},')
L.append('\tWindows = {')
for i in range(0, len(windows), 4):
    L.append('\t\t' + ' '.join(arr(w) + ',' for w in windows[i:i + 4]))
L.append('\t},')
L.append('\tLamps = {')
for i in range(0, len(lamps), 6):
    L.append('\t\t' + ' '.join(arr(l) + ',' for l in lamps[i:i + 6]))
L.append('\t},')
L.append('\tZones = {')
for z in zones:
    L.append('\t\t%s,' % arr(z))
L.append('\t},')
L.append('\tSpans = {')
for s in wire_spans:
    L.append('\t\t%s,' % arr(s))
L.append('\t},')
L.append('}')
open(OUT, 'w', encoding='utf-8').write('\n'.join(L) + '\n')
from collections import Counter
print(OUT)
print('lanes', len(lanes), 'walks', len(walks), 'spots', len(spots), dict(Counter(s[0] for s in spots)), 'windows', len(windows),
      'lamps', len(lamps), 'zones', len(zones), 'spans', len(wire_spans))
