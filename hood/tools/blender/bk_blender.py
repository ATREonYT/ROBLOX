"""Blender side of BoxKit: turn a boxkit.Model into meshes, light it, render it with Cycles.

Coordinates: models are authored in Roblox space. Roblox (x, y, z) maps to Blender (-x, z, y), a proper
rotation that also lines Roblox's front (-z) up with Blender's front (-y). The FBX exporter with
Forward = Z, Up = Y undoes exactly this, so exported meshes land in Roblox space 1:1.
"""
import math
import os

import bpy  # first: bmesh and mathutils load with it
import bmesh
import numpy as np
from mathutils import Matrix, Vector

import boxkit as bk

R2B = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))

# Global look knobs (render.py may override from the command line while tuning).
LOOK = dict(light=0.15, world=0.3, view='Standard', exposure=0.0, contrast='None')


def to_b(v):
	return R2B @ Vector(v)


def srgb_to_linear(c):
	c = c / 255.0
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(rgb):
	return tuple(srgb_to_linear(c) for c in rgb) + (1.0,)


# ---------- materials ----------
# Cycles look per material kind. Tuned for toy-like saturated plastic: soft speculars, clear coat on
# smooth plastic, polished gold, faceted glass with a tint, neon that glows (bloom is added in post).
MATERIALS = {
	'plastic': dict(rough=0.42, metal=0.0, coat=0.0),
	'smooth': dict(rough=0.26, metal=0.0, coat=0.35),
	'metal': dict(rough=0.34, metal=0.55, coat=0.0),
	'gold': dict(rough=0.22, metal=0.85, coat=0.0),
	'neon': dict(rough=0.4, metal=0.0, coat=0.0, emit=1.25),
	'glass': dict(rough=0.06, metal=0.0, coat=0.0, glass=True),
}

_mat_cache = {}


def material(rgb, kind):
	key = (rgb, kind)
	if key in _mat_cache:
		return _mat_cache[key]
	m = bpy.data.materials.new('%s_%02x%02x%02x' % (kind, *rgb))
	nt = m.node_tree
	bs = nt.nodes.get('Principled BSDF')
	spec = MATERIALS[kind]
	col = lin(rgb)
	bs.inputs['Base Color'].default_value = col
	bs.inputs['Roughness'].default_value = spec['rough']
	bs.inputs['Metallic'].default_value = spec['metal']
	bs.inputs['Coat Weight'].default_value = spec['coat']
	bs.inputs['Coat Roughness'].default_value = 0.08
	if spec.get('emit'):
		bs.inputs['Emission Color'].default_value = col
		bs.inputs['Emission Strength'].default_value = spec['emit']
	if spec.get('glass'):
		# Stylised gem rather than physical glass: mostly opaque saturated colour with a glossy coat,
		# a faint inner glow, and 30% see-through so neon cores show (like Roblox Glass at 0.35).
		bs.inputs['Alpha'].default_value = 0.72
		bs.inputs['Coat Weight'].default_value = 1.0
		bs.inputs['Coat Roughness'].default_value = 0.03
		bs.inputs['Specular IOR Level'].default_value = 0.8
		bs.inputs['Emission Color'].default_value = col
		bs.inputs['Emission Strength'].default_value = 0.3
	m.diffuse_color = col
	_mat_cache[key] = m
	return m


# ---------- meshes ----------
def _ngon_ring(x, radius, n, phase):
	return [(x, radius * math.cos(phase + 2 * math.pi * i / n), radius * math.sin(phase + 2 * math.pi * i / n)) for i in range(n)]


def local_geometry(p):
	"""Vertices and faces of one primitive in its own Roblox-local space."""
	sx, sy, sz = p.size
	x, y, z = sx / 2, sy / 2, sz / 2
	if p.kind == 'box':
		v = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
		f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 4, 7, 3), (1, 2, 6, 5), (3, 7, 6, 2), (0, 1, 5, 4)]
		return v, f, False
	if p.kind == 'wedge':
		v = [(-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z), (-x, y, z), (x, y, z)]
		f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
		return v, f, False
	if p.kind in ('cyl', 'prism'):
		if p.kind == 'cyl':
			n = 12 if p.stud else 32
			radius, phase = y, 0.0
		else:
			n = p.sides
			radius = y / math.cos(math.pi / n)
			phase = math.radians(p.spin) + math.pi / n  # flats face +Y when spin is 0
		v = _ngon_ring(-x, radius, n, phase) + _ngon_ring(x, radius, n, phase)
		f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
		f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
		return v, f, p.kind == 'cyl'
	if p.kind == 'ball':
		bm = bmesh.new()
		bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=x)
		v = [tuple(vert.co) for vert in bm.verts]
		f = [tuple(vert.index for vert in face.verts) for face in bm.faces]
		bm.free()
		return v, f, True
	raise ValueError(p.kind)


