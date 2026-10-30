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

def place_moves(nodes, plan):
    """BuildCannonMap moves a few map pieces out of the way: each group's middle goes to "to" (x, z)."""
    out = list(nodes)
    for mv in plan["moves"]:
        idx = [i for i, (n, _, _) in enumerate(out) if n.startswith(tuple(mv["names"]))]
        if not idx:
            continue
        mid = np.mean([(out[i][2].min(0) + out[i][2].max(0)) / 2 for i in idx], axis=0)
        step = np.array([mv["to"][0] - mid[0], 0, mv["to"][1] - mid[2]])
        for i in idx:
            n, m, v = out[i]
            out[i] = (n, m, v + step)
    return out

def frame(r):
    """A footprint is either a box on the axes (x and z ranges) or a turned one: its centre c, size
    [width, length] and the way it faces, dir (booths fire along dir). Returns centre, side axis, forward axis, half sizes."""
    if "c" in r:
        f = np.array(r["dir"], float)
        f /= np.linalg.norm(f)
        return np.array(r["c"], float), np.array([-f[1], f[0]]), f, np.array(r["size"], float) / 2
    c = np.array([sum(r["x"]) / 2, sum(r["z"]) / 2])
    return c, np.array([1.0, 0]), np.array([0, 1.0]), np.array([abs(r["x"][1] - r["x"][0]), abs(r["z"][1] - r["z"][0])]) / 2

def corners(r):
    c, a, b, h = frame(r)
    return [tuple(c + sa * h[0] * a + sb * h[1] * b) for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1))]

def check(nodes, plan):
    bad = 0
    for r in plan["footprints"]:
        c, a, b, h = frame(r)
        hits = []
        for n, _, v in nodes:
            if n.startswith(GROUND):
                continue
            d = v[:, [0, 2]] - c
            inside = (np.abs(d @ a) < h[0]) & (np.abs(d @ b) < h[1]) & (v[:, 1] > 1.5)
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
        pts = [P(*p) for p in corners(r)]
        d.line(pts + pts[:1], fill=col, width=3)
        d.text((min(p[0] for p in pts) + 3, min(p[1] for p in pts) + 3), r["name"], fill=col)
    im.convert("RGB").save(out, quality=85)

if __name__ == "__main__":
    plan = json.load(open(os.path.join(HERE, "lobby_plan.json")))
    nodes = place_moves(load(sys.argv[1]), plan)
    bad = check(nodes, plan)
    if len(sys.argv) > 2:
        draw(nodes, plan, sys.argv[2])
    print("clashes:", bad)
