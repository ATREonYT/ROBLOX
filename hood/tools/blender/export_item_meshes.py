"""SUPERSEDED (brief 32): the import package is now the user's own blocky designs, built by build_item_package.py
(Items_*.glb + manifest.json + studio_item_meshes.lua). This BoxKit exporter writes over those files, so it only runs
with --legacy (e.g. for preview OBJs of the Part-built chests: --legacy --obj DIR).

The showcase items as real 3D meshes (brief 31 MESH): one FBX the user imports ONCE into Studio, plus the setup
script that files the import into ReplicatedStorage.HoodItemMeshes (one Model per item id). The game clones them through
Shared/ItemMeshes (BoxModels, ShoeModels and the map's pads and gun stands); the Part builds stay as the fallback.

Usage (Blender as a Python module, see README):
  blenv/bin/python hood/tools/blender/export_item_meshes.py [ids or prefixes...] [--shoes] [--obj DIR] [--list]
Writes
  hood/art/models/items/HoodItemMeshes.fbx     every item, its MeshParts named <ItemId>__<Group>__<Material>_<hex>
  hood/art/models/items/manifest.json          per item: design bounds, parts (group, material, colour, centre, size, tris)
  hood/tools/blender/studio_item_meshes.lua    the Studio command-bar script (design bounds embedded)
  --obj DIR: one OBJ per MeshPart (Roblox axes, studs, centred on the part) for the offline previewer

Items (ids are what the code asks ItemMeshes for):
  Box_<Id>        the 5 World 1 chests (models/chests.py), at BoxModels' own frame and size (W 4.4, D 3.4, seam 2.1):
                  group Body (the tub) and Lid (the lid and its handle); the lid swings about (0, 2.1, 1.7)
  GunStand_<Id>   the 10 guns (models/guns.py), grip at the origin like GunModels.build
  Pad_<Key>       the product pads' items (Config/Products keys), from the Store/HUD icon models (icons_store.py,
                  icons_hd.py) so the pad shows the same toy as the button
  Shoe_<Id>       the 22 World 1 pairs (models/shoes.py), in ShoeModels.pair's frame (soles' centre on the ground);
                  only with --shoes (they gain little over their Parts; ShoeModels.pair uses them when imported)
How a BoxKit model becomes a toy mesh: every primitive gets a real rounded bevel (2 segments, harden normals, width
~3.5 % of the item's size, clamped to a third of the piece's thinnest side), the Part kit's fake bevel strips (LidEdge)
and the hidden Hinge are dropped, then the pieces are joined per (group, material, colour) and triangulated.
Colours live in the names (no textures, no SurfaceAppearance): studio_item_meshes.lua and ItemMeshes set
MeshPart.Color / Material from them, so nothing but the meshes needs uploading.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import boxkit as bk  # noqa: E402
import bk_blender as bb  # noqa: E402

HOOD = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HOOD, 'art', 'models', 'items')
LUA = os.path.join(HERE, 'studio_item_meshes.lua')
B2R = bb.R2B.inverted()
TRI_BUDGET = 5000
# BoxKit material kind -> the MeshPart's Roblox material (the recipe: SmoothPlastic for items, Neon only to glow)
ROBLOX = {'plastic': 'SmoothPlastic', 'smooth': 'SmoothPlastic', 'metal': 'Metal', 'gold': 'Foil', 'neon': 'Neon', 'glass': 'Glass'}


def hexc(rgb):
	return '%02x%02x%02x' % tuple(int(c) for c in rgb)


def srgb(lin_rgba):
	out = []
	for c in lin_rgba[:3]:
		c = max(0.0, min(1.0, c))
		c = c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
		out.append(int(round(c * 255)))
	return tuple(out)


# ------------------------------------------------------------------------------------------- BoxKit sources
def local_geometry(p, unit):
	"""bk_blender.local_geometry with a triangle budget: round pieces get fewer segments the smaller they are (a 0.3-stud
	ball needs no 960 triangles), everything else as BoxKit draws it."""
	import bmesh
	sx, sy, sz = p.size
	big = max(p.size) * unit
	if p.kind in ('ball', 'egg'):
		u = 20 if big > 1.2 else 14 if big > 0.5 else 10
		bm = bmesh.new()
		bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=max(6, u // 2), radius=1.0)
		k = (sx / 2, sy / 2, sz / 2) if p.kind == 'egg' else (sx / 2,) * 3
		v = [(vert.co.x * k[0], vert.co.y * k[1], vert.co.z * k[2]) for vert in bm.verts]
		f = [tuple(vert.index for vert in face.verts) for face in bm.faces]
		bm.free()
		return v, f, True
	if p.kind == 'cyl':
		x, y = sx / 2, sy / 2
		d = sy * unit
		n = 10 if d < 0.25 else 16 if d < 0.8 else 24
		v = bb._ngon_ring(-x, y, n, 0.0) + bb._ngon_ring(x, y, n, 0.0)
		f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
		f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
		return v, f, True
	return bb.local_geometry(p)


def prim_mesh(p, name, unit):
	verts, faces, smooth = local_geometry(p, unit)
	world = [bb.to_b(bk.add(bk.mat_vec(p.rot, v), p.pos)) for v in verts]
	me = bpy.data.meshes.new(name)
	me.from_pydata(world, [], faces)
	me.update()
	import bmesh
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(me)
	bm.free()
	for poly in me.polygons:
		poly.use_smooth = True
	me.set_sharp_from_angle(angle=math.radians(30 if smooth else 1))
	return me


def boxkit_objects(model, group_of, skip=lambda p: False, bevel_frac=0.035, unit_override=None, max_segs=3):
	"""One Blender object per primitive (Blender axes, STUDS), each with its bevel; returns [(obj, group, mat, rgb)]."""
	unit = unit_override or model.unit
	lo, hi = model.bounds()
	extent = max(hi[i] - lo[i] for i in range(3)) * unit
	max_b = bevel_frac * extent
	out = []
	for i, p in enumerate(model.prims):
		if skip(p):
			continue
		me = prim_mesh(p, '%s_%03d' % (model.id, i), unit)
		me.transform(Matrix.Diagonal((unit, unit, unit, 1.0)))
		ob = bpy.data.objects.new(me.name, me)
		bpy.context.scene.collection.objects.link(ob)
		if p.kind not in ('ball', 'egg'):
			thin = min(p.size) * unit
			bw = min(max_b, thin * 0.34)
			bw = max(bw, min(p.bevel * unit, thin * 0.45))
			# (pieces under ~0.3 studs - studs, screws, gem facets - show no bevel at item size: they stay crisp, 12 tris)
			if bw > 0.004 and max(p.size) * unit >= 0.3 * (extent / 4.4):
				mod = ob.modifiers.new('Bevel', 'BEVEL')
				mod.width = bw
				# two segments read as round on the big pieces; studs, screws and trims take one
				mod.segments = min(max_segs, 3 if bw > 0.12 else 2 if (bw > 0.03 and thin >= 0.28 * (extent / 4.4) and max(p.size) * unit >= 0.9 * (extent / 4.4) and p.kind != 'cyl') else 1)
				mod.limit_method = 'ANGLE'
				mod.angle_limit = math.radians(40)
				mod.harden_normals = True
				mod.use_clamp_overlap = True
		out.append((ob, group_of(p), ROBLOX.get(p.mat, 'SmoothPlastic'), tuple(p.color)))
	return out


def extruded(poly_xy, z_back, depth, rgb, bevel, name, tips=(), segs=3):
	"""A flat emblem standing on a front face: the polygon (Roblox x, y) extruded from the face plane z_back toward -Z by
	`depth`, with a rounded bevel all round (the sheets' raised crowns and stars), plus optional ball tips."""
	import bmesh
	bm = bmesh.new()
	back = [bm.verts.new(bb.to_b((x, y, z_back))) for x, y in poly_xy]
	face = bm.faces.new(back)
	bmesh.ops.recalc_face_normals(bm, faces=[face])
	ext = bmesh.ops.extrude_face_region(bm, geom=[face])
	moved = [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]
	bmesh.ops.translate(bm, verts=moved, vec=bb.to_b((0.0, 0.0, -depth)))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = True
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	mod = ob.modifiers.new('Bevel', 'BEVEL')
	mod.width, mod.segments, mod.limit_method = bevel, segs, 'ANGLE'
	mod.angle_limit, mod.harden_normals, mod.use_clamp_overlap = math.radians(25), True, True
	out = [ob]
	for (x, y, d) in tips:
		bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8, radius=d / 2, location=tuple(bb.to_b((x, y, z_back - depth / 2))))
		b = bpy.context.active_object
		bpy.ops.object.shade_smooth()
		out.append(b)
	return out