def prim_mesh(p, name, uv=None):
	"""Blender mesh for one primitive with world transform baked in (Blender space, DU)."""
	verts, faces, smooth = local_geometry(p)
	world = [to_b(bk.add(bk.mat_vec(p.rot, v), p.pos)) for v in verts]
	me = bpy.data.meshes.new(name)
	me.from_pydata(world, [], faces)
	me.update()
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(me)
	bm.free()
	for poly in me.polygons:
		poly.use_smooth = True
	me.set_sharp_from_angle(angle=math.radians(30 if smooth else 1))
	if uv is not None:
		layer = me.uv_layers.new(name='UVMap')
		for loop in layer.data:
			loop.uv = uv
	return me


def build(model, collection=None, uv_for=None, bevel_scale=1.0):
	"""Create one object per primitive. Returns the list of objects."""
	collection = collection or bpy.context.scene.collection
	objs = []
	for i, p in enumerate(model.prims):
		name = '%s_%03d_%s' % (model.id, i, p.name or p.kind)
		me = prim_mesh(p, name, uv_for(p) if uv_for else None)
		me.materials.append(material(p.color, p.mat))
		ob = bpy.data.objects.new(name, me)
		ob['kind'] = p.mat
		ob['rgb'] = p.color
		collection.objects.link(ob)
		bw = p.bevel * bevel_scale
		if bw > 0:
			mod = ob.modifiers.new('Bevel', 'BEVEL')
			mod.width = bw
			mod.segments = 2
			mod.limit_method = 'ANGLE'
			mod.angle_limit = math.radians(40)
			mod.harden_normals = True
			mod.use_clamp_overlap = True
		if p.mat == 'neon':
			ob.visible_shadow = False  # it is the light source
		objs.append(ob)
	return objs


# ---------- scene ----------
def reset_scene():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	_mat_cache.clear()
	sc = bpy.context.scene
	sc.unit_settings.system = 'NONE'
	return sc


def setup_render(sc, res, samples=96, transparent=True, look='AgX'):
	sc.render.engine = 'CYCLES'
	cy = sc.cycles
	cy.device = 'CPU'
	cy.samples = samples
	cy.use_adaptive_sampling = True
	cy.adaptive_threshold = 0.02
	cy.use_denoising = True
	cy.denoiser = 'OPENIMAGEDENOISE'
	cy.max_bounces = 10
	cy.diffuse_bounces = 3
	cy.glossy_bounces = 4
	cy.transmission_bounces = 10
	cy.transparent_max_bounces = 8
	cy.caustics_reflective = False
	cy.caustics_refractive = False
	cy.sample_clamp_indirect = 8.0
	sc.render.resolution_x = sc.render.resolution_y = res
	sc.render.resolution_percentage = 100
	sc.render.film_transparent = transparent
	sc.render.image_settings.file_format = 'PNG'
	sc.render.image_settings.color_mode = 'RGBA'
	sc.render.image_settings.color_depth = '8'
	sc.view_settings.view_transform = LOOK['view']
	sc.view_settings.look = LOOK['contrast'] if LOOK['view'] == 'AgX' else 'None'
	sc.view_settings.exposure = LOOK['exposure']
	sc.view_layers[0].use_pass_emit = True
	try:
		sc.render.threads_mode = 'AUTO'
	except Exception:
		pass


