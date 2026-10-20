# Bakes the plain-part stand-ins of the knives of the owner's files of several (the 5 Game Pass knives of
# design/knives/gamepass/Gamepass_Knives.glb and the 18 of design/knives/halloween/Halloween_Knives.glb) into
# src/ReplicatedStorage/Shared/KnifeStandInParts/<Key>.lua, one small module a knife, listed by
# src/ReplicatedStorage/Shared/KnifeStandIns.lua (owner, Oct 19, his Studio screenshot of the
# lobby stands: the hand-made stand-ins, "an orange blocky jagged blade" and "a small cyan stub", were nothing like
# his model; they show whenever his model can't be drawn: before his import, and wherever Roblox's EditableMesh is
# off, see Gameplay/KnifeDress).
# How (Oct 20, owner: "please fix the knifes finally, they are still missing pixels, and please just make them be
# normal"; his screenshots design/owner-oct19/2010-knife-*.png showed these stand-ins, and the old cut, thin slices
# of blocks, read as scattered bits: stepped edges, feathers in loose strips, gaps between slices): each look of his
# (colour, glow, material: one group per look, as tools/knives/bake_pass_meshes.py) is seen from the side (the
# blade's broad face, the Handle's Y and Z), its outline filled solid (his triangles merged, hairline seams closed),
# smoothed only as much as the part budget needs (SIMPLIFY steps, at most MAX_PARTS), and cut into triangles. Each
# triangle is two WedgeParts (a wedge is half a block, cut corner to corner, so two make any triangle) turned about
# the blade's thin axis; an outline that is a plain rectangle is one block. Each separate piece is as thick (X) as his
# triangles there. So the outline is his: the moon hole, the teeth, the spikes, the feathers, solid, with smooth
# slanted edges and nothing loose round it, in his colour and the Roblox material nearest his
# (Shared/KnifeLook.glbMaterial). Where a smaller piece lies over a bigger one (a gem on the guard, an inlay on the
# blade), the smaller one is drawn thicker (OVER, 0.02 studs each side for each bigger piece it lies over), so it shows on top as on
# his model instead of flickering in the same place. Seen edge on, a stand-in is flat slabs (his model is rounder):
# the broad side is what shows in a hand, on a back and on a stand.
# Each knife: { trail = { base y, tip y }, parts = { { name, size x, y, z, centre x, y, z, col (rrggbb), material
# (Enum.Material name), refl[, turn about X in degrees[, "W" = a WedgePart]] }, ... } } in the Handle's space
# (studs; the same frame as bake_pass_meshes.py), short rows so the file stays small. The Handle (the first row) is
# a tiny hidden block at the grip's middle; the biggest blade piece is "Blade" (the trail points ride on it).
# Needs shapely 2.1+ (python3 -m pip install shapely). Usage (from huzz-valley/): python3 -I tools/knives/bake_stand_ins.py
import collections, json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import shapely
from shapely.geometry import Polygon, MultiPolygon
import glb
from bake_knives import sheet_knives
from bake_pass_meshes import glb_material

OUT = 'src/ReplicatedStorage/Shared/KnifeStandIns.lua'  # the list
DIR = 'src/ReplicatedStorage/Shared/KnifeStandInParts'  # one module a knife
MAX_FILE = 60000  # bytes a module
MAX_PARTS = 199   # parts a knife besides the Handle, aimed for
HARD_MAX = MAX_PARTS
CLOSE = 0.004     # studs: seams narrower than this inside one look are filled
# Each piece's steps from finest to plainest: (outline smoothing in studs, holes smaller than this many square studs
# filled). The budget coarsens the piece costing the most parts one step at a time (the gaps between his bandage
# wraps and his chain links go before the moon hole of Hollow Eclipse), until the knife fits MAX_PARTS.
LADDER = ((0.003, 0), (0.005, 0), (0.008, 0.0006), (0.012, 0.002), (0.017, 0.006), (0.024, 0.02), (0.033, 0.05),
          (0.045, 1e9), (0.06, 1e9), (0.09, 1e9))
KEEP_ROUND = 0.12  # a ring (a piece with a real cut-out) is never smoothed by more than this share of its narrow side
KEEP_HOLE = 0.04   # a hole of this share of its piece or more is a real cut-out: never filled
AMIN = 0.0008     # pieces smaller than this (square studs) are left out
MIN = 0.02        # thinnest piece (studs)
OVER = 0.02       # studs a smaller piece sits proud of each bigger piece it lies over, each side (at most 3 deep;
                  # 0.02 and not less: Roblox flickers between faces closer than about that, seen from across a room)