def emblem_recorder(chests):
	"""Swap the chests' Part emblems (wedges, balls and a dark outline copy) for records; chest_item models them as
	one extruded bevelled shape each, like the sheets."""
	rec = []

	def crown_front(c, x, y, z, size, color, name='Emblem', tips=True, t=0.1, outline=True):
		rec.append(('crown', x, y, z, size, color, tips, t * (1.4 if outline else 1.0)))

	def star5_front(c, x, y, z, size, color, name='Star', t=0.1, outline=False):
		rec.append(('star', x, y, z, size, color, False, t))
	return rec, dict(crown_front=crown_front, star5_front=star5_front)


def emblem_objects(rec, group_of_z):
	out = []
	for kind, x, y, z, s, color, tips, t in rec:
		if kind == 'crown':
			# the sheets' crown: a band and body with three peaks (the outer two leaning out), notches between them
			pts = [(-0.5, 0.0), (0.5, 0.0), (0.5, 0.44), (0.62, 0.9), (0.27, 0.56), (0.0, 0.98), (-0.27, 0.56), (-0.62, 0.9), (-0.5, 0.44)]
			poly = [(x + px * s, y + py * s) for px, py in pts]
			tip = [(x + px * s, y + py * s, s * 0.17) for px, py in ((0.62, 0.9), (0.0, 0.98), (-0.62, 0.9))] if tips else []
			objs = extruded(poly, z, max(t, 0.12), color, min(0.06, s * 0.045), 'Emblem', tip)
		else:
			r = s / 2
			poly = []
			for i in range(10):
				a = math.radians(90 + 36 * i)
				rr = r if i % 2 == 0 else r * 0.48
				poly.append((x + rr * math.cos(a), y + rr * math.sin(a)))
			objs = extruded(poly, z, max(t, 0.12), color, min(0.05, s * 0.05), 'Star', segs=2)
		for ob in objs:
			out.append((ob, group_of_z(y), 'SmoothPlastic', tuple(color)))
	return out


