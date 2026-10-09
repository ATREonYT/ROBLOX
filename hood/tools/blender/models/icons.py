"""The HUD icons as BoxKit part models: the live fallbacks Studio shows until the PNGs (icons_hd.py) are uploaded.
Each one copies its PNG twin's shape and colours in chunky smooth plastic.

Icons face the camera at -z (Roblox Front), are centred on the origin and fit a 10 DU cube, which is
2 studs at the shared unit of 0.2 (the IconModels contract: fit in 2x2x2 at scale 1).
Remember when placing things: seen from the front, screen-right is world -x.
"""
import math

from boxkit import Model, cross, euler, from_columns, mat_mul, norm, rot_y, rot_z
from models import guns

UNIT = 0.2
FIT = 10.0  # DU


def pvp():
	m = Model('PVP', 'PVP', UNIT, kind='icon')
	with m.at((0, 0, 0), euler(-6, -14, -8)):
		m.box((0, 0.7, 0.9), (4.6, 4.0, 2.4), 'gold', 'gold', name='Hand')
		# Four curled fingers (small gaps so they read apart), middle finger tallest.
		tops = (2.85, 3.2, 3.05, 2.65)
		for i, top in enumerate(tops):
			x = 1.68 - i * 1.12
			h = top - 1.2
			m.box((x, 1.2 + h / 2, -0.55), (1.04, h, 2.1), 'gold', 'gold', studs=(1, 2), name='Finger')
			m.box((x, 0.45, -0.95), (1.04, 1.5, 1.5), 'gold', 'gold', name='FingerTip')
		# Thumb wraps across the lower fingers, in a deeper gold so it stands out.
		m.box((2.55, 0.0, -0.3), (1.25, 2.3, 2.0), 'golddark', 'gold', name='ThumbBase')
		m.box((0.85, -0.15, -1.75), (3.3, 1.2, 1.3), 'golddark', 'gold', rot=euler(0, 0, 6), name='Thumb')
		m.box((0, -2.5, 0.6), (3.6, 2.6, 2.6), 'gold', 'gold', name='Wrist')
		m.box((0, -2.1, 0.6), (3.95, 1.1, 2.95), 'red', 'smooth', name='Band')
	return m


def gun():
	m = Model('Gun', 'Gun', UNIT, kind='icon')
	with m.at((0, 0, 0), mat_mul(rot_z(-14), rot_y(90))):
		guns.pistol(slide='chrome', frame='gun', grip='wood', rust=False, into=m)
	m.meta['view'] = (-0.25, 0.22, -1.0)
	return m


# ---------------------------------------------------------------- brief 19: live fallbacks for the new HUD ids
# (the uploaded PNGs from icons_hd.py are the main look; these keep IconModels.build(id) working before the upload)
SNEAKER_RED = (232, 40, 56)
INK = (12, 10, 52)


def sneaker():
	"""A red high-top in profile: toe at screen-right (-x), heel collar at screen-left (+x)."""
	m = Model('Sneaker', 'Sneaker', UNIT, kind='icon')
	m.box((0, -2.75, 0), (9.6, 1.3, 4.0), 'white', 'smooth', name='Sole')
	m.box((0.05, -3.6, 0), (9.3, 0.42, 3.8), (84, 100, 140), 'smooth', name='Outsole')
	m.box((1.0, -1.0, 0), (6.6, 2.2, 3.6), SNEAKER_RED, 'smooth', name='Upper')
	m.box((3.0, 1.35, 0), (3.2, 2.5, 3.64), SNEAKER_RED, 'smooth', name='Ankle')
	m.box((-3.05, -1.33, 0), (3.3, 1.5, 3.7), 'white', 'smooth', name='ToeCap')
	m.box((1.2, 2.7, 0), (1.3, 1.6, 2.4), (250, 84, 98), 'smooth', name='Tongue')
	for i, x in enumerate((-1.4, -0.3, 0.8)):
		m.box((x, 0.18 + 0.02 * i, 0), (0.55, 0.36, 3.8), 'white', 'smooth', name='Lace')
	m.box((0.35, -1.4, -1.88), (5.2, 0.6, 0.2), 'yellow', 'smooth', bevel=0.02, name='Stripe')
	m.box((4.75, 1.6, 0), (0.42, 1.4, 1.4), 'yellow', 'smooth', name='HeelTab')
	return m


def shield(iid='Shield', letters=False):
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		m.box((0, 1.3, 0), (7.4, 4.4, 1.4), (30, 140, 250), 'smooth', name='Top')
		m.box((0, -1.0, 0), (5.2, 5.2, 1.36), (30, 140, 250), 'smooth', rot=euler(0, 0, 45), name='Point')
		m.box((0, 1.3, -0.76), (5.6, 3.2, 0.14), (10, 30, 190), 'smooth', name='FaceTop')
		m.box((0, -0.7, -0.78), (3.8, 3.8, 0.14), (10, 30, 190), 'smooth', rot=euler(0, 0, 45), name='FacePoint')
		if letters:
			# "XP" from bars (screen-right is -x): X on the left (+x), P on the right (-x)
			for sgn in (1, -1):
				m.box((1.3, 1.0, -0.9), (0.6, 3.2, 0.14), 'white', 'smooth', rot=euler(0, 0, sgn * 30), name='X')
			m.box((-0.9, 1.0, -0.92), (0.6, 3.2, 0.14), 'white', 'smooth', name='P')
			m.box((-1.55, 1.92, -0.94), (1.3, 1.3, 0.14), 'white', 'smooth', name='P')
		return m
	return build


def skull():
	m = Model('Skull', 'Skull', UNIT, kind='icon')
	m.ball((0, 0.9, 0), 7.6, 'white', 'smooth', name='Cranium')
	m.box((0, -2.6, 0.2), (5.2, 3.0, 4.6), 'white', 'smooth', name='Jaw')
	for sx in (-1, 1):
		m.box((sx * 1.55, 0.2, -3.45), (1.9, 2.0, 0.6), INK, 'smooth', name='Eye')
	m.box((0, -1.35, -2.95), (0.8, 0.9, 0.4), INK, 'smooth', name='Nose')
	for x in (-1.2, -0.4, 0.4, 1.2):
		m.box((x, -2.9, -2.15), (0.22, 1.4, 0.2), INK, 'smooth', name='Tooth')
	return m


def autofight():
	"""A red coin with a white crosshair (the Auto Fight pass)."""
	m = Model('AutoFight', 'AutoFight', UNIT, kind='icon')
	m.cyl((0, 0, 0), 1.3, 9.0, (226, 40, 66), 'smooth', axis='z', name='Coin')
	m.cyl((0, 0, -0.7), 0.12, 5.6, 'white', 'smooth', axis='z', name='Ring')
	m.cyl((0, 0, -0.78), 0.12, 4.6, (240, 64, 88), 'smooth', axis='z', name='Face')
	for (x, y, w, h) in ((0, 2.5, 0.7, 2.0), (0, -2.5, 0.7, 2.0), (2.5, 0, 2.0, 0.7), (-2.5, 0, 2.0, 0.7)):
		m.box((x, y, -0.9), (w, h, 0.14), 'white', 'smooth', name='Tick')
	m.box((0, 0, -0.9), (0.9, 0.9, 0.14), 'white', 'smooth', name='Dot')
	return m


