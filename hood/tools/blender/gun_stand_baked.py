# gun_stand_baked.py: parts.json (from export_gun_stand.luau / gun_stand_same_pads.luau) -> ONE mesh with its colours in
# ONE texture (a palette: each colour a 16 px cell, every face's UVs on its colour's cell centre), for uploading to Roblox
# as a single MeshPart. Writes <out>.glb (texture inside), <out>.fbx + <out>.obj/.mtl with <out>_Texture.png beside them.
# Usage: python3 hood/tools/blender/gun_stand_baked.py <parts.json> <out path without extension>
import json, math, os, sys
import bpy
import bmesh
from mathutils import Matrix

rows = json.load(open(sys.argv[1])); out = sys.argv[2]
name = os.path.basename(out)
bpy.ops.wm.read_factory_settings(use_empty=True)
B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Roblox (x, y up, z) -> Blender (x, -z, y up)

# the palette: one cell per distinct colour (sRGB bytes)
cols = []
for r in rows:
    c = tuple(max(0, min(255, round(v * 255))) for v in r['color'])
    r['_c'] = c
    if c not in cols:
        cols.append(c)
CELL = 16
n = math.ceil(math.sqrt(len(cols)))
W = n * CELL
img = bpy.data.images.new(name + '_Texture', W, W, alpha=False)
px = [0.0] * (W * W * 4)
for i, c in enumerate(cols):
    cx, cy = (i % n) * CELL, (i // n) * CELL
    for y in range(cy, cy + CELL):
        for x in range(cx, cx + CELL):
            k = (y * W + x) * 4
            px[k:k + 4] = [c[0] / 255, c[1] / 255, c[2] / 255, 1.0]
img.pixels = px
img.filepath_raw = out + '_Texture.png'
img.file_format = 'PNG'
img.save()

def uv_of(c):
    i = cols.index(c)
    return (((i % n) + 0.5) * CELL / W, ((i // n) + 0.5) * CELL / W)

bm = bmesh.new()
uvl = bm.loops.layers.uv.new('UVMap')
for r in rows:
    tmp = bmesh.new()
    if r['cyl']:
        bmesh.ops.create_cone(tmp, cap_ends=True, segments=12, radius1=0.5, radius2=0.5, depth=1,
                              matrix=Matrix.Rotation(math.pi / 2, 4, 'Y'))  # Roblox cylinders run along X
    else:
        bmesh.ops.create_cube(tmp, size=1)
    rx, ry, rz = r['rot']
    R = Matrix.Rotation(rx, 4, 'X') @ Matrix.Rotation(ry, 4, 'Y') @ Matrix.Rotation(rz, 4, 'Z')
    M = B @ Matrix.Translation(r['pos']) @ R @ Matrix.Diagonal((*r['size'], 1))
    bmesh.ops.transform(tmp, matrix=M, verts=tmp.verts)
    u = uv_of(r['_c'])
    vmap = {v: bm.verts.new(v.co) for v in tmp.verts}
    for f in tmp.faces:
        nf = bm.faces.new([vmap[v] for v in f.verts])
        for l in nf.loops:
            l[uvl].uv = u
    tmp.free()
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new(name)
bm.to_mesh(me); bm.free()
ob = bpy.data.objects.new(name, me)
bpy.context.scene.collection.objects.link(ob)
mat = bpy.data.materials.new(name + '_Mat'); mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes['Principled BSDF']; bsdf.inputs['Roughness'].default_value = 0.6
tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img; tex.interpolation = 'Closest'
nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
me.materials.append(mat)
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
# Triangulate once so every exporter writes the same faces
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.quads_convert_to_tris(); bpy.ops.object.mode_set(mode='OBJECT')
print('triangles', len(me.polygons), 'colours', len(cols))
bpy.ops.export_scene.gltf(filepath=out + '.glb', export_format='GLB', use_selection=True)
bpy.ops.export_scene.fbx(filepath=out + '.fbx', use_selection=True, path_mode='COPY', embed_textures=True)
bpy.ops.wm.obj_export(filepath=out + '.obj', export_selected_objects=True, path_mode='RELATIVE')
