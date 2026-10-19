# Bakes the plain-part stand-ins of the knives of the owner's files of several (the 5 Game Pass knives of
# design/knives/gamepass/Gamepass_Knives.glb and the 18 of design/knives/halloween/Halloween_Knives.glb) into
# src/ReplicatedStorage/Shared/KnifeStandInParts/<Key>.lua, one small module a knife, listed by
# src/ReplicatedStorage/Shared/KnifeStandIns.lua (owner, Oct 19, his Studio screenshot of the
# lobby stands: the hand-made stand-ins, "an orange blocky jagged blade" and "a small cyan stub", were nothing like
# his model; they show whenever his model can't be drawn: before his import, and wherever Roblox's EditableMesh is
# off, see Gameplay/KnifeDress).
# How: his knife is cut across its length into thin slices (SLICE studs). In each slice, each look of his (colour,
# glow, material: one group per look, as tools/knives/bake_pass_meshes.py) covers one or more stretches across the
# blade's width (Z): each stretch becomes one block, as thick (X) as his triangles there. Slices that hardly change
# are joined into one taller block. So the outline follows his: the moon hole, the jagged teeth, the crystal spikes,
# the feathers, each in his colour and the Roblox material nearest his (Shared/KnifeLook.glbMaterial). Where a
# smaller look lies over a bigger one (an outline plate under the blade, a gem on the guard), the smaller one is
# drawn a hair thicker (OVER for each bigger look it lies over), so it shows on top as on his model instead of
# flickering in the same place.
# Each knife: { trail = { base y, tip y }, parts = { { name, size x, y, z, centre x, y, z, col (rrggbb), material
# (Enum.Material name), refl }, ... } } in the Handle's space (studs; the same frame as bake_pass_meshes.py), short
# rows so the file stays small. The Handle (the first row) is a tiny hidden block at the grip's middle; the biggest
# blade block is "Blade" (the trail points ride on it).
# Usage (from huzz-valley/): python3 -I tools/knives/bake_stand_ins.py
import collections, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import glb
from bake_knives import sheet_knives
from bake_pass_meshes import glb_material

OUT = 'src/ReplicatedStorage/Shared/KnifeStandIns.lua'  # the list
DIR = 'src/ReplicatedStorage/Shared/KnifeStandInParts'  # one module a knife
MAX_FILE = 60000  # bytes a module
SLICE = 0.04      # studs per slice along the knife
GAP = 0.02        # stretches closer than this across the width are one
JOIN = 0.012      # slices whose stretches move less than this are joined (more and a slanted line or tooth grows fat)
MIN = 0.02        # thinnest block side (studs)
OVER = 0.004     # studs a smaller look sits proud of each bigger look it lies over, each side (at most 3 deep)
DANGLES = ('tassel', 'chain', 'cloth', 'rope', 'charm')  # hanging bits (Shared/KnifeLook.shape leaves them out of
# pommel to tip): their blocks are named Tassel<n>


def clip(tri, y0, y1):
    """The triangle's part between y0 and y1 (a polygon, its points), or []."""
    poly = list(tri)
    for lo, sign in ((y0, 1), (y1, -1)):
        out = []
        for i in range(len(poly)):
            a, b = poly[i], poly[(i + 1) % len(poly)]
            da, db = sign * (a[1] - lo), sign * (b[1] - lo)
            if da >= 0:
                out.append(a)
            if (da >= 0) != (db >= 0):
                t = da / (da - db)
                out.append(a + (b - a) * t)
        poly = out
        if not poly:
            return []
    return poly


