"""The 22 World 1 shoes (brief 30), modelled after the user's own render sheets
(brief/ref30/user_models/01-Street-Box.png .. 05-The-Grail-Bundle.png): one clean blocky sneaker kit dressed per shoe.

Every shoe on the sheets is the same toy sneaker:
  * a rounded-front SOLE of 3-4 flat layers (outsole, coloured stripe lines, midsole), a little wider than the upper;
  * a rounded TOE CAP bumper on the sole's front;
  * the UPPER: three stacked slabs, each one set further back at the front, so the front is a staircase (the vamp) and
    the sides show two horizontal grooves; an optional heel counter block low at the back of the side;
  * a sloped LACE BED in the middle of the staircase with white rectangular LACE BARS (three straight straps, or a top
    bar, an X and a bottom bar);
  * a clean SQUARE COLLAR: four padded bars round the opening with round corners, a grey lining floor inside;
  * the TONGUE: an upright block in front of the collar with a coloured label;
  * a HEEL TAB with a dark slot on the collar's back;
  * the side marks (a C, graffiti drip tags, stars, sparkles, a zigzag ...), a toe mark, and the extras: wings (Street
    Angel, Hologram, Platinum Wings, Astro Crown, The Grail), crowns (Block Royalty, Astro Crown), spikes (Solar Flare).

Space: Roblox axes, studs (unit 1). Authored for the RIGHT shoe in "foot space": ground y = 0, the R15 foot's centre at
x = z = 0, the outer side +X, the toe -Z (ShoeModels.lua mirrors it for the left shoe). The inner face sits on the
foot's inner plane (x = -0.49), so a worn pair never cuts into itself. Tags: shaft = rides the lower leg (the tongue and
what sits on it), text = {face, centre} a side mark that must read the same way on the left shoe (ShoeModels unmirrors it).
Budget: <= 60 parts a shoe (a worn pair <= 120).
"""
import math
from contextlib import contextmanager

import boxkit as bk

# ---------------------------------------------------------------------------------------------- layout (studs)
XI, XO = -0.49, 0.66          # the upper's inner and outer faces
XC = (XI + XO) / 2            # its centre line
SXI, SXO = -0.505, 0.70       # the sole's inner and outer edges (a lip on the outer side)
ZT, ZH = -1.02, 0.70          # sole toe tip and heel end
RF = 0.44                     # the sole's front corner radius (a round toe, flat in the middle)
UZT, UZH = -0.985, 0.665      # the toe cap's front and the upper's heel back
TOE_Z1 = -0.40                # the toe cap's back end (inside the upper)
YT = 0.54                     # the toe cap's top
Y1, Y2, Y3 = 0.69, 0.86, 1.02  # the three slabs' tops (the side grooves at Y1 and Y2)
Z1, Z2, Z3 = -0.74, -0.62, -0.5  # their fronts (the staircase's risers; a deep toe cap ledge in front)
GROOVE = 0.014                # the middle slab is set in by this (the grooves)
YC0, YC1 = 0.99, 1.24         # the collar ring's bottom and top (it wraps the upper's top edge)
CB = 0.21                     # the collar bar's width
CZ0, CZ1 = -0.43, 0.685       # the collar ring's front and back (outer)
CX0, CX1 = XI - 0.015, XO + 0.015  # and its sides (a hair proud of the upper)
TZ0, TZ1 = -0.6, -0.39        # the tongue (front, back)
TY0, TY1 = 0.9, 1.255         # its bottom and top
TW = 0.5                      # its width

# the sheets' palette (lit faces, sampled from the render sheets)
WHITE = (242, 243, 247)
LINING = (112, 116, 128)
SLOT = (40, 38, 46)
BLACK = (36, 35, 42)
RED = (230, 40, 52)
YELLOW = (252, 210, 58)
GOLD = (246, 196, 44)
PINK = (247, 104, 178)
HOTPINK = (238, 60, 148)
CYAN = (40, 200, 236)
ICE = (120, 236, 248)
NAVY = (44, 50, 80)
MIDNIGHT = (34, 38, 54)
PURPLE = (92, 50, 186)
LAVENDER = (178, 112, 246)
ORANGE = (250, 118, 40)
BROWN = (66, 44, 34)
LIME = (140, 230, 96)
GREY = (196, 200, 210)
RAINBOW = [(250, 74, 82), (255, 160, 44), (252, 214, 58), (90, 222, 110), (60, 200, 240), (170, 100, 250)]


# ---------------------------------------------------------------------------------------------- helpers
def rounded_layer(m, name, y0, y1, color, x0, x1, z0, z1, r, mat='smooth', round_back=False):
	"""A flat layer with rounded front corners (plan: a rectangle x0..x1 by z0..z1, front at z0): 4 parts."""
	h = y1 - y0
	yc = (y0 + y1) / 2
	m.box((( x0 + x1) / 2, yc, (z0 + r + z1) / 2), (x1 - x0, h, z1 - z0 - r), color, mat, name=name)
	# (a hair lower than the main block, so their top and bottom faces never share a plane where they overlap)
	m.box(((x0 + x1) / 2, yc, z0 + r / 2 + 0.002), (x1 - x0 - 2 * r, h - 0.002, r + 0.004), color, mat, name=name)
	for i, x in enumerate((x0 + r, x1 - r)):
		# (a hair taller than the blocks, and than each other: no two caps share a plane where they overlap)
		m.cyl((x, yc, z0 + r), h + 0.004 + 0.004 * i, 2 * r, color, mat, axis='y', name=name + 'Toe')


