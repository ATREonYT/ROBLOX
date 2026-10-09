"""hdkit: the modelling, lighting and post kit behind icons_hd.py (brief 19): smooth chunky cartoon 3D, glossy, a square-tile pattern
on the surfaces, a thick navy outline baked in, transparent 512x512 PNGs ready to upload.

These are render-only models built straight in Blender (bevelled boxes, swept bands, lathes, metaballs, text).
The live in-game fallback for each id is still the BoxKit part model in models/icons.py (IconModels.build), so
nothing breaks before the PNGs are uploaded.

Look recipe (measured on brief/ref17/user_26-28):
  - outline navy #0C0A34, ~3.4% of the canvas outside the silhouette, ~45% of that between parts;
  - saturated base colours through a hue-shifted ramp (dark -> base -> light) driven by the key light from the camera's
    upper left: coloured, never grey, shadows; calibrated on 10/50/90% colour percentiles of the reference;
  - a grid of soft raised squares on most surfaces, lighter than the base (darker on white);
  - speculars only from the small area lights (the world is hidden from glossy rays): crisp white glints, no grey sheen.
Space: Blender axes. x = screen right, z = up, the camera looks toward +y from the front (-y).
"""
import math
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
tempfile.tempdir = os.environ.get('BK_TMP') or None

import bpy  # noqa: E402
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Euler, Vector  # noqa: E402

import bk_blender as bb  # noqa: E402  (png io, blur, over)

HOOD = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HOOD, 'art', 'icons3d')
NAVY = (12, 10, 52)
FONT_PATHS = ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/Library/Fonts/Arial Bold.ttf',
	'/System/Library/Fonts/Supplemental/Arial Bold.ttf']

# Look knobs (tuned in rounds against the reference; see brief/out19/ICONS).
LOOK = dict(world=0.85, key=0.4, fill=0.2, rim=0.6, top=0.25, exposure=0.0, outline=0.034, inner=0.45, sat=1.15, spec=0.35)


def lin(rgb):
	return bb.lin(rgb)


def mix_rgb(a, b, t):
	return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


# ------------------------------------------------------------------------------------------- scene
class Ctx:
	"""Per-icon build state: next line group (pass index) and the objects made."""
	def __init__(self):
		self.objs = []
		self.group = 0
		self.mats = {}
		self.ldots = []  # DOT_PRODUCT nodes of the shading ramps (get the key-light direction)

	def new_group(self):
		self.group += 1
		return self.group


C = Ctx()


def reset(res, samples):
	global C
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bb._mat_cache.clear()
	_TILE.clear()
	_FONT.clear()
	C = Ctx()
	sc = bpy.context.scene
	sc.unit_settings.system = 'NONE'
	sc.render.engine = 'CYCLES'
	cy = sc.cycles
	cy.device = 'CPU'
	cy.samples = samples
	cy.use_adaptive_sampling = True
	cy.adaptive_threshold = 0.03
	cy.use_denoising = True
	cy.denoiser = 'OPENIMAGEDENOISE'
	cy.max_bounces = 6
	cy.diffuse_bounces = 2
	cy.glossy_bounces = 3
	cy.transparent_max_bounces = 4
	cy.caustics_reflective = False
	cy.caustics_refractive = False
	cy.sample_clamp_indirect = 6.0
	sc.render.resolution_x = sc.render.resolution_y = res
	sc.render.resolution_percentage = 100
	sc.render.film_transparent = True
	sc.render.image_settings.file_format = 'PNG'
	sc.render.image_settings.color_mode = 'RGBA'
	sc.render.image_settings.color_depth = '8'
	sc.view_settings.view_transform = 'Standard'
	sc.view_settings.look = 'None'
	sc.view_settings.exposure = LOOK['exposure']
	sc.view_layers[0].use_pass_object_index = True
	return sc


def world(sc):
	w = bpy.data.worlds.new('Soft')
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
	cr.elements[0].color = (0.62, 0.55, 0.5, 1)  # warm bounce from below keeps shadows coloured
	cr.elements[1].position = 0.5
	cr.elements[1].color = (0.9, 0.9, 0.92, 1)
	e = cr.elements.new(1.0)
	e.color = (0.82, 0.9, 1.0, 1)
	nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
	bg.inputs['Strength'].default_value = LOOK['world']
	nt.links.new(bg.outputs['Background'], out.inputs['Surface'])
	# The world lights the toys but is not seen in their reflections: speculars then come only from the small area
	# lights, i.e. crisp white glints like the reference instead of a grey sheen that washes the colours out.
	try:
		w.cycles_visibility.glossy = LOOK.get('world_glossy', False)
	except AttributeError:
		pass


