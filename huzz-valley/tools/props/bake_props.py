# Bakes the owner's 5 lobby props (design/lobby/Lobby_Props.glb: Shop_Stall, Like_Reward_Gift, Pumpkin_Patch_Chest,
# Witch_Brew_Cauldron, Sweets_Treats_Coffin; owner Oct 18: "implementing these objects into the lobby on top of the
# already placed circles") with the knife pipeline's reader (tools/knives/glb.py) into:
#   tools/props/props.json                                  one line per prop: size, glow colour, part counts
#   src/ServerScriptService/HuzzServer/LobbyPropShapes.lua  the stand-in: each part of his model as a Roblox block,
#                                                           ball or cylinder in its own colour (glow parts Neon), so the
#                                                           pads show his props before he imports the real meshes
#   tools/props/setup_lobby_props.lua                       the Studio Command Bar helper (paste it whole)
#   src/ServerStorage/HuzzStudioTools/SetupLobbyProps.lua   the same, shipped in the place
#                                                           (run: require(game.ServerStorage.HuzzStudioTools.SetupLobbyProps)())
# Units: the .glb's own (the game scales each prop by Config/LobbyProps Scale). Each prop's origin is the middle of
# its footprint at its lowest point, +Y up, its front (+Z of the .glb) facing the plaza.
# What the stand-in can't keep: his stud textures (flat average colours instead), the SHOP / LIKE pictures on the
# sign and tag, and curved pieces that aren't a box, ball or cylinder (rings, chains, vines, bow loops are left out;
# the cauldron and the coffin's body are rounded off). The real meshes come with File > Import 3D in Studio.
# Usage (from huzz-valley/): python3 -I tools/props/bake_props.py
import io, json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'knives'))
import glb
import numpy as np

SRC = 'design/lobby/Lobby_Props.glb'
HERE = 'tools/props'
PICTURE_STD = 30  # a texture whose colours vary more than this is a picture (the SHOP sign, the LIKE tag)


