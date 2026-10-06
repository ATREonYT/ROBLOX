"""BoxKit: low-poly, blocky, stud-style models described in code.

A model is a list of primitives placed in Roblox space (x right, y up, muzzle/front toward -z) and
measured in design units (DU). One DU is one classic stud pitch, so a 1x1 stud bump sits on every
whole DU of a top face. `Model.unit` converts DU to Roblox studs at scale 1 (guns and icons use 0.2).

The same primitive list drives two outputs:
  * bk_blender.py builds Blender meshes from it for Cycles renders and FBX export;
  * roblox_parts() expands it to plain Roblox Parts for export_luau.py.
So a render shows exactly the parts the game builds (bevels are render-only).

This file is plain Python (no bpy) so the exporters and checks can import it anywhere.
"""
import math
from contextlib import contextmanager

# Named colours (sRGB 0-255). A primitive may also take an (r, g, b) tuple.
PALETTE = {
	'white': (242, 243, 245),
	'offwhite': (226, 230, 238),
	'black': (32, 34, 40),
	'ink': (18, 19, 24),
	'gun': (58, 62, 72),         # dark gun steel
	'gunlight': (92, 99, 112),
	'steel': (150, 156, 166),    # Rusty Pistol grey
	'steeldark': (112, 118, 128),
	'chrome': (204, 210, 218),
	'rust': (190, 98, 46),
	'rustdark': (138, 66, 34),
	'wood': (178, 104, 56),
	'woodlight': (206, 132, 74),
	'wooddark': (118, 66, 36),
	'brown': (124, 76, 48),
	'gold': (255, 196, 48),
	'golddark': (222, 150, 28),
	'brass': (232, 176, 72),
	'red': (232, 48, 52),
	'reddark': (170, 28, 36),
	'shell': (214, 40, 44),
	'olive': (98, 112, 64),
	'olivedark': (72, 84, 46),
	'yellow': (255, 214, 52),
	'orange': (255, 140, 40),
	'green': (76, 217, 100),
	'greendark': (40, 160, 70),
	'cash': (92, 204, 96),
	'cashdark': (52, 150, 66),
	'cashlight': (180, 240, 170),
	'blue': (64, 156, 255),
	'bluedark': (30, 100, 210),
	'purple': (170, 85, 255),
	'purpledark': (118, 50, 196),
	'pink': (255, 90, 200),
	'pinkdark': (206, 50, 150),
	'cyan': (60, 230, 255),
	'cyandark': (20, 170, 210),
	'violet': (160, 86, 226),
	'violetneon': (196, 110, 255),
	'diamond': (120, 230, 255),
	'diamonddeep': (60, 170, 240),
	'skin': (255, 204, 150),
}

# Material kinds. Blender look lives in bk_blender.MATERIALS, Roblox mapping in export_luau.ROBLOX_MAT.
KINDS = ('plastic', 'smooth', 'metal', 'neon', 'gold', 'glass')

STUD_D, STUD_H, STUD_EMBED = 0.6, 0.25, 0.02  # classic stud: 0.6 wide, 0.25 tall per 1-DU pitch
STUD_BEVEL = 0.05
DEFAULT_BEVEL = {'box': 0.07, 'wedge': 0.05, 'cyl': 0.05, 'prism': 0.06, 'ball': 0.0}

IDENT = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


# ---------- tiny 3x3 maths (row-major tuples, same layout as CFrame.new(x,y,z, r00..r22)) ----------
def mat_mul(a, b):
	return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def mat_vec(m, v):
	return tuple(m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2] for i in range(3))


def add(a, b):
	return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
	return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def scale_v(a, s):
	return (a[0] * s, a[1] * s, a[2] * s)


def cross(a, b):
	return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
	length = math.sqrt(a[0] ** 2 + a[1] ** 2 + a[2] ** 2)
	return (a[0] / length, a[1] / length, a[2] / length)


def rot_x(deg):
	c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
	return ((1.0, 0.0, 0.0), (0.0, c, -s), (0.0, s, c))


def rot_y(deg):
	c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
	return ((c, 0.0, s), (0.0, 1.0, 0.0), (-s, 0.0, c))


def rot_z(deg):
	c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
	return ((c, -s, 0.0), (s, c, 0.0), (0.0, 0.0, 1.0))


def euler(rx=0.0, ry=0.0, rz=0.0):
	"""Same as Roblox CFrame.Angles(rx, ry, rz) in degrees (Rx * Ry * Rz)."""
	return mat_mul(mat_mul(rot_x(rx), rot_y(ry)), rot_z(rz))