class Face:
	"""A frame on a face of the shoe: u to the right and v up as seen from outside, n out of the face.
	Glyphs are built with flat pieces of thickness t standing proud of the face."""

	def __init__(self, m, origin, u, v, n, text=None):
		self.m, self.o, self.u, self.v, self.n = m, origin, u, v, n
		self.text = text  # 'x': the side face; its glyphs are tagged so the left shoe shows them unmirrored
		self.rot = bk.from_columns(n, v, bk.cross(n, v))  # local X = out, Y = up, Z = n x v
		self.k = 0  # (each piece stands a hair prouder than the last: no two front faces share a plane)

	def _t(self, t, out):
		"""The piece's thickness and its centre's offset off the face: its back sunk 0.01 into the face, both its
		faces a hair off every other piece's."""
		self.k += 1
		t = t + 0.0036 * self.k
		return t, out + t / 2 - 0.01 - 0.0018 * self.k

	@contextmanager
	def glyph(self, a, b):
		"""Pieces made inside belong to one glyph centred at (a, b): on a text face they flip as one about it."""
		if not self.text:
			yield self
			return
		with self.m.tagged(text={'face': self.text, 'centre': self.at(a, b)}):
			yield self

	def at(self, a, b, out=0.0):
		return bk.add(bk.add(bk.add(self.o, bk.scale_v(self.u, a)), bk.scale_v(self.v, b)), bk.scale_v(self.n, out))

	def bar(self, a, b, w, h, color, t=0.03, angle=0.0, name='Mark', out=0.0, mat='smooth'):
		"""A flat bar centred at (a, b), w along u and h along v, turned `angle` degrees (counter-clockwise as seen)."""
		# local frame: X = n, Y = v, Z = n x v = -u (seen from outside, u is to the right)
		rot = bk.mat_mul(self.rot, bk.rot_x(-angle))
		t, c = self._t(t, out)
		return self.m.box(self.at(a, b, c), (t, h, w), color, mat, rot=rot, name=name)

	def disc(self, a, b, d, color, t=0.03, name='Mark', out=0.0, mat='smooth'):
		t, c = self._t(t, out)
		return self.m.cyl(self.at(a, b, c), t, d, color, mat, axis='x', rot=self.rot, name=name)

	def diamond(self, a, b, s, color, t=0.03, name='Mark', out=0.0, mat='smooth'):
		return self.bar(a, b, s, s, color, t, 45.0, name, out, mat)


def side_face(m):
	"""The outer side of the right shoe: seen from outside, u (screen-right) points to the toe (-Z)."""
	return Face(m, (XO, 0.0, -0.15), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0), (1.0, 0.0, 0.0), text='x')


def toe_face(m):
	"""The toe cap's front: seen from the front, u (screen-right) points to -X."""
	return Face(m, (XC, 0.0, UZT), (-1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, -1.0))


# ---------------------------------------------------------------------------------------------- glyphs
def g_plus(f, a, b, s, color, t=0.03, out=0.0, name='Mark'):
	with f.glyph(a, b):
		f.bar(a, b, s, s * 0.34, color, t, 0, name, out)
		f.bar(a, b, s * 0.34, s, color, t + 0.004, 0, name, out)


def g_sparkle(f, a, b, s, color, t=0.03, out=0.0, name='Mark', mat='smooth'):
	"""A four-point star with pinched sides: two long thin bars crossed and a small diamond at the centre."""
	with f.glyph(a, b):
		f.bar(a, b, s * 0.2, s, color, t, 0, name, out, mat)
		f.bar(a, b, s * 0.62, s * 0.2, color, t + 0.003, 0, name, out, mat)
		f.diamond(a, b, s * 0.36, color, t + 0.006, name, out, mat)


def g_star(f, a, b, s, color, t=0.03, out=0.0, name='Star'):
	"""A chunky five-point star: a centre disc and five square points turned to the tips (6 parts)."""
	with f.glyph(a, b):
		r = s / 2
		for i in range(5):
			ang = math.radians(90 + 72 * i)
			f.bar(a + math.cos(ang) * r * 0.52, b + math.sin(ang) * r * 0.52, r * 0.62, r * 0.62, color, t, 45 + 72 * i, name, out)
		f.disc(a, b, r * 1.05, color, t + 0.004, name, out)


def g_star3(f, a, b, s, color, t=0.03, out=0.0, name='Star'):
	"""A small star in 3 parts: a disc and two crossed diamonds (reads as a star at a small size)."""
	with f.glyph(a, b):
		f.disc(a, b, s * 0.5, color, t, name, out)
		f.bar(a, b + s * 0.06, s * 0.36, s * 0.36, color, t + 0.003, 45, name, out)
		f.bar(a, b + s * 0.1, s * 0.16, s * 0.6, color, t + 0.002, 0, name, out)


def g_c(f, a, b, s, color, bg, t=0.03, out=0.0):
	"""A round 'C' (Fresh Canvas): a disc, the hole in the wall's colour, and the opening (to the right as seen)."""
	with f.glyph(a, b):
		f.disc(a, b, s, color, t, 'MarkC', out)
		f.disc(a, b, s * 0.48, bg, t + 0.006, 'MarkC', out)
		f.bar(a + s * 0.3, b, s * 0.44, s * 0.3, bg, t + 0.006, 0, 'MarkC', out)


