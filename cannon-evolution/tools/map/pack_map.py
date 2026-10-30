"""Pack Alex's mapeg.glb (9,162 small meshes) into a Roblox-friendly GLB with a few hundred meshes.

- 01_Lobby and 03_River keep one mesh per piece (named), so the lobby can be laid out piece by piece.
- 02_Stages and 04_Sky_Kingdom are merged per stage into slices along the track of at most MAX_TRIS
  triangles each (Roblox caps a MeshPart at 20,000 triangles).
- Each mesh is centred on its own middle (node translation), so MeshParts get sensible pivots.
Usage: python3 pack_map.py in.glb out.glb
"""
import json, struct, sys
import numpy as np

MAX_TRIS = 12000
COMP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    data = open(path, "rb").read()
    jl = struct.unpack_from("<I", data, 12)[0]
    j = json.loads(data[20:20 + jl])
    bin_start = 20 + jl + 8
    return j, data[bin_start:]


def accessor(j, buf, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride")
    item = np.dtype(dt).itemsize * n
    if stride and stride != item:
        raw = np.frombuffer(buf, np.uint8, count=stride * a["count"], offset=off).reshape(a["count"], stride)[:, :item]
        return raw.copy().view(dt).reshape(a["count"], n)
    return np.frombuffer(buf, dt, count=a["count"] * n, offset=off).reshape(a["count"], n)


def local_matrix(n):
    if "matrix" in n:
        return np.array(n["matrix"], float).reshape(4, 4).T
    t = np.array(n.get("translation", [0, 0, 0]), float)
    x, y, z, w = n.get("rotation", [0, 0, 0, 1])
    s = np.array(n.get("scale", [1, 1, 1]), float)
    r = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])
    m = np.eye(4)
    m[:3, :3] = r * s
    m[:3, 3] = t
    return m


def mesh_world(j, buf, node, mat):
    """All triangles of one node in world space: (positions, normals, uvs) as flat per-corner arrays."""
    P, N, U = [], [], []
    nm = np.linalg.inv(mat[:3, :3]).T
    for pr in j["meshes"][node["mesh"]]["primitives"]:
        at = pr["attributes"]
        pos = accessor(j, buf, at["POSITION"]).astype(float)
        nor = accessor(j, buf, at["NORMAL"]).astype(float) if "NORMAL" in at else None
        uv = accessor(j, buf, at["TEXCOORD_0"]).astype(float) if "TEXCOORD_0" in at else np.zeros((len(pos), 2))
        idx = accessor(j, buf, pr["indices"]).reshape(-1) if "indices" in pr else np.arange(len(pos))
        wp = pos @ mat[:3, :3].T + mat[:3, 3]
        if nor is None:
            tri = wp[idx].reshape(-1, 3, 3)
            fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
            wn = np.repeat(fn, 3, axis=0)
        else:
            wn = (nor @ nm.T)[idx]
        wn /= np.maximum(np.linalg.norm(wn, axis=1, keepdims=True), 1e-9)
        P.append(wp[idx]); N.append(wn); U.append(uv[idx])
    return np.vstack(P), np.vstack(N), np.vstack(U)


def split(P, N, U, max_tris):
    """Cut a triangle soup into slices along its longest axis, each under max_tris."""
    t = len(P) // 3
    if t <= max_tris:
        return [(P, N, U)]
    cent = P.reshape(-1, 3, 3).mean(axis=1)
    axis = int(np.argmax(cent.max(0) - cent.min(0)))
    order = np.argsort(cent[:, axis])
    parts = []
    pieces = int(np.ceil(t / max_tris))
    for chunk in np.array_split(order, pieces):
        sel = (chunk[:, None] * 3 + np.arange(3)).reshape(-1)
        parts.append((P[sel], N[sel], U[sel]))
    return parts


