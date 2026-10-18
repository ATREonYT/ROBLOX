# Writes the owner's knife meshes (design/knives/Knives/*.glb, as they are) as plain triangles for the offline
# pictures: tools/knives/render_cards.mjs (shop cards) and tools/preview/motion3d/render.mjs (knives in hand / on the
# back). Each knife: a list of parts { pos: [x,y,z,...] (triangles, the .glb's own units: +Y blade, X width,
# Z thickness), col: "#rrggbb" (its single-colour texture), glow: true for glow_glow_* materials, metal }.
# Usage (from huzz-valley/): python3 -I tools/knives/knife_meshes.py <out.json>
import json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb

SRC = 'design/knives/Knives'


def main(out):
    keys = {k['file']: k['key'] for k in json.load(open('tools/knives/knives.json'))}
    result = {}
    for f in sorted(os.listdir(SRC)):
        stem = f[:-4]
        if stem not in keys:
            continue
        js, binc = glb.load(os.path.join(SRC, f))
        parts = []
        for p in glb.meshes(js, binc):
            tri = p['pos'][p['idx'].reshape(-1)]
            name = p['material']['name']
            m = re.search(r'([0-9a-fA-F]{6})$', name)
            parts.append({'pos': [round(float(v), 4) for v in tri.reshape(-1)], 'col': '#' + (m.group(1).lower() if m else 'cccccc'),
                          'glow': name.startswith('glow'), 'metal': round(float(p['material']['metal']), 2), 'node': p['node']})
        result[keys[stem]] = parts
    with open(out, 'w') as fh:
        json.dump(result, fh, separators=(',', ':'))
    print('knife meshes: %d knives, %d KB -> %s' % (len(result), os.path.getsize(out) // 1024, out))


if __name__ == '__main__':
    main(sys.argv[1])