# ---------------------------------------------------------------- brief 19 round 2 (UICRITIC P1-3): live fallbacks
# that match their PNG twins (shape, colours, a chunky silhouette). Studio's ViewportFrame light is flat and dim, so
# these use bright smooth plastic (no Foil, which goes dark there) and no LEGO studs on top.
REB_RED, REB_WHITE, REB_GREEN = (240, 50, 82), (244, 246, 250), (60, 192, 82)
GOLD2, GOLD2_DARK = (252, 176, 30), (226, 128, 18)
ORANGE2 = (255, 170, 36)


def _screen(ts, r):
	"""World (x, y) of screen angle ts (degrees, counter-clockwise from screen-right) at radius r (screen-right is -x)."""
	a = math.radians(ts)
	return (-math.cos(a) * r, math.sin(a) * r)


def rebirth2(iid, top):
	"""The Rebirth mark like the PNG and ref22: a ring (hole 40% of the diameter) of two thick arrows with gaps
	between them: `top` colour from ~10:30 over the top to its head at ~1:30-3 o'clock, white from ~4 o'clock under the
	bottom to its head at ~7:30-9 o'clock pointing up-left. Heads are tapering box steps that follow the ring."""
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		r_in, r_out = 2.0, 5.0
		mid, w = (r_in + r_out) / 2, r_out - r_in

		def seg_box(ts, step, rmid, width, col, z, k, name):
			x, y = _screen(ts, rmid)
			seg = 2 * (rmid + width / 2) * math.sin(math.radians(abs(step) / 2)) + 0.1
			m.box((x, y, z + 0.03 * (k % 3)), (seg, width, 1.2 + 0.02 * (k % 2)), col, 'smooth', rot=euler(0, 0, 90 - ts), name=name)

		def arrow(start, col, z):
			arc_end, tip = start - 110, start - 160
			n = 8
			for k in range(n):  # the body
				step = (arc_end - start) / n
				seg_box(start + step * (k + 0.5), step, mid, w, col, z, k, 'Arc')
			n = 5
			for k in range(n):  # the head: a barb outside, a tab inside, narrowing to the tip on the outer edge
				step = (tip - arc_end) / n
				t = (k + 0.5) / n
				lo = (r_in - 0.5) + (r_out - 1.0 - (r_in - 0.5)) * t
				hi = (r_out + 0.9) - 0.6 * t
				seg_box(arc_end + step * (k + 0.5), step, (lo + hi) / 2, hi - lo, col, z - 0.06, k, 'Head')
		arrow(160, top, 0.0)
		arrow(-20, REB_WHITE, 0.12)
		return m
	return build


def arm_live(iid):
	"""The flexed arm of the Muscle PNG as overlapping balls (same layout as icons_hd.arm: x, y in 0..1 of the icon)."""
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		# the metaballs blend into one body; plain balls need ~25% more radius and a few fillers to read as one arm
		balls = [(0.2, 0.17, 0.165), (0.2, 0.3, 0.165), (0.23, 0.42, 0.15), (0.27, 0.52, 0.14), (0.31, 0.61, 0.13),
			(0.35, 0.7, 0.14), (0.38, 0.78, 0.18), (0.3, 0.86, 0.12), (0.5, 0.83, 0.12), (0.6, 0.765, 0.105),
			(0.33, 0.18, 0.16), (0.47, 0.2, 0.16), (0.6, 0.26, 0.16), (0.75, 0.4, 0.2), (0.88, 0.31, 0.15)]
		for i, (x, y, r) in enumerate(balls):
			# depths alternate a hair so no two balls are the same size at the same depth (lint, z-fighting)
			m.ball((-(x - 0.5) * 10, (y - 0.5) * 10, 0.02 * (i % 3)), r * 25, ORANGE2, 'smooth', name='Arm')
		return m
	return build


def basket2(iid, body, inside, handle, rim, holes=None, front=None):
	"""The Store basket, OPEN: four tapered walls round a low floor (so the inside shows from the icon view), a lighter
	rim, the grey-blue handle arching up over it; turned so a front corner faces the camera, like the PNG.
	holes = the dark squares of the red basket's front walls."""
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		with m.at((0, 0, 0), euler(-4, 38, 0)):
			_basket_parts(m, body, inside, handle, rim, holes, front or body)
		return m
	return build


def _basket_parts(m, body, inside, handle, rim, holes, front):
	"""The basket in its own frame: floor at y -2.8, walls up to y 1.2 (~60% of the width), opening 7 x 5."""
	m.box((0, -3.0, 0), (5.2, 0.6, 3.4), inside, 'smooth', name='Floor')
	# walls lean out: each is a box rotated a little about its bottom edge; 4.8 tall (~65% of the width)
	for sz in (-1, 1):  # front (-z, lighter) and back (+z)
		with m.at((0, -1.1, sz * 2.0), euler(sz * 10, 0, 0)):
			m.box((0, 0, 0), (6.4, 4.8, 0.6), front if sz < 0 else body, 'smooth', name='Wall')
	for sx in (-1, 1):  # sides
		with m.at((sx * 3.05, -1.1, 0), euler(0, 0, -sx * 10)):
			m.box((0, 0, 0), (0.6, 4.8, 4.2), body, 'smooth', name='Wall')
	m.box((0, 1.35, -2.36), (7.4, 0.5, 0.66), rim, 'smooth', name='Rim')
	m.box((0, 1.36, 2.36), (7.42, 0.5, 0.66), rim, 'smooth', name='Rim')
	for sx in (-1, 1):
		m.box((sx * 3.42, 1.37, 0), (0.66, 0.5, 4.1), rim, 'smooth', name='Rim')
	if holes:
		with m.at((0, -0.7, -2.0), euler(-10, 0, 0)):
			for y in (0.6, -0.8):
				for x in (-1.9, -0.63, 0.63, 1.9):
					m.box((x, y, -0.34), (0.9, 0.8, 0.12), holes, 'smooth', name='Hole')
	# handle: two posts from the side rims and a bar over the top
	for sx in (-1, 1):
		m.box((sx * 3.42, 3.0, 0), (0.6, 3.0, 0.6), handle, 'smooth', name='Handle')
	m.box((0, 4.75, 0), (7.46, 0.6, 0.64), handle, 'smooth', name='Handle')