def chest_item(box_id):
	from models import chests
	rec, swap = emblem_recorder(chests)
	saved = {k: getattr(chests, k) for k in swap}
	for k, f in swap.items():
		setattr(chests, k, f)
	try:
		m = chests.build(box_id)
	finally:
		for k, f in saved.items():
			setattr(chests, k, f)

	def group_of(p):
		g = (p.tag or {}).get('group', 'body')
		return 'Lid' if g in ('lid', 'topper') else 'Body'
	objs = boxkit_objects(m, group_of, skip=lambda p: p.name in ('Hinge', 'LidEdge'), bevel_frac=0.045,
		max_segs=2 if box_id == 'Graffiti' else 3)
	objs += emblem_objects(rec, lambda y: 'Lid' if y > chests.BODY else 'Body')
	return objs, dict(hinge=list(chests.HINGE), kind='box')


def gun_item(gun_id):
	from models import guns
	m = [g for g in guns.build_all() if g.id == gun_id][0]
	# (the recipe: items are clean colour, no studs; the reference's guns are smooth)
	return boxkit_objects(m, lambda p: 'Body', skip=lambda p: p.stud, bevel_frac=0.03), dict(kind='gun')


def shoe_item(shoe_id):
	"""The pair as ShoeModels.pair lays it out at scale 1: the right shoe as modelled at +PairGap, the left mirrored."""
	from models import shoes
	m = shoes.build(shoe_id)
	objs = boxkit_objects(m, lambda p: 'Body', bevel_frac=0.03, max_segs=1)
	gap, lift = 0.62, 0.0  # ShoeModels.PairGap; shoes.py already stands the sole on y = 0
	out = []
	for ob, g, mat, rgb in objs:
		left = ob.copy()
		left.data = ob.data.copy()
		bpy.context.scene.collection.objects.link(left)
		# Blender x = -Roblox x: the right shoe goes to Roblox +gap (Blender -gap); the left is the mirror (Roblox -x)
		ob.location = (-gap, 0, lift)
		left.scale = (-1, 1, 1)
		left.location = (gap, 0, lift)
		out.append((ob, g, mat, rgb))
		out.append((left, g, mat, rgb))
	return out, dict(kind='shoe')


