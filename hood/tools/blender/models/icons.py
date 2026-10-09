"""The HUD icons as BoxKit part models: the live fallbacks Studio shows until the PNGs (icons_hd.py) are uploaded.
Each one copies its PNG twin's shape and colours in chunky smooth plastic.

Icons face the camera at -z (Roblox Front), are centred on the origin and fit a 10 DU cube, which is
2 studs at the shared unit of 0.2 (the IconModels contract: fit in 2x2x2 at scale 1).
Remember when placing things: seen from the front, screen-right is world -x.
"""
import math

from boxkit import Model, euler, mat_mul, rot_y, rot_z
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
	"""The reference's Rebirth mark: a hollow ring of two thick arrows, `top` colour over the top with its head at
	~1-2 o'clock, white underneath with its head at ~7-8 o'clock (each head covers the other arrow's tail)."""
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		r_in, r_out = 1.9, 4.4
		mid, w = (r_in + r_out) / 2, r_out - r_in

		def arc(a0, a1, col, n, z):
			step = (a1 - a0) / n
			for k in range(n):
				ts = a0 + step * (k + 0.5)
				x, y = _screen(ts, mid)
				seg = 2 * r_out * math.sin(math.radians(abs(step) / 2)) + 0.12
				m.box((x, y, z + 0.03 * (k % 3)), (seg, w, 1.8 + 0.02 * (k % 2)), col, 'smooth', rot=euler(0, 0, 90 - ts), name='Arc')

		def head(ah, col, z):
			# an arrowhead slab: base across the band at ah (a barb outside, a tab in the hole), tip running clockwise
			bx, by = _screen(ah, mid + 0.2)
			a = math.radians(ah)
			tang = (-math.sin(a), -math.cos(a))  # clockwise travel, in world axes (screen-right is -x)
			inward = (math.cos(a), -math.sin(a))
			c, s_ = math.cos(math.radians(18)), math.sin(math.radians(18))
			tip = (tang[0] * c + inward[0] * s_, tang[1] * c + inward[1] * s_)
			side = (-math.cos(a), math.sin(a))
			m.tri((bx, by, z), (tip[0], tip[1], 0), (side[0], side[1], 0), 2.9, w + 1.3, 1.9, col, 'smooth', name='Head')

		arc(217, 45, top, 9, 0.0)
		arc(40, -135, REB_WHITE, 9, 0.1)
		head(45, top, -0.12)
		head(-135, REB_WHITE, -0.1)
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


def basket2(iid, body, inside, handle, rim, holes=None):
	"""The Store basket: a tub widening toward the top (three steps), a lighter rim and inside, a steel handle leaning
	back; holes = the dark squares of the red basket."""
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		with m.at((0, 0, 0), euler(-22, 0, 0)):  # top tipped toward the camera so the light inside shows, like the PNG
			_basket_parts(m, body, inside, handle, rim, holes)
		return m
	return build


def _basket_parts(m, body, inside, handle, rim, holes):
	"""The basket's parts in its own frame (basket2 tips the whole thing toward the camera)."""
	m.box((0, -2.55, 0), (5.0, 1.3, 3.5), body, 'smooth', name='Tub')
	m.box((0, -1.3, 0), (5.8, 1.32, 4.0), body, 'smooth', name='Tub')
	m.box((0, -0.02, 0), (6.6, 1.36, 4.5), body, 'smooth', name='Tub')
	m.box((0, 0.9, 0), (7.2, 0.62, 5.0), rim, 'smooth', name='Rim')
	m.box((0, 0.88, 0), (6.0, 0.5, 3.9), inside, 'smooth', name='Inside')
	if holes:
		for (y, half, zf) in ((-0.02, 3.3, -2.25), (-1.3, 2.9, -2.0)):
			for x in (-2.2, -0.73, 0.73, 2.2):
				if abs(x) < half - 0.3:
					m.box((x, y, zf - 0.07), (1.0, 0.82, 0.14), holes, 'smooth', name='Hole')
	with m.at((0, 1.0, 0.4), euler(-24, 0, 0)):
		for sx in (-1, 1):
			m.box((sx * 2.95, 1.1, 0), (0.62, 2.4, 0.62), handle, 'smooth', name='Handle')
		m.box((0, 2.5, 0), (6.62, 0.62, 0.64), handle, 'smooth', name='Handle')


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


ICONS = [
	('Shop', basket2('Shop', (252, 146, 28), (255, 208, 96), (130, 162, 200), (255, 190, 70))),
	('Rebirth', rebirth2('Rebirth', REB_RED)),
	('Rewards', rewards2),
	('PVP', pvp),
	('Evolve', evolve2('Evolve')),
	('Cash', cash2),
	('Power', arm_live('Power')),
	('Trophy', trophy2),
	('Gun', gun),
	('Muscle', arm_live('Muscle')),
	('Basket', basket2('Basket', (252, 146, 28), (255, 208, 96), (130, 162, 200), (255, 190, 70))),
	('BasketRed', basket2('BasketRed', (226, 32, 78), (242, 90, 130), (176, 188, 206), (246, 110, 146), holes=(130, 4, 40))),
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
]

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