def g_drip_tag(f, a, b, s, color, t=0.032, out=0.0, name='Tag'):
	"""A graffiti drip tag (the sheets' '4'-like tag): three upright strokes of different lengths with a slanted
	cross-stroke, two of them ending in round drips."""
	with f.glyph(a, b):
		w = s * 0.17
		f.bar(a - s * 0.32, b + s * 0.05, w, s * 0.62, color, t, 0, name, out)
		f.bar(a, b - s * 0.04, w, s * 0.86, color, t, 0, name, out)
		f.bar(a + s * 0.3, b + s * 0.2, w, s * 0.5, color, t, 0, name, out)
		f.bar(a - s * 0.05, b + s * 0.08, s * 0.72, w * 0.9, color, t + 0.004, 18, name, out)
		f.disc(a, b - s * 0.48, w * 1.45, color, t + 0.002, name, out)
		f.disc(a - s * 0.32, b - s * 0.27, w * 1.3, color, t + 0.002, name, out)


def g_splat(f, a, b, s, color, t=0.03, out=0.0, name='Splat'):
	"""A paint splat: a blob and a satellite drop."""
	with f.glyph(a, b):
		f.disc(a, b, s, color, t, name, out)
		f.disc(a + s * 0.5, b - s * 0.4, s * 0.42, color, t + 0.002, name, out)


def g_zigzag(f, a, b, s, color, t=0.032, out=0.0, name='Zigzag'):
	"""A heartbeat zigzag (Midnight Chrome): four slanted strokes."""
	with f.glyph(a, b):
		seg = s / 4
		for i, ang in enumerate((40, -60, 60, -40)):
			f.bar(a - s / 2 + seg * (i + 0.5), b + (0.06 if i % 2 else -0.02) * s, seg * 1.5, s * 0.1, color, t + 0.002 * (i % 2), ang, name, out)


def g_drip_bars(f, a, b, s, color, t=0.032, out=0.0, name='Drip'):
	"""Paint running down (Rainbow Drip): three upright bars of different lengths with round ends."""
	with f.glyph(a, b):
		for i, (dx, h) in enumerate(((-0.3, 0.9), (0.0, 0.62), (0.3, 1.0))):
			f.bar(a + dx * s, b + (1 - h) * s * 0.3, s * 0.15, s * h * 0.6, color, t, 0, name, out)
			if i != 1:
				f.disc(a + dx * s, b + (1 - h) * s * 0.3 - s * h * 0.3, s * 0.2, color, t + 0.002, name, out)


# ---------------------------------------------------------------------------------------------- the kit
def build_sole(m, d):
	"""The sole: layers bottom to top [(colour, thickness, kind?)]; a stripe line (thin) stands a hair proud."""
	y = 0.0
	for i, layer in enumerate(d['sole']):
		col, th = layer[0], layer[1]
		mat = layer[2] if len(layer) > 2 else 'smooth'
		grow = 0.006 if th < 0.05 else 0.0
		name = 'Outsole' if i == 0 else ('Sole' if i == len(d['sole']) - 1 else 'Stripe')
		x0 = SXI + 0.004 if grow else SXI  # (never past the inner plane: the other shoe is there)
		rounded_layer(m, name, y, y + th, col, x0, SXO + grow, ZT - grow, ZH + grow, RF + grow, mat)
		y += th
	return y


def build_upper(m, d, ys):
	q = d['quarter']
	# the toe cap: a rounded bumper on the sole's front
	rounded_layer(m, 'ToeBox', ys - 0.02, YT, d['toe'], XI - 0.006, XO + 0.012, UZT, TOE_Z1, RF - 0.045)
	# three slabs, each set back further at the front (the staircase) and running to the heel
	m.box((XC, (ys - 0.03 + Y1) / 2, (Z1 + UZH) / 2), (XO - XI, Y1 - ys + 0.03, UZH - Z1), q[0], name='Quarter')
	m.box((XC, (Y1 + Y2) / 2, (Z2 + UZH - GROOVE) / 2), (XO - XI - 2 * GROOVE, Y2 - Y1, UZH - GROOVE - Z2), q[1], name='Quarter')
	m.box((XC, (Y2 + Y3) / 2, (Z3 + UZH) / 2), (XO - XI, Y3 - Y2, UZH - Z3), q[2], name='Quarter')
	# a heel counter low at the back of the side (Spray Tag's and Drip Tag's white block)
	if d.get('heel'):
		m.box((XC + 0.006, (ys - 0.02 + YT) / 2, (0.08 + UZH + 0.012) / 2), (XO - XI + 0.024, YT - ys + 0.02, UZH + 0.012 - 0.08), d['heel'], name='HeelCounter')