def world(sc, strength=0.9):
	"""Studio gradient: cool sky above, warm bounce below. Metals and gold reflect it."""
	w = bpy.data.worlds.new('Studio')
	sc.world = w
	nt = w.node_tree
	nt.nodes.clear()
	out = nt.nodes.new('ShaderNodeOutputWorld')
	bg = nt.nodes.new('ShaderNodeBackground')
	tc = nt.nodes.new('ShaderNodeTexCoord')
	sep = nt.nodes.new('ShaderNodeSeparateXYZ')
	ramp = nt.nodes.new('ShaderNodeValToRGB')
	mapr = nt.nodes.new('ShaderNodeMapRange')
	nt.links.new(tc.outputs['Generated'], sep.inputs[0])
	nt.links.new(sep.outputs['Z'], mapr.inputs['Value'])
	mapr.inputs['From Min'].default_value = -1.0
	mapr.inputs['From Max'].default_value = 1.0
	nt.links.new(mapr.outputs['Result'], ramp.inputs['Fac'])
	cr = ramp.color_ramp
	cr.elements[0].position = 0.0
	cr.elements[0].color = (0.34, 0.29, 0.24, 1)  # warm floor bounce keeps gold sides from going brown
	cr.elements[1].position = 0.52
	cr.elements[1].color = (0.80, 0.80, 0.82, 1)
	e = cr.elements.new(0.75)
	e.color = (0.62, 0.74, 0.98, 1)
	e2 = cr.elements.new(1.0)
	e2.color = (0.85, 0.9, 1.0, 1)
	nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
	bg.inputs['Strength'].default_value = strength * LOOK['world'] / 0.85
	nt.links.new(bg.outputs['Background'], out.inputs['Surface'])
	return w


def area_light(sc, name, loc, target, size, energy, color=(1, 1, 1), spread=180):
	ld = bpy.data.lights.new(name, 'AREA')
	ld.shape = 'DISK'
	ld.size = size
	ld.energy = energy
	ld.color = color
	ld.spread = math.radians(spread)
	ob = bpy.data.objects.new(name, ld)
	sc.collection.objects.link(ob)
	ob.location = loc
	ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
	return ob


def scene_bounds(objs):
	dg = bpy.context.evaluated_depsgraph_get()
	pts = []
	for ob in objs:
		ev = ob.evaluated_get(dg)
		me = ev.to_mesh()
		mw = ob.matrix_world
		pts.extend(mw @ v.co for v in me.vertices)
		ev.to_mesh_clear()
	arr = np.array([tuple(p) for p in pts])
	return arr


def camera_fit(sc, pts, view_dir_r, fill=0.84, lens=70.0, roll=0.0):
	"""Perspective camera looking along -view_dir (view_dir points from the subject to the camera,
	given in Roblox space) that frames all points with `fill` of the frame used."""
	cam = bpy.data.cameras.new('Cam')
	cam.lens = lens
	cam.sensor_fit = 'AUTO'
	cam.clip_start = 0.05
	cam.clip_end = 500
	co = bpy.data.objects.new('Cam', cam)
	sc.collection.objects.link(co)
	sc.camera = co
	d = to_b(bk.norm(view_dir_r))
	lo, hi = pts.min(axis=0), pts.max(axis=0)
	centre = Vector((lo + hi) / 2)
	radius = float(np.linalg.norm(hi - lo)) / 2
	fov = 2 * math.atan(18.0 / lens)  # 36 mm sensor, square frame
	dist = radius / math.tan(fov / 2) * 1.1
	for _ in range(6):
		co.location = centre + d * dist
		q = (-d).to_track_quat('-Z', 'Y')
		co.rotation_euler = q.to_euler()
		if roll:
			co.rotation_euler.rotate_axis('Z', math.radians(roll))
		bpy.context.view_layer.update()
		m = co.matrix_world.inverted()
		local = np.array([tuple(m @ Vector(p)) for p in pts])
		# Perspective projection to the image plane (tan space).
		px = local[:, 0] / -local[:, 2]
		py = local[:, 1] / -local[:, 2]
		half = math.tan(fov / 2)
		ext = max(px.max() - px.min(), py.max() - py.min()) / 2
		cx, cy = (px.max() + px.min()) / 2, (py.max() + py.min()) / 2
		# Re-aim at the projected centre, then scale distance so the extent matches the fill.
		right, upv = Vector(co.matrix_world.col[0][:3]), Vector(co.matrix_world.col[1][:3])
		centre = centre + (right * cx + upv * cy) * dist
		dist *= ext / (half * fill)
	co.location = centre + d * dist
	co.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
	if roll:
		co.rotation_euler.rotate_axis('Z', math.radians(roll))
	bpy.context.view_layer.update()
	return co, centre, dist