def compositor_index(sc, path_prefix):
	"""Main image as usual; the object-index pass (line groups) saved as a float EXR for the inner lines."""
	tree = bpy.data.node_groups.new('Comp', 'CompositorNodeTree')
	sc.compositing_node_group = tree
	rl = tree.nodes.new('CompositorNodeRLayers')
	out = tree.nodes.new('NodeGroupOutput')
	tree.interface.new_socket('Image', in_out='OUTPUT', socket_type='NodeSocketColor')
	tree.links.new(rl.outputs['Image'], out.inputs[0])
	fo = tree.nodes.new('CompositorNodeOutputFile')
	fo.file_output_items.new('FLOAT', 'idx')
	fo.directory = os.path.dirname(path_prefix) + '/'
	fo.file_name = os.path.basename(path_prefix)
	fo.format.media_type = 'IMAGE'
	fo.format.file_format = 'OPEN_EXR'
	fo.format.color_depth = '32'
	tree.links.new(rl.outputs['Object Index'], fo.inputs['idx'])


# ------------------------------------------------------------------------------------------- materials
_TILE = {}


def tile_image(kind='square'):
	"""A 64 px tile: one soft raised rounded square (the reference's surface grid)."""
	if kind in _TILE:
		return _TILE[kind]
	n = 64
	y, x = np.mgrid[0:n, 0:n] + 0.5
	px, py = np.abs(x / n - 0.5), np.abs(y / n - 0.5)
	b, r = 0.30, 0.07
	qx, qy = np.maximum(px - b + r, 0), np.maximum(py - b + r, 0)
	d = np.sqrt(qx * qx + qy * qy) + np.minimum(np.maximum(px - b + r, py - b + r), 0) - r
	h = np.clip(-d / 0.045, 0, 1)
	h = h * h * (3 - 2 * h)
	img = bpy.data.images.new('tile_' + kind, n, n, alpha=False, float_buffer=True)
	img.colorspace_settings.name = 'Non-Color'
	rgba = np.dstack([h, h, h, np.ones_like(h)]).astype(np.float32)
	img.pixels.foreach_set(rgba.ravel())
	img.pack()
	_TILE[kind] = img
	return img


def ramp_colors(rgb):
	"""Hue-shifted shadow and light tones for a base colour: shadows go warmer/deeper (never grey), lights go
	toward a warm yellow-white, like the reference's toon shading."""
	r, g, b = rgb
	if min(rgb) > 200:  # white plastic: cool blue shadows
		return (int(r * 0.78), int(g * 0.86), int(b * 0.94)), (255, 255, 255)
	if b > r:  # cool colours: lights go toward a cool white (a warm light turns blue lavender)
		return (int(r * 0.7), int(g * 0.72), int(b * 0.82)), mix_rgb(rgb, (236, 246, 255), 0.2)
	dark = (int(r * 0.88), int(g * 0.7), int(b * 0.8))
	light = mix_rgb(rgb, (255, 240, 170), 0.16)
	return dark, light