def from_columns(x, y, z):
	"""Rotation whose local X, Y, Z axes point along the given world vectors."""
	return ((x[0], y[0], z[0]), (x[1], y[1], z[1]), (x[2], y[2], z[2]))


def column(m, i):
	return (m[0][i], m[1][i], m[2][i])


AXIS = {'x': IDENT, 'y': rot_z(90), 'z': rot_y(-90)}  # turns local X (Roblox cylinder axis) onto an axis


def to_rgb(color):
	if isinstance(color, str):
		return PALETTE[color]
	return tuple(int(c) for c in color)


class Prim:
	"""One primitive. kind: box | wedge | cyl | prism | ball. Size and shape follow Roblox rules:
	cylinders and prisms run along local X, wedges slope up from the front-bottom (-z) edge to the
	back-top (+z) edge, balls are uniform."""
	__slots__ = ('kind', 'size', 'pos', 'rot', 'color', 'mat', 'bevel', 'name', 'sides', 'spin', 'stud', 'shadow')

	def __init__(self, kind, size, pos, rot, color, mat, bevel=None, name=None, sides=0, spin=0.0, stud=False, shadow=None):
		assert mat in KINDS, mat
		self.kind, self.size, self.pos, self.rot = kind, tuple(size), tuple(pos), rot
		self.color, self.mat = to_rgb(color), mat
		self.bevel = DEFAULT_BEVEL[kind] if bevel is None else bevel
		self.name, self.sides, self.spin, self.stud, self.shadow = name, sides, spin, stud, shadow