SQUARE = 0.97     # an outline filling this much of its tightest rectangle is one block
DANGLES = ('tassel', 'chain', 'cloth', 'rope', 'charm')  # hanging bits (Shared/KnifeLook.shape leaves them out of
# pommel to tip): their parts are named Tassel<n>


def polys(g):
    if isinstance(g, Polygon):
        return [g] if not g.is_empty else []
    if isinstance(g, MultiPolygon):
        return list(g.geoms)
    return [x for x in getattr(g, 'geoms', []) if isinstance(x, Polygon)]


def pieces_of(tris):
    """One look's triangles (n, 3, 3 in x, y, z) -> [(outline polygon in (y, z), x0, x1)], one per separate piece."""
    flat = []
    for t in tris:
        q = t[:, 1:3]
        if abs((q[1, 0] - q[0, 0]) * (q[2, 1] - q[0, 1]) - (q[2, 0] - q[0, 0]) * (q[1, 1] - q[0, 1])) > 1e-9:
            flat.append(Polygon(q))
    if not flat:
        return []
    shape = shapely.unary_union(flat).buffer(CLOSE, join_style='mitre').buffer(-CLOSE, join_style='mitre')
    cy = tris[:, :, 1].mean(1)
    cz = tris[:, :, 2].mean(1)
    xlo, xhi = tris[:, :, 0].min(1), tris[:, :, 0].max(1)
    out = []
    for p in polys(shape):
        if p.area < AMIN:
            continue
        inside = shapely.contains_xy(p.buffer(CLOSE), cy, cz)
        if not inside.any():
            continue
        out.append((p, float(xlo[inside].min()), float(xhi[inside].max())))
    return out


def turn(uy, uz):
    return math.degrees(math.atan2(uz, uy))


def block_of(p):
    """A rectangle-like outline -> (size y, size z, centre y, z, turn) of one block, or None."""
    if p.interiors:
        return None
    r = p.minimum_rotated_rectangle
    if r.area <= 0 or p.area / r.area < SQUARE:
        return None
    c = np.array(r.exterior.coords)[:4]
    e1, e2 = c[1] - c[0], c[2] - c[1]
    l1, l2 = np.linalg.norm(e1), np.linalg.norm(e2)
    if min(l1, l2) < 1e-4:
        return None
    u = e1 / l1  # the block's Y; its Z is u turned a quarter (so X = Y x Z stays the Handle's +X)
    m = c.mean(0)
    return l1, l2, m[0], m[1], turn(u[0], u[1])


def wedges_of(tri):
    """A triangle in (y, z) -> up to two right triangles as wedges: (size y, size z, centre y, z, turn)."""
    a, b, c = [np.array(v, dtype=float) for v in tri]
    pts = [a, b, c]
    edges = [(np.linalg.norm(pts[(i + 1) % 3] - pts[(i + 2) % 3]), i) for i in range(3)]
    _, i = max(edges)
    p, e0, e1 = pts[i], pts[(i + 1) % 3], pts[(i + 2) % 3]
    d = e1 - e0
    t = np.dot(p - e0, d) / np.dot(d, d)
    f = e0 + d * t  # the foot of the height: both halves have their square corner there
    out = []
    for e in (e0, e1):
        py, pz = p, e  # first try: the height is the wedge's Y leg, the edge piece its Z leg
        u, v = py - f, f - pz
        lu, lv = np.linalg.norm(u), np.linalg.norm(v)
        if lu < 1e-4 or lv < 1e-4:
            continue
        u, v = u / lu, v / lv
        if u[0] * v[1] - u[1] * v[0] < 0:  # wrong hand: swap the legs
            py, pz = e, p
            u, v = py - f, f - pz
            lu, lv = np.linalg.norm(u), np.linalg.norm(v)
            u, v = u / lu, v / lv
        m = f + (py - f) / 2 + (pz - f) / 2
        out.append((lu, lv, m[0], m[1], turn(u[0], u[1])))
    return out