def mat(rgb, rough=0.38, coat=0.2, tiles=0.0, tile_rgb=None, density=4.0, bump=0.35, metal=0.0, emit=0.0, name=None,
		dark=None, light=None, ramp=True, spec=None):
	"""Glossy toy plastic. The base colour runs through a 3-stop ramp driven by how much a surface faces the key
	light (dark -> rgb -> light; hue-shifted defaults from ramp_colors). tiles>0 adds the raised-square grid
	(world space, `density` squares per unit) tinted toward tile_rgb (default: a lighter version of rgb)."""
	key = (rgb, rough, coat, tiles, tile_rgb, density, bump, metal, emit, dark, light, ramp, spec)
	if key in C.mats:
		return C.mats[key]
	m = bpy.data.materials.new(name or 'm_%02x%02x%02x' % tuple(rgb))
	nt = m.node_tree
	bs = nt.nodes.get('Principled BSDF')
	bs.inputs['Base Color'].default_value = lin(rgb)
	base_socket = None
	if ramp:
		d0, l0 = ramp_colors(rgb)
		geo0 = nt.nodes.new('ShaderNodeNewGeometry')
		dot = nt.nodes.new('ShaderNodeVectorMath')
		dot.operation = 'DOT_PRODUCT'
		dot.inputs[1].default_value = (-0.5, -0.6, 0.62)  # replaced by the real key direction in lights()
		C.ldots.append(dot)
		nt.links.new(geo0.outputs['Normal'], dot.inputs[0])
		mr = nt.nodes.new('ShaderNodeMapRange')
		mr.inputs['From Min'].default_value = -1.0
		mr.inputs['From Max'].default_value = 1.0
		nt.links.new(dot.outputs['Value'], mr.inputs['Value'])
		cr = nt.nodes.new('ShaderNodeValToRGB')
		el = cr.color_ramp.elements
		el[0].position = 0.25
		el[0].color = lin(dark or d0)
		el[1].position = 1.0
		el[1].color = lin(light or l0)
		mid = el.new(0.7)
		mid.color = lin(rgb)
		nt.links.new(mr.outputs['Result'], cr.inputs['Fac'])
		base_socket = cr.outputs['Color']
		nt.links.new(base_socket, bs.inputs['Base Color'])
	bs.inputs['Roughness'].default_value = rough
	bs.inputs['Metallic'].default_value = metal
	bs.inputs['Coat Weight'].default_value = coat
	bs.inputs['Coat Roughness'].default_value = 0.12
	bs.inputs['Specular IOR Level'].default_value = LOOK['spec'] if spec is None else spec
	if emit:
		bs.inputs['Emission Color'].default_value = lin(rgb)
		bs.inputs['Emission Strength'].default_value = emit
	if tiles > 0:
		geo = nt.nodes.new('ShaderNodeNewGeometry')
		mp = nt.nodes.new('ShaderNodeMapping')
		mp.inputs['Scale'].default_value = (density, density, density)
		tex = nt.nodes.new('ShaderNodeTexImage')
		tex.image = tile_image()
		tex.projection = 'BOX'
		tex.projection_blend = 0.3
		tex.interpolation = 'Cubic'
		nt.links.new(geo.outputs['Position'], mp.inputs['Vector'])
		nt.links.new(mp.outputs['Vector'], tex.inputs['Vector'])
		mul = nt.nodes.new('ShaderNodeMath')
		mul.operation = 'MULTIPLY'
		mul.inputs[1].default_value = tiles
		nt.links.new(tex.outputs['Color'], mul.inputs[0])
		mix = nt.nodes.new('ShaderNodeMix')
		mix.data_type = 'RGBA'
		mix.inputs['A'].default_value = lin(rgb)
		if base_socket is not None:
			nt.links.new(base_socket, mix.inputs['A'])
		trgb = tile_rgb or mix_rgb(rgb, (255, 255, 255), 0.32)
		mix.inputs['B'].default_value = lin(trgb)
		nt.links.new(mul.outputs[0], mix.inputs['Factor'])
		nt.links.new(mix.outputs['Result'], bs.inputs['Base Color'])
		bmp = nt.nodes.new('ShaderNodeBump')
		bmp.inputs['Strength'].default_value = bump
		bmp.inputs['Distance'].default_value = 0.02
		nt.links.new(tex.outputs['Color'], bmp.inputs['Height'])
		nt.links.new(bmp.outputs['Normal'], bs.inputs['Normal'])
		if 'Normal' in bs.inputs and 'Coat Normal' in bs.inputs:
			nt.links.new(bmp.outputs['Normal'], bs.inputs['Coat Normal'])
	m.diffuse_color = lin(rgb)
	C.mats[key] = m
	return m


def flat(rgb, strength=1.0):
	"""Unlit colour (crease lines, painted details)."""
	key = ('flat', rgb, strength)
	if key in C.mats:
		return C.mats[key]
	m = bpy.data.materials.new('flat_%02x%02x%02x' % tuple(rgb))
	nt = m.node_tree
	nt.nodes.clear()
	o = nt.nodes.new('ShaderNodeOutputMaterial')
	e = nt.nodes.new('ShaderNodeEmission')
	e.inputs['Color'].default_value = lin(rgb)
	e.inputs['Strength'].default_value = strength
	nt.links.new(e.outputs[0], o.inputs['Surface'])
	C.mats[key] = m
	return m


# ------------------------------------------------------------------------------------------- shapes
def _link(ob, material, group):
	bpy.context.scene.collection.objects.link(ob)
	if material is not None:
		ob.data.materials.append(material)
	ob.pass_index = group if group is not None else C.new_group()
	C.objs.append(ob)
	return ob


def _mesh_obj(name, verts, faces, material, group, smooth=True, face_mats=None):
	"""material: one material, or a list used with face_mats (one material index per face)."""
	me = bpy.data.meshes.new(name)
	me.from_pydata([tuple(v) for v in verts], [], faces)
	me.update()
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = smooth
	ob = bpy.data.objects.new(name, me)
	if isinstance(material, (list, tuple)):
		_link(ob, None, group)
		for m in material:
			me.materials.append(m)
		if face_mats:
			for p, k in zip(me.polygons, face_mats):
				p.material_index = k
		return ob
	return _link(ob, material, group)