# ------------------------------------------------------------------------------------------- icon sources (hdkit)
PAD_ICONS = {
	# Products key -> (icon module, icon id, design height in studs)
	'DoubleRep': ('icons_store', 'DoublePower'), 'DoubleCash': ('icons_store', 'DoubleCash'),
	'VIP': ('hero', 'VIP'), 'AutoShoot': ('icons_store', 'AutoFight'), 'Lucky': ('icons_store', 'Lucky'),
	'TripleOpen': ('icons_store', 'TripleOpen'), 'AutoOpen': ('icons_store', 'AutoOpen'),
	'ExtraEquip': ('icons_store', 'ExtraEquip'), 'Speed2x': ('icons_store', 'Speed2x'),
	'AutoCollect': ('own', 'Magnet'),
}


def mesh_crown():
	"""The VIP crown: B31 LOOK's hero mesh (work31_LOOK/tools/hero.py), the proof that a mesh reads as a toy: a 16-sided
	band with a zig-zag edge cut into 8 points, ball tips, faceted ruby and sapphire gems, a darker gold rim."""
	import bmesh
	GOLD, GOLD_D, RUBY, SAPH = (255, 200, 40), (226, 150, 20), (232, 30, 72), (40, 150, 255)
	R, H, S = 3.2, 2.2, 16
	out = []
	bm = bmesh.new()
	verts = {}
	for i in range(S):
		a = 2 * math.pi * i / S
		top = H / 2 + (2.0 if i % 2 == 0 else 0.0)
		for side, r in (('o', R + 0.35), ('i', R - 0.35)):
			x, y = r * math.sin(a), r * math.cos(a)
			verts[(side, i, 'b')] = bm.verts.new((x, y, -H / 2))
			verts[(side, i, 't')] = bm.verts.new((x, y, top))
	for i in range(S):
		j = (i + 1) % S
		bm.faces.new([verts[('o', i, 'b')], verts[('o', j, 'b')], verts[('o', j, 't')], verts[('o', i, 't')]])
		bm.faces.new([verts[('i', j, 'b')], verts[('i', i, 'b')], verts[('i', i, 't')], verts[('i', j, 't')]])
		bm.faces.new([verts[('o', i, 't')], verts[('o', j, 't')], verts[('i', j, 't')], verts[('i', i, 't')]])
		bm.faces.new([verts[('i', i, 'b')], verts[('i', j, 'b')], verts[('o', j, 'b')], verts[('o', i, 'b')]])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new('CrownBand')
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new('CrownBand', me)
	bpy.context.scene.collection.objects.link(ob)
	bev = ob.modifiers.new('Bevel', 'BEVEL')
	bev.width, bev.segments, bev.limit_method = 0.16, 3, 'ANGLE'
	bev.angle_limit, bev.harden_normals, bev.use_clamp_overlap = math.radians(30), True, True
	for p in me.polygons:
		p.use_smooth = True
	out.append((ob, 'Body', 'SmoothPlastic', GOLD))
	bpy.ops.mesh.primitive_torus_add(major_radius=R + 0.32, minor_radius=0.32, major_segments=24, minor_segments=8, location=(0, 0, -H / 2 + 0.3))
	t = bpy.context.active_object
	bpy.ops.object.shade_smooth()
	out.append((t, 'Body', 'SmoothPlastic', GOLD_D))
	for i in range(0, S, 2):
		a = 2 * math.pi * i / S
		bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.42, location=(R * math.sin(a), R * math.cos(a), H / 2 + 2.25))
		b = bpy.context.active_object
		bpy.ops.object.shade_smooth()
		out.append((b, 'Body', 'SmoothPlastic', GOLD))
		bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.42, location=((R + 0.42) * math.sin(a), (R + 0.42) * math.cos(a), 0.1))
		g = bpy.context.active_object
		out.append((g, 'Body', 'SmoothPlastic', RUBY if i % 4 == 0 else SAPH))
	for o, *_ in out:
		bpy.context.view_layer.objects.active = o
	return out


