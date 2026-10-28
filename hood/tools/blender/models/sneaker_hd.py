"""Smooth cartoon sneakers (Oct 28, the owner: "remodel the shoes with blender to make them way better"). One sneaker
shape, built from lofted cross-sections and smoothed (Subdivision), in separate recolourable pieces so every shoe is the
same mesh set in its own colours: Sole, Stripe (the midsole line), Outsole, Upper, ToeCap, Collar, Opening, Tongue,
Laces, Swoosh, HeelTab.

Space: Blender axes (hdkit / icons_hd), the RIGHT shoe: toe +x, outer side -y (toward the camera), ground z = 0, about
2.4 long and 1.05 wide (studs once exported: the R15 foot is about 1 wide).

Usage (Blender as a Python module):
  python3 hood/tools/blender/models/sneaker_hd.py RedRocket [more ids] [--res 512] [--out DIR]
renders <out>/ShoeHD_<Id>.png with the icon look (icons_hd.render_icon). Colours come from Config/Shoes.lua.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import bpy  # noqa: E402
import bmesh  # noqa: E402,I100

import hdkit as K  # noqa: E402
import icons_hd as I  # noqa: E402
from hdkit import ball, mat, rbox, tube  # noqa: E402

HOOD = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SHOES_LUA = os.path.join(HOOD, 'src', 'ReplicatedStorage', 'Shared', 'Config', 'Shoes.lua')

# ------------------------------------------------------------------------------------------------ shape (units)
X0, X1 = -1.16, 1.22      # heel and toe tips of the footprint
HALF_W = 0.52             # footprint half width at the ball of the foot
SOLE_TOP = 0.40           # where the upper sits on the sole
YAW = float(os.environ.get('SHOE_YAW', '-50'))
P_OUT = 2.6               # footprint roundness (superellipse exponent: 2 = ellipse, higher = squarer)


def smooth(a, b, x):
	t = max(0.0, min(1.0, (x - a) / (b - a)))
	return t * t * (3 - 2 * t)


def spline(pts, x):
	"""Piecewise-cubic (Catmull-Rom) through (x, y) points sorted by x."""
	if x <= pts[0][0]:
		return pts[0][1]
	if x >= pts[-1][0]:
		return pts[-1][1]
	for i in range(len(pts) - 1):
		if pts[i][0] <= x <= pts[i + 1][0]:
			p0 = pts[max(0, i - 1)][1]
			p1, p2 = pts[i][1], pts[i + 1][1]
			p3 = pts[min(len(pts) - 1, i + 2)][1]
			t = (x - pts[i][0]) / (pts[i + 1][0] - pts[i][0])
			return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
	return pts[-1][1]


def outline(n, scale=1.0, x0=X0, x1=X1, hw=HALF_W):
	"""The footprint: n (x, half width) samples from heel to toe, a superellipse narrowed at the heel."""
	cx, hl = (x0 + x1) / 2, (x1 - x0) / 2 * scale
	out = []
	for i in range(n):
		ph = math.pi * (1 - i / (n - 1))
		c, s = math.cos(ph), math.sin(ph)
		x = cx + hl * math.copysign(abs(c) ** (2 / P_OUT), c)
		w = hw * scale * abs(s) ** (2 / P_OUT)
		w *= 0.84 + 0.16 * smooth(-0.9, 0.45, x)  # a narrower heel
		out.append((x, max(w, 0.012)))
	return out


TOP = [(-1.2, 1.36), (-1.0, 1.42), (-0.62, 1.30), (-0.25, 1.30), (0.1, 1.1), (0.5, 0.86), (0.85, 0.7), (1.25, 0.5)]


def top_z(x):
	return spline(TOP, x)


def toe_spring(x):
	return 0.13 * smooth(0.55, 1.25, x) ** 1.6


def loft(sections, ring, material, group, name, subsurf=2):
	"""sections: [(x, half_w, z_bottom, z_top)], each a superellipse ring of `ring` points; ends capped."""
	bm = bmesh.new()
	rings = []
	for (x, hw, zb, zt, n) in sections:
		zc, hh = (zb + zt) / 2, (zt - zb) / 2
		r = []
		for k in range(ring):
			a = 2 * math.pi * k / ring
			c, s = math.cos(a), math.sin(a)
			y = hw * math.copysign(abs(c) ** (2 / n), c)
			z = zc + hh * math.copysign(abs(s) ** (2 / n), s)
			r.append(bm.verts.new((x, y, z)))
		rings.append(r)
	for i in range(len(rings) - 1):
		a, b = rings[i], rings[i + 1]
		for k in range(ring):
			bm.faces.new((a[k], a[(k + 1) % ring], b[(k + 1) % ring], b[k]))
	for r, flip in ((rings[0], True), (rings[-1], False)):
		f = bm.faces.new(list(reversed(r)) if flip else r)
		bmesh.ops.poke(bm, faces=[f])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = True
	ob = bpy.data.objects.new(name, me)
	K._link(ob, material, group)
	if subsurf:
		m = ob.modifiers.new('sub', 'SUBSURF')
		m.levels = m.render_levels = subsurf
	return ob


def build(cols):
	"""cols: dict upper, accent, trim (sRGB tuples) -> every piece of one right shoe."""
	G = K.C.new_group
	white = (246, 247, 250)
	upper = mat(cols['upper'], rough=0.42, coat=0.25)
	trim = mat(cols['trim'], rough=0.4, coat=0.2, light=(255, 255, 255))
	accent = mat(cols['accent'], rough=0.35, coat=0.3)
	sole_m = mat(white, rough=0.45, light=(255, 255, 255), dark=(190, 202, 224))
	dark = mat((44, 40, 66), rough=0.6)
	lace_m = mat(white, rough=0.4, light=(255, 255, 255), dark=(196, 206, 226))

	# the sole: a thick rounded slab on the footprint, the toe sprung up, a coloured midsole line and a dark outsole
	fp = outline(44, 1.0)
	sole = [(x, w * 1.06, toe_spring(x), toe_spring(x) + SOLE_TOP + 0.04, 5.0) for x, w in fp]
	loft(sole, 40, sole_m, G(), 'Sole')
	stripe = [(x, w * 1.12, toe_spring(x) + 0.15, toe_spring(x) + 0.27, 6.0) for x, w in fp]
	loft(stripe, 40, accent, G(), 'Stripe')
	outsole = [(x, w * 1.07, toe_spring(x) - 0.05, toe_spring(x) + 0.07, 6.0) for x, w in fp]
	loft(outsole, 40, dark, G(), 'Outsole')

	# the upper: rounded sections from the sole to the top line (high heel collar, a sloping vamp, a low round toe)
	fu = outline(40, 0.965)
	up = [(x, w * 0.96, toe_spring(x) + SOLE_TOP - 0.06, max(top_z(x), toe_spring(x) + SOLE_TOP + 0.08), 2.8) for x, w in fu]
	loft(up, 36, upper, G(), 'Upper')
	# the toe cap: a bumper over the front of the upper
	cap = [(x, w * 1.0, toe_spring(x) + SOLE_TOP - 0.04, min(top_z(x), 0.66 + toe_spring(x)) + 0.03, 2.6)
		for x, w in outline(40, 0.985) if x > 0.42]
	cap.insert(0, (0.4, cap[0][1] * 0.6, cap[0][2], cap[0][3] - 0.12, 2.6))
	loft(cap, 36, trim, G(), 'ToeCap')

	# the opening and its padded collar
	ox, oz = -0.66, top_z(-0.66)
	rx, ry = 0.40, 0.30
	ring = []
	for k in range(49):
		a = 2 * math.pi * k / 48
		x = ox + rx * math.cos(a)
		ring.append((x, ry * math.sin(a), top_z(x) + 0.02))
	tube(ring, 0.105, trim, group=G(), name='Collar', caps=False)
	ball((ox, 0, oz - 0.02), (rx * 0.92, ry * 0.88, 0.06), dark, group=G(), name='Opening')

	# the tongue: a padded flap standing up in front of the opening, leaning back
	tz = top_z(-0.2)
	rbox((-0.24, 0, tz + 0.1), (0.15, 0.46, 0.36), 0.07, upper, rot=(0, -24, 0), group=G(), name='Tongue')
	rbox((-0.285, 0, tz + 0.2), (0.07, 0.28, 0.12), 0.03, accent, rot=(0, -24, 0), group=G(), name='TongueTag')

	# the laces: chunky bars across the vamp, following its slope
	gl = G()
	for x in (0.42, 0.22, 0.02):
		z = top_z(x) + 0.03
		slope = math.degrees(math.atan2(top_z(x + 0.05) - top_z(x - 0.05), 0.1))
		rbox((x, 0, z), (0.12, 0.62, 0.09), 0.04, lace_m, rot=(0, -slope, 0), group=gl, name='Lace')

	# the swoosh on the outer side and a heel tab
	bpy.context.view_layer.update()
	sw = [(-0.98, 0.96), (-0.72, 0.76), (-0.35, 0.66), (0.0, 0.66), (0.3, 0.72), (0.55, 0.84)]
	pts = []
	dg = bpy.context.evaluated_depsgraph_get()
	for x, z in sw:
		hit, loc, *_ = bpy.context.scene.ray_cast(dg, (x, -50, z), (0, 1, 0))
		if hit:
			pts.append((loc.x, loc.y + 0.02, loc.z))
	if len(pts) >= 2:
		tube(pts, 0.12, accent, group=G(), name='Swoosh', taper=(1.0, 0.3))
	rbox((-1.13, 0, top_z(-1.1) - 0.05), (0.14, 0.3, 0.42), 0.06, accent, group=G(), name='HeelTab')


def shoe_colours():
	"""Config/Shoes.lua -> {id: (c1, c2, c3)} from each shoe's { 'Id', 'Name', { c1, c2, c3 } } row."""
	src = open(SHOES_LUA).read()
	col = r"(W|C\(\s*\d+,\s*\d+,\s*\d+\s*\))"
	out = {}
	for m in re.finditer(r"\{ '([A-Za-z]+)', '[^']+', \{ " + col + r", " + col + r", " + col + r" \} \}", src):
		def rgb(s):
			if s == 'W':
				return (246, 247, 250)
			return tuple(int(v) for v in re.findall(r'\d+', s))
		out[m.group(1)] = (rgb(m.group(2)), rgb(m.group(3)), rgb(m.group(4)))
	return out