def tub(top, bot, h, wall, mat_out, mat_in, loc=(0, 0, 0), rot=(0, 0, 0), r=0.05, group=None, name='tub'):
	"""An open box (basket, cup): outer frustum from bot=(w, d) at z=0 to top=(w, d) at z=h, walls `wall` thick.
	The inside (inner walls + floor) uses mat_in."""
	(tw, td), (bw, bd) = top, bot
	def rect(w, d, z):
		return [(-w / 2, -d / 2, z), (w / 2, -d / 2, z), (w / 2, d / 2, z), (-w / 2, d / 2, z)]
	k = wall * 2
	v = rect(bw, bd, 0) + rect(tw, td, h) + rect(tw - k, td - k, h) + rect(bw - k * 1.2, bd - k * 1.2, wall)
	f, fm = [(3, 2, 1, 0)], [0]
	for i in range(4):
		j = (i + 1) % 4
		f.append((i, j, 4 + j, 4 + i)); fm.append(0)
		f.append((4 + i, 4 + j, 8 + j, 8 + i)); fm.append(0)
		f.append((8 + i, 8 + j, 12 + j, 12 + i)); fm.append(1)
	f.append((12, 13, 14, 15)); fm.append(1)
	ob = _mesh_obj(name, v, f, [mat_out, mat_in], group, face_mats=fm)
	place(ob, loc, rot)
	if r:
		bevel(ob, r, 4)
	return ob


def fillet(points, r, steps=6):
	"""Round the interior corners of a polyline with radius r."""
	pts = [Vector(p) for p in points]
	out = [pts[0]]
	for i in range(1, len(pts) - 1):
		a, b, c = pts[i - 1], pts[i], pts[i + 1]
		u, w = (a - b).normalized(), (c - b).normalized()
		ang = u.angle(w)
		if ang > math.radians(175):
			out.append(b)
			continue
		t = min(r / math.tan(ang / 2), (a - b).length * 0.49, (c - b).length * 0.49)
		p0, p1 = b + u * t, b + w * t
		for k in range(steps + 1):
			s = k / steps
			# quadratic Bezier through the corner: smooth enough for a fillet
			out.append(p0 * (1 - s) ** 2 + b * 2 * s * (1 - s) + p1 * s * s)
	out.append(pts[-1])
	return out


def path_frames(points, up=(0, -1, 0)):
	"""Frames along a polyline (parallel transport), first U chosen from `up` when possible."""
	pts = [Vector(p) for p in points]
	frames = []
	t0 = (pts[1] - pts[0]).normalized()
	U = Vector(up) - t0 * Vector(up).dot(t0)
	U = U.normalized() if U.length > 1e-4 else t0.orthogonal().normalized()
	for i, p in enumerate(pts):
		if i == 0:
			t = t0
		elif i == len(pts) - 1:
			t = (pts[i] - pts[i - 1]).normalized()
		else:
			t = (pts[i + 1] - pts[i - 1]).normalized()
		U = (U - t * U.dot(t)).normalized()
		V = t.cross(U).normalized()
		frames.append((p, U, V))
	return frames


def bar(points, w, d, material, rr=0.3, corner=0.0, group=None, name='bar', up=(0, -1, 0)):
	"""A bar with a rounded-rectangle section (w along U, d along V) swept along a polyline whose corners are
	rounded by `corner`."""
	pts = fillet(points, corner) if corner else [Vector(p) for p in points]
	prof = round_rect(w, d, min(w, d) * rr, 4)
	return sweep(path_frames(pts, up), prof, material, group, name)


def place(ob, loc=(0, 0, 0), rot=(0, 0, 0), scale=None):
	ob.location = loc
	ob.rotation_euler = Euler(tuple(math.radians(a) for a in rot), 'XYZ')
	if scale is not None:
		ob.scale = scale
	return ob


def bevel(ob, width, seg=4, angle=None, harden=True):
	mod = ob.modifiers.new('Bevel', 'BEVEL')
	mod.width = width
	mod.segments = seg
	mod.use_clamp_overlap = True
	if angle is None:
		mod.limit_method = 'NONE'
	else:
		mod.limit_method = 'ANGLE'
		mod.angle_limit = math.radians(angle)
	mod.harden_normals = harden
	return mod


def rbox(loc, size, r, material, rot=(0, 0, 0), seg=4, group=None, name='box', taper=None):
	"""Rounded box. taper=(sx, sy) scales the top face (a frustum)."""
	sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
	tx, ty = taper or (1, 1)
	v = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
		(-sx * tx, -sy * ty, sz), (sx * tx, -sy * ty, sz), (sx * tx, sy * ty, sz), (-sx * tx, sy * ty, sz)]
	f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
	ob = _mesh_obj(name, v, f, material, group, smooth=True)
	place(ob, loc, rot)
	if r > 0:
		bevel(ob, r, seg)
	return ob


