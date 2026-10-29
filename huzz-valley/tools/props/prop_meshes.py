# Writes the owner's 5 lobby props (design/lobby/Lobby_Props.glb, as they are: his triangles, UVs and textures) and
# our stand-in shapes (bake_props.py) as JSON for the offline picture (tools/props/render_props.mjs ->
# tools/props/props_vs_ref.py -> docs/previews/lobby-props-vs-ref.jpg).
# Each prop: { size, real: [ { pos: [x,y,z,...] triangles (prop-local .glb units, origin = footprint middle at its
# lowest point), uv: [...], tex: texture index or -1, col: "#rrggbb", glow } ], standIn: [ bake rows ] }, plus
# textures: [ "data:image/png;base64,..." ].
# Usage (from huzz-valley/): python3 -I tools/props/prop_meshes.py <out.json>
import base64, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'knives'))
import glb
import bake_props
import numpy as np


def main(out):
    js, binc = glb.load(bake_props.SRC)
    textures = []
    for t in js.get('textures', []):
        im = js['images'][t['source']]
        bv = js['bufferViews'][im['bufferView']]
        data = binc[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
        textures.append('data:%s;base64,%s' % (im.get('mimeType', 'image/png'), base64.b64encode(data).decode()))
    parent = {}
    for i, n, m, d, p in glb.walk(js):
        parent[i] = p
    root = js['scenes'][js.get('scene', 0)]['nodes'][0]
    prims = glb.meshes(js, binc)
    baked = {p['key']: p for p in bake_props.props()}
    result = {'textures': textures, 'props': {}}
    for c in js['nodes'][root].get('children', []):
        key = js['nodes'][c]['name']

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
        real = []
        for p in mine:
            idx = p['idx'].reshape(-1)
            tri = (p['pos'] - origin)[idx]
            uv = p['uv'][idx] if p['uv'] is not None else None
            mat = p['material']
            col = mat['color']
            real.append({'pos': [round(float(v), 4) for v in tri.reshape(-1)],
                         'uv': [round(float(v), 4) for v in uv.reshape(-1)] if uv is not None else None,
                         'tex': mat['texture'] if mat['texture'] is not None else -1,
                         'col': '#%02x%02x%02x' % tuple(int(max(0, min(1, v)) * 255) for v in col[:3]),
                         'glow': mat['name'].startswith('glow'),
                         # what SetupLobbyProps makes of a glowing part: Neon in its texture's colour (the SHOP sign and
                         # the LIKE tag keep their pictures)
                         'neon': ('#' + (glb.texture_colour(js, binc, mat['texture']) or 'ffffff'))
                         if mat['name'].startswith('glow') and p['node'] not in baked[key]['pictures'] else None})
        b = baked[key]
        stand = [{'shape': q['shape'], 'c': [float(v) for v in q['c']], 'R': [float(v) for v in q['R'].reshape(-1)],
                  's': [float(v) for v in q['s']], 'col': '#' + q['hex'], 'glow': bool(q['glow'] and not q['picture'])} for q in b['parts']]
        result['props'][key] = {'size': [float(v) for v in hi - lo], 'real': real, 'standIn': stand,
                                'pictures': b['pictures']}
    with open(out, 'w') as fh:
        json.dump(result, fh, separators=(',', ':'))
    print('prop meshes: %d props, %d KB -> %s' % (len(result['props']), os.path.getsize(out) // 1024, out))


if __name__ == '__main__':
    main(sys.argv[1])
