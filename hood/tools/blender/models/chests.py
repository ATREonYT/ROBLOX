"""The World 1 shoe boxes as chests (brief 30), modelled after the user's render sheets
(brief/ref30/user_models/01-Street-Box.png .. 05-The-Grail-Bundle.png): each shown closed and open, with a handle and
a hinged lid.

  Street      white and red: red corner posts with little square studs, a white front panel with a red crown, a
              yellow and a white plate on the sides, a white lid with red corner caps, a red latch band with a gold
              latch, a red handle
  Graffiti    cyan and pink: pink paint dripping from the pink lid, a white X tag, a pink heart and a yellow star on
              the front, a white jagged splash round the foot, yellow tape on the lid's corners, a white hasp, a cyan
              handle
  Exclusive   (shown as the Chrome Box) navy and white: white-grey lid sides and corner blocks with diamond studs, a
              navy front panel with a big cyan cut diamond between two cyan straps, cyan plates on the sides, a cyan
              handle
  Grail       (shown as the Crown Box) purple and gold: gold foot, corner posts with gold diamonds, a gold crown on the
              front, big gold wings on the sides, a gold trim and latch on the purple lid, a gold handle
  GrailBundle purple, gold and white: a white band over the foot, gold corner brackets, a gold crown between two
              white wings on the front, white wings on the sides, a chunky bevelled lid with purple block studs and
              a gold hasp

Space: Roblox axes, studs (unit 1); the box stands on y = 0, centred on x = z = 0, its front toward -Z. Every box
shares one frame (BoxModels.Size: W 4.4, D 3.4, the seam (Body) at 2.1, the lid's top (Top) at 3.08), so the reveal's
layout, seal and hinge work for any of them. Tags: group = 'body' | 'lid' | 'topper' (the topper rides the lid); the
lid swings about the HINGE on the body's back top edge (0, Body, D / 2). The tub is hollow (an inside floor and walls
in the inside colour) and the lid has an inside plate, so the open view shows the inside like the sheets.
Budget: <= 140 parts a box.
"""
import math

import boxkit as bk

W, D = 4.4, 3.4
BODY, TOP = 2.1, 3.08
HW, HD = W / 2, D / 2
HINGE = (0.0, BODY, HD)
WALL = 0.3          # the tub's wall thickness (the rim seen when open)
FLOOR = 0.42        # the inside floor's top
LID_OUT = 0.06      # the lid stands this much proud of the tub all round
FOOT_H = 0.34       # the foot band's height
FOOT_OUT = 0.08     # and how far it stands out
MIN_T = 0.066       # the thinnest a piece may be (brief 28's finish: nothing hair-thin)

PI = math.pi


def P(*c):
	return tuple(c)