def magnet():
	"""Auto Collect: a chunky red horseshoe magnet with silver tips, standing on its bend, and a gold coin it pulls."""
	RED, SILVER, GOLD = (232, 40, 56), (226, 232, 242), (255, 196, 40)
	out = []
	R, r = 1.1, 0.42
	bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=28, minor_segments=12, location=(0, 0, 0), rotation=(math.pi / 2, 0, 0))
	t = bpy.context.active_object
	import bmesh
	bm = bmesh.new()
	bm.from_mesh(t.data)
	# keep the lower half (the bend): in the torus' own space the ring lies in x/y, the bend is y < 0 after the turn
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.001], context='VERTS')
	bm.to_mesh(t.data)
	bm.free()
	bpy.ops.object.shade_smooth()
	out.append((t, 'Body', 'SmoothPlastic', RED))
	for sx in (-1, 1):
		bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=r, depth=0.9, location=(sx * R, 0, 0.45))
		a = bpy.context.active_object
		bpy.ops.object.shade_smooth()
		out.append((a, 'Body', 'SmoothPlastic', RED))
		bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=r * 1.04, depth=0.55, location=(sx * R, 0, 1.17))
		tip = bpy.context.active_object
		bev = tip.modifiers.new('Bevel', 'BEVEL')
		bev.width, bev.segments, bev.harden_normals = 0.08, 2, True
		bpy.ops.object.shade_smooth()
		out.append((tip, 'Body', 'SmoothPlastic', SILVER))
	bpy.ops.mesh.primitive_cylinder_add(vertices=28, radius=0.5, depth=0.16, location=(0, -0.2, 2.15), rotation=(math.pi / 2, 0, 0))
	coin = bpy.context.active_object
	bev = coin.modifiers.new('Bevel', 'BEVEL')
	bev.width, bev.segments, bev.harden_normals = 0.05, 2, True
	bpy.ops.object.shade_smooth()
	out.append((coin, 'Body', 'SmoothPlastic', GOLD))
	return out


def icon_item(key):
	src, iid = PAD_ICONS[key]
	if src == 'hero':
		return mesh_crown(), dict(kind='pad', icon=iid)
	if src == 'own':
		return magnet(), dict(kind='pad', icon=iid)
	import hdkit as K
	import icons_hd as H
	if src == 'icons_store':
		import icons_store  # noqa: F401  (registers its icons over icons_hd's)
	K.reset(64, 1)
	H.ICONS[iid]['fn']()
	out = []
	for ob in list(K.C.objs):
		if ob.type not in ('MESH', 'CURVE', 'FONT', 'META', 'SURFACE'):
			continue
		mat = ob.active_material or (ob.material_slots[0].material if ob.material_slots else None)
		if mat is None or mat.name.startswith('flat_'):
			continue  # crease lines and painted details belong to the 2D icon only
		rgb = srgb(mat.diffuse_color)
		emit = 0.0
		try:
			emit = mat.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value
		except Exception:  # noqa: BLE001
			pass
		for mod in ob.modifiers:
			if mod.type == 'BEVEL':
				mod.segments = min(mod.segments, 2)  # (the icon's 4-5 segment bevels: 2 read the same at pad size)
		out.append((ob, 'Body', 'Neon' if emit > 0.5 else 'SmoothPlastic', rgb))
	return out, dict(kind='pad', icon=iid)