def register(sid):
	c1, c2, c3 = shoe_colours()[sid]
	cols = dict(upper=c1, accent=c2, trim=c3)

	@I.icon('ShoeHD_' + sid, view=(0.5, -0.8, 0.32), fill=0.9, inner=0.6)
	def _():
		piv_before = set(bpy.data.objects)
		build(cols)
		piv = bpy.data.objects.new('Pivot', None)
		bpy.context.scene.collection.objects.link(piv)
		for ob in set(bpy.data.objects) - piv_before:
			if ob is not piv and ob.parent is None:
				ob.parent = piv
		I.place(piv, (0, 0, 0), (0, 0, YAW))


if __name__ == '__main__':
	import argparse
	ap = argparse.ArgumentParser()
	ap.add_argument('ids', nargs='+')
	ap.add_argument('--res', type=int, default=512)
	ap.add_argument('--ss', type=int, default=2)
	ap.add_argument('--samples', type=int, default=40)
	ap.add_argument('--out', default=os.path.join(HOOD, 'art', 'renders', 'shoes-hd'))
	a = ap.parse_args()
	os.makedirs(a.out, exist_ok=True)
	for sid in a.ids:
		register(sid)
		I.render_icon('ShoeHD_' + sid, a.out, a.res, a.ss, a.samples)