# ---------------------------------------------------------------------------------------------- the kit
class Chest:
	def __init__(self, id, name):
		self.m = bk.Model(id, name, unit=1.0, kind='box')
		self.seal = None

	# groups
	def body(self):
		return self.m.tagged(group='body')

	def lid(self):
		return self.m.tagged(group='lid')

	def topper(self):
		return self.m.tagged(group='topper')

	def box(self, pos, size, color, name, mat='smooth', rot=None, bevel=None):
		return self.m.box(pos, size, color, mat, rot=rot, name=name, bevel=bevel)

	def span(self, a, b, color, name, mat='smooth', bevel=None):
		lo = tuple(min(a[i], b[i]) for i in range(3))
		hi = tuple(max(a[i], b[i]) for i in range(3))
		return self.m.box(tuple((lo[i] + hi[i]) / 2 for i in range(3)), tuple(hi[i] - lo[i] for i in range(3)), color, mat, name=name, bevel=bevel)

	# the tub: hollow (floor + four walls in the inside colour), dressed outside by the box's own pieces
	def tub(self, inside, foot, foot_h=FOOT_H):
		with self.body():
			self.span((-HW - FOOT_OUT, 0.0, -HD - FOOT_OUT), (HW + FOOT_OUT, foot_h, HD + FOOT_OUT), foot, 'Foot')
			self.span((-HW + 0.01, foot_h - 0.02, -HD + 0.01), (HW - 0.01, FLOOR, HD - 0.01), inside, 'Inside')
			# walls: front and back the full width, the sides between them (their tops are the rim seen when open)
			self.span((-HW, FLOOR - 0.01, -HD), (HW, BODY, -HD + WALL), inside, 'Inside')
			self.span((-HW, FLOOR - 0.01, HD - WALL), (HW, BODY - 0.003, HD), inside, 'Inside')
			self.span((-HW, FLOOR - 0.01, -HD + WALL - 0.004), (-HW + WALL, BODY - 0.006, HD - WALL + 0.004), inside, 'Inside')
			self.span((HW - WALL, FLOOR - 0.01, -HD + WALL - 0.004), (HW, BODY - 0.006, HD - WALL + 0.004), inside, 'Inside')

	def faces(self, color, y0=FOOT_H, y1=BODY - 0.02, proud=0.03, name='Body', sides=None, back=None):
		"""The tub's outer skin: four thin slabs just proud of the walls (front and back the full width, the sides
		between them), so the tub stays hollow. sides / back: other colours for those faces."""
		t = proud + 0.02
		with self.body():
			self.span((-HW - proud, y0, -HD - proud), (HW + proud, y1, -HD + 0.02), color, name)
			self.span((-HW - proud, y0, HD - 0.02), (HW + proud, y1, HD + proud), back or color, name)
			for sx in (-1, 1):
				self.span((sx * (HW - 0.02), y0 + 0.002, -HD + 0.02), (sx * (HW + proud), y1 - 0.002, HD - 0.02), sides or color, name)

	def band(self, y0, y1, color, out, name='BodyBand'):
		"""A band round the tub (y0..y1), standing `out` proud: four slabs, so the tub stays hollow."""
		t = out + 0.04
		with self.body():
			self.span((-HW - out, y0, -HD - out), (HW + out, y1, -HD + 0.04), color, name)
			self.span((-HW - out, y0, HD - 0.04), (HW + out, y1, HD + out), color, name)
			for sx in (-1, 1):
				self.span((sx * (HW - 0.04), y0 + 0.002, -HD + 0.04), (sx * (HW + out), y1 - 0.002, HD - 0.04), color, name)

	def lid_block(self, color, inside, y0=BODY, y1=TOP - 0.12, cap=None, cap_in=0.35, cap_h=0.12, rim=None, rim_h=0.0):
		"""The lid: an optional rim band at its foot, the lid body, the cap panel on top, and its inside plate."""
		o = LID_OUT
		with self.lid():
			if rim:
				self.span((-HW - o - 0.02, y0, -HD - o - 0.02), (HW + o + 0.02, y0 + rim_h, HD + o + 0.02), rim, 'LidRim')
				y0b = y0 + rim_h - 0.002
			else:
				y0b = y0
			self.span((-HW - o, y0b, -HD - o), (HW + o, y1, HD + o), color, 'LidBody')
			self.span((-HW - o + cap_in, y1 - 0.01, -HD - o + cap_in), (HW + o - cap_in, y1 + cap_h, HD + o - cap_in), cap or color, 'LidCap')
			self.span((-HW + WALL + 0.03, y0 - 0.025, -HD + WALL + 0.03), (HW - WALL - 0.03, y0 + 0.02, HD - WALL - 0.03), inside, 'LidInside')

	def handle(self, color, y=TOP, z=0.35, w=1.0, h=0.42, t=0.2):
		"""A rectangular loop on the lid's top (the sheets' handle): two posts and a grip bar, with a slot."""
		with self.topper():
			for sx in (-1, 1):
				self.box((sx * (w / 2 - t / 2), y + h / 2 - 0.02, z), (t, h + 0.04, 0.26), color, 'Handle')
			self.box((0.0, y + h - t / 2, z), (w - 2 * t + 0.004, t, 0.26 - 0.006), color, 'Handle')
			self.box((0.0, y + 0.03, z), (w - 2 * t + 0.01, 0.06, 0.2), color, 'Handle')

	def stud(self, pos, normal, s, color, name='Stud', t=0.05, rot45=False):
		"""A small square bevelled stud on a face (normal: 'x+', 'x-', 'z-', 'z+', 'y+'); rot45: a diamond."""
		n = {'x+': (1, 0, 0), 'x-': (-1, 0, 0), 'z-': (0, 0, -1), 'z+': (0, 0, 1), 'y+': (0, 1, 0)}[normal]
		c = tuple(pos[i] + n[i] * t / 2 for i in range(3))
		if normal[0] == 'x':
			size, rot = (t, s, s), (bk.rot_x(45) if rot45 else None)
		elif normal[0] == 'z':
			size, rot = (s, s, t), (bk.rot_z(45) if rot45 else None)
		else:
			size, rot = (s, t, s), (bk.rot_y(45) if rot45 else None)
		return self.m.box(c, size, color, 'smooth', rot=rot, name=name, bevel=0.012)

	def hinge(self):
		with self.lid():
			self.m.box(HINGE, (0.4, 0.1, 0.1), (255, 255, 255), name='Hinge', bevel=0)


def front(x, y, proud=0.0):
	return (x, y, -HD - proud)


# ---------------------------------------------------------------------------------------------- emblems
def crown_front(c, x, y, z, size, color, name='Emblem', tips=True, t=0.1):
	"""A crown standing on a front face (z = its back plane), like the sheets': a wide band, a body, and three pointed
	peaks on it (flat triangles: the middle one tallest, the outer two leaning out) with notches down to the body
	between them and round tips. 8-11 parts."""
	s = size
	m = c.m
	c.box((x, y + s * 0.06, z - t / 2), (s * 1.0, s * 0.12, t + 0.008), color, name)           # the band
	c.box((x, y + s * 0.29, z - t / 2), (s * 0.84, s * 0.36, t), color, name)                  # the body
	for i, (dx, lean, h, w) in enumerate(((-0.29, 16.0, 0.36, 0.32), (0.0, 0.0, 0.42, 0.36), (0.29, -16.0, 0.36, 0.32))):
		a = math.radians(lean)
		u = (-math.sin(a), math.cos(a), 0.0)
		v = (math.cos(a), math.sin(a), 0.0)
		# (a leaning peak's base tilts with it: lowered so its inner corner stays inside the body)
		base = (x + dx * s, y + s * (0.45 - w / 2 * abs(math.sin(a))), z - t / 2 - 0.004 - 0.003 * i)
		m.tri(base, u, v, h * s, w * s, t - 0.006, color, name=name)
		if tips:
			m.ball((base[0] + u[0] * h * s, base[1] + u[1] * h * s, z - t / 2), s * 0.12, color, name=name)