def decimate(objs, budget):
	"""Bring an over-budget item under `budget` triangles: collapse-decimate each part by the same ratio, then shade
	smooth with sharp edges over 40 degrees (the decimated custom normals are dropped)."""
	tris = sum(len(o.data.polygons) for o in objs)
	if tris <= budget:
		return tris
	ratio = budget * 0.97 / tris
	for ob in objs:
		if len(ob.data.polygons) < 200:
			continue
		bpy.ops.object.select_all(action='DESELECT')
		bpy.context.view_layer.objects.active = ob
		ob.select_set(True)
		mod = ob.modifiers.new('Dec', 'DECIMATE')
		mod.decimate_type = 'COLLAPSE'
		mod.ratio = ratio
		mod.use_collapse_triangulate = True
		bpy.ops.object.modifier_apply(modifier='Dec')
		try:
			bpy.ops.mesh.customdata_custom_splitnormals_clear()
		except Exception:  # noqa: BLE001
			pass
		for p in ob.data.polygons:
			p.use_smooth = True
		ob.data.set_sharp_from_angle(angle=math.radians(40))
	return sum(len(o.data.polygons) for o in objs)


# ------------------------------------------------------------------------------------------- items
def item_list(shoes_too=False):
	"""Boxes, pads and guns; the 22 pairs only with --shoes (or by name): meshed, they gain little over their Parts
	(work31_MESH shots) and would be over half of the import (about 160 MeshParts, 160k triangles)."""
	from models import chests, guns, shoes
	items = []
	for b in chests.ORDER:
		items.append(('Box_' + b, lambda b=b: chest_item(b)))
	for k in PAD_ICONS:
		items.append(('Pad_' + k, lambda k=k: icon_item(k)))
	for g in guns.build_all():
		items.append(('GunStand_' + g.id, lambda gid=g.id: gun_item(gid)))
	for s in shoes.WORLD1 if shoes_too else []:
		items.append(('Shoe_' + s, lambda s=s: shoe_item(s)))
	return items


def evaluated_copy(ob, dg):
	ev = ob.evaluated_get(dg)
	me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
	me.transform(ob.matrix_world)
	if ob.matrix_world.determinant() < 0:
		me.flip_normals()
	return me


def join_group(name, meshes):
	sc = bpy.context.scene
	objs = []
	for me in meshes:
		o = bpy.data.objects.new(name, me)
		sc.collection.objects.link(o)
		objs.append(o)
	bpy.ops.object.select_all(action='DESELECT')
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	if len(objs) > 1:
		bpy.ops.object.join()
	ob = bpy.context.view_layer.objects.active
	ob.name = name
	ob.data.name = name
	tri = ob.modifiers.new('Tri', 'TRIANGULATE')
	tri.quad_method = 'BEAUTY'
	tri.ngon_method = 'BEAUTY'
	tri.keep_custom_normals = True
	bpy.ops.object.modifier_apply(modifier='Tri')
	ob.data.materials.clear()
	return ob