def colour_of(js, binc, mat):
    """'rrggbb': the texture's average colour, or its most common colour for a picture; else the material colour."""
    tex = mat.get('texture')
    if tex is None:
        c = mat['color']
        return '%02x%02x%02x' % tuple(int(max(0, min(1, v)) * 255 + 0.5) for v in c[:3]), False
    from PIL import Image
    im = js['images'][js['textures'][tex]['source']]
    bv = js['bufferViews'][im['bufferView']]
    data = binc[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
    img = Image.open(io.BytesIO(data)).convert('RGB')
    a = np.asarray(img).reshape(-1, 3).astype(int)
    if a.std(0).mean() > PICTURE_STD:
        q = (a // 16) * 16 + 8
        vals, counts = np.unique(q, axis=0, return_counts=True)
        r, g, b = vals[counts.argmax()]
        return '%02x%02x%02x' % (r, g, b), True
    r, g, b = a.mean(0)
    return '%02x%02x%02x' % (int(r + 0.5), int(g + 0.5), int(b + 0.5)), False


def volume(lp, idx):
    v0, v1, v2 = lp[idx[:, 0]], lp[idx[:, 1]], lp[idx[:, 2]]
    return abs(np.einsum('ij,ij->i', v0, np.cross(v1, v2)).sum()) / 6


def shape_of(lp, idx):
    """B (block), S (ball: an ellipsoid), C (cylinder standing on its local Y), or None (leave it out)."""
    lo, hi = lp.min(0), lp.max(0)
    c, h = (lo + hi) / 2, np.maximum((hi - lo) / 2, 1e-6)
    q = (lp - c) / h
    a = np.abs(q)
    if np.all(np.isclose(a, 1, atol=0.03)):
        return 'B'
    r = np.sqrt((q ** 2).sum(1))
    if np.all(np.abs(r - 1) < 0.08):
        return 'S'
    for ax in range(3):
        o = [i for i in range(3) if i != ax]
        rr = np.sqrt((q[:, o] ** 2).sum(1))
        if np.all(np.isclose(a[:, ax], 1, atol=0.03)) and np.all((np.abs(rr - 1) < 0.08) | (rr < 0.05)):
            return 'C' + 'XYZ'[ax]
    # anything else: by how much of its box it fills (a box 1, a ball 0.52, rings, chains, vines and the stud
    # overlays far less: those are left out rather than drawn as a solid block)
    # (and anything with hundreds of points that isn't one of those: tendrils, the frosting trim, stud overlays)
    if len(lp) > 800:
        return None
    fill = volume(lp, idx) / max(1e-9, np.prod(hi - lo))
    if fill >= 0.62:
        return 'B'
    if fill >= 0.3:
        return 'S'
    # an open bowl (the cauldron's pot) fills little of its box but is chunky, not a thin ring or vine: a ball
    ext = hi - lo
    if fill >= 0.1 and ext.min() >= 0.3 * ext.max():
        return 'S'
    return None


def props():
    js, binc = glb.load(SRC)
    parent = {}
    for i, n, m, d, p in glb.walk(js):
        parent[i] = p
    root = js['scenes'][js.get('scene', 0)]['nodes'][0]
    prims = glb.meshes(js, binc)
    out = []
    for c in js['nodes'][root].get('children', []):
        def under(i, c=c):
            while i is not None:
                if i == c:
                    return True
                i = parent[i]
            return False
        mine = [p for p in prims if under(p['nodeIndex'])]
        allp = np.vstack([p['pos'] for p in mine])
        lo, hi = allp.min(0), allp.max(0)
        origin = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
        parts, glows, skipped, centres, seen = [], [], 0, [], set()
        for p in mine:
            lp, idx, m = p['local'], p['idx'], p['matrix']
            hexc, picture = colour_of(js, binc, p['material'])
            glow = p['material']['name'].startswith('glow')
            if glow:
                glows.append(hexc)
            centres.append({'name': p['node'], 'c': (p['matrix'] @ np.r_[(p['local'].min(0) + p['local'].max(0)) / 2, 1])[:3] - origin, 'hex': hexc, 'glow': glow, 'picture': picture})
            kind = shape_of(lp, idx)
            if kind is None and glow and len(lp) <= 64:
                kind = 'B'  # (the jack-o'-lanterns' little glowing eyes and mouths: a small Neon block each)
            if kind is None:
                skipped += 1
                continue
            llo, lhi = lp.min(0), lp.max(0)
            sc = np.linalg.norm(m[:3, :3], axis=0)
            R = m[:3, :3] / sc
            if np.linalg.det(R) < 0:
                R[:, 0] = -R[:, 0]
            size = (lhi - llo) * sc
            centre = (m @ np.r_[(llo + lhi) / 2, 1])[:3] - origin
            if kind.startswith('C'):
                # Roblox's Cylinder is round along its X: turn the part so its X is the mesh's axis
                ax = 'XYZ'.index(kind[1])
                o = [i for i in range(3) if i != ax]
                cols = [R[:, ax], R[:, o[0]], R[:, o[1]]]
                if np.linalg.det(np.column_stack(cols)) < 0:
                    cols[2] = -cols[2]
                R = np.column_stack(cols)
                d = (size[o[0]] + size[o[1]]) / 2
                size = np.array([size[ax], d, d])
                kind = 'C'
            row = (kind, tuple(np.round(centre, 3)), tuple(np.round(size, 3)))
            if row in seen:
                continue  # (one node drawn in several pieces with the same box: the sign, the tag)
            seen.add(row)
            parts.append({'name': p['node'], 'shape': kind, 'c': centre, 'R': R, 's': size, 'hex': hexc, 'glow': glow,
                          'picture': picture})
        # the prop's glow colour (effects): its most colourful glowing part, else its most colourful part
        def vivid(h):
            r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
            return max(r, g, b) + (max(r, g, b) - min(r, g, b))
        glow = max(glows or [p['hex'] for p in parts], key=vivid)
        names = [p['node'] for p in mine]
        out.append({'key': js['nodes'][c]['name'], 'size': hi - lo, 'glow': glow, 'parts': parts, 'meshes': len(mine),
                    'skipped': skipped, 'glowNames': [p['node'] for p in mine if p['material']['name'].startswith('glow')],
                    'pictures': [q['name'] for q in centres if q['picture']], 'names': names, 'centres': centres})
    return out


def f(v):
    if abs(v) < 0.0005:
        return '0'
    return ('%.3f' % v).rstrip('0').rstrip('.')


def main():
    ps = props()
    with open(os.path.join(HERE, 'props.json'), 'w') as fh:
        rows = [json.dumps({'key': p['key'], 'size': [round(float(v), 3) for v in p['size']], 'glow': p['glow'], 'meshes': p['meshes'],
                            'standIn': len(p['parts']), 'leftOut': p['skipped'], 'glowParts': len(p['glowNames']), 'pictures': p['pictures']}) for p in ps]
        fh.write('[\n' + ',\n'.join(rows) + '\n]\n')

    # The stand-in shapes (server + place build).
    lines = []
    for p in ps:
        rows = []
        for q in p['parts']:
            R = q['R']
            rows.append('{"%s",%s,%s,%s, %s, %s,%s,%s,"%s",%d}' % (
                q['shape'], f(q['c'][0]), f(q['c'][1]), f(q['c'][2]), ','.join(f(v) for v in R.T.reshape(-1)),
                f(q['s'][0]), f(q['s'][1]), f(q['s'][2]), q['hex'], 1 if q['glow'] and not q['picture'] else 0))
        lines.append('\t%s = {\n\t\tsize = { %s, %s, %s }, glow = "%s",\n\t\tparts = {\n\t\t\t%s,\n\t\t},\n\t},' % (
            p['key'], f(p['size'][0]), f(p['size'][1]), f(p['size'][2]), p['glow'], ',\n\t\t\t'.join(rows)))
    head = '''--[[
	GENERATED by tools/props/bake_props.py from design/lobby/Lobby_Props.glb: re-run it, don't edit this.
	The owner's 5 lobby props as plain Roblox parts (the stand-in until he imports the real meshes with the
	SetupLobbyProps helper): each row is one part of his model:
	{ shape (B block, S ball, C cylinder round along X), x, y, z (centre), 9 numbers (rotation: right, up, back
	columns), sx, sy, sz (size), colour, glow (1 = Neon) }, in the .glb's units, origin = the middle of the prop's
	footprint at its lowest point, its front along +Z. HuzzServer/LobbyPropService scales them by Config/LobbyProps.
	Left out: his stud textures and the SHOP / LIKE pictures (flat colours here), and rings, chains, vines and bow
	loops (not a box, ball or cylinder).
]]
return {
'''
    with open('src/ServerScriptService/HuzzServer/LobbyPropShapes.lua', 'w') as fh:
        fh.write(head + '\n'.join(lines) + '\n}\n')

    # The Studio helper's data: per prop, its size and glow colour, and every mesh: name, centre (the middle of its
    # box: where Studio puts a MeshPart's Position), colour, and 1 = glows (Neon), 2 = glows but carries a picture (the SHOP sign, the LIKE tag: kept as it is).
    rows = []
    for p in ps:
        ns = ', '.join('{"%s",%s,%s,%s,"%s",%d}' % (q['name'], f(q['c'][0]), f(q['c'][1]), f(q['c'][2]), q['hex'], 2 if q['picture'] else (1 if q['glow'] else 0)) for q in p['centres'])
        rows.append('\t{ key = "%s", size = { %s, %s, %s }, glow = "%s",\n\t\tnodes = { %s } },' % (
            p['key'], f(p['size'][0]), f(p['size'][1]), f(p['size'][2]), p['glow'], ns))
    data = 'local PROPS = {\n' + '\n'.join(rows) + '\n}'
    template = open(os.path.join(HERE, 'setup_lobby_props.template.lua')).read()
    body = template.replace('--@@PROPS@@', data)
    gen = '-- GENERATED by tools/props/bake_props.py from tools/props/setup_lobby_props.template.lua: edit those, not this.\n'
    with open(os.path.join(HERE, 'setup_lobby_props.lua'), 'w') as fh:
        fh.write(gen + body.replace('--@@RUN@@', 'run()'))
    with open('src/ServerStorage/HuzzStudioTools/SetupLobbyProps.lua', 'w') as fh:
        fh.write(gen + body.replace('--@@RUN@@', 'if script == nil then run() end -- (pasted whole into the Command Bar)\nreturn run'))
    for p in ps:
        print('%-22s size %s  glow #%s  meshes %3d  stand-in parts %3d  left out %2d  glow parts %2d  pictures %s' % (
            p['key'], np.round(p['size'], 2).tolist(), p['glow'], p['meshes'], len(p['parts']), p['skipped'], len(p['glowNames']), p['pictures']))


if __name__ == '__main__':
    main()