def wing_side(c, x_sign, cy, cz, size, colors, name='Wing', splay=60.0):
	"""A big chunky gold wing on a side face (x = x_sign * HW), like the Crown box's: spread out from the side by
	`splay` degrees and reaching forward (so from the sheets' corner view the near wing covers its side and the far one
	shows beside the box), from a root block high on the side: a long top feather rising past the lid, three broad ones
	under it fanning down to level and overlapping, a paler layer over their roots on the outer face. The feathers (tips
	cut on the slant) keep clear of the lid's side, so the lid swings past them. 12 parts."""
	m = c.m
	feathers = ((48, 1.0), (26, 0.84), (8, 0.72), (-10, 0.6))
	# local +X out from the side and forward; local Y up; local Z the wing's normal
	th = math.degrees(math.atan2(math.cos(math.radians(splay)), x_sign * math.sin(math.radians(splay))))
	out = -0.13 * x_sign
	m.box((x_sign * (HW + 0.17), cy - size * 0.2, cz + 0.1), (0.34, size * 0.4, 0.5), colors[0], 'smooth', name=name)
	with m.at((x_sign * (HW + 0.2), cy, cz), bk.rot_y(th)):
		for j, (deg, ln) in enumerate(feathers):
			L = size * ln
			with m.at((0.0, -j * size * 0.25, 0.012 * j), bk.rot_z(deg)):
				m.box((L * 0.37 + 0.05, 0.0, 0.0), (L * 0.74, size * 0.36, 0.22), colors[0], 'smooth', name=name, bevel=0.1)
				# the tip cut on the slant: the top edge runs on, the bottom edge stops (a wedge, its right angle at the
				# box's top end corner)
				m.wedge((L * 0.74 + 0.05 + L * 0.15 - 0.002, 0.0, 0.0), (0.22 - 0.004, size * 0.36, L * 0.3), colors[0], 'smooth',
					rot=((0.0, 0.0, -1.0), (0.0, -1.0, 0.0), (-1.0, 0.0, 0.0)), name=name, bevel=0.1)
				if j:
					m.box((L * 0.28 + 0.05, 0.0, out), (L * 0.52, size * 0.3, 0.1), colors[1], 'smooth', name=name, bevel=0.08)


def flat_wing(c, cx, cy, z, size, color, mirror=False, name='Wing'):
	"""A small white wing flat on a face (the Grail Bundle's): three rounded feathers (flat ellipsoids) from a root at
	(cx, cy) pointing outward (to +x, or -x when mirrored), the top one longest and tilted up, the lower ones fanning
	down. 3 parts."""
	m = c.m
	sx = -1 if mirror else 1
	for j, (ang, ln) in enumerate(((24, 1.0), (8, 0.84), (-8, 0.66))):
		with m.at((cx, cy - j * size * 0.17, z - 0.04 - 0.006 * j), bk.rot_z(sx * ang)):
			m.egg((sx * ln * size * 0.5, 0.0, 0.0), (ln * size, size * 0.36, 0.1), color, name=name)


def star5_front(c, x, y, z, size, color, name='Star', t=0.1):
	"""A five-point star on a front face (z = its back plane): a pentagon-ish centre disc and five pointed arms, each two
	wedges back to back (a flat triangle). 11 parts."""
	r = size / 2
	m = c.m
	for i in range(5):
		a = math.radians(90 + 72 * i)
		u = (math.cos(a), math.sin(a), 0.0)
		v = (-math.sin(a), math.cos(a), 0.0)
		base = (x + u[0] * r * 0.3, y + u[1] * r * 0.3, z - t / 2 - 0.003 * (i % 2))
		m.tri(base, u, v, r * 0.72, r * 0.66, t, color, name=name)
	m.cyl((x, y, z - t / 2 - 0.006), t + 0.004, r * 0.78, color, 'smooth', axis='z', name=name)


# ---------------------------------------------------------------------------------------------- the boxes
RED = P(226, 30, 40)
RED_D = P(196, 18, 28)
WHITE = P(246, 246, 248)
GREY_IN = P(220, 222, 228)
GOLD = P(250, 200, 44)
YELLOW = P(252, 222, 70)