class Model:
	def __init__(self, id, name=None, unit=0.2, kind='gun'):
		self.id, self.name, self.unit, self.kind = id, name or id, unit, kind
		self.prims = []
		self.meta = {}
		self._frame = [(IDENT, (0.0, 0.0, 0.0))]

	# ---------- frames: build a sub-assembly in its own local space ----------
	@contextmanager
	def at(self, pos=(0, 0, 0), rot=None):
		r0, p0 = self._frame[-1]
		r = mat_mul(r0, rot or IDENT)
		self._frame.append((r, add(mat_vec(r0, pos), p0)))
		try:
			yield self
		finally:
			self._frame.pop()

	def _place(self, pos, rot):
		r0, p0 = self._frame[-1]
		return add(mat_vec(r0, pos), p0), mat_mul(r0, rot or IDENT)

	def _add(self, prim):
		self.prims.append(prim)
		return prim

	# ---------- primitives ----------
	def box(self, pos, size, color, mat='smooth', rot=None, studs=False, bevel=None, name=None, skip=None, shadow=None):
		p, r = self._place(pos, rot)
		prim = self._add(Prim('box', size, p, r, color, mat, bevel, name, shadow=shadow))
		if studs:
			self.studs_on(prim, studs, skip)
		return prim

	def wedge(self, pos, size, color, mat='smooth', rot=None, bevel=None, name=None):
		p, r = self._place(pos, rot)
		return self._add(Prim('wedge', size, p, r, color, mat, bevel, name))

	def cyl(self, pos, length, d, color, mat='smooth', axis='x', rot=None, bevel=None, name=None, stud=False, shadow=None):
		p, r = self._place(pos, mat_mul(rot or IDENT, AXIS[axis]))
		return self._add(Prim('cyl', (length, d, d), p, r, color, mat, bevel, name, stud=stud, shadow=shadow))

	def prism(self, pos, length, d, color, mat='smooth', sides=8, axis='x', spin=0.0, rot=None, bevel=None, name=None):
		"""Low-poly n-gon prism (even sides). d is flat-to-flat. Roblox gets sides/2 crossed blocks."""
		assert sides % 2 == 0 and sides >= 4
		p, r = self._place(pos, mat_mul(rot or IDENT, AXIS[axis]))
		return self._add(Prim('prism', (length, d, d), p, r, color, mat, bevel, name, sides=sides, spin=spin))

	def ball(self, pos, d, color, mat='smooth', name=None):
		p, r = self._place(pos, None)
		return self._add(Prim('ball', (d, d, d), p, r, color, mat, 0.0, name))

	def stud(self, pos, color, mat='smooth', rot=None, d=STUD_D, h=STUD_H):
		"""A single stud standing on local +Y (pos is the centre of the stud's base)."""
		p, r = self._place(add(pos, (0, h / 2 - STUD_EMBED, 0)), mat_mul(rot or IDENT, AXIS['y']))
		return self._add(Prim('cyl', (h, d, d), p, r, color, mat, STUD_BEVEL, 'Stud', stud=True, shadow=False))

	def studs_on(self, prim, spec=True, skip=None):
		"""Classic studs on the local +Y face of a box, one per whole DU. spec: True or (nx, nz).
		skip(x, z) can drop studs (box-local coords), e.g. where a ribbon or handle sits."""
		sx, sy, sz = prim.size
		if spec is True:
			nx, nz = int(math.floor(sx + 0.3)), int(math.floor(sz + 0.3))
		else:
			nx, nz = spec
		for i in range(nx):
			for j in range(nz):
				lx, lz = (i - (nx - 1) / 2), (j - (nz - 1) / 2)
				if skip and skip(lx, lz):
					continue
				local = (lx, sy / 2 + STUD_H / 2 - STUD_EMBED, lz)
				pos = add(mat_vec(prim.rot, local), prim.pos)
				rot = mat_mul(prim.rot, AXIS['y'])
				self.prims.append(Prim('cyl', (STUD_H, STUD_D, STUD_D), pos, rot, prim.color, prim.mat, STUD_BEVEL, 'Stud', stud=True, shadow=False))

	def tri(self, base, tip_dir, side_dir, height, width, thick, color, mat='smooth', bevel=None, name=None):
		"""Isosceles triangle slab (an arrowhead) from two wedges. base: centre of the base edge;
		tip_dir: unit vector from base to tip; side_dir: unit vector along the base; thick: slab depth."""
		p0, r0 = self._place(base, None)
		u, v = norm(mat_vec(r0, tip_dir)), norm(mat_vec(r0, side_dir))
		for sgn in (1, -1):
			vv = scale_v(v, sgn)
			zw = scale_v(u, -1)
			xw = cross(vv, zw)
			rot = from_columns(xw, vv, zw)
			centre = add(add(p0, scale_v(vv, width / 4)), scale_v(u, height / 2))
			self.prims.append(Prim('wedge', (thick, width / 2, height), centre, rot, color, mat, bevel, name))

	# ---------- results ----------
	def roblox_parts(self):
		"""Expand to plain Roblox parts in DU: dicts with cls, shape, size, pos, rot, color, mat, name, stud."""
		out = []
		for p in self.prims:
			base = dict(color=p.color, mat=p.mat, name=p.name, stud=p.stud, shadow=p.shadow)
			if p.kind == 'box':
				out.append(dict(base, cls='Part', shape='Block', size=p.size, pos=p.pos, rot=p.rot))
			elif p.kind == 'wedge':
				out.append(dict(base, cls='WedgePart', shape='Wedge', size=p.size, pos=p.pos, rot=p.rot))
			elif p.kind == 'cyl':
				out.append(dict(base, cls='Part', shape='Cylinder', size=p.size, pos=p.pos, rot=p.rot))
			elif p.kind == 'ball':
				out.append(dict(base, cls='Part', shape='Ball', size=p.size, pos=p.pos, rot=p.rot))
			elif p.kind == 'prism':
				# A regular even n-gon is the union of n/2 bands, each spanning two opposite edges.
				length, d = p.size[0], p.size[1]
				n = p.sides
				side = d * math.tan(math.pi / n)
				for k in range(n // 2):
					rot = mat_mul(p.rot, rot_x(p.spin + k * 360.0 / n))
					out.append(dict(base, cls='Part', shape='Block', size=(length, d, side), pos=p.pos, rot=rot,
						name=(p.name or 'Prism') if k == 0 else (p.name or 'Prism') + str(k + 1)))
		return out

	def bounds(self):
		"""Exact axis-aligned bounds (DU) of the expanded Roblox parts: wedges by their six corners,
		cylinders and balls by their round extents, blocks by their corners."""
		lo, hi = [math.inf] * 3, [-math.inf] * 3
		for part in self.roblox_parts():
			s, r, c = part['size'], part['rot'], part['pos']
			for i in range(3):
				if part['shape'] == 'Cylinder':
					a = abs(r[i][0])
					h = a * s[0] / 2 + math.sqrt(max(0.0, 1 - a * a)) * s[1] / 2
					vals = (c[i] - h, c[i] + h)
				elif part['shape'] == 'Ball':
					vals = (c[i] - s[0] / 2, c[i] + s[0] / 2)
				else:
					x, y, z = s[0] / 2, s[1] / 2, s[2] / 2
					corners = [(-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z), (-x, y, z), (x, y, z)]
					if part['shape'] == 'Block':
						corners += [(-x, y, -z), (x, y, -z)]
					vals = [c[i] + r[i][0] * v[0] + r[i][1] * v[1] + r[i][2] * v[2] for v in corners]
				lo[i] = min(lo[i], min(vals))
				hi[i] = max(hi[i], max(vals))
		return tuple(lo), tuple(hi)

	def recentre(self):
		"""Move everything so the bounding-box centre sits on the origin (icons)."""
		lo, hi = self.bounds()
		c = tuple((lo[i] + hi[i]) / 2 for i in range(3))
		for p in self.prims:
			p.pos = sub(p.pos, c)
		if 'muzzle' in self.meta:
			self.meta['muzzle'] = sub(self.meta['muzzle'], c)
		return c

	def part_count(self):
		return len(self.roblox_parts())


# ---------- lint ----------
def _block_faces(part):
	"""World-space faces of a block: (normal, centre, [4 corners])."""
	r, c, size = part['rot'], part['pos'], part['size']
	axes = [column(r, i) for i in range(3)]
	out = []
	for ax in range(3):
		o1, o2 = [k for k in range(3) if k != ax]
		for sgn in (-1, 1):
			n = scale_v(axes[ax], sgn)
			fc = add(c, scale_v(n, size[ax] / 2))
			u, v = scale_v(axes[o1], size[o1] / 2), scale_v(axes[o2], size[o2] / 2)
			corners = [add(add(fc, scale_v(u, a)), scale_v(v, b)) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
			out.append((n, fc, corners))
	return out


def _clip(poly, edge_a, edge_b):
	"""Sutherland-Hodgman: keep the part of a 2D polygon left of the edge a->b."""
	def inside(p):
		return (edge_b[0] - edge_a[0]) * (p[1] - edge_a[1]) - (edge_b[1] - edge_a[1]) * (p[0] - edge_a[0]) >= -1e-9

	def cut(p, q):
		x1, y1, x2, y2 = p[0], p[1], q[0], q[1]
		x3, y3, x4, y4 = edge_a[0], edge_a[1], edge_b[0], edge_b[1]
		den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
		t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
		return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))
	out = []
	for i in range(len(poly)):
		p, q = poly[i], poly[(i + 1) % len(poly)]
		if inside(q):
			if not inside(p):
				out.append(cut(p, q))
			out.append(q)
		elif inside(p):
			out.append(cut(p, q))
	return out


