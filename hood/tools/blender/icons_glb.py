"""UI pictures from the user's blocky designs (brief 32): the gun icons (Gun_<Id>) and the Robux pass icons, rendered from
the import package's GLBs (hood/art/models/items/Items_*.glb) in the same presentation as the other icons in
hood/art/icons3d: transparent 512 px, glossy Cycles (hdkit's camera, lights and world), the thick navy outline, optional
sparkles, the same framing as before (guns in profile, muzzle to the screen-right, long guns tilted up; pass items from
the front, a little from above).

  $PY hood/tools/blender/icons_glb.py                      # all -> hood/art/icons3d/<Id>.png
  $PY hood/tools/blender/icons_glb.py Gun_AK VIP --out /tmp/x --res 256 --samples 12
  $PY hood/tools/blender/icons_glb.py --list
($PY = a Python with bpy, see README.)
"""
import argparse
import math
import os
import sys
import tempfile
import time

import bpy
from mathutils import Euler

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hdkit as K  # noqa: E402

ITEMS = os.path.join(K.HOOD, 'art', 'models', 'items')

ICONS = {}


def icon(iid, item, package, view, fill=0.9, tilt=0.0, **opts):
	ICONS[iid] = dict(item=item, package=package, view=view, fill=fill, tilt=tilt, opts=opts)


# Guns: seen from their right side (Blender +X; the GLB's -Z muzzle is Blender +Y = the screen-right), a touch from the
# muzzle side and above, like the old Gun_* icons; the long guns tilt their muzzle up (as the old Shotgun/Tommy/AK did).
GUN_VIEW = (1.0, 0.16, 0.26)
for gid, tilt, sp in (('Pistol', 0, 0), ('Revolver', 0, 0), ('Uzi', 0, 0), ('Shotgun', 28, 0), ('Tommy', 28, 0), ('AK', 28, 0),
		('Deagle', 0, 2), ('Minigun', 0, 2), ('Blaster', 0, 3), ('Diamond', 0, 4)):
	icon('Gun_' + gid, 'Gun_' + gid, 'Items_Guns.glb', GUN_VIEW, fill=0.92, tilt=tilt, sparkles=sp, seed=11)

# Pass icons: the Robux pad's prize, from the front (the GLB's -Z = Blender +Y), a little from the left and above.
PAD_VIEW = (-0.22, 1.0, 0.34)
for iid, item, seed in (('VIP', 'Pad_VIP', 6), ('DoubleCash', 'Pad_DoubleCash', 7), ('DoublePower', 'Pad_DoubleRep', 4),
		('AutoFight', 'Pad_AutoShoot', 8), ('AutoCollect', 'Pad_AutoCollect', 9), ('AutoOpen', 'Pad_AutoOpen', 12),
		('TripleOpen', 'Pad_TripleOpen', 3), ('Lucky', 'Pad_Lucky', 5), ('Speed2x', 'Pad_Speed2x', 18),
		('ExtraEquip', 'Pad_ExtraEquip', 14)):
	icon(iid, item, 'Items_Pads.glb', PAD_VIEW, fill=0.88, sparkles=3, seed=seed)


def style_materials(objs):
	"""The icon look on the GLB's materials: palette swatches stay crisp (closest), glossy plastic with a clear coat;
	glow parts are emissive in their colour."""
	seen = set()
	for ob in objs:
		for slot in ob.material_slots:
			m = slot.material
			if not m or m.name in seen or not m.use_nodes:
				continue
			seen.add(m.name)
			glow = '_Glow_' in ob.name or '_Glow_' in m.name
			for n in m.node_tree.nodes:
				if n.type == 'TEX_IMAGE':
					n.interpolation = 'Closest'
				if n.type == 'BSDF_PRINCIPLED':
					n.inputs['Roughness'].default_value = 0.28
					if 'Coat Weight' in n.inputs:
						n.inputs['Coat Weight'].default_value = 0.3
					if glow:
						col = n.inputs['Base Color'].default_value
						n.inputs['Emission Color'].default_value = col
						n.inputs['Emission Strength'].default_value = 1.25


def build(spec):
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=os.path.join(ITEMS, spec['package']))
	new = [ob for ob in bpy.data.objects if ob not in before]
	keep_root = None
	for ob in new:
		if ob.name.split('.')[0] == spec['item'] and ob.type == 'EMPTY':
			keep_root = ob
	assert keep_root, 'no %s in %s' % (spec['item'], spec['package'])
	keep = {keep_root} | set(keep_root.children_recursive)
	for ob in new:
		if ob not in keep:
			bpy.data.objects.remove(ob, do_unlink=True)
	# the item at the origin (the package lays items out in a row), its own tilt about the screen axis
	keep_root.location = (0, 0, 0)
	keep_root.rotation_mode = 'XYZ'
	keep_root.rotation_euler = Euler((math.radians(spec['tilt']), 0, 0))
	meshes = [ob for ob in keep if ob.type == 'MESH']
	for i, ob in enumerate(meshes):
		ob.pass_index = 1  # one line group: the outline only (the palette carries the detail)
		K.C.objs.append(ob)
	style_materials(meshes)


def render_icon(iid, out_dir, res, ss, samples):
	t0 = time.time()
	spec = ICONS[iid]
	sc = K.reset(res * ss, samples)
	K.world(sc)
	build(spec)
	cam, centre, dist = K.frame_camera(sc, spec['view'], spec['fill'] * K.LOOK['frame'], 85.0, 0.0)
	K.lights(sc, cam, centre, dist, 1.0)
	tmp = tempfile.mkdtemp(prefix='hdg_')
	raw = os.path.join(tmp, 'beauty.png')
	K.compositor_index(sc, os.path.join(tmp, 'ix_'))
	sc.render.filepath = raw
	bpy.ops.render.render(write_still=True)
	ix = [f for f in os.listdir(tmp) if f.startswith('ix_idx')]
	out_png = os.path.join(out_dir, iid + '.png')
	K.finish(raw, os.path.join(tmp, ix[0]) if ix else '', out_png, ss, spec['opts'])
	for f in os.listdir(tmp):
		os.remove(os.path.join(tmp, f))
	os.rmdir(tmp)
	print('rendered %s in %.1fs' % (out_png, time.time() - t0), flush=True)


def main(argv):
	ap = argparse.ArgumentParser()
	ap.add_argument('ids', nargs='*')
	ap.add_argument('--res', type=int, default=512)
	ap.add_argument('--ss', type=int, default=2)
	ap.add_argument('--samples', type=int, default=40)
	ap.add_argument('--out', default=K.OUT)
	ap.add_argument('--list', action='store_true')
	a = ap.parse_args(argv)
	if a.list:
		print(' '.join(ICONS))
		return
	for iid in a.ids or list(ICONS):
		render_icon(iid, a.out, a.res, a.ss, a.samples)


if __name__ == '__main__':
	main(sys.argv[1:])