def stretches(items):
    """items: (zlo, zhi, xlo, xhi); joined where they overlap or nearly touch."""
    items.sort()
    out = []
    for z0, z1, x0, x1 in items:
        if out and z0 <= out[-1][1] + GAP:
            o = out[-1]
            out[-1] = [o[0], max(o[1], z1), min(o[2], x0), max(o[3], x1)]
        else:
            out.append([z0, z1, x0, x1])
    return out


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
        ylo = min(t[:, :, 1].min() for g in groups.values() for t in g)
        yhi = max(t[:, :, 1].max() for g in groups.values() for t in g)
        n = int(np.ceil((yhi - ylo) / SLICE))
        parts = []
        blocks = []  # (look, its blocks)
        for (col, glow, blade, mat, refl, dangle), tris in groups.items():
            tris = np.concatenate(tris)
            rows = [[] for _ in range(n)]
            tmin, tmax = tris[:, :, 1].min(1), tris[:, :, 1].max(1)
            for t, a, b in zip(tris, tmin, tmax):
                for s in range(max(0, int((a - ylo) / SLICE)), min(n, int((b - ylo) / SLICE) + 1)):
                    y0 = ylo + s * SLICE
                    poly = clip(t, y0, y0 + SLICE)
                    if poly:
                        q = np.array(poly)
                        rows[s].append((q[:, 2].min(), q[:, 2].max(), q[:, 0].min(), q[:, 0].max()))
            # one block per stretch, joined up the knife while it hardly changes
            open_ = []  # [y0, y1, z0, z1, x0, x1]
            done = []
            for s in range(n):
                y0 = ylo + s * SLICE
                now = stretches(rows[s])
                nxt = []
                used = set()
                for st in now:
                    hit = None
                    for i, o in enumerate(open_):
                        if i not in used and abs(o[2] - st[0]) < JOIN and abs(o[3] - st[1]) < JOIN and o[1] >= y0 - 1e-9:
                            hit = i
                            break
                    if hit is not None:
                        used.add(hit)
                        o = open_[hit]
                        nxt.append([o[0], y0 + SLICE, min(o[2], st[0]), max(o[3], st[1]), min(o[4], st[2]), max(o[5], st[3])])
                    else:
                        nxt.append([y0, y0 + SLICE, st[0], st[1], st[2], st[3]])
                for i, o in enumerate(open_):
                    if i not in used:
                        done.append(o)
                open_ = nxt
            done += open_
            blocks.append(((col, glow, blade, mat, refl, dangle), done))
        area = {i: sum((b[1] - b[0]) * (b[3] - b[2]) for b in bl) for i, (_, bl) in enumerate(blocks)}

        def over(a, b):
            return a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3] and a[4] < b[5] and b[4] < a[5]
        for i, ((col, glow, blade, mat, refl, dangle), done) in enumerate(blocks):
            bigger = [j for j in area if area[j] > area[i] or (area[j] == area[i] and j < i)]
            for y0, y1, z0, z1, x0, x1 in done:
                b = (y0, y1, z0, z1, x0, x1)
                depth = min(3, sum(1 for j in bigger if any(over(b, c) for c in blocks[j][1])))
                x0, x1 = x0 - OVER * depth, x1 + OVER * depth
                size = [max(x1 - x0, MIN), max(y1 - y0, MIN), max(z1 - z0, MIN)]
                at = [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2]
                parts.append({'blade': blade, 'glow': glow, 'dangle': dangle, 'size': size, 'at': at, 'col': col, 'mat': mat, 'refl': refl})
        # names: the biggest blade block is "Blade" (the trail points ride on it), other blade blocks Blade<n>, the rest Part<n>
        blades = [p for p in parts if p['blade'] and not p['glow']] or [p for p in parts if p['blade']]
        big = max(blades, key=lambda p: p['size'][0] * p['size'][1] * p['size'][2]) if blades else None
        nb = np_ = nd = 0
        out = ['\t\t{ "Handle", 0.1, 0.1, 0.1, 0, 0, 0, "202020", "SmoothPlastic", 0 },']
        for p in parts:
            if p is big:
                name = 'Blade'
            elif p['dangle']:
                nd += 1
                name = 'Tassel%d' % nd
            elif p['blade']:
                nb += 1
                name = 'Blade%d' % nb
            else:
                np_ += 1
                name = 'Part%d' % np_
            out.append('\t\t{ "%s", %g, %g, %g, %g, %g, %g, "%s", "%s", %g },' % (
                name, *[round(v, 3) for v in p['size']], *[round(v, 3) + 0.0 for v in p['at']], p['col'], p['mat'], p['refl']))
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
        print('%-18s %d looks, %d blocks (%d slices), %d KB' % (k['key'], len(groups), len(parts), n, size // 1024))
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