def cash2():
	m = Model('Cash', 'Cash', UNIT, kind='icon')
	band = lambda x, z: abs(x) < 0.9
	with m.at((0.6, 0, 0.6), euler(-28, 0, 0)):
		for i, (ry, dx) in enumerate(((-7, 0.3), (5, -0.25), (-2, 0.0))):
			y = -1.2 + i * 0.62
			m.box((dx, y, 0), (7.2, 0.6, 3.8), (88, 200, 78), 'smooth', rot=euler(0, ry, 0), name='Bill')
			m.box((dx, y, 0), (7.25, 0.22, 3.85), (44, 146, 62), 'smooth', rot=euler(0, ry, 0), name='BillEdge')
		m.box((1.0, -0.55, 0), (1.3, 2.05, 3.95), (250, 236, 200), 'smooth', rot=euler(0, -2, 0), name='Band')
		m.box((-1.0, -0.26, -0.2), (2.6, 0.12, 1.9), (50, 156, 64), 'smooth', rot=euler(0, -2, 0), name='Seal')
	with m.at((-2.6, -0.9, -2.2), euler(-6, 24, -8)):
		m.cyl((0, 0, 0), 0.9, 4.4, GOLD2, 'smooth', axis='z', name='Coin')
		m.cyl((0, 0, -0.46), 0.12, 3.5, GOLD2_DARK, 'smooth', axis='z', name='CoinFace')
		for y in (0.85, 0.0, -0.85):
			m.box((0, y, -0.6), (1.4, 0.38, 0.2), (255, 230, 120), 'smooth', name='Dollar')
		m.box((0.52, 0.43, -0.6), (0.38, 0.85, 0.24), (255, 230, 120), 'smooth', name='Dollar')
		m.box((-0.52, -0.43, -0.6), (0.38, 0.85, 0.24), (255, 230, 120), 'smooth', name='Dollar')
		m.box((0, 0, -0.62), (0.28, 2.6, 0.3), (255, 230, 120), 'smooth', name='Dollar')
	return m


def trophy2():
	m = Model('Trophy', 'Trophy', UNIT, kind='icon')
	m.prism((0, 1.5, 0), 2.6, 4.8, GOLD2, 'smooth', sides=8, axis='y', spin=22.5, name='Cup')
	m.prism((0, 3.05, 0), 0.6, 5.4, GOLD2, 'smooth', sides=8, axis='y', spin=22.5, name='Rim')
	m.prism((0, 3.38, 0), 0.08, 4.5, (232, 70, 34), 'smooth', sides=8, axis='y', spin=22.5, name='Inside')
	m.prism((0, -0.25, 0), 1.0, 3.4, GOLD2, 'smooth', sides=8, axis='y', spin=22.5, name='Bowl')
	m.cyl((0, -1.35, 0), 1.4, 1.1, GOLD2_DARK, 'smooth', axis='y', name='Stem')
	for sx in (-1, 1):
		m.box((sx * 2.95, 2.5, 0), (1.4, 0.55, 0.7), GOLD2, 'smooth', name='Handle')
		m.box((sx * 3.45, 1.5, 0), (0.55, 2.4, 0.76), GOLD2, 'smooth', name='Handle')
		m.box((sx * 2.85, 0.5, 0), (1.3, 0.55, 0.7), GOLD2, 'smooth', name='Handle')
	m.box((0, -2.4, 0), (3.6, 0.7, 3.0), GOLD2, 'smooth', name='Foot')
	m.box((0, -3.4, 0), (4.8, 1.3, 3.8), GOLD2_DARK, 'smooth', name='Base')
	return m


def rewards2():
	m = Model('Rewards', 'Rewards', UNIT, kind='icon')
	box, lid, rib = (232, 50, 120), (246, 90, 150), (255, 164, 18)
	m.box((0, -1.7, 0), (6.6, 4.6, 5.6), box, 'smooth', name='Box')
	m.box((0, 1.25, 0), (7.2, 1.4, 6.2), lid, 'smooth', name='Lid')
	m.box((0, -1.7, -2.86), (1.6, 4.64, 0.2), rib, 'smooth', name='Ribbon')
	m.box((0, 1.25, -3.17), (1.65, 1.44, 0.22), rib, 'smooth', name='Ribbon')
	for sx in (-1, 1):
		m.box((sx * 3.36, -1.7, 0), (0.2, 4.64, 1.6), rib, 'smooth', name='Ribbon')
		m.box((sx * 3.66, 1.25, 0), (0.2, 1.44, 1.65), rib, 'smooth', name='Ribbon')
	m.box((0, 2.0, 0), (1.61, 0.2, 6.29), rib, 'smooth', name='Ribbon')
	m.box((0, 2.0, 0), (7.29, 0.24, 1.61), rib, 'smooth', name='Ribbon')
	for sx in (-1, 1):
		m.box((sx * 1.8, 3.0, -0.3 - 0.04 * sx), (3.4, 1.7, 1.3), rib, 'smooth', rot=euler(0, 0, sx * 18), name='Bow')
		m.box((sx * 1.85, 3.02, -0.98), (1.7, 0.6, 0.12), (226, 120, 10), 'smooth', rot=euler(0, 0, sx * 18), name='BowHole')
	m.box((0, 2.75, -0.35), (1.3, 1.25, 1.35), (240, 140, 14), 'smooth', name='Knot')
	return m


def evolve2(iid, tilt=0):
	"""The green arrow with a darker copy behind it, offset down-right, so the flat ViewportFrame light still shows its
	thickness (screen-right is -x)."""
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		with m.at((0, 0, 0), euler(0, 0, tilt)):
			for (dx, dy, dz, col, nm) in ((-0.55, -0.55, 0.5, (28, 132, 54), 'Side'), (0, 0, 0, (52, 186, 74), 'Face')):
				m.box((dx, -2.3 + dy, dz), (3.6, 4.8, 2.4), col, 'smooth', name=nm)
				m.tri((dx, 0.0 + dy, dz), (0, 1, 0), (1, 0, 0), 4.9, 8.8, 2.4, col, 'smooth', name=nm)
			m.box((0, -2.1, -1.25), (2.4, 3.9, 0.2), (124, 228, 124), 'smooth', name='Shine')
			m.tri((0, 0.55, -1.25), (0, 1, 0), (1, 0, 0), 3.4, 6.1, 0.2, (124, 228, 124), 'smooth', name='Shine')
		return m
	return build


def vip2():
	m = Model('VIP', 'VIP', UNIT, kind='icon')
	m.box((0, -2.2, 0), (8.6, 2.2, 2.6), GOLD2_DARK, 'smooth', name='Band')
	m.box((0, -0.5, 0.1), (7.8, 1.4, 2.2), GOLD2, 'smooth', name='Crown')
	for (x, h) in ((3.1, 3.4), (0.0, 4.2), (-3.1, 3.4)):
		m.tri((x, 0.15, 0.1), (0, 1, 0), (1, 0, 0), h, 2.8, 2.2, GOLD2, 'smooth', name='Point')
		m.ball((x, 0.15 + h + 0.35, 0.1), 1.2, GOLD2, 'smooth', name='Tip')
	m.box((0, -2.2, -1.38), (1.4, 1.4, 0.3), (230, 30, 70), 'smooth', rot=euler(0, 0, 45), name='Ruby')
	for sx in (-1, 1):
		m.box((sx * 2.8, -2.2, -1.38), (1.0, 1.0, 0.26), (40, 150, 255), 'smooth', name='Sapphire')
	return m