def allowed(p, step, dangle):
    """Whether a piece may go to this LADDER step. A piece with a real cut-out (a hole of KEEP_HOLE of it or more:
    Hollow Eclipse's moon, Celestial Seraph's halo, a gem's bezel) is a ring: it is never smoothed by more than
    KEEP_ROUND of its narrow side, so it stays round instead of turning into a diamond; outline() never fills such a
    hole. Everything else may go as smooth as the budget needs; hanging bits (chains, tassels) may go plain."""
    if dangle or step == 0:
        return True
    outer = Polygon(p.exterior).area
    if not any(Polygon(r).area >= KEEP_HOLE * outer for r in p.interiors):
        return True
    x0, y0, x1, y1 = p.bounds
    return LADDER[step][0] <= KEEP_ROUND * min(x1 - x0, y1 - y0)


def outline(p, step, dangle=False):
    """A piece's outline at a LADDER step: [polygons]."""
    tol, hole = LADDER[step]
    if hole and p.interiors:
        outer = Polygon(p.exterior).area
        p = Polygon(p.exterior, [r for r in p.interiors if Polygon(r).area >= hole or (not dangle and Polygon(r).area >= KEEP_HOLE * outer)])
    q = p.simplify(tol, preserve_topology=True)
    if not q.is_valid:
        q = q.buffer(0)
    return [qq for qq in polys(q) if qq.area >= AMIN]


def cost(qs):
    return sum(1 if block_of(q) else 2 * len(shapely.constrained_delaunay_triangles(q).geoms) for q in qs)


def build(looks):
    """looks: [(look, [(polygon, x0, x1)])] -> (parts, the coarsest step used), within MAX_PARTS."""
    pieces = [[look, p, x0, x1, 0] for look, ps in looks for p, x0, x1 in ps]
    cache = {}

    def at(i, step):
        if (i, step) not in cache:
            qs = outline(pieces[i][1], step, pieces[i][0][5])
            cache[(i, step)] = (qs, cost(qs))
        return cache[(i, step)]
    while sum(at(i, r[4])[1] for i, r in enumerate(pieces) if r[4] >= 0) > MAX_PARTS:
        can = [i for i, r in enumerate(pieces) if 0 <= r[4] < len(LADDER) - 1 and allowed(r[1], r[4] + 1, r[0][5])]
        if not can:  # nothing left to smooth within the keep rules: the smallest piece that isn't blade goes
            rest = [i for i, r in enumerate(pieces) if not r[0][2] and r[4] >= 0]
            if not rest:
                break
            pieces[min(rest, key=lambda i: pieces[i][1].area)][4] = -1
            continue
        i = max(can, key=lambda i: at(i, pieces[i][4])[1] - at(i, pieces[i][4] + 1)[1] + 1e-3 * at(i, pieces[i][4])[1])
        pieces[i][4] += 1
    flat = [(r[0], q, r[2], r[3]) for i, r in enumerate(pieces) if r[4] >= 0 for q in at(i, r[4])[0]]
    flat.sort(key=lambda r: -r[1].area)
    parts = []
    for i, (look, q, x0, x1) in enumerate(flat):
        depth = 0
        for look2, q2, a0, a1 in flat[:i]:
            if a0 < x1 and x0 < a1 and q.intersects(q2) and q.intersection(q2).area > 1e-6:
                depth += 1
        depth = min(3, depth)
        x0, x1 = x0 - OVER * depth, x1 + OVER * depth
        sx, cx = max(x1 - x0, MIN), (x0 + x1) / 2
        b = block_of(q)
        if b:
            parts.append(dict(look=look, kind='B', size=(sx, max(b[0], MIN), max(b[1], MIN)), at=(cx, b[2], b[3]), rx=b[4], area=q.area))
            continue
        for t in shapely.constrained_delaunay_triangles(q).geoms:
            for w in wedges_of(np.array(t.exterior.coords)[:3]):
                parts.append(dict(look=look, kind='W', size=(sx, w[0], w[1]), at=(cx, w[2], w[3]), rx=w[4], area=w[0] * w[1] / 2))
    return parts, max((r[4] for r in pieces), default=0)