def light_rig(sc, cam_ob, centre, dist, key=1.0, rim=1.0, rim_color=(1.0, 0.97, 0.92)):
	"""Three-point studio light placed relative to the camera so every shot is lit the same way."""
	mw = cam_ob.matrix_world
	right = Vector(mw.col[0][:3])
	up = Vector(mw.col[1][:3])
	back = Vector(mw.col[2][:3])  # points from subject toward the camera
	c = Vector(centre)
	r = dist
	e = r * r * LOOK['light']  # energy grows with distance squared
	area_light(sc, 'Key', c + (back * 0.9 - right * 0.75 + up * 0.85).normalized() * r, c, r * 0.55, 95 * e * key, (1.0, 0.96, 0.9))
	area_light(sc, 'Fill', c + (back * 1.0 + right * 0.9 - up * 0.1).normalized() * r, c, r * 0.9, 32 * e, (0.86, 0.92, 1.0))
	area_light(sc, 'Top', c + (up * 1.0 + back * 0.15).normalized() * r, c, r * 0.8, 40 * e, (1.0, 1.0, 1.0))
	area_light(sc, 'RimL', c + (-back * 0.9 - right * 0.8 + up * 0.35).normalized() * r, c, r * 0.35, 70 * e * rim, rim_color)
	area_light(sc, 'RimR', c + (-back * 0.9 + right * 0.85 + up * 0.25).normalized() * r, c, r * 0.35, 65 * e * rim, rim_color)


def compositor_emission(sc, emit_path_prefix):
	"""Main image passes through; the Emission pass is saved next to it for the bloom pass."""
	tree = bpy.data.node_groups.new('Comp', 'CompositorNodeTree')
	sc.compositing_node_group = tree
	rl = tree.nodes.new('CompositorNodeRLayers')
	out = tree.nodes.new('NodeGroupOutput')
	tree.interface.new_socket('Image', in_out='OUTPUT', socket_type='NodeSocketColor')
	tree.links.new(rl.outputs['Image'], out.inputs[0])
	fo = tree.nodes.new('CompositorNodeOutputFile')
	fo.file_output_items.new('RGBA', 'emit')
	fo.directory = os.path.dirname(emit_path_prefix) + '/'
	fo.file_name = os.path.basename(emit_path_prefix)
	fo.format.media_type = 'IMAGE'
	fo.format.file_format = 'PNG'
	fo.format.color_mode = 'RGB'
	tree.links.new(rl.outputs['Emission'], fo.inputs['emit'])
	return fo


def render_to(sc, path):
	sc.render.filepath = path
	bpy.ops.render.render(write_still=True)


# ---------- post: bloom + outline in numpy ----------
def load_png(path):
	img = bpy.data.images.load(path, check_existing=False)
	w, h = img.size
	ch = img.channels
	buf = np.empty(w * h * ch, dtype=np.float32)
	img.pixels.foreach_get(buf)
	bpy.data.images.remove(img)
	arr = buf.reshape(h, w, ch)
	if ch == 3:
		arr = np.concatenate([arr, np.ones((h, w, 1), np.float32)], axis=2)
	return arr


def save_png(arr, path):
	h, w, _ = arr.shape
	img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
	img.colorspace_settings.name = 'sRGB'
	img.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
	img.filepath_raw = path
	img.file_format = 'PNG'
	img.save()
	bpy.data.images.remove(img)


def _box_blur(a, r, axis):
	if r < 1:
		return a
	pad = [(0, 0)] * a.ndim
	pad[axis] = (r + 1, r)
	c = np.cumsum(np.pad(a, pad, mode='edge'), axis=axis)
	n = a.shape[axis]
	hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
	lo = np.take(c, np.arange(0, n), axis=axis)
	return (hi - lo) / (2 * r + 1)


def blur(a, sigma):
	"""Gaussian-ish blur: three box passes per axis."""
	r = max(1, int(round(sigma * 0.87)))
	for _ in range(3):
		a = _box_blur(a, r, 0)
		a = _box_blur(a, r, 1)
	return a