def dumbbell():
	"""The DoublePower card art's live twin: a gold dumbbell with octagonal plates."""
	m = Model('DoublePower', 'DoublePower', UNIT, kind='icon')
	with m.at((0, 0, 0), euler(0, 30, 28)):
		m.cyl((0, 0, 0), 9.0, 0.8, (196, 206, 222), 'smooth', axis='x', name='Bar')
		m.cyl((0, 0, 0), 3.0, 1.2, (70, 74, 96), 'smooth', axis='x', name='Grip')
		for sx in (-1, 1):
			m.cyl((sx * 1.9, 0, 0), 0.5, 1.8, (196, 206, 222), 'smooth', axis='x', name='Collar')
			m.prism((sx * 2.75, 0, 0), 1.2, 5.6, GOLD2, 'smooth', sides=8, axis='x', spin=22.5, name='PlateBig')
			m.prism((sx * 3.85, 0, 0), 1.0, 4.3, GOLD2_DARK, 'smooth', sides=8, axis='x', spin=22.5, name='PlateSmall')
			m.cyl((sx * 4.55, 0, 0), 0.4, 1.6, (196, 206, 222), 'smooth', axis='x', name='Cap')
	return m


def quest2():
	m = Model('Quest', 'Quest', UNIT, kind='icon')
	paper, end, core = (236, 138, 94), (196, 92, 62), (150, 64, 44)
	with m.at((0, 0, 0), euler(0, 0, -40)):
		m.cyl((0, 0, 0), 7.6, 3.6, paper, 'smooth', axis='x', name='Roll')
		m.cyl((3.85, 0, 0), 0.2, 3.1, end, 'smooth', axis='x', name='End')
		m.cyl((3.96, 0, 0), 0.1, 1.6, core, 'smooth', axis='x', name='Core')
		m.cyl((-3.85, 0, 0), 0.2, 3.3, (250, 186, 146), 'smooth', axis='x', name='Lip')
		m.cyl((-1.4, 0, 0), 1.7, 3.8, (240, 50, 82), 'smooth', axis='x', name='Band')
	m.box((0.6, -2.4, -1.6), (0.75, 2.2, 0.25), (240, 50, 82), 'smooth', rot=euler(0, 0, 14), name='Tail')
	m.box((-0.3, -2.6, -1.65), (0.75, 2.4, 0.25), (200, 30, 60), 'smooth', rot=euler(0, 0, -10), name='Tail')
	return m


def robux2():
	m = Model('Robux', 'Robux', UNIT, kind='icon')
	ink = (11, 42, 0)
	m.prism((0, 0, 0), 1.2, 8.6, (250, 251, 252), 'smooth', sides=6, axis='z', spin=30, name='Outer')
	m.prism((0, 0, -0.66), 0.14, 6.0, ink, 'smooth', sides=6, axis='z', spin=30, name='Groove')
	m.prism((0, 0, -0.78), 0.14, 5.2, (250, 251, 252), 'smooth', sides=6, axis='z', spin=30, name='Inner')
	m.box((0, 0, -0.9), (1.3, 1.3, 0.14), ink, 'smooth', name='Hole')
	return m


# ---------------------------------------------------------------- brief 22 (ref22): live fallbacks for the new art
SEA, LAND = (84, 174, 250), (88, 200, 74)
PACK, PACK_LIGHT, PACK_DARK = (224, 90, 69), (240, 120, 96), (184, 58, 42)
GLASSY, GLASSY_DARK = (176, 228, 252), (120, 188, 236)
BILL, BILL_EDGE = (88, 200, 78), (44, 146, 62)


def world():
	"""The globe like the PNG: ocean #3C8FE0 with a lighter (#7BC4F5) top-left cap, three irregular green land masses
	(2-4 overlapping flat discs each, of different sizes) lying on the surface: the Americas on the left, Africa and
	Europe on the right."""
	m = Model('World', 'World', UNIT, kind='icon')
	m.ball((0, 0, 0), 9.6, (60, 143, 224), 'smooth', name='Sea')

	def patch(x, y, z, d, col, lift, name):
		r = math.sqrt(x * x + y * y + z * z)
		nrm = (x / r, y / r, z / r)
		up = (0, 1, 0) if abs(nrm[1]) < 0.9 else (1, 0, 0)
		yw = norm(cross(up, nrm))
		zw = cross(nrm, yw)
		R = 4.8 + lift
		m.cyl((nrm[0] * R, nrm[1] * R, nrm[2] * R), 0.24, d, col, 'smooth', rot=from_columns(nrm, yw, zw), name=name)
	# the light cap (top-left of the ball as seen; screen-left is +x)
	patch(1.6, 2.0, -3.6, 5.2, (84, 160, 232), -0.12, 'SeaLight')
	k = 0
	for mass in (
		[(2.6, 2.2, -3.2, 2.8), (2.2, 0.6, -4.0, 2.4), (1.8, -1.2, -4.2, 2.0), (1.0, -2.6, -3.9, 1.8)],  # the Americas
		[(-2.2, 1.0, -3.9, 3.0), (-2.6, -0.8, -3.7, 2.6), (-1.8, -2.2, -3.8, 1.8)],  # Africa
		[(-1.4, 3.2, -3.0, 2.2), (-0.4, 3.9, -2.4, 1.6)],  # Europe
	):
		for (x, y, z, d) in mass:
			patch(x, y, z, d, (76, 192, 58), 0.02 * (k % 3), 'Land')
			k += 1
	return m