def main(src, dst):
    j, buf = read_glb(src)
    nodes = j["nodes"]
    root = j["scenes"][0]["nodes"][0]
    out = []  # (name, P, N, U)

    def collect(i, mat, path):
        n = nodes[i]
        m = mat @ local_matrix(n)
        here = path + [n.get("name", str(i))]
        found = []
        if "mesh" in n:
            found.append((here, mesh_world(j, buf, n, m)))
        for c in n.get("children", []):
            found += collect(c, m, here)
        return found

    rootm = local_matrix(nodes[root])
    for ci in nodes[root].get("children", []):
        group = nodes[ci].get("name")
        items = collect(ci, rootm, [])
        if group in ("01_Lobby", "03_River"):
            for path, (P, N, U) in items:
                name = "_".join(path[1:]) if len(path) > 1 else path[0]
                for k, part in enumerate(split(P, N, U, MAX_TRIS)):
                    out.append((group, name + ("" if k == 0 else f"_{k + 1}"), *part))
        else:
            # one bucket per stage (second level), packed along the track
            buckets = {}
            for path, geo in items:
                key = path[1] if len(path) > 1 else path[0]
                buckets.setdefault(key, []).append(geo)
            for key, geos in buckets.items():
                P = np.vstack([g[0] for g in geos]); N = np.vstack([g[1] for g in geos]); U = np.vstack([g[2] for g in geos])
                for k, part in enumerate(split(P, N, U, MAX_TRIS)):
                    out.append((group + "/" + key, f"{key}_{k + 1:02d}", *part))

    # write one GLB: a group node per top folder, a centred mesh node per piece
    blob = bytearray()
    views, accs, meshes, gnodes = [], [], [], []
    groups = {}

    def add(arr, target, kind, minmax=False):
        nonlocal blob
        while len(blob) % 4:
            blob += b"\0"
        b = arr.tobytes()
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(b), **({"target": target} if target else {})})
        blob += b
        a = {"bufferView": len(views) - 1, "componentType": 5126 if arr.dtype == np.float32 else 5125, "count": len(arr), "type": kind}
        if minmax:
            a["min"] = arr.min(0).tolist(); a["max"] = arr.max(0).tolist()
        accs.append(a)
        return len(accs) - 1

    mat_index = 0 if j.get("materials") else None
    tris = 0
    for group, name, P, N, U in out:
        # weld identical corners so the file stays small; flat shading survives because normals differ per face
        key = np.hstack([P.round(4), N.round(3), U.round(5)])
        uniq, inv = np.unique(key, axis=0, return_inverse=True)
        centre = (P.min(0) + P.max(0)) / 2
        pos = (uniq[:, :3] - centre).astype(np.float32)
        nor = uniq[:, 3:6].astype(np.float32)
        uv = uniq[:, 6:8].astype(np.float32)
        ind = inv.reshape(-1).astype(np.uint32)
        prim = {"attributes": {"POSITION": add(pos, 34962, "VEC3", True), "NORMAL": add(nor, 34962, "VEC3"),
                               "TEXCOORD_0": add(uv, 34962, "VEC2")}, "indices": add(ind, 34963, "SCALAR")}
        if mat_index is not None:
            prim["material"] = mat_index
        meshes.append({"name": name, "primitives": [prim]})
        node = {"name": name, "mesh": len(meshes) - 1, "translation": centre.tolist()}
        gnodes.append(node)
        groups.setdefault(group.split("/")[0], []).append(len(gnodes) - 1)
        tris += len(ind) // 3
    # the palette image
    img = j["images"][0]
    ibv = j["bufferViews"][img["bufferView"]]
    png = buf[ibv.get("byteOffset", 0):ibv.get("byteOffset", 0) + ibv["byteLength"]]
    while len(blob) % 4:
        blob += b"\0"
    views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(png)})
    blob += png
    image = {"bufferView": len(views) - 1, "mimeType": img.get("mimeType", "image/png"), "name": img.get("name", "palette")}

    all_nodes = list(gnodes)
    top = []
    for g, kids in groups.items():
        all_nodes.append({"name": g, "children": kids})
        top.append(len(all_nodes) - 1)
    all_nodes.append({"name": "CannonMap", "children": top})
    gl = {
        "asset": {"version": "2.0", "generator": "pack_map.py"},
        "scene": 0, "scenes": [{"nodes": [len(all_nodes) - 1]}],
        "nodes": all_nodes, "meshes": meshes, "accessors": accs, "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
        "materials": j.get("materials", []), "textures": j.get("textures", []),
        "samplers": j.get("samplers", []), "images": [image],
    }
    js = json.dumps(gl, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    while len(blob) % 4:
        blob += b"\0"
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(dst, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(blob), 0x004E4942)); f.write(blob)
    print(f"{len(meshes)} meshes, {tris} triangles, {total / 1e6:.1f} MB")
    for g, kids in groups.items():
        print(" ", g, len(kids))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