def build_collar(m, d):
	col = d['collar']
	h = YC1 - YC0
	yc = (YC0 + YC1) / 2
	xa, xb = CX0 + CB / 2, CX1 - CB / 2      # the bars' centre lines
	za, zb = CZ0 + CB / 2, CZ1 - CB / 2
	m.box((xa, yc, (za + zb) / 2), (CB, h, zb - za), col, name='Collar')
	m.box((xb, yc, (za + zb) / 2), (CB, h, zb - za), col, name='Collar')
	m.box(((xa + xb) / 2, yc, za), (xb - xa, h - 0.004, CB), col, name='Collar')
	m.box(((xa + xb) / 2, yc, zb), (xb - xa, h - 0.004, CB), col, name='Collar')
	for x in (xa, xb):
		for z in (za, zb):
			m.cyl((x, yc, z), h + 0.006, CB, col, axis='y', name='CollarCorner')
	# the lining: the floor of the opening, grey
	m.box((XC, Y3 + 0.007, (za + zb) / 2), (xb - xa - CB + 0.02, 0.024, zb - za - CB + 0.02), d.get('lining', LINING), name='Lining')
	# the heel tab on the back bar, with its slot
	if d.get('tab', True) is not False:
		tab = d.get('tab') or col
		m.box((XC, YC1 + 0.085, zb + 0.02), (0.22, 0.25, 0.1), tab, name='HeelTab')
		m.box((XC, YC1 + 0.13, zb + 0.02), (0.11, 0.065, 0.104), d.get('slot', SLOT), name='HeelTabHole')


def build_tongue(m, d):
	with m.tagged(shaft=True):
		m.box((XC, (TY0 + TY1) / 2, (TZ0 + TZ1) / 2), (TW, TY1 - TY0, TZ1 - TZ0), d.get('tongue', d['quarter'][2]), name='Tongue')
		if d.get('label') is not False:
			lw, lh = d.get('labelSize', (0.34, 0.14))
			m.box((XC, TY1 - 0.1 - lh / 2 + 0.04, TZ0 - 0.012), (lw, lh, 0.03), d.get('label', WHITE), name='TongueLabel')


# the lace bed's slope: through the staircase's nosings, from the toe cap's top to under the tongue's label
NOSE0 = (Z1, Y1)
SLOPE_U = bk.norm((0.0, Y2 - Y1, Z2 - Z1))       # up the slope (toward the heel)
SLOPE_N = bk.norm((0.0, Z2 - Z1, -(Y2 - Y1)))    # out of it (forward and up)
SLOPE_ROT = bk.from_columns((1.0, 0.0, 0.0), SLOPE_U, bk.cross((1.0, 0.0, 0.0), SLOPE_U))


def on_slope(s, out):
	"""A point s along the slope from the first nosing, `out` off it (centre line x = XC)."""
	return (XC, NOSE0[1] + SLOPE_U[1] * s + SLOPE_N[1] * out, NOSE0[0] + SLOPE_U[2] * s + SLOPE_N[2] * out)


BED_S0, BED_S1, BED_T = -0.25, 0.46, 0.08


def build_laces(m, d):
	bed = d.get('bed', d['quarter'][1])
	w = d.get('bedW', 0.84)
	# (its face on the plane through the stair's nosings: it fills the steps' notches, the steps show either side)
	m.box(on_slope((BED_S0 + BED_S1) / 2, -BED_T / 2 + 0.006), (w, BED_S1 - BED_S0, BED_T), bed, rot=SLOPE_ROT, name='Eyestay')
	cols = d['laces']
	if not isinstance(cols, list):
		cols = [cols]  # one colour (an RGB tuple)

	def c(i):
		return cols[i % len(cols)]
	t = 0.05
	base = 0.006 + t / 2
	lw = w - 0.04
	style = d.get('laceStyle', 'x')
	if style == 'straps':
		# three straight straps up the bed (Fresh Canvas)
		for i, s in enumerate((-0.05, 0.12, 0.29)):
			m.box(on_slope(s, base + 0.012), (lw + 0.02, 0.125, t + 0.024), c(i), rot=SLOPE_ROT, name='Lace')
		return
	# a bottom bar, the X and a top bar
	t = 0.06
	base = 0.006 + t / 2
	m.box(on_slope(-0.07, base), (lw, 0.11, t), c(0), rot=SLOPE_ROT, name='Lace')
	ang = math.degrees(math.atan2(0.24, lw * 0.86))
	ln = math.hypot(lw * 0.86, 0.24) + 0.04
	for j, sgn in enumerate((1, -1)):
		rot = bk.mat_mul(SLOPE_ROT, bk.rot_z(sgn * ang))
		m.box(on_slope(0.1, base + 0.014 + j * 0.018), (ln, 0.11, t), c(1 + j), rot=rot, name='Lace')
	m.box(on_slope(0.29, base + 0.046), (lw + 0.03, 0.11, t), c(3), rot=SLOPE_ROT, name='Lace')
	if d.get('rivets'):
		# Rainbow Drip, Platinum Wings: small rivets at the bars' ends
		for (a, s) in ((-lw / 2 + 0.05, 0.29), (lw / 2 - 0.05, 0.29)):
			p = on_slope(s, base + 0.04 + t / 2 + 0.006)
			m.box((p[0] + a, p[1], p[2]), (0.035, 0.035, 0.02), d['rivets'], rot=SLOPE_ROT, name='Rivet')