def backpack():
	"""ref22's backpack: a rounded red-orange pack, a darker rounded top flap, a lighter front pocket, two straps with gold
	buckles, side pockets and a handle loop on top."""
	m = Model('Backpack', 'Backpack', UNIT, kind='icon')
	m.box((0, -1.4, 0), (7.4, 4.8, 5.0), PACK, 'smooth', name='Body')
	# the rounded top half: a cylinder across, and two rounded side caps so the corners aren't square
	m.cyl((0, 1.0, 0.0), 6.2, 5.0, PACK, 'smooth', axis='x', name='Top')
	for sx in (-1, 1):
		m.ball((sx * 2.9, 1.0, 0.0), 5.0, PACK, 'smooth', name='TopEnd')
	m.cyl((0, 1.3, -0.4), 6.3, 4.5, PACK_DARK, 'smooth', axis='x', name='Flap')
	m.box((0, -2.1, -2.7), (5.0, 3.0, 1.0), PACK_LIGHT, 'smooth', name='Pocket')
	for sx in (-1, 1):
		m.box((sx * 1.4, 0.5, -2.62), (0.9, 3.8, 0.3), PACK_DARK, 'smooth', name='Strap')
		m.box((sx * 1.4, -0.75, -2.84), (1.1, 0.8, 0.3), (255, 214, 80), 'smooth', name='Buckle')
		m.box((sx * 3.85, -1.6, 0), (0.8, 2.8, 3.5), PACK_DARK, 'smooth', name='SidePocket')
	for sx in (-1, 1):
		m.box((sx * 1.2, 3.95, 0), (0.6, 1.4, 0.6), PACK_DARK, 'smooth', name='Handle')
	m.box((0, 4.5, 0), (3.12, 0.6, 0.66), PACK_DARK, 'smooth', name='Handle')
	return m


def _mini_sneaker(m, at, col, stripe, facing=1, s=1.0):
	"""A small sneaker in side view (along x): white sole, upper with a sloped toe (wedge), high ankle, white toe cap,
	laces, a stripe; facing = +1 toe to the screen-left (+x), -1 to the screen-right."""
	x0, y0, z0 = at
	f = facing
	m.box((x0, y0, z0), (5.4 * s, 0.9 * s, 2.4 * s), 'white', 'smooth', name='Sole')
	m.box((x0 - f * 0.9 * s, y0 + 1.15 * s, z0), (3.4 * s, 1.4 * s, 2.2 * s), col, 'smooth', name='Upper')
	m.wedge((x0 + f * 1.55 * s, y0 + 1.15 * s, z0), (2.2 * s, 1.4 * s, 1.6 * s), col, 'smooth',
		rot=euler(0, 90 if f > 0 else -90, 0), name='Toe')
	m.box((x0 - f * 1.55 * s, y0 + 2.35 * s, z0), (2.0 * s, 1.6 * s, 2.24 * s), col, 'smooth', name='Ankle')
	m.box((x0 + f * 2.18 * s, y0 + 0.78 * s, z0), (0.96 * s, 0.7 * s, 2.3 * s), 'white', 'smooth', name='ToeCap')
	for k in range(3):
		m.box((x0 + f * (0.05 - 0.55 * k) * s, y0 + (1.95 + 0.12 * k) * s, z0), (0.3 * s, 0.24 * s, 2.32 * s), 'white', 'smooth',
			name='Lace')
	m.box((x0 - f * 0.5 * s, y0 + 1.0 * s, z0 - 1.16 * s), (2.6 * s, 0.4 * s, 0.12 * s), stripe, 'smooth', name='Stripe')


def shoe_pile():
	"""Two sneakers stacked the same way round, like the PNG: a blue one behind and above, the red one in front."""
	m = Model('ShoePile', 'ShoePile', UNIT, kind='icon')
	_mini_sneaker(m, (-1.0, 0.8, 1.6), (40, 130, 245), 'white', facing=1, s=0.85)
	_mini_sneaker(m, (0.6, -1.8, -0.9), (232, 40, 56), 'yellow', facing=1, s=1.0)
	return m


def shoe_box():
	m = Model('ShoeBox', 'ShoeBox', UNIT, kind='icon')
	m.box((0, -1.2, 0), (9.4, 4.0, 5.8), (255, 140, 30), 'smooth', name='Box')
	m.box((0, 1.6, 0), (9.9, 1.5, 6.3), (250, 104, 30), 'smooth', rot=euler(0, 0, -4), name='Lid')
	m.box((0, -1.5, -2.95), (5.0, 1.6, 0.14), (255, 236, 200), 'smooth', name='Emblem')
	return m


def _front_studs(m, pts, z, col, d=1.0):
	"""Studs on a front (-Z) face: short cylinders along z."""
	for (x, y) in pts:
		m.cyl((x, y, z - 0.18), 0.36, d, col, 'smooth', axis='z', name='Stud')


def delete_x():
	m = Model('Delete', 'Delete', UNIT, kind='icon')
	m.box((0, 0, 0), (10.0, 2.8, 3.2), (236, 52, 92), 'smooth', rot=euler(0, 0, 45), name='Bar')
	m.box((0, 0, 0.02), (10.0, 2.8, 3.36), (236, 52, 92), 'smooth', rot=euler(0, 0, -45), name='Bar')
	pts = []
	for t in (-3.0, -1.6, 1.6, 3.0):
		c = t / math.sqrt(2)
		pts += [(c, c), (c, -c)]
	pts.append((0, 0))
	_front_studs(m, pts, -1.6, (255, 128, 158))
	return m


def _star(m, at, r_out, r_in, depth, col, name='Star'):
	"""A 5-point star slab: a decagon core and five exact arrowhead arms. The core's flats sit at r_in (on the notches and
	across the points), so it covers the whole inner pentagon (no gaps at the notches) and its corners stay inside the
	arms."""
	x0, y0, z0 = at
	c36 = math.cos(math.radians(36))
	m.prism((x0, y0, z0), depth, 2 * r_in, col, 'smooth', sides=10, axis='z', spin=18, name=name)
	for k in range(5):
		a = math.radians(90 + 72 * k)
		bx, by = x0 + math.cos(a) * r_in * c36, y0 + math.sin(a) * r_in * c36
		m.tri((bx, by, z0), (math.cos(a), math.sin(a), 0), (-math.sin(a), math.cos(a), 0), r_out - r_in * c36,
			2 * r_in * math.sin(math.radians(36)), depth + 0.04 * (k % 2), col, 'smooth', name=name)


def favorite():
	m = Model('Favorite', 'Favorite', UNIT, kind='icon')
	_star(m, (0, 0, 0), 5.0, 2.4, 2.4, GOLD2)
	pts = [(0, 0)] + [(math.cos(math.radians(90 + 72 * k)) * 2.3, math.sin(math.radians(90 + 72 * k)) * 2.3) for k in range(5)]
	_front_studs(m, pts, -1.24, (255, 222, 90))
	return m


def search():
	m = Model('Search', 'Search', UNIT, kind='icon')
	m.cyl((-1.0, 1.0, 0), 1.0, 6.6, (60, 66, 90), 'smooth', axis='z', name='Rim')
	m.cyl((-1.0, 1.0, -0.06), 1.0, 5.2, (170, 226, 250), 'smooth', axis='z', name='Lens')
	m.box((2.6, -2.6, 0), (1.6, 4.6, 1.6), (255, 176, 40), 'smooth', rot=euler(0, 0, 45), name='Handle')
	return m


