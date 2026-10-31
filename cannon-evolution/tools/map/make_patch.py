"""Make a small fix-up GLB for pieces of an already packed map that are too long for Roblox.

Roblox caps a MeshPart at 2048 studs a side, so Import 3D squashed the two 3,028-stud volcano slices of
CannonMap.glb (Oct 30): holes in the volcano stage. This cuts every piece over TOO_LONG the way pack_map.py
now does and writes only those, so Alex imports a small file instead of the whole map again. It also prints
the Lua table for src/tools/PlaceMapPatch.lua (where each new piece goes, in the file's units).
Usage: python3 make_patch.py CannonMap.glb MapPatch.glb
"""
import sys
import numpy as np
from pack_map import read_glb, local_matrix, mesh_world, cap_span, write_glb

TOO_LONG = 1500  # over 2048 once the map is built 1.3x bigger (Config.Map.Scale); shorter pieces are left alone


def main(src, dst):
    j, buf = read_glb(src)
    nodes = j["nodes"]
    out, rows = [], []

    def walk(i, mat, group):
        n = nodes[i]
        m = mat @ local_matrix(n)
        if "mesh" in n:
            P, N, U = mesh_world(j, buf, n, m)
            if (P.max(0) - P.min(0)).max() > TOO_LONG:
                for suffix, (p, nn, u) in cap_span(P, N, U):
                    out.append((group, n["name"] + suffix, p, nn, u))
                    lo, hi = p.min(0), p.max(0)
                    rows.append((n["name"] + suffix, n["name"], (lo + hi) / 2, hi - lo, len(p) // 3))
        for c in n.get("children", []):
            walk(c, m, group)

    root = j["scenes"][0]["nodes"][0]
    rootm = local_matrix(nodes[root])
    for gi in nodes[root].get("children", []):
        group = nodes[gi].get("name")
        gm = rootm @ local_matrix(nodes[gi])
        for c in nodes[gi].get("children", []):
            walk(c, gm, group)
    if not out:
        print("nothing too long: no patch needed")
        return
    write_glb(out, j, buf, dst)
    # the plaza, so the Lua tool can find the map's scale and spot the same way BuildCannonMap does
    lo, hi = np.full(3, np.inf), np.full(3, -np.inf)
    for n in nodes:
        if "mesh" in n and n.get("name", "").startswith("Plaza_Compass_Spawn"):
            a = j["accessors"][j["meshes"][n["mesh"]]["primitives"][0]["attributes"]["POSITION"]]
            t = np.array(n.get("translation", [0, 0, 0]))
            lo, hi = np.minimum(lo, np.array(a["min"]) + t), np.maximum(hi, np.array(a["max"]) + t)
    f = lambda v: ", ".join(f"{x:.4f}" for x in v)
    print(f"local PLAZA = {{ centre = Vector3.new({f((lo + hi) / 2)}), width = {hi[0] - lo[0]:.4f} }}")
    print("local PIECES = { -- new piece = { replaces, centre, size } in the file's units")
    for name, old, c, s, t in rows:
        print(f'\t["{name}"] = {{ "{old}", Vector3.new({f(c)}), Vector3.new({f(s)}) }}, -- {t} triangles')
    print("}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