def main():
    knives = {k['node']: k for k in json.load(open('tools/knives/knives.json')) if '/' in k['file']}
    os.makedirs(DIR, exist_ok=True)
    for f in os.listdir(DIR):
        if f.endswith('.lua'):
            os.remove(os.path.join(DIR, f))
    keys = []
    for node_name, prims, inv, js, binc in sheet_knives():
        k = knives.get(node_name)
        if not k:
            continue
        per = k['studs'] / k['length']
        groups = collections.OrderedDict()
        for p in prims:
            m = inv @ p['matrix']
            pos = (np.c_[p['local'], np.ones(len(p['local']))] @ m.T)[:, :3]
            h = np.c_[pos[:, 2], pos[:, 1] - k['grip'], -pos[:, 0]] * per
            col = glb.texture_colour(js, binc, p['material'].get('texture')) or 'cccccc'
            glow = p['material']['name'].startswith('glow')
            blade = 'blade' in p['node'].lower().split('_')  # (blade_0, glow_blade_0: the reapers' blades glow)
            dangle = any(d in p['node'].lower() for d in DANGLES)
            mat, refl = glb_material(round(float(p['material']['metal']), 2), round(float(p['material']['rough']), 2), glow)
            g = groups.setdefault((col, glow, blade, mat, refl, dangle), [])
            g.append(h[p['idx']])  # (triangles, 3, 3)
        looks = [(look, pieces_of(np.concatenate(tris))) for look, tris in groups.items()]
        parts, step = build(looks)
        assert len(parts) <= HARD_MAX, (k['key'], len(parts))
        # names: the biggest blade piece is "Blade" (the trail points ride on it), other blade pieces Blade<n>, the rest Part<n>
        blades = [p for p in parts if p['look'][2] and not p['look'][1]] or [p for p in parts if p['look'][2]]
        big = max(blades, key=lambda p: p['area']) if blades else None
        nb = np_ = nd = 0
        out = ['\t\t{ "Handle", 0.1, 0.1, 0.1, 0, 0, 0, "202020", "SmoothPlastic", 0 },']
        for p in parts:
            col, glow, blade, mat, refl, dangle = p['look']
            if p is big:
                name = 'Blade'
            elif dangle:
                nd += 1
                name = 'Tassel%d' % nd
            elif blade:
                nb += 1
                name = 'Blade%d' % nb
            else:
                np_ += 1
                name = 'Part%d' % np_
            row = '{ "%s", %g, %g, %g, %g, %g, %g, "%s", "%s", %g' % (
                name, *[round(v, 3) for v in p['size']], *[round(v, 3) + 0.0 for v in p['at']], col, mat, refl)
            rx = round(p['rx'], 1) + 0.0
            if p['kind'] == 'W':
                row += ', %g, "W"' % rx
            elif rx != 0:
                row += ', %g' % rx
            out.append('\t\t' + row + ' },')
        trail = ((0 - k['grip']) * per, (k['tip'] - k['grip']) * per)
        lines = ["-- GENERATED by tools/knives/bake_stand_ins.py from design/knives/%s.glb: don't edit." % k['file'],
                 "-- The plain-part stand-in of %s, cut from the owner's own model (format in that tool)." % k['name'],
                 'return { trail = { %.3f, %.3f }, parts = {' % trail]
        lines += [l[1:] for l in out]
        lines.append('} }')
        path = os.path.join(DIR, k['key'] + '.lua')
        open(path, 'w').write('\n'.join(lines) + '\n')
        size = os.path.getsize(path)
        assert size < MAX_FILE, (path, size)
        keys.append(k['key'])
        print('%-18s %d looks, %d parts (%d wedges, plainest piece: smoothing %.3f, holes under %g filled), %d KB' % (
            k['key'], len(groups), len(parts), sum(1 for p in parts if p['kind'] == 'W'), *LADDER[step], size // 1024))
    index = ["-- GENERATED by tools/knives/bake_stand_ins.py: don't edit.",
             "-- The plain-part stand-ins of the knives of the owner's files of several (the 5 Game Pass knives, his 18",
             "-- Halloween knives), cut from his own models: one module a knife in Shared/KnifeStandInParts (format in that",
             "-- tool; Shared/KnifeShapes hands them to HuzzServer/KnifeService.buildRecipe).",
             "local KEYS = {",
             ] + ['\t"%s",' % key for key in keys] + [
             "}",
             "local folder = script.Parent:WaitForChild(\"KnifeStandInParts\")",
             "local list = {}",
             "for _, key in KEYS do",
             "\tlist[key] = require(folder:FindFirstChild(key) or folder:WaitForChild(key))",
             "end",
             "return list"]
    open(OUT, 'w').write('\n'.join(index) + '\n')
    print('%s: %d knives, %d KB in all' % (DIR, len(keys), sum(os.path.getsize(os.path.join(DIR, f)) for f in os.listdir(DIR)) // 1024))


if __name__ == '__main__':
    main()