def street():
	c = Chest('Street', 'Street Box')
	c.tub(GREY_IN, RED, foot_h=0.32)
	post = 0.62
	with c.body():
		# corner blocks on the foot and red corner posts up to the seam
		for sx in (-1, 1):
			for sz in (-1, 1):
				c.span((sx * (HW + 0.1), 0.0, sz * (HD + 0.1)), (sx * (HW - post + 0.02), 0.44, sz * (HD - post + 0.02)), RED_D, 'Foot')
				c.span((sx * (HW + 0.07), 0.44 - 0.002, sz * (HD + 0.07)), (sx * (HW - post), BODY - 0.01, sz * (HD - post)), RED, 'Post')
		# the skin: a white front panel between the posts, red sides and back
		c.span((-HW + post, 0.3, -HD - 0.04), (HW - post, BODY - 0.04, -HD + 0.02), WHITE, 'Body')
		for sx in (-1, 1):
			c.span((sx * (HW - 0.02), 0.3, -HD + post), (sx * (HW + 0.03), BODY - 0.02, HD - post), RED, 'Body')
		c.span((-HW + post, 0.3, HD - 0.02), (HW - post, BODY - 0.02, HD + 0.03), RED, 'BodyBand')
		# little square studs down the posts' outer faces (red, a yellow one among them), front and back faces
		for sx in (-1, 1):
			for sz in (-1, 1):
				x0, z0 = sx * (HW + 0.07), sz * (HD + 0.07)
				for k, y in enumerate((0.72, 1.12, 1.52, 1.86)):
					col = GOLD if (k == 1 and sz < 0) else P(240, 54, 62)
					c.stud((sx * (HW - post / 2 + 0.035), y, z0), 'z-' if sz < 0 else 'z+', 0.16, col)
					if k % 2 == 0:
						c.stud((x0, y, sz * (HD - post / 2 + 0.035)), 'x+' if sx > 0 else 'x-', 0.15, P(240, 54, 62))
		# the side plates: yellow high, white low (both sides); the back gets a white plate
		for sx in (-1, 1):
			c.span((sx * (HW + 0.03), 1.25, -0.55), (sx * (HW + 0.1), 1.75, 0.45), YELLOW, 'Plate')
			c.span((sx * (HW + 0.03), 0.52, -0.55), (sx * (HW + 0.09), 0.92, 0.25), WHITE, 'Plate')
		c.span((-0.6, 0.9, HD + 0.03), (0.6, 1.5, HD + 0.09), WHITE, 'Plate')
		# the crown on the front panel (red, raised)
		crown_front(c, 0.0, 0.3, -HD - 0.04, 1.52, RED)
		# the panel's four corner screws
		for x in (-HW + post + 0.18, HW - post - 0.18):
			for y in (0.48, BODY - 0.24):
				c.m.cyl((x, y, -HD - 0.06), 0.04, 0.08, P(230, 230, 236), 'smooth', axis='z', name='Screw')
	# the lid: white, red corner caps, a red latch band with a gold latch, white studs
	c.lid_block(WHITE, GREY_IN, y1=TOP - 0.1, cap=WHITE, cap_in=0.45, cap_h=0.1)
	o = LID_OUT
	with c.lid():
		for sx in (-1, 1):
			for sz in (-1, 1):
				x1, z1 = sx * (HW + o + 0.05), sz * (HD + o + 0.05)
				cw = 0.62
				# an L of red on the top's corner, and the corner's edge in red down the lid's side (a narrow strip)
				c.span((x1, TOP - 0.12, z1), (sx * (HW + o - cw), TOP + 0.04, sz * (HD + o - 0.24)), RED, 'LidCorner')
				c.span((x1 - sx * 0.002, TOP - 0.118, z1 - sz * 0.002), (sx * (HW + o - 0.24), TOP + 0.038, sz * (HD + o - cw)), RED, 'LidCorner')
				c.span((x1, BODY + 0.06, z1), (sx * (HW + o - 0.3), TOP - 0.1, sz * (HD + o - 0.3)), RED, 'LidCorner')
		# the latch band on the front and its gold latch
		c.span((-0.75, BODY - 0.04, -HD - o - 0.07), (0.75, TOP - 0.06, -HD - o + 0.1), RED, 'Latch')
		c.span((-0.42, BODY + 0.18, -HD - o - 0.15), (0.42, BODY + 0.52, -HD - o - 0.06), GOLD, 'LatchPlate')
		for x in (-0.55, 0.55):
			c.stud((x, TOP - 0.3, -HD - o - 0.07), 'z-', 0.13, P(244, 64, 70))
		c.span((-0.75, TOP - 0.1, -HD - o - 0.07), (0.75, TOP + 0.06, -HD - o + 0.75), RED, 'Latch')
		# white square studs on the lid's white sides
		for x in (-1.45, 1.45):
			c.stud((x, BODY + 0.4, -HD - o), 'z-', 0.17, P(236, 236, 240))
		for sx in (-1, 1):
			for z in (-0.6, 0.6):
				c.stud((sx * (HW + o), BODY + 0.4, z), 'x+' if sx > 0 else 'x-', 0.17, P(236, 236, 240))
	c.handle(RED, z=0.3)
	c.hinge()
	c.seal = dict(body=-HD - 0.04, lid=-HD - o - 0.07, low=BODY - 0.32, top=TOP + 0.06)
	return c


