# Reads the owner's knife .glb files (design/knives/Knives) without any 3D library: nodes, world transforms,
# triangle meshes, materials (colour, glow) and textures. Used by bake_knives.py (the Studio setup script's data)
# and knife_mesh_json.py (the offline pictures).
# Usage as a tool: python3 -I tools/knives/glb.py <file.glb>   (prints the node tree and materials)
import json, struct, sys
import numpy as np

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def load(path):
    b = open(path, 'rb').read()
    _, _, length = struct.unpack_from('<III', b, 0)
    off, js, binc = 12, None, b''
    while off < length:
        clen, ctype = struct.unpack_from('<II', b, off)
        off += 8
        chunk = b[off:off + clen]
        off += clen
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        else:
            binc = chunk
    return js, binc


def accessor(js, binc, i):
    a = js['accessors'][i]
    bv = js['bufferViews'][a['bufferView']]
    n, dt = NC[a['type']], CT[a['componentType']]
    start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride', 0)
    item = np.dtype(dt).itemsize * n
    if stride and stride != item:
        raw = np.frombuffer(binc, np.uint8, count=stride * a['count'], offset=start).reshape(a['count'], stride)[:, :item]
        arr = np.frombuffer(raw.tobytes(), dt)
    else:
        arr = np.frombuffer(binc, dt, count=n * a['count'], offset=start)
    return arr.reshape(a['count'], n) if n > 1 else arr


def quat_mat(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def local(node):
    if 'matrix' in node:
        return np.array(node['matrix'], float).reshape(4, 4).T  # (column-major in glTF)
    m = np.eye(4)
    s = np.array(node.get('scale', [1, 1, 1]), float)
    m[:3, :3] = quat_mat(node.get('rotation', [0, 0, 0, 1])) * s
    m[:3, 3] = node.get('translation', [0, 0, 0])
    return m


def walk(js):
    """Yields (node index, node, world 4x4, depth, parent index) for every node in the scene, parents first."""
    out = []

    def rec(i, parent_m, depth, parent):
        n = js['nodes'][i]
        m = parent_m @ local(n)
        out.append((i, n, m, depth, parent))
        for c in n.get('children', []):
            rec(c, m, depth + 1, i)
    for r in js['scenes'][js.get('scene', 0)]['nodes']:
        rec(r, np.eye(4), 0, None)
    return out


def material(js, i):
    if i is None:
        return {'name': '', 'color': [0.8, 0.8, 0.8, 1], 'emissive': [0, 0, 0], 'texture': None, 'metal': 0, 'rough': 1}
    m = js['materials'][i]
    pbr = m.get('pbrMetallicRoughness', {})
    tex = pbr.get('baseColorTexture')
    return {'name': m.get('name', ''), 'color': pbr.get('baseColorFactor', [1, 1, 1, 1]),
            'emissive': [e * m.get('extensions', {}).get('KHR_materials_emissive_strength', {}).get('emissiveStrength', 1) for e in m.get('emissiveFactor', [0, 0, 0])],
            'texture': tex['index'] if tex else None, 'metal': pbr.get('metallicFactor', 1), 'rough': pbr.get('roughnessFactor', 1)}


def texture_colour(js, binc, tex):
    """The average colour of a texture ('rrggbb'), or None. (The gamepass knives' materials carry their colour in a
    small texture, not in the material's name like the 30 shop knives.)"""
    if tex is None:
        return None
    import io
    from PIL import Image
    im = js['images'][js['textures'][tex]['source']]
    bv = js['bufferViews'][im['bufferView']]
    data = binc[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
    r, g, b = Image.open(io.BytesIO(data)).convert('RGB').resize((1, 1), Image.BOX).getpixel((0, 0))
    return '%02x%02x%02x' % (r, g, b)


def meshes(js, binc):
    """Every drawn primitive in world space: dicts with node name, material, positions (N,3), indices (M,3), uv."""
    out = []
    for i, n, m, depth, parent in walk(js):
        if 'mesh' not in n:
            continue
        for p in js['meshes'][n['mesh']]['primitives']:
            pos = accessor(js, binc, p['attributes']['POSITION']).astype(float)
            w = (np.c_[pos, np.ones(len(pos))] @ m.T)[:, :3]
            idx = accessor(js, binc, p['indices']).astype(int).reshape(-1, 3) if 'indices' in p else np.arange(len(pos)).reshape(-1, 3)
            uv = accessor(js, binc, p['attributes']['TEXCOORD_0']) if 'TEXCOORD_0' in p['attributes'] else None
            out.append({'node': n.get('name', ''), 'nodeIndex': i, 'mesh': n['mesh'], 'matrix': m, 'material': material(js, p.get('material')),
                        'materialIndex': p.get('material'), 'pos': w, 'local': pos, 'idx': idx, 'uv': uv})
    return out


if __name__ == '__main__':
    js, binc = load(sys.argv[1])
    for i, n, m, depth, parent in walk(js):
        t = m[:3, 3]
        sc = np.linalg.norm(m[:3, :3], axis=0)
        info = ''
        if 'mesh' in n:
            prim = js['meshes'][n['mesh']]['primitives'][0]
            lp = accessor(js, binc, prim['attributes']['POSITION'])
            info = 'mesh %d (%s) mat %s  local box %s..%s' % (n['mesh'], js['meshes'][n['mesh']].get('name', ''), material(js, prim.get('material'))['name'],
                                                        np.round(lp.min(0), 3).tolist(), np.round(lp.max(0), 3).tolist())
        print('  ' * depth + '%s  at %s scale %s  %s%s' % (n.get('name'), np.round(t, 3).tolist(), np.round(sc, 3).tolist(), info, '  [matrix]' if 'matrix' in n else ''))
    for i, mt in enumerate(js.get('materials', [])):
        print('material', i, json.dumps(material(js, i)))
    print('images', [im.get('name', im.get('mimeType')) for im in js.get('images', [])])
