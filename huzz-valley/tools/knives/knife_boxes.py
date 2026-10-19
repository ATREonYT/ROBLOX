# Writes tools/knives/knife_boxes.json: for every knife (the 30 and the 5 Game Pass ones), each .glb part's box in
# the game's Handle space, in studs: { node, lo: [x,y,z], hi: [x,y,z], col: "rrggbb", glow }. Handle space = the
# setup's frame (tools/knives/setup_knives.lua): X = the .glb's Z (the blade's thin way), Y = the .glb's Y minus the
# grip (to the tip), Z = minus the .glb's X; scaled so pommel to tip is the knife's Studs.
# tests/KnifeModels.spec checks the owner's imported models (assets/knives/HuzzKnives.rbxm) part by part against it.
# Usage (from huzz-valley/): python3 -I tools/knives/knife_boxes.py   (reads the .glbs through knife_meshes.py)
import json, os, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import knife_meshes


def main():
    knives = {k['key']: k for k in json.load(open('tools/knives/knives.json'))}
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, 'meshes.json')
        knife_meshes.main(path)
        meshes = json.load(open(path))
    out = {}
    for key, parts in meshes.items():
        k = knives[key]
        per = k['studs'] / k['length']
        boxes = []
        for p in parts:
            v = p['pos']
            xs, ys, zs = v[0::3], v[1::3], v[2::3]
            # Handle space: (z, y - grip, -x) * per
            hx = [z * per for z in zs]
            hy = [(y - k['grip']) * per for y in ys]
            hz = [-x * per for x in xs]
            boxes.append({'node': p['node'], 'col': p['col'].lstrip('#'), 'glow': p['glow'],
                          'lo': [round(min(a), 3) for a in (hx, hy, hz)], 'hi': [round(max(a), 3) for a in (hx, hy, hz)]})
        out[key] = boxes
    with open('tools/knives/knife_boxes.json', 'w') as fh:
        json.dump(out, fh, separators=(',', ':'))
    print('knife boxes: %d knives -> tools/knives/knife_boxes.json (%d KB)' % (len(out), os.path.getsize('tools/knives/knife_boxes.json') // 1024))


if __name__ == '__main__':
    main()