def _star_bottle(m, liquid):
	"""The PNG's fat star bottle (star point/notch 0.61): a glass star; on its front the liquid, the same star scaled
	0.88 and cut level just under the middle (the bottom triangle of the inner pentagon, the two lower points and a band
	up to the cut), so a glass rim shows round it; a short glass neck on the top point and a big gold cork."""
	R, r, D, y0, k = 4.9, 3.0, 2.6, -0.9, 0.88
	c36, s36, s18 = math.cos(math.radians(36)), math.sin(math.radians(36)), math.sin(math.radians(18))
	_star(m, (0, y0, 0), R, r, D, GLASSY)
	zc = -D / 2 - 0.06
	rk, Rk = r * k, R * k
	yb = y0 - rk * s18  # the inner pentagon's lower side corners (198 / 342 deg)
	xb = rk * math.cos(math.radians(18))
	m.tri((0, yb, zc), (0, -1, 0), (1, 0, 0), rk - rk * s18, 2 * xb, 0.3, liquid, 'smooth', name='Liquid')
	for a in (234, 306):
		u = (math.cos(math.radians(a)), math.sin(math.radians(a)), 0)
		m.tri((u[0] * rk * c36, y0 + u[1] * rk * c36, zc), u, (-u[1], u[0], 0), Rk - rk * c36, 2 * rk * s36,
			0.32 + 0.02 * (a == 306), liquid, 'smooth', name='Liquid')
	m.box((0, yb + 0.4, zc), (2 * xb, 0.8, 0.36), liquid, 'smooth', name='Liquid')
	m.cyl((0, y0 + R - 0.75, 0), 1.7, 2.2, GLASSY_DARK, 'smooth', axis='y', name='Neck')
	m.box((0, y0 + R + 0.65, 0), (3.0, 1.3, 3.0), (255, 196, 40), 'smooth', name='Cork')


# The live camera (IconModels.View) is ~18 deg round and ~19 deg up on the screen-right; the PNG potions are seen
# almost square on from a little to the left (icons_hd view (-0.18, -1, 0.12)). This turn puts IconModels.View exactly
# on that direction in the bottle's own space.
_FACE_CAMERA = euler(13, 27, 0)


def potion(iid, liquid):
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		with m.at((0, 0, 0), _FACE_CAMERA):
			_star_bottle(m, liquid)
		return m
	return build


def boost_bundle():
	"""One big red star potion tilted ~15 deg, like the PNG (ref42)."""
	m = Model('BoostBundle', 'BoostBundle', UNIT, kind='icon')
	with m.at((0, 0, 0), mat_mul(_FACE_CAMERA, euler(0, 0, -15))):
		_star_bottle(m, (236, 44, 72))
	return m


FLOOR = -3.0  # the piles' floor (y)
K29 = 2.9  # icons_hd units -> DU: the piles below are ported part for part from the PNG piles (icons_hd cash_* / power_*)
# IconModels.View is ~18 deg round to the screen-right and ~19 deg up; the PNG piles are seen from ~15 deg to the left and
# ~26 deg up (icons_hd CASH_VIEW / POWER_VIEW). This turn of the whole pile puts IconModels.View exactly on that direction.
_PILE_VIEW = euler(-7, 35, 0)


def _P(x, y, z):
	"""An icons_hd pile point (x to the screen-right, y away from the camera, z up) in DU here."""
	return (-x * K29, FLOOR + z * K29, y * K29)


_STACK = [0]


def _bills(m, at, n, yaw=0.0):
	"""The PNG's bills(): n bills (2.0 x 1.02 there) fanned a little, a cream band across one end and a dark green
	seal with a white stroke on the top bill. at: the bottom bill's centre (DU)."""
	_STACK[0] += 1
	x, y, z = at
	y += 0.013 * (_STACK[0] % 7) + 0.17  # each stack a hair higher than the last: no two bills share a plane
	for k in range(n):
		m.box((x + 0.09 * (k % 2), y + k * 0.38, z), (5.8, 0.34, 2.96), BILL if k == n - 1 else BILL_EDGE, 'smooth',
			rot=euler(0, yaw + (k - n / 2) * 2.5, 0), name='Bill')
	with m.at((x, y, z), euler(0, yaw + (n - 1 - n / 2) * 2.5, 0)):
		m.box((-1.6, (n - 1) * 0.19, 0), (0.99, (n - 1) * 0.38 + 0.46, 3.13), (250, 236, 200), 'smooth', name='Band')
		top = (n - 1) * 0.38 + 0.17
		m.cyl((0.58, top + 0.03, 0), 0.08, 2.0, (50, 156, 64), 'smooth', axis='y', name='Seal')
		m.box((0.58, top + 0.09, 0), (0.26, 0.06, 1.1), (236, 255, 220), 'smooth', name='Dollar')


def _coin(m, at, r=0.3):
	"""A gold coin lying flat (the PNG's coin, radius r there) with a darker face."""
	d = 2 * r * K29
	m.cyl(at, 0.41, d, GOLD2, 'smooth', axis='y', name='Coin')
	m.cyl((at[0], at[1] + 0.22, at[2]), 0.04, d * 0.74, GOLD2_DARK, 'smooth', axis='y', name='CoinFace')


def _gold_bar(m, at, yaw):
	"""The PNG's gold_bar (0.9 x 0.42 x 0.3, tapered): a bar and a narrower top."""
	with m.at(at, euler(0, yaw, 0)):
		m.box((0, 0, 0), (2.61, 0.6, 1.22), GOLD2, 'smooth', name='GoldBar')
		m.box((0, 0.36, 0), (2.14, 0.3, 0.86), GOLD2, 'smooth', name='GoldBar')


def _money_bag(m, at, s=1.0):
	"""The PNG piles' green cash sack: a ball, a narrow neck under a gold cord, a flared top, a white "$" on the front.
	at: the bottom of the sack."""
	x, y, z = at
	y += 0.009  # (off the bills' planes)
	m.ball((x, y + 2.6 * s, z), 5.4 * s, (70, 176, 70), 'smooth', name='Sack')
	m.cyl((x, y + 5.2 * s, z), 1.4 * s, 1.3 * s, (70, 176, 70), 'smooth', axis='y', name='Neck')
	m.cyl((x, y + 5.25 * s, z), 0.45 * s, 1.9 * s, GOLD2, 'smooth', axis='y', name='Cord')
	m.cyl((x, y + 6.1 * s, z), 0.7 * s, 2.9 * s, (84, 190, 80), 'smooth', axis='y', name='Tuft')
	m.cyl((x, y + 6.55 * s, z), 0.3 * s, 1.8 * s, (84, 190, 80), 'smooth', axis='y', name='Tuft')
	# "$": three bars, two side strokes and the line through it, standing 0.3 off the sack's front
	f, w = z - 2.62 * s, (236, 255, 220)
	for (dx, dy, sx, sy, dz) in ((0, 0.75, 1.3, 0.35, 0), (0, 0, 1.3, 0.37, 0.02), (0, -0.75, 1.3, 0.35, 0.04),
			(0.5, 0.42, 0.34, 0.66, 0.06), (-0.5, -0.42, 0.34, 0.66, 0.08), (0, 0, 0.22, 2.3, 0.1)):
		m.box((x + dx * s, y + (2.7 + dy) * s, f - dz * s), (sx * s, sy * s, 0.3 * s), w, 'smooth', name='Dollar')