def dilate(mask, radius):
	"""Round-ish dilation by alternating 4- and 8-neighbour max filters."""
	m = mask.copy()
	for i in range(int(radius)):
		p = np.pad(m, 1, mode='constant')
		n = np.maximum.reduce([p[1:-1, 1:-1], p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
		if i % 2 == 1:
			n = np.maximum.reduce([n, p[:-2, :-2], p[:-2, 2:], p[2:, :-2], p[2:, 2:]])
		m = n
	return m


def over(top, bottom):
	"""Straight-alpha 'over' composite."""
	ta, ba = top[..., 3:4], bottom[..., 3:4]
	oa = ta + ba * (1 - ta)
	rgb = (top[..., :3] * ta + bottom[..., :3] * ba * (1 - ta)) / np.maximum(oa, 1e-6)
	return np.concatenate([rgb, oa], axis=2)


def sparkle_layer(h, w, alpha, n, seed, size):
	"""White four-point sparkles scattered just outside/along the silhouette (rarity bling)."""
	rng = np.random.default_rng(seed)
	edge = (dilate((alpha > 0.35).astype(np.float32), int(size * 0.6)) > 0) & (alpha < 0.2)
	ys, xs = np.nonzero(edge)
	layer = np.zeros((h, w), np.float32)
	if len(xs) == 0:
		return layer
	yy, xx = np.mgrid[0:h, 0:w]
	picks = rng.choice(len(xs), size=min(n * 6, len(xs)), replace=False)
	chosen = []
	for k in picks:
		p = (ys[k], xs[k])
		if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 > (size * 4) ** 2 for q in chosen):
			chosen.append(p)
		if len(chosen) >= n:
			break
	for i, (cy, cx) in enumerate(chosen):
		r = size * (0.7 + 0.6 * rng.random())
		dx, dy = np.abs(xx - cx) / r, np.abs(yy - cy) / r
		arm_h = np.exp(-dy * dy * 60) * np.clip(1 - dx, 0, 1) ** 2
		arm_v = np.exp(-dx * dx * 60) * np.clip(1 - dy, 0, 1) ** 2
		core = np.exp(-(dx * dx + dy * dy) * 18)
		layer = np.maximum(layer, np.clip(arm_h + arm_v + core, 0, 1))
	return layer


def finish(beauty_path, emit_path, out_path, outline_px=10, outline_rgb=(0.07, 0.06, 0.13), glow=1.0, shadow=0.35,
		backglow=None, sparkles=0, seed=1):
	"""Bloom from the emission pass, then a dark outline and soft shadow around the silhouette.
	backglow=(r, g, b, strength) adds a soft tier-coloured halo behind the model; sparkles adds stars."""
	img = load_png(beauty_path)
	h, w, _ = img.shape
	solid0 = img[..., 3].copy()
	if emit_path and os.path.exists(emit_path) and glow > 0:
		em = load_png(emit_path)[..., :3]
		g = blur(em, w * 0.012) * 0.9 + blur(em, w * 0.035) * 0.8
		g = g * glow
		ga = np.clip(g.max(axis=2, keepdims=True), 0, 1)
		glow_layer = np.concatenate([g / np.maximum(ga, 1e-6), ga], axis=2)
		glow_layer[..., :3] = np.clip(glow_layer[..., :3], 0, 1)
		# Glow adds light over the object and spills onto the transparent background.
		a = img[..., 3:4]
		lit = np.clip(img[..., :3] + g * a * 0.25, 0, 1)
		img = np.concatenate([lit, a], axis=2)
		img = over(img, glow_layer * np.array([1, 1, 1, 0.9], np.float32))
	alpha = img[..., 3]
	if outline_px > 0:
		solid = (alpha > 0.35).astype(np.float32)
		ring = dilate(solid, outline_px)
		ring = np.clip(blur(ring, 0.9) * 1.15, 0, 1)
		outline = np.zeros_like(img)
		outline[..., :3] = outline_rgb
		outline[..., 3] = ring
		img = over(img, outline)
		if shadow > 0:
			sh = blur(ring, w * 0.012)
			sh = np.roll(sh, -int(w * 0.012), axis=0)  # drop the shadow down (rows run bottom-up)
			shadow_layer = np.zeros_like(img)
			shadow_layer[..., 3] = sh * shadow
			img = over(img, shadow_layer)
	if backglow:
		halo = blur(dilate((solid0 > 0.35).astype(np.float32), int(w * 0.02)), w * 0.06)
		halo = np.clip(halo * 1.6, 0, 1) * backglow[3]
		layer = np.zeros_like(img)
		layer[..., :3] = backglow[:3]
		layer[..., 3] = halo
		img = over(img, layer)
	if sparkles:
		sp = sparkle_layer(h, w, solid0, sparkles, seed, w * 0.045)
		layer = np.zeros_like(img)
		layer[..., :3] = (1.0, 0.98, 0.9)
		layer[..., 3] = sp
		img = over(layer, img)
	save_png(img, out_path)