def _area(poly):
	return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))) / 2


def lint(model, min_size=0.001):
	"""Problems that show up as artefacts: block faces lying in the same plane and overlapping (they
	z-fight in Roblox and render as black speckles in Cycles), and parts thinner than Roblox allows."""
	issues = []
	parts = model.roblox_parts()
	for i, p in enumerate(parts):
		if min(p['size']) * model.unit < min_size:
			issues.append('%s #%d %s thinner than %.3f studs' % (model.id, i, p['name'], min_size))
	blocks = [(i, p, _block_faces(p)) for i, p in enumerate(parts) if p['shape'] == 'Block']
	for a in range(len(blocks)):
		ia, pa, fa_list = blocks[a]
		for b in range(a + 1, len(blocks)):
			ib, pb, fb_list = blocks[b]
			if pa['pos'] == pb['pos'] and (pa['name'] or '').rstrip('0123456789') == (pb['name'] or '').rstrip('0123456789'):
				continue  # bands of one prism share their caps by design (Blender renders the real n-gon)
			for na, ca, qa in fa_list:
				for nb, cb, qb in fb_list:
					if sum(na[k] * nb[k] for k in range(3)) < 0.9999:
						continue
					if abs(sum(na[k] * (cb[k] - ca[k]) for k in range(3))) > 1e-3:
						continue
					u = norm(sub(qa[1], qa[0]))
					v = cross(na, u)
					to2 = lambda p: (sum((p[k] - ca[k]) * u[k] for k in range(3)), sum((p[k] - ca[k]) * v[k] for k in range(3)))
					poly = [to2(p) for p in qb]
					ra = [to2(p) for p in qa]
					if _area(ra) <= 0 or _area(poly) <= 0:
						continue
					# make both counter-clockwise
					def ccw(pl):
						sa = sum(pl[i][0] * pl[(i + 1) % 4][1] - pl[(i + 1) % 4][0] * pl[i][1] for i in range(4))
						return pl if sa > 0 else pl[::-1]
					ra, poly = ccw(ra), ccw(poly)
					for i in range(4):
						if not poly:
							break
						poly = _clip(poly, ra[i], ra[(i + 1) % 4])
					if len(poly) >= 3 and _area(poly) > 1e-3:
						issues.append('%s: %s #%d / %s #%d coplanar faces overlap %.3f DU^2' % (model.id, pa['name'], ia, pb['name'], ib, _area(poly)))
	return issues