def graffiti():
	PINK = P(250, 74, 160)
	PINK2 = P(250, 110, 190)
	CYAN = P(16, 190, 236)
	CYAN_IN = P(30, 160, 214)
	c = Chest('Graffiti', 'Graffiti Box')
	c.tub(CYAN_IN, WHITE, foot_h=0.3)
	with c.body():
		c.faces(CYAN, y0=0.28, proud=0.03)
		# the white splash round the foot: jagged white squares turned on the faces, and white corner blocks
		for sx in (-1, 1):
			for sz in (-1, 1):
				c.span((sx * (HW + 0.1), 0.0, sz * (HD + 0.1)), (sx * (HW - 0.5), 0.5, sz * (HD - 0.5)), WHITE, 'Foot')
		for i, (x, s) in enumerate(((-1.35, 0.62), (-0.5, 0.5), (0.35, 0.66), (1.2, 0.5))):
			c.box((x, s * 0.7 + 0.01, -HD - 0.05 - 0.004 * i), (s, s, 0.06), WHITE, 'Splash', rot=bk.rot_z(45))
		for sx in (-1, 1):
			for i, (z, s) in enumerate(((-0.75, 0.6), (0.2, 0.5), (1.0, 0.56))):
				c.box((sx * (HW + 0.05 + 0.004 * i), s * 0.7 + 0.01, z), (0.06, s, s), WHITE, 'Splash', rot=bk.rot_x(45))
		# paint dripping from the lid: pink runs of different lengths with round ends (front and sides)
		runs = ((-1.95, 0.55), (-1.45, 0.95), (-0.75, 0.4), (1.35, 0.75), (1.9, 0.5))
		for i, (x, ln) in enumerate(runs):
			z = -HD - 0.05 - 0.002 * i
			c.box((x, BODY - ln / 2, z), (0.16, ln, 0.05), PINK, 'Drip')
			c.m.cyl((x, BODY - ln, z), 0.05, 0.2, PINK, 'smooth', axis='z', name='Drip')
		for sx in (-1, 1):
			for i, (z, ln) in enumerate(((-1.2, 0.8), (-0.3, 0.45), (0.7, 0.7))):
				x = sx * (HW + 0.05 + 0.002 * i)
				c.box((x, BODY - ln / 2, z), (0.05, ln, 0.16), PINK, 'Drip')
				c.m.cyl((x, BODY - ln, z), 0.05, 0.2, PINK, 'smooth', axis='x', name='Drip')
		# the front's tag: a pink heart behind a big white X tag, a yellow star, a little white star at the left
		fz = -HD - 0.03
		c.m.cyl((-0.62, 1.12, fz - 0.05), 0.06, 0.78, PINK2, 'smooth', axis='z', name='Heart')
		c.m.cyl((0.02, 1.12, fz - 0.052), 0.06, 0.78, PINK2, 'smooth', axis='z', name='Heart')
		c.box((-0.3, 0.78, fz - 0.054), (0.9, 0.9, 0.06), PINK2, 'Heart', rot=bk.rot_z(45))
		# the white tag: a big 'A' (two thick strokes leaning together) with its crossbar running out to the left
		c.box((-0.52, 1.0, fz - 0.11), (0.32, 1.45, 0.08), WHITE, 'Tag', rot=bk.rot_z(-24))
		c.box((0.06, 1.0, fz - 0.118), (0.32, 1.45, 0.08), WHITE, 'Tag', rot=bk.rot_z(24))
		c.box((-0.42, 0.92, fz - 0.126), (1.35, 0.28, 0.08), WHITE, 'Tag', rot=bk.rot_z(8))
		star5_front(c, 1.35, 1.0, fz, 1.15, YELLOW)
		star5_front(c, -1.8, 0.8, fz, 0.6, WHITE)
		# the sides: a white star and a yellow splat
		for sx in (-1, 1):
			with c.m.at((sx * (HW + 0.03), 0.0, 0.0), bk.rot_y(-sx * 90)):
				star5_front(c, -0.35 * sx, 0.95, 0.0, 0.62, WHITE)
				c.m.cyl((0.7 * sx, 0.72, -0.05), 0.06, 0.34, YELLOW, 'smooth', axis='z', name='Splat')
	o = LID_OUT
	c.lid_block(PINK, P(236, 90, 170), y1=TOP - 0.1, cap=PINK, cap_in=0.4, cap_h=0.1)
	with c.lid():
		# pink corner blocks with a little yellow stud on each, yellow tape across two corners
		for sx in (-1, 1):
			for sz in (-1, 1):
				c.span((sx * (HW + o + 0.06), BODY - 0.02, sz * (HD + o + 0.06)), (sx * (HW + o - 0.5), TOP - 0.08, sz * (HD + o - 0.5)), P(244, 60, 150), 'LidCorner')
				c.stud((sx * (HW + o + 0.06), BODY + 0.62, sz * (HD + o - 0.25)), 'x+' if sx > 0 else 'x-', 0.14, YELLOW)
				c.stud((sx * (HW + o - 0.25), BODY + 0.62, sz * (HD + o + 0.06)), 'z+' if sz > 0 else 'z-', 0.14, YELLOW)
		c.span((-HW - o - 0.07, BODY + 0.12, -0.95), (-HW - o + 0.6, TOP + 0.02, -0.55), YELLOW, 'Tape')
		c.span((HW + o - 1.1, TOP - 0.06, HD - 0.75), (HW + o - 0.5, TOP + 0.03, HD + o + 0.05), YELLOW, 'Tape')
		# the white hasp hanging over the seam, with its slot
		c.span((-0.68, BODY - 0.32, -HD - o - 0.1), (0.68, TOP - 0.22, -HD - o + 0.02), WHITE, 'Latch')
		c.span((-0.26, BODY - 0.18, -HD - o - 0.16), (0.26, BODY + 0.08, -HD - o - 0.08), P(214, 216, 224), 'LatchPlate')
		for x in (-0.55, 0.55):
			c.stud((x, TOP - 0.36, -HD - o - 0.1), 'z-', 0.1, P(224, 226, 232))
	c.handle(CYAN, z=0.25)
	c.hinge()
	c.seal = dict(body=-HD - 0.03, lid=-HD - o - 0.1, low=BODY - 0.55, top=TOP)
	return c


