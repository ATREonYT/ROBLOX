# gun_pedestal_glb.py: parts.json (from export_gun_pedestal.luau) -> GunPedestal.glb and a preview picture.
# Usage: python3 hood/tools/blender/gun_pedestal_glb.py <parts.json> <out.glb> <preview.png>
import json, math, sys
import bpy
from mathutils import Matrix, Euler
rows = json.load(open(sys.argv[1])); out = sys.argv[2]; png = sys.argv[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
# Roblox (x, y up, z) -> Blender (x, -z, y up)
B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
mats = {}
def material(c, neon):
    k = (tuple(round(v, 3) for v in c), neon)
    if k in mats: return mats[k]
    m = bpy.data.materials.new('Pedestal_%02d' % len(mats)); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    lin = [((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c]
    b.inputs['Base Color'].default_value = (*lin, 1); b.inputs['Roughness'].default_value = 0.5
    if neon:
        b.inputs['Emission Color'].default_value = (*lin, 1); b.inputs['Emission Strength'].default_value = 1.5
    mats[k] = m; return m
for i, r in enumerate(rows):
    if r['cyl']:
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.5, depth=1, rotation=(0, math.pi / 2, 0))
        bpy.ops.object.transform_apply(rotation=True)  # Roblox cylinders run along X
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object; o.name = '%s_%02d' % (r['name'], i)
    rx, ry, rz = r['rot']
    R = Matrix.Rotation(rx, 4, 'X') @ Matrix.Rotation(ry, 4, 'Y') @ Matrix.Rotation(rz, 4, 'Z')
    M = Matrix.Translation(r['pos']) @ R @ Matrix.Diagonal((*r['size'], 1))
    o.matrix_world = B @ M
    o.data.materials.append(material(r['color'], r['neon']))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB')
# a preview picture
bpy.ops.object.light_add(type='SUN', rotation=(math.radians(50), 0, math.radians(30))); bpy.context.object.data.energy = 3
w = bpy.data.worlds.new('w'); bpy.context.scene.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (0.85, 0.88, 0.95, 1); w.node_tree.nodes['Background'].inputs[1].default_value = 1.0
bpy.ops.object.camera_add(location=(-7.5, -7.5, 6.0)); cam = bpy.context.object
cam.rotation_euler = Euler((math.radians(58), 0, math.radians(-45)))
bpy.context.scene.camera = cam
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.samples = 32; sc.cycles.device = 'CPU'
sc.render.resolution_x = sc.render.resolution_y = 800; sc.render.filepath = png
sc.view_settings.view_transform = 'Standard'
bpy.ops.render.render(write_still=True)