def cash_pile(iid, bags=(), bills=(), bars=(), stacks=(), coins=()):
	"""The PNG piles (icons_hd cash_tiny..cash_large) ported part for part, in icons_hd units: bags (x, y, z, s),
	bills (x, y, z, yaw, n), bars (x, y, z, yaw), stacks (x, y, z, n, r), coins (x, y, z, r)."""
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		with m.at((0, 0, 0), _PILE_VIEW):
			for (x, y, z, s) in bags:
				_money_bag(m, _P(x, y, z), s * 0.75)
			for (x, y, z, yaw, n) in bills:
				_bills(m, _P(x, y, z), n, yaw)
			for (x, y, z, yaw) in bars:
				_gold_bar(m, _P(x, y, z), yaw)
			for (x, y, z, n, r) in stacks:
				for k in range(n):
					_coin(m, _P(x + 0.03 * (k % 2), y, z + k * 0.15), r)
			for (x, y, z, r) in coins:
				_coin(m, _P(x, y, z), r)
		return m
	return build


def _dumbbell(m, at, s=1.0, yaw=0.0, roll=0.0):
	"""A dumbbell (the PNG's dumbbell_parts at the same scale) lying with its bar level, turned by yaw about the
	vertical, its octagon plates facing the camera at an angle."""
	with m.at(at, euler(0, yaw, roll)):
		m.cyl((0, 0, 0), 7.8 * s, 0.75 * s, (196, 206, 222), 'smooth', axis='x', name='Bar')
		m.cyl((0, 0, 0), 2.6 * s, 1.04 * s, (70, 74, 96), 'smooth', axis='x', name='Grip')
		for sx in (-1, 1):
			m.prism((sx * 2.38 * s, 0, 0), 1.04 * s, 4.8 * s, GOLD2, 'smooth', sides=8, axis='x', spin=22.5, name='Plate')
			m.cyl((sx * 3.36 * s, 0, 0), 0.87 * s, 3.7 * s, GOLD2_DARK, 'smooth', axis='x', name='Plate')  # (one part: the
			# PowerLarge heap has to stay under the 120-part limit)


def _kettlebell(m, at, s=1.0):
	"""A gold kettlebell (the PNG's): a ball on the floor and a thick handle with rounded corners."""
	x, y, z = at
	m.ball((x, y + 1.45 * s, z), 3.5 * s, GOLD2, 'smooth', name='Bell')
	for sx in (-1, 1):
		m.box((x + sx * 1.02 * s, y + 3.0 * s, z), (0.64 * s, 1.5 * s, 0.64 * s), GOLD2, 'smooth', name='Handle')
		m.box((x + sx * 0.82 * s, y + 3.78 * s, z), (0.64 * s, 0.8 * s, 0.7 * s), GOLD2, 'smooth', rot=euler(0, 0, -sx * 45),
			name='Handle')
	m.box((x, y + 3.96 * s, z), (1.3 * s, 0.64 * s, 0.67 * s), GOLD2, 'smooth', name='Handle')


def _plate(m, at, s=1.0):
	"""A loose weight plate lying flat (octagon, dark hole)."""
	x, y, z = at
	m.prism((x, y, z), 0.52 * s, 3.6 * s, GOLD2_DARK, 'smooth', sides=8, axis='y', spin=22.5, name='Plate')
	m.cyl((x, y + 0.28 * s, z), 0.08 * s, 0.93 * s, (70, 74, 96), 'smooth', axis='y', name='Hole')


def power_pile(iid, kettles=(), bells=(), plates=()):
	"""The PNG piles (icons_hd power_tiny..power_large) ported part for part. Each entry is in icons_hd units:
	kettles (x, y, z, s), bells (x, y, z, s, yaw, roll), plates (x, y, z, s)."""
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		with m.at((0, 0, 0), _PILE_VIEW):
			for (x, y, z, s) in kettles:
				_kettlebell(m, _P(x, y, z), s)
			for (x, y, z, s, yaw, roll) in bells:
				_dumbbell(m, _P(x, y, z), s, yaw, roll)
			for (x, y, z, s) in plates:
				_plate(m, _P(x, y, z), s)
		return m
	return build