def chrome():
	NAVY = P(40, 46, 72)
	NAVY2 = P(56, 66, 100)
	NAVY_D = P(28, 32, 50)
	SILVER = P(224, 230, 238)
	CYAN = P(34, 206, 248)
	c = Chest('Exclusive', 'Chrome Box')
	c.tub(NAVY_D, SILVER, foot_h=0.34)
	o = LID_OUT
	with c.body():
		c.faces(NAVY, y0=0.32, proud=0.03)
		# silver corner blocks on the foot
		for sx in (-1, 1):
			for sz in (-1, 1):
				c.span((sx * (HW + 0.12), 0.0, sz * (HD + 0.12)), (sx * (HW - 0.6), 0.5, sz * (HD - 0.6)), SILVER, 'Foot')
		# the front: a navy panel (rising onto the lid) between two cyan straps with white diamond studs
		c.span((-1.05, 0.5, -HD - 0.09), (1.05, BODY - 0.02, -HD + 0.1), NAVY2, 'Panel')
		for sx in (-1, 1):
			c.span((sx * 1.05, 0.5, -HD - 0.12), (sx * 1.5, BODY + 0.0, -HD + 0.1), CYAN, 'Strap')
			for y in (0.85, 1.55):
				c.stud((sx * 1.275, y, -HD - 0.12), 'z-', 0.15, P(236, 250, 255), rot45=True)
		# the big cut diamond: a square turned 45 degrees, a lighter table and a glint
		gz = -HD - 0.09
		c.box((0.0, 1.0, gz - 0.07), (1.06, 1.06, 0.14), CYAN, 'Gem', rot=bk.rot_z(45))
		c.box((0.0, 1.0, gz - 0.16), (0.6, 0.6, 0.06), P(120, 232, 255), 'GemTable', rot=bk.rot_z(45))
		c.box((-0.1, 1.12, gz - 0.198), (0.14, 0.14, 0.02), P(240, 252, 255), 'GemGlint', rot=bk.rot_z(45))
		# the sides: two cyan plates each, and cyan straps at the front corners
		for sx in (-1, 1):
			for y0, y1 in ((0.7, 1.15), (1.32, 1.77)):
				c.span((sx * (HW + 0.03), y0, -0.95), (sx * (HW + 0.11), y1, 0.45), CYAN, 'Plate')
			c.span((sx * (HW + 0.03), 0.5, -HD + 0.05), (sx * (HW + 0.1), BODY, -HD + 0.45), CYAN, 'Strap')
			c.stud((sx * (HW + 0.1), 1.2, -HD + 0.25), 'x+' if sx > 0 else 'x-', 0.13, P(236, 250, 255), rot45=True)
	# the lid: silver-white sides, a navy top with dark corner blocks, the front panel's top part
	c.lid_block(SILVER, NAVY_D, y1=TOP - 0.16, cap=NAVY, cap_in=0.06, cap_h=0.16)
	with c.lid():
		for sx in (-1, 1):
			for sz in (-1, 1):
				c.span((sx * (HW + o + 0.06), TOP - 0.2, sz * (HD + o + 0.06)), (sx * (HW + o - 0.62), TOP + 0.08, sz * (HD + o - 0.62)), NAVY_D, 'LidCorner')
				c.stud((sx * (HW + o - 0.6), BODY + 0.48, sz * (HD + o)), 'z+' if sz > 0 else 'z-', 0.17, P(196, 204, 216), rot45=True)
				c.stud((sx * (HW + o), BODY + 0.48, sz * (HD + o - 0.6)), 'x+' if sx > 0 else 'x-', 0.17, P(196, 204, 216), rot45=True)
			# a navy strip along each side's top
			c.span((sx * (HW + o + 0.03), TOP - 0.16, -0.7), (sx * (HW + o - 0.3), TOP + 0.02, 0.7), NAVY2, 'LidTrim')
		c.span((-1.05, BODY - 0.0, -HD - o - 0.09), (1.05, TOP - 0.1, -HD - o + 0.1), NAVY2, 'Latch')
		c.span((-1.0, TOP - 0.12, -HD - o - 0.09), (1.0, TOP + 0.03, -HD - o + 0.35), NAVY2, 'Latch')
		for x in (-0.6, 0.6):
			c.span((x - 0.18, TOP - 0.02, -HD - 0.1), (x + 0.18, TOP + 0.07, -HD + 0.2), SILVER, 'LidTrim')
	c.handle(CYAN, z=0.25)
	c.hinge()
	c.seal = dict(body=-HD - 0.09, lid=-HD - o - 0.09, low=BODY - 0.32, top=TOP + 0.03)
	return c