# ---------------------------------------------------------------------------------------------- extras
def wings(m, d, colors, style='round', scale=1.0):
	"""A wing on the outer side at the back, spread outward and up like the sheets' (seen face-on from the front):
	a round root and four feathers fanning from nearly level to upright. style 'round': soft finger feathers
	(ellipsoids); 'blade': flat feathers with a slanted tip (Hologram, Platinum Wings). 5-9 parts."""
	k = scale * 1.65
	root = (XO + 0.08, 1.02, 0.34)
	# the wing's plane: across the shoe, swept back 25 degrees; local X = through the wing (thickness)
	sweep = bk.rot_y(-25.0)
	with m.at(root, sweep):
		if style == 'blade':
			m.cyl((0.1, 0.02, 0.0), 0.1, 0.4 * k, colors[0], axis='z', name='WingRoot')
		else:
			m.egg((0.1, 0.02, 0.0), (0.42 * k, 0.42 * k, 0.16), colors[0], name='WingRoot')
		fan = ((20, 0.56), (40, 0.66), (60, 0.66), (80, 0.56))
		for i, (deg, ln) in enumerate(fan):
			col = colors[i % len(colors)]
			ln *= k
			rot = bk.rot_z(deg - 90)  # feather along local +Y turned toward +X (outward)
			with m.at((0.12 * k, 0.06, 0.012 * (i - 1.5)), rot):
				if style == 'blade':
					m.box((0.0, ln / 2 + 0.06, 0.0), (0.24 * k, ln, 0.07), col, name='Feather')
					# a slanted tip: a wedge whose slope runs from the blade's top face down to its point
					m.wedge((0.0, ln + 0.06 + 0.07 * k, 0.0), (0.24 * k, 0.14 * k, 0.07), col, rot=bk.rot_x(-90), name='Feather')
				else:
					m.egg((0.0, ln / 2 + 0.04, 0.0), (0.3 * k, ln + 0.16, 0.14), col, name='Feather')


def crown(m, pos, size, color, gem, white=None):
	"""A blocky crown (Block Royalty, Astro Crown): a band, four square points like crenellations, a gem on the
	front (and a pearl). 6-7 parts."""
	w = size
	x, y, z = pos
	m.box((x, y + w * 0.13, z), (w * 0.94, w * 0.26, w * 0.5), color, name='CrownBand')
	for i in range(4):
		px = x - w * 0.375 + i * w * 0.25
		m.box((px, y + w * 0.34, z), (w * 0.17, w * 0.17, w * 0.17), color, name='CrownPoint')
	m.box((x, y + w * 0.13, z - w * 0.25 - 0.012), (w * 0.16, w * 0.12, 0.03), gem, name='CrownGem')
	if white:
		m.ball((x + w * 0.2, y + w * 0.3, z - w * 0.1), w * 0.14, white, name='CrownPearl')


def spikes(m, d, color, color2):
	"""Solar Flare's flames: tall flat spikes standing round the collar, leaning out a little. 2 parts each."""
	spots = (
		((CX1 - 0.04, -0.3), 0.42, 90, 8), ((CX1 - 0.04, 0.12), 0.58, 90, 10), ((CX1 - 0.06, 0.55), 0.5, 90, 12),
		((XC + 0.2, CZ1 - 0.06), 0.62, 0, -8), ((XC - 0.22, CZ1 - 0.06), 0.46, 0, -10), ((CX0 + 0.2, CZ1 - 0.08), 0.4, 0, -12),
	)
	for i, ((x, z), h, yaw, lean) in enumerate(spots):
		col = color if i % 2 == 0 else color2
		with m.at((x, YC1 - 0.03, z), bk.mat_mul(bk.rot_y(yaw), bk.rot_x(lean))):
			# two wedges back to back: a flat triangle, base 0.24 along local Z, apex up local Y
			m.wedge((0.0, h / 2, -0.06), (0.07, h, 0.12), col, name='Spike')
			m.wedge((0.0, h / 2, 0.06), (0.07, h, 0.12), col, rot=bk.rot_y(180), name='Spike')


def side_stripes(m, cols, z0=0.1, y0=0.44, step=0.075, length=0.42, name='SideStripe', mat='smooth'):
	"""Short coloured bars low on the outer side, toward the heel (The Grail, Platinum Wings)."""
	f = side_face(m)
	with f.glyph(-(z0 + length / 2), y0):
		for i, c in enumerate(cols):
			f.bar(-(z0 + length / 2), y0 + i * step, length, 0.05, c, 0.026, 0, name, 0.0, mat)


# ---------------------------------------------------------------------------------------------- the 22 shoes
# sole: bottom to top (colour, thickness[, kind]); toe: the toe cap; quarter: the three slabs bottom to top; bed: the
# lace bed; laces: one colour or a list (bottom bar, X, X, top bar); collar, tongue, label, tab; marks: a function
# adding the side and toe marks and the extras.
def S3(base, stripe, mid):
	return [(base, 0.05), (stripe, 0.036), (mid, 0.104)]


DEFS = {}
ORDER = []


def shoe(id, name, box, **d):
	d.update(Id=id, Name=name, Box=box)
	DEFS[id] = d
	ORDER.append(id)


# --- 01 Street box ---------------------------------------------------------------------------------------------------
def m_fresh(m, d):
	g_c(side_face(m), -0.22, 0.6, 0.36, RED, WHITE)


shoe('FreshCanvas', 'Fresh Canvas', 'Street', sole=S3(WHITE, BLACK, WHITE), toe=WHITE, quarter=[WHITE, WHITE, WHITE],
	laces=WHITE, laceStyle='straps', collar=WHITE, label=RED, tab=RED, marks=m_fresh)


