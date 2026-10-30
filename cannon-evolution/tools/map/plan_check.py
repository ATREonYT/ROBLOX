"""Checks the new-map lobby plan against the map itself (Oct 30).

    python3 plan_check.py CannonMap.glb [out.jpg]

Reads lobby_plan.json (the footprints our build tools use, in map studs: x, z) and
  1. lists every map piece inside each footprint (rocks, palms, fences, props), so nothing overlaps;
  2. draws a top-down picture of the lobby with the footprints and the edge walls on it.
The packed map uses the same coordinates as Studio after BuildCannonMap.lua has placed it.
"""
import json, sys, os
import numpy as np, trimesh
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GROUND = ("Island", "Plaza", "Path_", "Mountains", "River", "Dock_")  # floors, and the dock you stand on

def load(path):
    sc = trimesh.load(path, force="scene")
    g = sc.graph
    out = []
    for n in g.nodes_geometry:
        T, geom = g[n]
        m = sc.geometry[geom]
        v = trimesh.transformations.transform_points(m.vertices, T)
        if v[:, 0].min() > 40:
            continue
        out.append((n, m, v))
    return out

def moved(plan, name, v):
    for mv in plan["moves"]:
        if name.startswith(tuple(mv["names"])):
            return v + np.array([mv["offset"][0], 0, mv["offset"][1]])
    return v

def check(nodes, plan):
    bad = 0
    for r in plan["footprints"]:
        x0, x1 = sorted((r["x"][0], r["x"][1]))
        z0, z1 = sorted((r["z"][0], r["z"][1]))
        hits = []
        for n, _, v in nodes:
            if n.startswith(GROUND):
                continue
            v = moved(plan, n, v)
            inside = (v[:, 0] > x0) & (v[:, 0] < x1) & (v[:, 2] > z0) & (v[:, 2] < z1) & (v[:, 1] > 1.5)
            if inside.any():
                hits.append(n)
        if hits:
            bad += 1
        print(("CLASH " if hits else "ok    ") + r["name"], hits)
    return bad

def draw(nodes, plan, out):
    S, x0, x1, z0, z1 = 7, -125, 25, -58, 58
    P = lambda x, z: ((x - x0) * S, (z - z0) * S)
    im = Image.new("RGB", (int((x1 - x0) * S), int((z1 - z0) * S)), (30, 60, 90))
    d = ImageDraw.Draw(im)
    polys = []
    for n, m, v in nodes:
        if n.startswith("Mountains"):
            continue
        v = moved(plan, n, v)
        a = np.asarray(m.visual.material.baseColorTexture.convert("RGB"))
        h, w = a.shape[:2]
        uv = m.visual.uv[m.faces].mean(1)
        px = np.clip((uv[:, 0] * w).astype(int), 0, w - 1)
        py = np.clip(((1 - uv[:, 1]) * h).astype(int), 0, h - 1)
        cols = a[py, px]
        tri = v[m.faces]
        top = tri[:, :, 1].max(1)
        for i in range(len(tri)):
            polys.append((top[i], [P(x, z) for x, z in tri[i][:, [0, 2]]], tuple(int(c) for c in cols[i])))
    for _, p, c in sorted(polys, key=lambda t: t[0]):
        d.polygon(p, fill=c)
    for x in range(x0, x1 + 1, 10):
        d.line([P(x, z0), P(x, z1)], fill=(80, 80, 80))
        d.text((P(x, z0)[0] + 2, 2), str(x), fill="white")
    for z in range(z0 - z0 % 10, z1 + 1, 10):
        d.line([P(x0, z), P(x1, z)], fill=(80, 80, 80))
        d.text((2, P(x0, z)[1] + 2), str(z), fill="white")
    wall = plan["walls"]
    for i in range(len(wall)):
        a, b = wall[i], wall[(i + 1) % len(wall)]
        d.line([P(*a), P(*b)], fill=(255, 60, 200), width=3)
    for r in plan["footprints"]:
        col = tuple(r.get("color", (255, 80, 80)))
        d.rectangle([P(min(r["x"]), min(r["z"])), P(max(r["x"]), max(r["z"]))], outline=col, width=3)
        d.text((P(min(r["x"]), min(r["z"]))[0] + 3, P(min(r["x"]), min(r["z"]))[1] + 3), r["name"], fill=col)
    im.convert("RGB").save(out, quality=85)

if __name__ == "__main__":
    plan = json.load(open(os.path.join(HERE, "lobby_plan.json")))
    nodes = load(sys.argv[1])
    bad = check(nodes, plan)
    if len(sys.argv) > 2:
        draw(nodes, plan, sys.argv[2])
    print("clashes:", bad)