def crown_box():
	PURPLE = P(110, 46, 206)
	PURPLE_D = P(86, 34, 168)
	PURPLE_L = P(140, 76, 226)
	GOLD2 = P(252, 206, 46)
	GOLD_D = P(226, 160, 24)
	c = Chest('Grail', 'Crown Box')
	c.tub(PURPLE_D, GOLD2, foot_h=0.36)
	o = LID_OUT
	with c.body():
		c.faces(PURPLE, y0=0.34, proud=0.03)
		# the gold foot's corner blocks and gold corner posts with gold diamonds
		for sx in (-1, 1):
			for sz in (-1, 1):
				c.span((sx * (HW + 0.12), 0.0, sz * (HD + 0.12)), (sx * (HW - 0.62), 0.5, sz * (HD - 0.62)), GOLD_D, 'Foot')
				c.span((sx * (HW + 0.08), 0.5 - 0.002, sz * (HD + 0.08)), (sx * (HW - 0.48), BODY - 0.01, sz * (HD - 0.48)), GOLD2, 'Post')
		# purple inlays on the posts' faces carry the gold diamond studs
		for sx in (-1, 1):
			for sz in (-1, 1):
				c.span((sx * (HW - 0.38), 0.75, sz * (HD + 0.08)), (sx * (HW - 0.02), 1.95, sz * (HD + 0.12)), PURPLE_L, 'Inlay')
				c.span((sx * (HW + 0.08), 0.75, sz * (HD - 0.38)), (sx * (HW + 0.12), 1.95, sz * (HD - 0.02)), PURPLE_L, 'Inlay')
				for y in (1.05, 1.65):
					c.stud((sx * (HW - 0.2), y, sz * (HD + 0.12)), 'z+' if sz > 0 else 'z-', 0.16, GOLD2, rot45=True)
					c.stud((sx * (HW + 0.12), y, sz * (HD - 0.2)), 'x+' if sx > 0 else 'x-', 0.16, GOLD2, rot45=True)
		# a gold band along the tub's top
		c.band(BODY - 0.3, BODY - 0.04, GOLD2, 0.06)
		# the crown on the front
		crown_front(c, 0.0, 0.3, -HD - 0.03, 1.66, GOLD2, tips=False)
		# the wings: three layers of gold feathers out of each side
		for sx in (-1, 1):
			wing_side(c, sx, 2.0, -0.1, 1.8, [GOLD2, P(255, 226, 110)])
	c.lid_block(PURPLE, PURPLE_D, y1=TOP - 0.12, cap=PURPLE_L, cap_in=0.5, cap_h=0.12, rim=GOLD2, rim_h=0.22)
	with c.lid():
		for sx in (-1, 1):
			for sz in (-1, 1):
				c.span((sx * (HW + o + 0.06), BODY + 0.2, sz * (HD + o + 0.06)), (sx * (HW + o - 0.55), TOP + 0.03, sz * (HD + o - 0.55)), PURPLE_D, 'LidCorner')
				c.stud((sx * (HW + o - 0.28), TOP + 0.03, sz * (HD + o - 0.28)), 'y+', 0.13, GOLD2)
		# the gold latch over the seam, a gold strip on the lid's front
		c.span((-0.42, BODY - 0.3, -HD - o - 0.12), (0.42, BODY + 0.6, -HD - o + 0.04), GOLD2, 'Latch')
		c.span((-0.16, BODY + 0.05, -HD - o - 0.17), (0.16, BODY + 0.32, -HD - o - 0.1), GOLD_D, 'LatchPlate')
		c.span((-1.6, TOP - 0.12, -HD - o - 0.05), (1.6, TOP + 0.02, -HD - o + 0.3), GOLD2, 'LidTrim')
	c.handle(GOLD2, z=0.3)
	c.hinge()
	c.seal = dict(body=-HD - 0.03, lid=-HD - o - 0.12, low=BODY - 0.36, top=TOP + 0.03)
	return c