def m_rocket(m, d):
	f = side_face(m)
	# the yellow puff on the side (a rounded cross with a head)
	with f.glyph(-0.2, 0.66):
		f.bar(-0.2, 0.62, 0.13, 0.3, YELLOW, 0.032)
		f.bar(-0.2, 0.6, 0.27, 0.11, YELLOW, 0.034)
		f.disc(-0.2, 0.8, 0.15, YELLOW, 0.033)


shoe('RedRocket', 'Red Rocket', 'Street', sole=S3(WHITE, BLACK, WHITE), toe=WHITE, quarter=[RED, RED, RED],
	laces=WHITE, collar=BLACK, label=YELLOW, tab=RED, marks=m_rocket)


def m_check(m, d):
	f = side_face(m)
	# the checker print: squares of the other colour on the three bands, and a red flash
	with f.glyph(-0.2, 0.7):
		for (a, b, col) in ((-0.48, 0.71, WHITE), (-0.1, 0.71, WHITE), (-0.29, 0.89, BLACK), (-0.29, 0.52, BLACK), (0.1, 0.89, BLACK)):
			f.bar(a, b, 0.19, 0.17, col, 0.022)
		f.bar(-0.29, 0.66, 0.07, 0.42, RED, 0.03, -12)
	g_star(toe_face(m), 0.0, 0.34, 0.28, RED, 0.03)


shoe('Checkmate', 'Checkmate', 'Street', sole=[(RED, 0.07), (WHITE, 0.12)], toe=WHITE, quarter=[BLACK, WHITE, BLACK],
	bed=BLACK, laces=WHITE, collar=BLACK, label=RED, tab=RED, marks=m_check)


def m_chrome(m, d):
	f = side_face(m)
	g_plus(f, -0.2, 0.66, 0.3, (250, 150, 200), 0.03)
	f.disc(-0.2, 0.8, 0.12, (250, 150, 200), 0.031)
	g_plus(f, 0.18, 0.38, 0.14, (250, 170, 210), 0.03)


shoe('ChromeKicks', 'Chrome Kicks', 'Street', sole=S3(BLACK, HOTPINK, BLACK), toe=BLACK, quarter=[WHITE, WHITE, WHITE],
	laces=(244, 64, 112), collar=BLACK, tongue=WHITE, label=(244, 64, 112), tab=RED, marks=m_chrome)


def m_angel(m, d):
	wings(m, d, [WHITE, (232, 236, 246)], 'round')


shoe('StreetAngel', 'Street Angel', 'Street', sole=S3(YELLOW, WHITE, WHITE), toe=YELLOW, quarter=[WHITE, WHITE, WHITE],
	laces=WHITE, collar=YELLOW, tongue=YELLOW, label=WHITE, tab=GOLD, marks=m_angel)


def m_royal(m, d):
	f = side_face(m)
	with f.glyph(-0.36, 0.58):
		f.bar(-0.36, 0.58, 0.46, 0.07, YELLOW, 0.03)
	g_star(toe_face(m), 0.0, 0.34, 0.28, YELLOW, 0.03)
	with m.tagged(shaft=True):
		crown(m, (XC, TY1 - 0.01, (TZ0 + TZ1) / 2), 0.5, YELLOW, (250, 110, 40), WHITE)


shoe('BlockRoyalty', 'Block Royalty', 'Street', sole=S3(RED, YELLOW, RED), toe=BLACK,
	quarter=[BLACK, BLACK, BLACK], laces=[(255, 150, 40), YELLOW, (80, 220, 110), (60, 210, 240)], collar=RED,
	tongue=BLACK, label=False, tab=RED, marks=m_royal)


# --- 02 Graffiti box -------------------------------------------------------------------------------------------------
def m_spray(m, d):
	f = side_face(m)
	with f.glyph(-0.12, 0.66):
		f.disc(-0.12, 0.66, 0.2, CYAN, 0.03, 'Splat')
		f.disc(-0.12, 0.66, 0.09, WHITE, 0.036, 'Splat')
	g_splat(f, -0.3, 0.52, 0.13, (252, 206, 60), 0.03)


shoe('SprayTag', 'Spray Tag', 'Graffiti', sole=[(WHITE, 0.06), (GREY, 0.02), (WHITE, 0.11)], toe=WHITE, heel=WHITE,
	quarter=[PINK, PINK, PINK], laces=(252, 214, 52), collar=WHITE, tongue=PINK, label=CYAN, tab=CYAN, marks=m_spray)


def m_drip(m, d):
	f = side_face(m)
	g_drip_tag(f, -0.2, 0.7, 0.46, (240, 110, 196))
	g_splat(f, -0.42, 0.52, 0.1, (252, 200, 56))
	g_splat(f, 0.02, 0.5, 0.08, (252, 150, 40))


shoe('DripTag', 'Drip Tag', 'Graffiti', sole=[(PINK, 0.05), (WHITE, 0.025), (PINK, 0.025), (WHITE, 0.09)], toe=WHITE, heel=WHITE,
	quarter=[CYAN, CYAN, CYAN], laces=WHITE, collar=PINK, tongue=CYAN, label=(252, 200, 56), tab=PINK, marks=m_drip)


def m_paint(m, d):
	f = side_face(m)
	g_drip_tag(f, -0.18, 0.7, 0.46, (244, 108, 196))
	g_splat(f, -0.38, 0.5, 0.11, (140, 230, 96))
	g_splat(f, 0.04, 0.52, 0.09, (252, 200, 56))
	g_plus(toe_face(m), 0.0, 0.34, 0.24, (244, 108, 196), 0.03)


