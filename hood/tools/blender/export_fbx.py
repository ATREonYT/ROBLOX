"""Export every BoxKit model as an .fbx for Studio's 3D Importer (MeshParts), sharing one palette atlas.

Usage: blenv/bin/python hood/tools/blender/export_fbx.py [ids...]
Writes hood/art/models/fbx/<Id>.fbx and hood/art/models/fbx/palette.png.

* One small palette PNG holds a swatch per colour; every face is UV'd to the centre of its swatch, so
  a whole model shares one texture (one draw call per material kind).
* Objects are split by material kind and named <Id>_<RobloxMaterial> (e.g. Pistol_SmoothPlastic,
  Blaster_Neon_c46eff) so a short script sets MeshPart.Material after import (studio_apply_materials.lua).
  Neon and Glass objects are also split by colour: those materials look best as a plain Color.
* Geometry is in Roblox studs at scale 1 (bevels included), exported with the Roblox-documented
  settings: Apply Scalings = FBX Unit Scale, Forward = Z, Up = Y, textures embedded.
* Neon and Glass MeshParts cannot glow or tint through a texture, so studio_apply_materials.lua clears
  their TextureID and sets Material + Color from the name.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import boxkit as bk  # noqa: E402
import bk_blender as bb  # noqa: E402
from models import guns, icons  # noqa: E402
from export_luau import ROBLOX_MAT  # noqa: E402

HOOD = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HOOD, 'art', 'models', 'fbx')
COLS, SWATCH = 16, 8


def palette_for(models):
	seen = []
	for m in models:
		for p in m.prims:
			if p.color not in seen:
				seen.append(p.color)
	seen.sort(key=lambda c: (sum(c), c))
	rows = max(1, math.ceil(len(seen) / COLS))
	h = 1 << max(3, math.ceil(math.log2(rows * SWATCH)))
	w = COLS * SWATCH
	px = np.ones((h, w, 4), np.float32)
	uv = {}
	for i, c in enumerate(seen):
		r, col = divmod(i, COLS)
		y0 = r * SWATCH  # Blender pixel rows start at the bottom, like UV v
		px[y0:y0 + SWATCH, col * SWATCH:(col + 1) * SWATCH, :3] = np.array(c, np.float32) / 255.0
		uv[c] = ((col + 0.5) / COLS, (y0 + SWATCH / 2) / h)
	return px, uv


def palette_material(img, name):
	m = bpy.data.materials.new(name)
	nt = m.node_tree
	bs = nt.nodes['Principled BSDF']
	tex = nt.nodes.new('ShaderNodeTexImage')
	tex.image = img
	tex.interpolation = 'Closest'
	nt.links.new(tex.outputs['Color'], bs.inputs['Base Color'])
	bs.inputs['Roughness'].default_value = 0.5
	return m


def export_model(model, img_path, uv):
	bb.reset_scene()
	sc = bpy.context.scene
	sc.unit_settings.system = 'NONE'
	sc.unit_settings.scale_length = 1.0
	img = bpy.data.images.load(img_path)
	objs = bb.build(model, uv_for=lambda p: uv[p.color])
	dg = bpy.context.evaluated_depsgraph_get()
	groups = {}
	for ob, p in zip(objs, model.prims):
		roblox_mat = ROBLOX_MAT[p.mat][0]
		key = roblox_mat
		if p.mat in ('neon', 'glass'):
			key = '%s_%02x%02x%02x' % (roblox_mat, *p.color)
		groups.setdefault(key, []).append(ob)
	made = []
	for key, members in groups.items():
		meshes = []
		for ob in members:
			ev = ob.evaluated_get(dg)
			me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
			meshes.append(me)
		base = key.split('_')[0]
		name = '%s_%s' % (model.id, key)  # e.g. Pistol_Metal, Blaster_Neon_c46eff (hex = the Color to use)
		joined = bpy.data.objects.new(name, meshes[0])
		sc.collection.objects.link(joined)
		for me in meshes[1:]:
			tmp = bpy.data.objects.new('tmp', me)
			sc.collection.objects.link(tmp)
		for ob in members:
			bpy.data.objects.remove(ob)
		bpy.ops.object.select_all(action='DESELECT')
		for o in sc.collection.objects:
			if o.name.startswith('tmp'):
				o.select_set(True)
		joined.select_set(True)
		bpy.context.view_layer.objects.active = joined
		bpy.ops.object.join()
		me = joined.data
		me.materials.clear()
		me.materials.append(palette_material(img, base))
		# DU -> studs, then triangulate (the importer wants no n-gons).
		joined.scale = (model.unit,) * 3
		bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
		tri = joined.modifiers.new('Tri', 'TRIANGULATE')
		tri.quad_method = 'BEAUTY'
		tri.ngon_method = 'BEAUTY'
		bpy.ops.object.modifier_apply(modifier='Tri')
		made.append(joined)
	bpy.ops.object.select_all(action='DESELECT')
	for ob in made:
		ob.select_set(True)
	path = os.path.join(OUT, model.id + '.fbx')
	bpy.ops.export_scene.fbx(
		filepath=path, use_selection=True, object_types={'MESH'}, apply_scale_options='FBX_SCALE_UNITS',
		axis_forward='Z', axis_up='Y', use_mesh_modifiers=True, mesh_smooth_type='FACE', use_tspace=False,
		path_mode='COPY', embed_textures=True, bake_anim=False, add_leaf_bones=False,
	)
	tris = sum(len(o.data.polygons) for o in made)
	return path, [o.name for o in made], tris


def reimport_check(path):
	"""Load the FBX back with the same axis settings and report object names and the overall size."""
	bb.reset_scene()
	bpy.ops.import_scene.fbx(filepath=path, axis_forward='Z', axis_up='Y')
	lo = np.array([1e9] * 3)
	hi = -lo
	tris = 0
	for ob in bpy.context.scene.objects:
		if ob.type != 'MESH':
			continue
		for v in ob.data.vertices:
			w = ob.matrix_world @ v.co
			r = bb.R2B.inverted() @ w  # back to Roblox axes
			lo = np.minimum(lo, r)
			hi = np.maximum(hi, r)
		tris += len(ob.data.polygons)
	return hi - lo, tris


def main():
	os.makedirs(OUT, exist_ok=True)
	ids = sys.argv[1:]
	models = guns.build_all() + icons.build_all()
	px, uv = palette_for(models)
	h, w, _ = px.shape
	img_path = os.path.join(OUT, 'palette.png')
	bb.reset_scene()
	img = bpy.data.images.new('palette', w, h, alpha=True)
	img.pixels.foreach_set(px.ravel())
	img.filepath_raw = img_path
	img.file_format = 'PNG'
	img.save()
	print('palette %dx%d, %d colours -> %s' % (w, h, len(uv), img_path))
	for m in models:
		if ids and m.id not in ids:
			continue
		path, names, tris = export_model(m, img_path, uv)
		size, tris_back = reimport_check(path)
		lo, hi = m.bounds()
		want = [(hi[i] - lo[i]) * m.unit for i in range(3)]
		ok = all(abs(size[i] - want[i]) < 0.03 for i in range(3)) and tris == tris_back and tris < 20000
		print('%s %s tris=%d size=%s want=%s objects=%s' % ('OK ' if ok else 'BAD', os.path.basename(path), tris,
			[round(float(s), 3) for s in size], [round(s, 3) for s in want], names), flush=True)


if __name__ == '__main__':
	main()