def bundle_box():
	PURPLE = P(126, 50, 214)
	PURPLE_D = P(98, 38, 170)
	PURPLE_L = P(160, 96, 240)
	GOLD2 = P(250, 202, 60)
	c = Chest('GrailBundle', 'The Grail Bundle')
	c.tub(PURPLE_D, PURPLE, foot_h=0.22)
	o = LID_OUT
	with c.body():
		c.faces(PURPLE, y0=0.2, proud=0.03)
		# the white band and the gold band over the foot
		c.band(0.22, 0.42, WHITE, 0.07)
		c.band(0.42 - 0.002, 0.56, GOLD2, 0.06)
		# gold corner brackets (top and bottom of each corner)
		for sx in (-1, 1):
			for sz in (-1, 1):
				for y0, y1 in ((0.55, 0.95), (1.62, BODY)):
					c.span((sx * (HW + 0.09), y0, sz * (HD + 0.09)), (sx * (HW - 0.5), y1, sz * (HD - 0.14)), GOLD2, 'Post')
					c.span((sx * (HW + 0.09 - 0.003), y0 + 0.002, sz * (HD + 0.09 - 0.003)), (sx * (HW - 0.14), y1 - 0.002, sz * (HD - 0.5)), GOLD2, 'Post')
		# the front: a raised purple panel with the crown, a white wing either side of it
		c.span((-1.0, 0.62, -HD - 0.1), (1.0, BODY - 0.08, -HD + 0.1), PURPLE_L, 'Panel')
		crown_front(c, 0.0, 0.84, -HD - 0.1, 0.88, GOLD2)
		flat_wing(c, 1.05, 1.68, -HD - 0.03, 0.95, WHITE)
		flat_wing(c, -1.05, 1.68, -HD - 0.03, 0.95, WHITE, mirror=True)
		# white wings on the sides
		for sx in (-1, 1):
			with c.m.at((sx * (HW + 0.03), 0.0, 0.0), bk.rot_y(-sx * 90)):
				flat_wing(c, -0.55 * sx, 1.68, 0.0, 1.15, WHITE, mirror=sx > 0)
	# the lid: chunky, its top edge bevelled (wedges), purple block studs on top, a gold hasp
	c.lid_block(PURPLE, PURPLE_D, y1=TOP - 0.2, cap=PURPLE_L, cap_in=0.32, cap_h=0.2)
	with c.lid():
		y = TOP - 0.2
		# the bevel: wedges round the cap's edge (front, back, sides)
		c.m.wedge((0.0, y + 0.1, -HD - o + 0.16), (W + 2 * o - 0.64, 0.2, 0.32), PURPLE, rot=bk.rot_y(180), name='LidBevel')
		c.m.wedge((0.0, y + 0.1, HD + o - 0.16), (W + 2 * o - 0.64, 0.2, 0.32), PURPLE, name='LidBevel')
		for sx in (-1, 1):
			c.m.wedge((sx * (HW + o - 0.16), y + 0.1, 0.0), (D + 2 * o - 0.64, 0.2, 0.32), PURPLE, rot=bk.rot_y(-sx * 90), name='LidBevel')
		# the hasp
		c.span((-0.5, BODY - 0.45, -HD - o - 0.12), (0.5, TOP - 0.18, -HD - o + 0.04), GOLD2, 'Latch')
		c.span((-0.5, TOP - 0.2, -HD - o - 0.12), (0.5, TOP + 0.02, -HD - o + 0.5), GOLD2, 'Latch')
		c.span((-0.28, BODY - 0.32, -HD - o - 0.17), (0.28, BODY + 0.05, -HD - o - 0.1), P(222, 164, 30), 'LatchPlate')
	with c.topper():
		# the block studs on the lid's top (2 rows of 3, like the sheet's)
		for x in (-1.25, 0.0, 1.25):
			for z in (-0.7, 0.7):
				if x == 0.0 and z < 0:
					continue
				c.box((x, TOP + 0.13, z), (0.5, 0.3, 0.5), PURPLE_L, 'Stud', bevel=0.04)
	c.hinge()
	c.seal = dict(body=-HD - 0.03, lid=-HD - o - 0.12, low=BODY - 0.42, top=TOP + 0.03)
	return c


BUILDERS = {'Street': street, 'Graffiti': graffiti, 'Exclusive': chrome, 'Grail': crown_box, 'GrailBundle': bundle_box}
ORDER = ['Street', 'Graffiti', 'Exclusive', 'Grail', 'GrailBundle']


def _aabb(p):
	one = bk.Model('one', unit=1.0)
	one.prims.append(p)
	return one.bounds()


def seal_spots(m, low, half=0.43):
	"""Where the reveal's seal tape lies (UnboxWorld.seal): in the middle column (|x| < half: the tape is 0.86 wide), the
	frontmost face of anything between the tape's lower end and the seam (its lower piece rides the tub) and between the
	seam and the lid's top (its upper piece rides the lid), the lower end, and the lid's top over its front. Measured
	from the model, so the tape lies ON the panel, the latch or the hasp, never inside them."""
	body_z, lid_z, top = -HD, -HD - LID_OUT, TOP
	boxes = []
	for p in m.prims:
		if p.name == 'Hinge':
			continue
		lo, hi = _aabb(p)
		if hi[0] < -half or lo[0] > half:
			continue
		boxes.append(((p.tag or {}).get('group', 'body'), lo, hi))
	for g, lo, hi in boxes:
		if hi[1] > low and lo[1] < BODY:
			body_z = min(body_z, lo[2])
		if hi[1] > BODY and lo[1] < TOP - 0.1:
			lid_z = min(lid_z, lo[2])
	for g, lo, hi in boxes:
		if g != 'body' and lo[2] < lid_z + 0.62 and hi[1] > TOP - 0.3:
			top = max(top, hi[1])
	return dict(body=body_z, lid=lid_z, low=low, top=top)


def build(id, open_t=0.0):
	"""The chest as a BoxKit model; open_t > 0 turns the lid group about the hinge (0..1 of 110 degrees)."""
	c = BUILDERS[id]()
	m = c.m
	m.meta['seal'] = c.seal
	# (no hair-thin parts: every piece at least MIN_T thick, grown about its centre; then no shared face planes)
	for p in m.prims:
		if p.name != 'Hinge':
			p.size = tuple(max(v, MIN_T) for v in p.size)
	bk.unshare(m)
	m.meta['seal'] = seal_spots(m, c.seal['low'])
	if open_t:
		ang = 110.0 * open_t
		R = bk.rot_x(ang)
		for p in m.prims:
			if p.tag and p.tag.get('group') in ('lid', 'topper'):
				rel = bk.sub(p.pos, HINGE)
				p.pos = bk.add(bk.mat_vec(R, rel), HINGE)
				p.rot = bk.mat_mul(R, p.rot)
	return m


def build_all():
	return [build(id) for id in ORDER]


if __name__ == '__main__':
	for mm in build_all():
		print('%-12s %3d parts' % (mm.id, mm.part_count()), bk.lint(mm)[:4])