shoe('PaintSplash', 'Paint Splash', 'Graffiti', sole=[(PINK, 0.05), (WHITE, 0.025), (PINK, 0.025), (WHITE, 0.09)], toe=WHITE,
	quarter=[BLACK, BLACK, BLACK], laces=WHITE, collar=BLACK, tongue=BLACK, label=(120, 226, 90), tab=PINK, marks=m_paint)


def m_neon(m, d):
	f = side_face(m)
	g_drip_tag(f, -0.22, 0.7, 0.46, ICE)
	g_plus(f, 0.06, 0.46, 0.13, WHITE, 0.03)
	f.disc(-0.48, 0.44, 0.06, WHITE, 0.03)


shoe('NeonBomb', 'Neon Bomb', 'Graffiti', sole=S3(BLACK, (60, 220, 240), BLACK), toe=BLACK, quarter=[HOTPINK, HOTPINK, HOTPINK],
	laces=ICE, collar=BLACK, tongue=HOTPINK, label=(170, 200, 250), tab=HOTPINK, marks=m_neon)


def m_wild(m, d):
	f = side_face(m)
	g_drip_tag(f, -0.2, 0.7, 0.46, LIME)
	g_plus(f, -0.46, 0.5, 0.11, PINK, 0.03)
	g_plus(toe_face(m), 0.0, 0.34, 0.24, (210, 250, 200), 0.03)


shoe('WildStyle', 'Wild Style', 'Graffiti', sole=[(PINK, 0.05), ((230, 250, 210), 0.025), ((252, 214, 58), 0.025), (PINK, 0.09)], toe=LIME,
	quarter=[BLACK, BLACK, BLACK], bed=PINK, laces=WHITE, collar=PINK, tongue=PINK, label=LIME, tab=PINK, marks=m_wild)


def m_master(m, d):
	f = side_face(m)
	g_drip_tag(f, -0.2, 0.7, 0.46, (100, 228, 248))
	g_plus(f, -0.46, 0.48, 0.12, YELLOW, 0.03)
	g_plus(toe_face(m), 0.0, 0.34, 0.24, YELLOW, 0.03)


shoe('Masterpiece', 'Masterpiece', 'Graffiti', sole=[(PINK, 0.05), (WHITE, 0.025), (YELLOW, 0.025), (PINK, 0.09)], toe=PURPLE,
	quarter=[PURPLE, PURPLE, PURPLE], laces=[(250, 120, 190), YELLOW, YELLOW, (100, 228, 248)], collar=PURPLE, tongue=PURPLE,
	label=YELLOW, tab=PURPLE, marks=m_master)


# --- 03 Chrome box (internal id Exclusive) ---------------------------------------------------------------------------
def m_silver(m, d):
	g_sparkle(side_face(m), -0.2, 0.66, 0.36, CYAN, 0.032)
	g_sparkle(toe_face(m), 0.0, 0.34, 0.28, (150, 236, 250), 0.03)


shoe('SilverStreak', 'Silver Streak', 'Exclusive', sole=S3(CYAN, WHITE, WHITE), toe=WHITE, quarter=[WHITE, WHITE, WHITE],
	laces=WHITE, collar=NAVY, tongue=WHITE, label=CYAN, tab=CYAN, marks=m_silver)


def m_midnight(m, d):
	g_zigzag(side_face(m), -0.2, 0.68, 0.4, ICE)
	g_sparkle(toe_face(m), 0.0, 0.34, 0.28, ICE, 0.03)


shoe('MidnightChrome', 'Midnight Chrome', 'Exclusive', sole=[(WHITE, 0.05), (CYAN, 0.025), (WHITE, 0.025), (WHITE, 0.09)], toe=WHITE,
	quarter=[MIDNIGHT, MIDNIGHT, MIDNIGHT], laces=ICE, collar=MIDNIGHT, tongue=MIDNIGHT, label=ICE, tab=ICE, marks=m_midnight)


def m_rainbow(m, d):
	g_drip_bars(side_face(m), -0.24, 0.66, 0.42, HOTPINK)


shoe('RainbowDrip', 'Rainbow Drip', 'Exclusive', sole=[(CYAN, 0.05), (WHITE, 0.025), (HOTPINK, 0.025), (WHITE, 0.09)], toe=CYAN,
	quarter=[WHITE, WHITE, WHITE], laces=[RAINBOW[0], RAINBOW[2], RAINBOW[3], RAINBOW[4]], rivets=WHITE, collar=HOTPINK, tongue=WHITE,
	label=HOTPINK, tab=HOTPINK, marks=m_rainbow)


def m_holo(m, d):
	g_sparkle(side_face(m), -0.3, 0.64, 0.3, CYAN, 0.032)
	g_sparkle(toe_face(m), 0.0, 0.34, 0.28, CYAN, 0.03)
	wings(m, d, [(250, 150, 220), (250, 236, 250)], 'blade')


shoe('Hologram', 'Hologram', 'Exclusive', sole=[(CYAN, 0.05), (WHITE, 0.025), ((250, 170, 220), 0.025), (WHITE, 0.09)], toe=WHITE,
	quarter=[WHITE, WHITE, WHITE], laces=(248, 170, 214), collar=(110, 220, 240), tongue=WHITE, label=CYAN, tab=(110, 220, 240),
	marks=m_holo)