def ball(loc, radius, material, rot=(0, 0, 0), group=None, name='ball', seg=48):
	bm = bmesh.new()
	bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=1.0)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = True
	ob = bpy.data.objects.new(name, me)
	_link(ob, material, group)
	r = radius if isinstance(radius, (tuple, list)) else (radius, radius, radius)
	return place(ob, loc, rot, r)


def lathe(profile, material, loc=(0, 0, 0), rot=(0, 0, 0), segs=56, group=None, name='lathe', bevel_w=0.0, sides=None):
	"""Surface of revolution around local z. profile: [(r, z), ...] bottom to top; r == 0 ends close it.
	sides: a low-poly n-gon instead of round (prism-like)."""
	n = sides or segs
	verts, faces, rings = [], [], []
	for (r, z) in profile:
		if r <= 1e-6:
			rings.append([len(verts)])
			verts.append((0, 0, z))
		else:
			ring = []
			for i in range(n):
				a = 2 * math.pi * i / n + (math.pi / n if sides else 0)
				ring.append(len(verts))
				verts.append((r * math.cos(a), r * math.sin(a), z))
			rings.append(ring)
	for a, b in zip(rings, rings[1:]):
		if len(a) == 1 and len(b) == 1:
			continue
		if len(a) == 1:
			for i in range(n):
				faces.append((a[0], b[i], b[(i + 1) % n]))
		elif len(b) == 1:
			for i in range(n):
				faces.append((a[i], b[0], a[(i + 1) % n]))
		else:
			for i in range(n):
				faces.append((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
	if len(rings[0]) > 1:
		faces.append(tuple(reversed(rings[0])))
	if len(rings[-1]) > 1:
		faces.append(tuple(rings[-1]))
	ob = _mesh_obj(name, verts, faces, material, group)
	place(ob, loc, rot)
	if sides:
		ob.data.set_sharp_from_angle(angle=math.radians(40))
	if bevel_w:
		bevel(ob, bevel_w, 3, angle=40)
	return ob


def cyl(loc, radius, depth, material, rot=(0, 0, 0), r=0.0, group=None, name='cyl', segs=56, sides=None):
	"""Cylinder along local z, caps rounded by r."""
	ob = lathe([(0, -depth / 2), (radius, -depth / 2), (radius, depth / 2), (0, depth / 2)], material, loc, rot, segs, group,
		name, sides=sides)
	ob.data.set_sharp_from_angle(angle=math.radians(50))
	if r:
		bevel(ob, r, 4, angle=50)
	return ob


def slab(points, depth, material, loc=(0, 0, 0), rot=(0, 0, 0), r=0.04, seg=4, group=None, name='slab', y0=None):
	"""A 2D outline in the xz plane (x right, z up), extruded along y, edges rounded by r."""
	bm = bmesh.new()
	y0 = -depth / 2 if y0 is None else y0
	front = [bm.verts.new((x, y0, z)) for (x, z) in points]
	back = [bm.verts.new((x, y0 + depth, z)) for (x, z) in points]
	n = len(points)
	bm.faces.new(front)
	bm.faces.new(list(reversed(back)))
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((front[i], front[j], back[j], back[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = True
	ob = bpy.data.objects.new(name, me)
	_link(ob, material, group)
	place(ob, loc, rot)
	if r:
		bevel(ob, r, seg, angle=30)
	return ob


def round_rect(w, h, r, n=6):
	"""Points of a rounded rectangle centred on 0 (counter-clockwise)."""
	pts = []
	for cx, cz, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
		for k in range(n + 1):
			a = math.radians(a0 + 90 * k / n)
			pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))
	return pts


def sweep(frames, profile, material, group=None, name='sweep', caps=True):
	"""Sweep a closed 2D profile [(u, v)] along frames [(pos, U, V)] (U, V: unit axes for u, v)."""
	verts, faces = [], []
	n = len(profile)
	for (p, U, V) in frames:
		for (u, v) in profile:
			verts.append(tuple(Vector(p) + Vector(U) * u + Vector(V) * v))
	for i in range(len(frames) - 1):
		for k in range(n):
			a, b = i * n + k, i * n + (k + 1) % n
			faces.append((a, b, b + n, a + n))
	if caps:
		faces.append(tuple(range(n - 1, -1, -1)))
		last = (len(frames) - 1) * n
		faces.append(tuple(last + k for k in range(n)))
	return _mesh_obj(name, verts, faces, material, group)


def arc_frames(centre, radius, a0, a1, steps, plane='xz'):
	"""Frames along a circular arc in the xz plane (angles in degrees, counter-clockwise from +x).
	U = radial (outward), V = +y (depth)."""
	out = []
	cx, cy, cz = centre
	for i in range(steps + 1):
		a = math.radians(a0 + (a1 - a0) * i / steps)
		radial = Vector((math.cos(a), 0, math.sin(a)))
		out.append((Vector((cx, cy, cz)) + radial * radius, radial, Vector((0, 1, 0))))
	return out


def arc_band(a0, a1, rin0, rout0, rin1, rout1, depth, material, centre=(0, 0, 0), steps=36, corner=0.12, group=None,
		name='band', y=0.0):
	"""A flat ring segment in the xz plane (front face toward -y), from angle a0 to a1 (degrees, counter-clockwise from
	+x; a1 < a0 runs clockwise). Its radial span goes linearly from [rin0, rout0] to [rin1, rout1], so the same call makes
	the ring body (constant span) and an arrow head that narrows to a point along the ring. Section: rounded rectangle."""
	cx, cy, cz = centre
	frames = []
	for i in range(steps + 1):
		t = i / steps
		a = math.radians(a0 + (a1 - a0) * t)
		rin = rin0 + (rin1 - rin0) * t
		rout = rout0 + (rout1 - rout0) * t
		radial = Vector((math.cos(a), 0, math.sin(a)))
		frames.append((Vector((cx, cy + y, cz)) + radial * ((rin + rout) / 2), radial, max(rout - rin, 0.02)))
	verts, faces = [], []
	n = None
	for (p, U, w) in frames:
		cr = min(corner, w * 0.45, depth * 0.45)
		prof = round_rect(w, depth, cr, 4)
		n = len(prof)
		for (u, v) in prof:
			verts.append(tuple(p + U * u + Vector((0, 1, 0)) * v))
	for i in range(len(frames) - 1):
		for k in range(n):
			a, b = i * n + k, i * n + (k + 1) % n
			faces.append((a, b, b + n, a + n))
	faces.append(tuple(range(n - 1, -1, -1)))
	last = (len(frames) - 1) * n
	faces.append(tuple(last + k for k in range(n)))
	return _mesh_obj(name, verts, faces, material, group)


def tube(points, radius, material, group=None, name='tube', segs=20, caps=True, taper=None):
	"""Round tube through 3D points (parallel-transport frames). taper: (start, end) radius factors."""
	pts = [Vector(p) for p in points]
	frames = path_frames(pts)
	if not taper:
		prof = [(radius * math.cos(2 * math.pi * k / segs), radius * math.sin(2 * math.pi * k / segs)) for k in range(segs)]
		return sweep(frames, prof, material, group, name, caps)
	n = len(frames)
	scaled = []
	for i, (p, U, V) in enumerate(frames):
		f = taper[0] + (taper[1] - taper[0]) * i / max(1, n - 1)
		scaled.append((p, U * f, V * f))
	prof = [(radius * math.cos(2 * math.pi * k / segs), radius * math.sin(2 * math.pi * k / segs)) for k in range(segs)]
	return sweep(scaled, prof, material, group, name, caps)


def metaball(elements, material, res=0.05, group=None, name='mb', threshold=0.6):
	"""elements: (type, co, radius, (sx, sy, sz), rot_euler_deg); type BALL / ELLIPSOID / CAPSULE."""
	mb = bpy.data.metaballs.new(name)
	mb.resolution = res
	mb.render_resolution = res * 0.5
	mb.threshold = threshold
	for (kind, co, radius, size, rot) in elements:
		e = mb.elements.new(type=kind)
		e.co = co
		e.radius = radius
		e.size_x, e.size_y, e.size_z = size
		e.rotation = Euler(tuple(math.radians(a) for a in rot), 'XYZ').to_quaternion()
		e.stiffness = 2.0
	ob = bpy.data.objects.new(name, mb)
	return _link(ob, material, group)


_FONT = []


def font():
	if not _FONT:
		f = None
		for p in FONT_PATHS:
			if os.path.exists(p):
				f = bpy.data.fonts.load(p)
				break
		_FONT.append(f)
	return _FONT[0]


def text(s, material, loc=(0, 0, 0), size=1.0, depth=0.1, rot=(90, 0, 0), bev=0.02, group=None, name='text', spacing=1.0):
	cu = bpy.data.curves.new(name, 'FONT')
	cu.body = s
	cu.size = size
	cu.extrude = depth
	cu.bevel_depth = bev
	cu.bevel_resolution = 3
	cu.align_x = 'CENTER'
	cu.align_y = 'CENTER'
	cu.space_character = spacing
	f = font()
	if f:
		cu.font = f
	ob = bpy.data.objects.new(name, cu)
	_link(ob, material, group)
	return place(ob, loc, rot)


# ------------------------------------------------------------------------------------------- camera + lights
def eval_points(objs):
	dg = bpy.context.evaluated_depsgraph_get()
	pts = []
	for ob in objs:
		ev = ob.evaluated_get(dg)
		try:
			me = ev.to_mesh()
		except RuntimeError:
			continue
		if me is None:
			continue
		mw = ev.matrix_world
		pts.extend(tuple(mw @ v.co) for v in me.vertices)
		ev.to_mesh_clear()
	return np.array(pts)


def frame_camera(sc, view, fill=0.86, lens=85.0, roll=0.0, shift=(0, 0)):
	"""Camera looking from direction `view` (subject -> camera, Blender axes) framing every vertex."""
	bpy.context.view_layer.update()
	pts = eval_points(C.objs)
	cam = bpy.data.cameras.new('Cam')
	cam.lens = lens
	cam.sensor_fit = 'AUTO'
	cam.clip_start = 0.01
	cam.clip_end = 1000
	co = bpy.data.objects.new('Cam', cam)
	sc.collection.objects.link(co)
	sc.camera = co
	d = Vector(view).normalized()
	lo, hi = pts.min(axis=0), pts.max(axis=0)
	centre = Vector((lo + hi) / 2)
	radius = float(np.linalg.norm(hi - lo)) / 2
	half = math.tan(math.atan(18.0 / lens))
	dist = radius / half * 1.2
	for _ in range(8):
		co.location = centre + d * dist
		co.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
		if roll:
			co.rotation_euler.rotate_axis('Z', math.radians(roll))
		bpy.context.view_layer.update()
		m = np.array(co.matrix_world.inverted())
		local = pts @ m[:3, :3].T + m[:3, 3]
		px = local[:, 0] / -local[:, 2]
		py = local[:, 1] / -local[:, 2]
		ext = max(px.max() - px.min(), py.max() - py.min()) / 2
		cx, cy = (px.max() + px.min()) / 2, (py.max() + py.min()) / 2
		right, upv = Vector(co.matrix_world.col[0][:3]), Vector(co.matrix_world.col[1][:3])
		centre = centre + (right * (cx - shift[0] * ext) + upv * (cy - shift[1] * ext)) * dist
		dist *= ext / (half * fill)
	co.location = centre + d * dist
	co.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
	if roll:
		co.rotation_euler.rotate_axis('Z', math.radians(roll))
	bpy.context.view_layer.update()
	return co, centre, dist


def area(sc, name, loc, target, size, energy, color=(1, 1, 1)):
	ld = bpy.data.lights.new(name, 'AREA')
	ld.shape = 'DISK'
	ld.size = size
	ld.energy = energy
	ld.color = color
	ob = bpy.data.objects.new(name, ld)
	sc.collection.objects.link(ob)
	ob.location = loc
	ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
	return ob


def lights(sc, cam, centre, dist, key=1.0):
	mw = cam.matrix_world
	right, up, back = Vector(mw.col[0][:3]), Vector(mw.col[1][:3]), Vector(mw.col[2][:3])
	c = Vector(centre)
	r = dist
	e = r * r * 0.15
	kdir = (back * 0.95 - right * 0.7 + up * 0.9).normalized()
	for node in C.ldots:
		node.inputs[1].default_value = tuple(kdir)
	area(sc, 'Key', c + kdir * r, c, r * 0.7, 80 * e * LOOK['key'] * key, (1.0, 0.97, 0.92))
	area(sc, 'Fill', c + (back * 1.0 + right * 0.8 - up * 0.2).normalized() * r, c, r * 1.0, 40 * e * LOOK['fill'], (0.92, 0.95, 1.0))
	area(sc, 'Top', c + (up * 1.0 + back * 0.2).normalized() * r, c, r * 0.9, 60 * e * LOOK['top'])
	area(sc, 'RimR', c + (-back * 0.6 + right * 0.9 + up * 0.5).normalized() * r, c, r * 0.3, 90 * e * LOOK['rim'])
	area(sc, 'RimL', c + (-back * 0.6 - right * 0.9 + up * 0.2).normalized() * r, c, r * 0.3, 60 * e * LOOK['rim'])


# ------------------------------------------------------------------------------------------- post
def load_exr_index(path):
	img = bpy.data.images.load(path, check_existing=False)
	w, h = img.size
	buf = np.empty(w * h * img.channels, dtype=np.float32)
	img.pixels.foreach_get(buf)
	ch = img.channels
	bpy.data.images.remove(img)
	return np.rint(buf.reshape(h, w, ch)[..., 0]).astype(np.int32)


def edt(seed):
	"""Distance (px) from every pixel to the nearest True pixel of `seed`, by jump flooding."""
	h, w = seed.shape
	yy, xx = np.mgrid[0:h, 0:w]
	sy = np.where(seed, yy, -10 ** 6).astype(np.int32)
	sx = np.where(seed, xx, -10 ** 6).astype(np.int32)
	best = np.where(seed, 0, 10 ** 12).astype(np.int64)
	step = 1
	while step * 2 < max(h, w):
		step *= 2
	while step >= 1:
		for dy in (-step, 0, step):
			for dx in (-step, 0, step):
				if dy == 0 and dx == 0:
					continue
				cy = np.full_like(sy, -10 ** 6)
				cx = np.full_like(sx, -10 ** 6)
				ys0, ys1 = max(0, -dy), min(h, h - dy)
				xs0, xs1 = max(0, -dx), min(w, w - dx)
				cy[ys0:ys1, xs0:xs1] = sy[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx]
				cx[ys0:ys1, xs0:xs1] = sx[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx]
				d = (yy - cy).astype(np.int64) ** 2 + (xx - cx).astype(np.int64) ** 2
				better = d < best
				best = np.where(better, d, best)
				sy = np.where(better, cy, sy)
				sx = np.where(better, cx, sx)
		step //= 2
	return np.sqrt(best.astype(np.float64)).astype(np.float32)


def downsample(img, k):
	if k == 1:
		return img
	h, w, _ = img.shape
	a = img[..., 3:4]
	pre = np.concatenate([img[..., :3] * a, a], axis=2)
	pre = pre.reshape(h // k, k, w // k, k, 4).mean(axis=(1, 3))
	a = pre[..., 3:4]
	rgb = pre[..., :3] / np.maximum(a, 1e-6)
	return np.concatenate([rgb, a], axis=2)


def saturate(img, k):
	if abs(k - 1) < 1e-3:
		return img
	rgb = img[..., :3]
	g = rgb.mean(axis=2, keepdims=True)
	return np.concatenate([np.clip(g + (rgb - g) * k, 0, 1), img[..., 3:4]], axis=2)


def finish(beauty, index_path, out_png, ss, opts):
	img = bb.load_png(beauty)
	h, w, _ = img.shape
	img = saturate(img, LOOK['sat'] * opts.get('sat', 1.0))
	alpha = img[..., 3]
	navy = np.array(opts.get('ink', NAVY), np.float32) / 255.0  # outline + part lines (Robux: dark green)
	solid = alpha > 0.5
	r_out = LOOK['outline'] * w * opts.get('outline', 1.0)
	# Inner lines where two line groups meet (both sides of the boundary), drawn over the beauty.
	if os.path.exists(index_path) and opts.get('inner', 1.0) > 0:
		idx = load_exr_index(index_path)
		idx = np.where(solid, idx, 0)
		e = np.zeros_like(solid)
		for dy, dx in ((0, 1), (1, 0)):
			a = idx[: h - dy, : w - dx]
			b = idx[dy:, dx:]
			diff = (a != b) & (a > 0) & (b > 0)
			e[: h - dy, : w - dx] |= diff
			e[dy:, dx:] |= diff
		if e.any():
			r_in = r_out * LOOK['inner'] * opts.get('inner', 1.0)
			d = edt(e)
			line = np.clip(r_in - d + 0.5, 0, 1) * alpha
			layer = np.zeros_like(img)
			layer[..., :3] = navy
			layer[..., 3] = line
			img = bb.over(layer, img)
	# Thick outline behind everything.
	d = edt(solid)
	ring = np.clip(r_out - d + 0.5, 0, 1)
	layer = np.zeros_like(img)
	layer[..., :3] = navy
	layer[..., 3] = ring
	img = bb.over(img, layer)
	glow = opts.get('glow')
	if glow:
		col, strength = glow
		halo = bb.blur(np.clip(ring, 0, 1), w * 0.05)
		halo = np.clip(halo * 1.8, 0, 1) * strength
		lay = np.zeros_like(img)
		lay[..., :3] = col
		lay[..., 3] = halo
		img = bb.over(img, lay)
	if opts.get('sparkles'):
		sp = bb.sparkle_layer(h, w, ring, opts['sparkles'], opts.get('seed', 3), w * 0.05)
		lay = np.zeros_like(img)
		lay[..., :3] = (1.0, 0.99, 0.9)
		lay[..., 3] = sp
		img = bb.over(lay, img)
	img = downsample(img, ss)
	os.makedirs(os.path.dirname(out_png), exist_ok=True)
	bb.save_png(img, out_png)