def build_item(item_id, fn, design_scale=None):
	"""Build one item in a fresh scene; returns (objects named <id>__<group>__<mat>_<hex>, info)."""
	bb.reset_scene()
	sc = bpy.context.scene
	sc.unit_settings.system = 'NONE'
	sc.unit_settings.scale_length = 1.0
	objs, info = fn()
	dg = bpy.context.evaluated_depsgraph_get()
	groups = {}
	for ob, g, mat, rgb in objs:
		key = (g, mat, hexc(rgb))
		groups.setdefault(key, []).append(evaluated_copy(ob, dg))
	for ob, *_ in objs:
		bpy.data.objects.remove(ob)
	# pad items: scale so the item is 4 studs at its largest (ItemMeshes.place fits it to the pad anyway), bottom on y=0
	made = []
	for (g, mat, hx), meshes in sorted(groups.items()):
		made.append(join_group('%s__%s__%s_%s' % (item_id, g, mat, hx), meshes))
	if info.get('kind') == 'pad':
		lo, hi = bounds_r(made)
		k = 4.0 / max(hi[i] - lo[i] for i in range(3))
		c = Vector(((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2))
		for ob in made:
			ob.data.transform(Matrix.Diagonal((k, k, k, 1.0)) @ Matrix.Translation(-(bb.R2B @ c)))
	tris = decimate(made, TRI_BUDGET) if info.get('kind') == 'pad' else sum(len(o.data.polygons) for o in made)
	info['tris'] = tris
	return made, info


def bounds_r(objs):
	lo = [1e9] * 3
	hi = [-1e9] * 3
	for ob in objs:
		for v in ob.data.vertices:
			r = B2R @ (ob.matrix_world @ v.co)
			for i in range(3):
				lo[i] = min(lo[i], r[i])
				hi[i] = max(hi[i], r[i])
	return lo, hi


def part_record(ob):
	lo, hi = bounds_r([ob])
	_, group, rest = ob.name.split('__')
	mat, hx = rest.rsplit('_', 1)
	return dict(name=ob.name, group=group, material=mat, color=hx, centre=[(lo[i] + hi[i]) / 2 for i in range(3)],
		size=[hi[i] - lo[i] for i in range(3)], tris=len(ob.data.polygons))


def write_obj(ob, path, centre):
	"""Roblox axes, studs, relative to the part's centre; per-corner normals (custom normals kept)."""
	me = ob.data
	try:
		normals = [Vector(n.vector) for n in me.corner_normals]
	except AttributeError:
		me.calc_normals_split()
		normals = [Vector(l.normal) for l in me.loops]
	c = Vector(centre)
	lines = ['# %s' % ob.name]
	for v in me.vertices:
		r = B2R @ v.co - c
		lines.append('v %.4f %.4f %.4f' % (r.x, r.y, r.z))
	for n in normals:
		r = (B2R @ n).normalized()
		lines.append('vn %.3f %.3f %.3f' % (r.x, r.y, r.z))
	for p in me.polygons:
		lines.append('f ' + ' '.join('%d//%d' % (me.loops[li].vertex_index + 1, li + 1) for li in p.loop_indices))
	with open(path, 'w') as f:
		f.write('\n'.join(lines) + '\n')


def write_lua(manifest):
	rows = []
	for iid, it in manifest['items'].items():
		lo, hi = it['min'], it['max']
		rows.append("\t%s = { %s, %s, %s, %s, %s, %s }," % (iid, *['%.3f' % v for v in lo + hi]))
	with open(os.path.join(HERE, 'studio_item_meshes.template.lua')) as f:
		text = f.read()
	text = text.replace('--@DESIGN@', '\n'.join(rows))
	with open(LUA, 'w') as f:
		f.write(text)


def main(argv):
	if '--legacy' not in argv:
		print('export_item_meshes.py is superseded by build_item_package.py (brief 32); pass --legacy to run it anyway')
		return 2
	argv = [a for a in argv if a != '--legacy']
	obj_dir = None
	if '--obj' in argv:
		i = argv.index('--obj')
		obj_dir = argv[i + 1]
		del argv[i:i + 2]
	want0 = [a for a in argv if not a.startswith('-')]
	items = item_list('--shoes' in argv or any(w.startswith('Shoe_') for w in want0))
	if '--list' in argv:
		print(' '.join(i for i, _ in items))
		return
	want = [a for a in argv if not a.startswith('-')]
	if want:
		items = [(i, f) for i, f in items if any(i == w or i.startswith(w) for w in want)]
	os.makedirs(OUT, exist_ok=True)
	man_path = os.path.join(OUT, 'manifest.json')
	manifest = json.load(open(man_path)) if (want and os.path.exists(man_path)) else {'items': {}}
	blend_parts = []
	import tempfile
	tmp = tempfile.mkdtemp(prefix='itemmeshes_')
	for item_id, fn in items:
		made, info = build_item(item_id, fn)
		lo, hi = bounds_r(made)
		parts = [part_record(o) for o in made]
		manifest['items'][item_id] = dict(min=lo, max=hi, tris=info['tris'], parts=parts,
			**{k: v for k, v in info.items() if k not in ('tris',)})
		flag = 'OK ' if info['tris'] <= TRI_BUDGET else 'BIG'
		print('%s %-24s tris=%5d parts=%2d size=%s' % (flag, item_id, info['tris'], len(parts), [round(hi[i] - lo[i], 2) for i in range(3)]), flush=True)
		if obj_dir:
			d = os.path.join(obj_dir, item_id)
			os.makedirs(d, exist_ok=True)
			for o, pr in zip(made, parts):
				write_obj(o, os.path.join(d, o.name.split('__', 1)[1] + '.obj'), pr['centre'])
		# keep the meshes for the one FBX: save them into a library blend per item
		path = os.path.join(tmp, item_id + '.blend')
		bpy.data.libraries.write(path, set(o for o in made), fake_user=True)
		blend_parts.append((item_id, path, [o.name for o in made]))
	# order: the manifest's own order (stable), then write it
	manifest['items'] = dict(sorted(manifest['items'].items(), key=lambda kv: kv[0]))
	with open(man_path, 'w') as f:
		json.dump(manifest, f, indent=1)
	write_lua(manifest)
	export_fbx(manifest, blend_parts if not want else None)


def export_fbx(manifest, blend_parts):
	"""Every item in one FBX, laid out on a grid (8 studs apart) so the importer's preview is readable."""
	if blend_parts is None:
		print('(subset run: the FBX is written by a full run)')
		return
	bb.reset_scene()
	sc = bpy.context.scene
	sc.unit_settings.system = 'NONE'
	sc.unit_settings.scale_length = 1.0
	cols = 8
	all_objs = []
	for n, (item_id, path, names) in enumerate(blend_parts):
		with bpy.data.libraries.load(path) as (src, dst):
			dst.objects = [nm for nm in src.objects if nm in names]
		gx, gz = n % cols, n // cols
		off = bb.R2B @ Vector((gx * 8.0, 0.0, gz * 8.0))
		for ob in dst.objects:
			sc.collection.objects.link(ob)
			ob.data.transform(Matrix.Translation(off))
			all_objs.append(ob)
	bpy.ops.object.select_all(action='DESELECT')
	for o in all_objs:
		o.select_set(True)
	path = os.path.join(OUT, 'HoodItemMeshes.fbx')
	bpy.ops.export_scene.fbx(
		filepath=path, use_selection=True, object_types={'MESH'}, apply_scale_options='FBX_SCALE_UNITS',
		axis_forward='Z', axis_up='Y', use_mesh_modifiers=False, mesh_smooth_type='OFF', use_tspace=False,
		path_mode='COPY', embed_textures=False, bake_anim=False, add_leaf_bones=False, bake_space_transform=True,
	)
	print('FBX %s: %d MeshParts, %d tris, %.1f MB' % (path, len(all_objs), sum(len(o.data.polygons) for o in all_objs), os.path.getsize(path) / 1e6))
	check_fbx(path, manifest)


def check_fbx(path, manifest):
	"""Load the FBX back with the importer's axes: every item's parts are there and each item has its design size."""
	bb.reset_scene()
	bpy.ops.import_scene.fbx(filepath=path, axis_forward='Z', axis_up='Y')
	by_item = {}
	for ob in bpy.context.scene.objects:
		if ob.type == 'MESH':
			by_item.setdefault(ob.name.split('__')[0], []).append(ob)
	bad = 0
	for iid, it in manifest['items'].items():
		objs = by_item.get(iid, [])
		lo, hi = bounds_r(objs) if objs else ([0] * 3, [0] * 3)
		size = [hi[i] - lo[i] for i in range(3)]
		want = [it['max'][i] - it['min'][i] for i in range(3)]
		ok = len(objs) == len(it['parts']) and all(abs(size[i] - want[i]) < 0.02 for i in range(3))
		bad += not ok
		if not ok:
			print('FBX BAD', iid, len(objs), len(it['parts']), size, want)
	print('FBX re-import: %d items, %d bad' % (len(manifest['items']), bad))


if __name__ == '__main__':
	main(sys.argv[1:])