def m_platinum(m, d):
	side_stripes(m, [ICE, (140, 240, 190), (250, 200, 90)], z0=0.12, y0=0.42, length=0.36)
	g_sparkle(toe_face(m), 0.0, 0.34, 0.28, CYAN, 0.03)
	wings(m, d, [(236, 244, 252), (214, 230, 246)], 'blade')


shoe('PlatinumWings', 'Platinum Wings', 'Exclusive', sole=[(ICE, 0.05, 'neon'), (WHITE, 0.025), ((250, 190, 220), 0.025), (WHITE, 0.09)],
	toe=WHITE, quarter=[(232, 236, 242), (232, 236, 242), (232, 236, 242)], laces=[RAINBOW[0], RAINBOW[2], RAINBOW[3], RAINBOW[4]],
	rivets=WHITE, collar=(88, 108, 140), tongue=(232, 236, 242), label=False, tab=(88, 108, 140), marks=m_platinum)


# --- 04 Crown box (internal id Grail) --------------------------------------------------------------------------------
def m_golden(m, d):
	g_sparkle(side_face(m), -0.22, 0.66, 0.34, ORANGE, 0.034)


shoe('GoldenHour', 'Golden Hour', 'Grail', sole=[(ORANGE, 0.06), (WHITE, 0.13)], toe=WHITE, quarter=[GOLD, GOLD, GOLD],
	laces=WHITE, collar=WHITE, tongue=GOLD, label=ORANGE, tab=ORANGE, marks=m_golden)


def m_star(m, d):
	f = side_face(m)
	g_star(f, -0.24, 0.66, 0.24, GOLD, 0.03)
	g_star3(f, -0.02, 0.84, 0.11, GOLD, 0.03)
	g_star3(f, -0.44, 0.48, 0.1, GOLD, 0.03)
	g_star(toe_face(m), 0.0, 0.34, 0.28, GOLD, 0.03)


shoe('Starlight', 'Starlight', 'Grail', sole=[(GOLD, 0.06), (WHITE, 0.13)], toe=WHITE, quarter=[(30, 50, 140), (30, 50, 140), (30, 50, 140)],
	laces=WHITE, collar=(30, 50, 140), tongue=(30, 50, 140), label=GOLD, tab=GOLD, marks=m_star)


def m_solar(m, d):
	f = side_face(m)
	g_sparkle(f, -0.24, 0.64, 0.3, ORANGE, 0.034)
	spikes(m, d, (250, 120, 30), (252, 160, 40))


shoe('SolarFlare', 'Solar Flare', 'Grail', sole=[(BROWN, 0.05), ((252, 192, 40), 0.025), (BROWN, 0.025), (ORANGE, 0.09)], toe=ORANGE,
	quarter=[(252, 192, 40), (252, 192, 40), (252, 192, 40)], laces=WHITE, collar=BROWN, tongue=(252, 192, 40), label=ORANGE,
	tab=ORANGE, marks=m_solar)


ASTRO = (82, 34, 150)


def m_astro(m, d):
	f = side_face(m)
	g_star3(f, -0.18, 0.66, 0.16, YELLOW, 0.03)
	g_star3(f, -0.38, 0.5, 0.12, YELLOW, 0.03)
	with m.tagged(shaft=True):
		crown(m, (XC, TY1 - 0.01, (TZ0 + TZ1) / 2), 0.5, YELLOW, (250, 110, 40))
	wings(m, d, [YELLOW, (196, 160, 250)], 'round', 0.95)


shoe('AstroCrown', 'Astro Crown', 'Grail', sole=[(ASTRO, 0.05), (YELLOW, 0.025), (WHITE, 0.025), (YELLOW, 0.09)], toe=YELLOW,
	quarter=[ASTRO, ASTRO, ASTRO], laces=YELLOW, collar=(52, 22, 98), tongue=ASTRO, label=YELLOW, tab=False, marks=m_astro)


def m_grail(m, d):
	side_stripes(m, [(200, 160, 250), (120, 236, 236), (250, 250, 255)], z0=0.1, y0=0.44, length=0.4)
	g_sparkle(toe_face(m), 0.0, 0.34, 0.28, WHITE, 0.03)
	wings(m, d, [WHITE, (236, 238, 248)], 'round')


shoe('TheGrail', 'The Grail', 'Grail', sole=[(LAVENDER, 0.05), (WHITE, 0.025), ((110, 230, 240), 0.025, 'neon'), (LAVENDER, 0.09)],
	toe=LAVENDER, quarter=[GOLD, GOLD, GOLD], laces=[(250, 110, 90), (250, 180, 60), YELLOW, (110, 230, 240)], collar=LAVENDER,
	tongue=GOLD, label=False, tab=LAVENDER, marks=m_grail)


WORLD1 = list(ORDER)


def build(id):
	d = DEFS[id]
	m = bk.Model(id, d['Name'], unit=1.0, kind='shoe')
	ys = build_sole(m, d)
	build_upper(m, d, ys)
	build_laces(m, d)
	build_collar(m, d)
	build_tongue(m, d)
	if d.get('marks'):
		d['marks'](m, d)
	m.meta.update(box=d['Box'])
	bk.unshare(m)
	return m


def build_all():
	return [build(id) for id in ORDER]


if __name__ == '__main__':
	for mm in build_all():
		print('%-15s %3d parts' % (mm.id, mm.part_count()), bk.lint(mm)[:3])
