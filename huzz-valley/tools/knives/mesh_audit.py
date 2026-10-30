# Audits the owner's knife .glb meshes for what Roblox draws badly: Roblox draws one side of each triangle only
# (the side its winding faces), so a mesh wound inside out shows its far side (looks hollow, "missing pixels"), an
# open sheet vanishes from behind, and two looks lying in the same plane flicker (z-fighting).
# Per mesh: triangles, open edges (edges used by one triangle), signed volume (negative = wound inside out) and the
# share of triangles facing away from the mesh's centre.
# Usage (from huzz-valley/): python3 -I tools/knives/mesh_audit.py [file.glb ...]   (default: his 30)
import os
import sys
from collections import Counter

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb  # noqa: E402


def audit(path):
    js, binc = glb.load(path)
    rows = []
    for p in glb.meshes(js, binc):
        pos = np.asarray(p['pos'], dtype=float)
        idx = np.asarray(p['idx']).reshape(-1, 3)
        # weld coincident vertices (glb splits them by normal/uv)
        key = np.round(pos / 1e-4).astype(np.int64)
        _, inv = np.unique(key, axis=0, return_inverse=True)
        tri = inv.reshape(-1)[idx.reshape(-1)].reshape(-1, 3) if inv.ndim else idx
        edges = Counter()
        for a, b, c in tri:
            for u, v in ((a, b), (b, c), (c, a)):
                edges[(min(u, v), max(u, v))] += 1
        open_edges = sum(1 for n in edges.values() if n == 1)
        v0, v1, v2 = pos[idx[:, 0]], pos[idx[:, 1]], pos[idx[:, 2]]
        vol = float(np.einsum('ij,ij->i', v0, np.cross(v1, v2)).sum() / 6)
        n = np.cross(v1 - v0, v2 - v0)
        centre = pos.mean(axis=0)
        mid = (v0 + v1 + v2) / 3
        away = float((np.einsum('ij,ij->i', n, mid - centre) < 0).mean()) if len(idx) else 0
        rows.append((p['node'], p['material']['name'], len(idx), open_edges, vol, away))
    return rows


def main(files):
    if not files:
        files = sorted(os.path.join('design/knives/Knives', f) for f in os.listdir('design/knives/Knives') if f[:2].isdigit())
    bad = 0
    for f in files:
        for node, mat, ntri, opened, vol, away in audit(f):
            flag = []
            if vol < 0:
                flag.append('INSIDE OUT')
            if opened:
                flag.append('open %d' % opened)
            if flag:
                bad += 1
            print('%-36s %-22s %-22s tris %5d vol %+.5f faces-in %.2f %s' % (os.path.basename(f)[:36], node[:22], mat[:22], ntri, vol, away, ' '.join(flag)))
    print('meshes flagged:', bad)


if __name__ == '__main__':
    main(sys.argv[1:])