ICONS = [
	('Shop', basket2('Shop', (236, 112, 8), (200, 84, 10), (130, 162, 200), (250, 150, 30), front=(250, 140, 24))),
	('Rebirth', rebirth2('Rebirth', REB_RED)),
	('Rewards', rewards2),
	('PVP', pvp),
	('Evolve', evolve2('Evolve')),
	('Cash', cash2),
	('Power', arm_live('Power')),
	('Trophy', trophy2),
	('Gun', gun),
	('Muscle', arm_live('Muscle')),
	('Basket', basket2('Basket', (236, 112, 8), (200, 84, 10), (130, 162, 200), (250, 150, 30), front=(250, 140, 24))),
	('BasketRed', basket2('BasketRed', (224, 48, 60), (150, 16, 40), (176, 188, 206), (246, 100, 120), holes=(120, 6, 30))),
	('Quest', quest2),
	('Sneaker', sneaker),
	('Robux', robux2),
	('Shield', shield('Shield')),
	('XP', shield('XP', letters=True)),
	('Skull', skull),
	('VIP', vip2),
	('AutoFight', autofight),
	('Arrow', evolve2('Arrow', tilt=45)),
	('RebirthSkip', rebirth2('RebirthSkip', REB_GREEN)),
	('DoublePower', dumbbell),
	('World', world),
	('Backpack', backpack),
	('ShoePile', shoe_pile),
	('ShoeBox', shoe_box),
	('Delete', delete_x),
	('Favorite', favorite),
	('Search', search),
	('PotionRed', potion('PotionRed', (236, 44, 72))),
	('PotionGold', potion('PotionGold', (255, 204, 30))),
	('BoostBundle', boost_bundle),
	('CashTiny', cash_pile('CashTiny', bags=[(0.1, 0.25, 0.0, 1.25)], bills=[(-0.5, -0.6, 0.0, -24, 3)],
		coins=[(0.75, -0.75, 0.05, 0.36)])),
	('CashSmall', cash_pile('CashSmall', bags=[(0.3, 0.45, 0.0, 1.25)], bills=[(-0.75, 0.15, 0.0, 12, 4), (-0.45, -0.75, 0.0, -8, 3)],
		stacks=[(0.95, -0.7, 0.07, 3, 0.32)], coins=[(0.3, -1.05, 0.05, 0.32), (-1.25, -0.85, 0.05, 0.3)])),
	('CashMedium', cash_pile('CashMedium', bags=[(-0.5, 0.6, 0.0, 1.2), (0.6, 0.75, 0.0, 1.05)],
		bills=[(0.0, -0.05, 0.0, 4, 5), (-1.15, -0.45, 0.0, 14, 3), (1.15, -0.4, 0.0, -12, 3)], bars=[(0.0, -0.95, 0.15, 8)],
		stacks=[(-0.85, -1.15, 0.07, 3, 0.3), (0.85, -1.1, 0.07, 2, 0.3)], coins=[(-0.05, -1.45, 0.05, 0.3)])),
	('CashLarge', cash_pile('CashLarge', bags=[(0.0, 1.05, 0.25, 1.35), (-1.05, 0.7, 0.0, 1.1), (1.1, 0.75, 0.0, 1.05)],
		bills=[(-0.6, 0.0, 0.0, 10, 5), (0.6, 0.05, 0.0, -8, 5), (0.0, -0.3, 0.62, 2, 3), (-1.5, -0.55, 0.0, 16, 3),
		(1.5, -0.5, 0.0, -16, 3)], bars=[(-0.55, -0.95, 0.15, 14), (0.55, -1.0, 0.15, -10), (0.0, -0.95, 0.45, 2)],
		stacks=[(-1.25, -1.2, 0.07, 4, 0.3), (1.25, -1.2, 0.07, 3, 0.3)], coins=[(-0.45, -1.55, 0.05, 0.3), (0.4, -1.6, 0.05, 0.3)])),
	('PowerTiny', power_pile('PowerTiny', kettles=[(0.35, 0.3, 0.0, 1.0)], bells=[(-0.2, -0.55, 0.3, 0.62, 16, -6)],
		plates=[(-0.95, 0.1, 0.1, 0.8)])),
	('PowerSmall', power_pile('PowerSmall', kettles=[(-0.5, 0.45, 0.0, 0.95), (0.6, 0.55, 0.0, 0.8)],
		bells=[(0.0, -0.45, 0.3, 0.62, 10, -6), (0.05, -0.15, 0.82, 0.55, -14, 4)],
		plates=[(-1.2, -0.6, 0.1, 0.7), (1.2, -0.55, 0.1, 0.65)])),
	('PowerMedium', power_pile('PowerMedium', kettles=[(0.0, 0.85, 0.3, 1.0), (-1.0, 0.6, 0.0, 0.85), (1.0, 0.65, 0.0, 0.8)],
		bells=[(-0.5, -0.35, 0.3, 0.55, 14, -4), (0.55, -0.3, 0.3, 0.55, -12, -4), (0.0, -0.2, 0.85, 0.55, 4, -4)],
		plates=[(-1.35, -0.7, 0.1, 0.65), (1.35, -0.65, 0.1, 0.6), (0.0, -1.1, 0.1, 0.6)])),
	('PowerLarge', power_pile('PowerLarge', kettles=[(0.0, 0.85, 0.3, 1.05), (-1.1, 0.6, 0.0, 0.9), (1.1, 0.65, 0.0, 0.85)],
		bells=[(-0.65, -0.35, 0.3, 0.52, 14, -4), (0.65, -0.3, 0.3, 0.52, -12, -4), (0.0, -0.25, 0.85, 0.52, 4, -4),
		(-1.4, -0.75, 0.25, 0.52, 20, -4), (1.4, -0.7, 0.25, 0.52, -18, -4)],
		plates=[(-0.7, -1.2, 0.1, 0.55), (0.0, -1.3, 0.1, 0.55), (0.7, -1.2, 0.1, 0.55)])),
]

# (brief 22) PNG ids whose live fallback is the game's own part model (IconModels delegates to ShoeModels / BoxModels):
# the 22 shoes of World 1's boxes (Shoes.boxesForWorld(1): Street, Graffiti, Exclusive, Grail) and those 4 boxes.
EXTERNAL_SHOES = ['FreshCanvas', 'RedRocket', 'Checkmate', 'ChromeKicks', 'StreetAngel', 'BlockRoyalty',
	'SprayTag', 'DripTag', 'PaintSplash', 'NeonBomb', 'WildStyle', 'Masterpiece',
	'SilverStreak', 'MidnightChrome', 'RainbowDrip', 'Hologram', 'PlatinumWings',
	'GoldenHour', 'Starlight', 'SolarFlare', 'AstroCrown', 'TheGrail']
EXTERNAL_BOXES = ['Street', 'Graffiti', 'Exclusive', 'Grail']
# the other worlds' shoes and boxes (their PNGs are rendered too)
EXTERNAL_SHOES_MORE = ['IceCold', 'SnowDay', 'Flurry', 'Glacier', 'BlizzardKing', 'AbsoluteZero', 'Ember',
	'HotStep', 'MagmaCrack', 'Obsidian', 'Inferno', 'Phoenix', 'SlimeTime', 'GlowStick', 'Ooze', 'Reactor',
	'ToxicTitan', 'Mutant', 'Bubblegum', 'CottonCandy', 'Sprinkles', 'Gummy', 'SugarRush', 'CandyKingdom', 'Wave',
	'Coral', 'Tidal', 'Pearl', 'DeepSea', 'Atlantis', 'EmeraldKick', 'RubyRunner', 'Facet', 'DiamondStep',
	'CrystalCrown', 'PrismCore', 'NightSky', 'Comet', 'Nebula', 'Supernova', 'CosmicWings', 'BlackHole', 'GoldRush',
	'Royal', 'Monogram', 'TwentyFourKarat', 'KingsCrown', 'PlusOneInfinity']
EXTERNAL_BOXES_MORE = ['Frost', 'Lava', 'Toxic', 'Candy', 'Ocean', 'Gem', 'Galaxy', 'Gold']
# id -> (source module, approximate size in studs at scale 1, for M.viewport framing)
EXTERNAL = dict([('Shoe_' + i, ('ShoeModels', (1.5, 1.7, 1.9))) for i in EXTERNAL_SHOES + EXTERNAL_SHOES_MORE]
	+ [('Box_' + i, ('BoxModels', (4.6, 6.0, 3.6))) for i in EXTERNAL_BOXES + EXTERNAL_BOXES_MORE])

# Ids that reuse another model's live fallback (their PNGs differ; see icons_hd.py).
ALIASES = {
	'PowerPack1': 'Muscle',
	'PowerPack2': 'Muscle',
	'PowerPack3': 'Muscle',
	'DoubleCash': 'Cash',
}


def build_all():
	out = []
	for iid, fn in ICONS:
		m = fn()
		m.recentre()
		lo, hi = m.bounds()
		extent = max(hi[i] - lo[i] for i in range(3))
		if extent > FIT:
			m.unit = UNIT * FIT / extent  # keep the 2x2x2 stud contract
		m.meta.pop('muzzle', None)
		out.append(m)
	return out
