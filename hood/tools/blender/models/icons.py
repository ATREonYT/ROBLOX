"""The 9 HUD icons. Bold silhouettes that read at 64 px: one big shape, one accent colour, studs on top.

Icons face the camera at -z (Roblox Front), are centred on the origin and fit a 10 DU cube, which is
2 studs at the shared unit of 0.2 (the IconModels contract: fit in 2x2x2 at scale 1).
Remember when placing things: seen from the front, screen-right is world -x.
"""
import math

from boxkit import Model, euler, mat_mul, rot_y, rot_z
from models import guns

UNIT = 0.2
FIT = 10.0  # DU
# (brief 18) colours of the user's reference HUD icons
GIFT, GIFT_LID = (236, 64, 140), (252, 104, 172)
ARM, ARM_LIGHT, ARM_DARK = (255, 152, 30), (255, 196, 84), (226, 112, 18)
PARCHMENT, PARCHMENT_END, PARCHMENT_DARK = (246, 196, 150), (214, 132, 100), (180, 100, 74)


def shop():
	m = Model('Shop', 'Shop', UNIT, kind='icon')
	m.box((0, -0.9, 0), (6.6, 5.8, 3.4), 'blue', 'smooth', name='Bag')
	handle_feet = lambda x, z: abs(abs(x) - 1.9) < 0.75 and abs(z) < 0.8
	m.box((0, 2.3, 0), (6.9, 0.9, 3.7), 'bluedark', 'smooth', studs=True, skip=handle_feet, name='Rim')
	# Handle: two posts and a bar with chamfered corners.
	for sx in (-1, 1):
		m.box((sx * 1.9, 3.55, 0), (0.75, 1.7, 0.75), 'gold', 'gold', name='Handle')
		m.box((sx * 1.55, 4.55, 0), (1.05, 0.75, 0.7), 'gold', 'gold', rot=euler(0, 0, sx * -45), name='Handle')
	m.box((0, 4.82, 0), (2.4, 0.75, 0.75), 'gold', 'gold', name='Handle')
	# Big white "U" on the front, like the reference bag.
	for sx in (-1, 1):
		m.box((sx * 1.15, -0.55, -1.82), (0.75, 2.5, 0.3), 'white', 'smooth', bevel=0.02, name='U')
	m.box((0, -1.8, -1.86), (3.1, 0.75, 0.34), 'white', 'smooth', bevel=0.02, name='U')
	m.box((0, -3.9, 0), (6.7, 0.35, 3.5), 'bluedark', 'smooth', name='Base')
	return m


def rebirth():
	m = Model('Rebirth', 'Rebirth', UNIT, kind='icon')
	R, tube, depth = 3.3, 1.35, 1.7
	for (a0, a1, col, dark) in ((165, 25, 'red', 'reddark'), (345, 205, 'white', 'offwhite')):
		n = 9
		for k in range(n):
			ta = math.radians(a0 + (a1 - a0) * (k + 0.5) / n)
			step = abs(a1 - a0) / n
			seg = 2 * R * math.sin(math.radians(step / 2)) + 2 * (tube / 2) * math.tan(math.radians(step / 2)) + 0.04
			m.box((R * math.cos(ta), R * math.sin(ta), 0), (seg, tube, depth), col, 'smooth', rot=euler(0, 0, math.degrees(ta) + 90), studs=(1, 1) if k % 2 == 1 else False, bevel=0.0, name='Arc')
			depth = 1.7 if depth > 1.72 else 1.76  # alternate so neighbours never share a face plane
		# Arrowhead at the a1 end, pointing on round the circle.
		e = math.radians(a1)
		tip = (math.sin(e), -math.cos(e), 0)  # direction of travel for a decreasing angle
		radial = (math.cos(e), math.sin(e), 0)
		base = (R * math.cos(e) - tip[0] * 0.15, R * math.sin(e) - tip[1] * 0.15, 0)
		m.tri(base, tip, radial, 2.5, 3.9, 1.84, col, 'smooth', bevel=0.03, name='Arrow')
	return m


def rewards():
	m = Model('Rewards', 'Rewards', UNIT, kind='icon')
	# (brief 18: the reference's Playtime Reward gift: a pink box, a yellow-orange ribbon and bow)
	m.box((0, -1.7, 0), (6.4, 4.6, 5.6), GIFT, 'smooth', name='Box')
	ribbon = lambda x, z: abs(x) < 0.8 or abs(z) < 0.8
	m.box((0, 1.25, 0), (7.0, 1.4, 6.2), GIFT_LID, 'smooth', studs=True, skip=ribbon, name='Lid')
	# Gold ribbon: bands on the front and sides, a cross on the lid.
	m.box((0, -1.7, -2.86), (1.25, 4.64, 0.2), 'gold', 'gold', name='Ribbon')
	m.box((0, 1.25, -3.17), (1.3, 1.44, 0.22), 'gold', 'gold', name='Ribbon')
	for sx in (-1, 1):
		m.box((sx * 3.26, -1.7, 0), (0.2, 4.64, 1.25), 'gold', 'gold', name='Ribbon')
		m.box((sx * 3.56, 1.25, 0), (0.2, 1.44, 1.3), 'gold', 'gold', name='Ribbon')
	m.box((0, 2.0, 0), (1.26, 0.2, 6.29), 'gold', 'gold', name='Ribbon')
	m.box((0, 2.0, 0), (7.09, 0.24, 1.26), 'gold', 'gold', name='Ribbon')
	# Bow: two tilted loops and a knot.
	for sx in (-1, 1):
		m.box((sx * 1.35, 2.95, 0), (2.4, 1.5, 1.0), 'gold', 'gold', rot=euler(0, sx * 12, sx * 28), name='Bow')
		m.box((sx * 1.35, 2.95, -0.52), (1.1, 0.55, 0.12), 'golddark', 'gold', rot=euler(0, sx * 12, sx * 28), bevel=0.02, name='BowHole')
	m.box((0, 2.7, 0), (1.1, 1.1, 1.15), 'golddark', 'gold', name='Knot')
	return m


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


def evolve():
	m = Model('Evolve', 'Evolve', UNIT, kind='icon')
	depth = 2.8
	m.box((0, -2.3, 0), (3.6, 4.8, depth), 'green', 'smooth', name='Shaft')
	m.tri((0, 0.0, 0), (0, 1, 0), (1, 0, 0), 4.9, 8.8, depth, 'green', 'smooth', name='Head')
	# Lighter face panels give the arrow a bevelled, toy-like front.
	m.box((0, -2.1, -1.45), (2.4, 3.9, 0.2), 'cashlight', 'smooth', bevel=0.04, name='Shine')
	m.tri((0, 0.55, -1.45), (0, 1, 0), (1, 0, 0), 3.4, 6.1, 0.2, 'cashlight', 'smooth', bevel=0.03, name='Shine')
	m.box((0, -4.85, 0), (3.9, 0.4, 3.1), 'greendark', 'smooth', name='Foot')
	return m


def cash():
	m = Model('Cash', 'Cash', UNIT, kind='icon')
	band = lambda x, z: abs(x) < 0.9
	with m.at((0.6, 0, 0.6), euler(-28, 0, 0)):
		for i, (ry, dx) in enumerate(((-7, 0.3), (5, -0.25), (-2, 0.0))):
			y = -1.2 + i * 0.62
			top = i == 2
			m.box((dx, y, 0), (7.2, 0.6, 3.8), 'cash', 'smooth', rot=euler(0, ry, 0), studs=top, skip=band, name='Bill')
			m.box((dx, y, 0), (7.25, 0.22, 3.85), 'cashdark', 'smooth', rot=euler(0, ry, 0), bevel=0.02, name='BillEdge')
		m.box((0, -0.55, 0), (1.3, 2.05, 3.95), 'offwhite', 'smooth', rot=euler(0, -2, 0), name='Band')
	# Gold coin standing in front at the right, turned a little so its rim shows.
	with m.at((-2.6, -0.9, -2.2), euler(-6, 24, -8)):
		m.cyl((0, 0, 0), 0.9, 4.4, 'gold', 'gold', axis='z', name='Coin')
		m.cyl((0, 0, -0.46), 0.12, 3.5, 'golddark', 'gold', axis='z', bevel=0.02, name='CoinFace')
		# "$" (screen-left is +x): top bar, upper-left post, middle bar, lower-right post, bottom bar.
		for y in (0.85, 0.0, -0.85):
			m.box((0, y, -0.6), (1.4, 0.38, 0.2), 'gold', 'gold', bevel=0.03, name='Dollar')
		m.box((0.52, 0.43, -0.6), (0.38, 0.85, 0.24), 'gold', 'gold', bevel=0.03, name='Dollar')
		m.box((-0.52, -0.43, -0.6), (0.38, 0.85, 0.24), 'gold', 'gold', bevel=0.03, name='Dollar')
		m.box((0, 0, -0.62), (0.28, 2.6, 0.3), 'gold', 'gold', bevel=0.03, name='Dollar')
	return m


def power():
	m = Model('Power', 'Power', UNIT, kind='icon')
	# Boxing glove in profile: knuckles to screen-left (+x), outer side facing the camera.
	with m.at((0, 0, 0), euler(8, -22, 18)):
		m.box((0, 0.8, 0), (5.0, 4.6, 3.6), 'red', 'smooth', name='Mitt')
		m.box((-0.3, 3.45, 0), (3.6, 0.8, 3.2), 'red', 'smooth', studs=True, name='MittTop')
		m.box((2.85, 0.6, 0), (0.8, 3.4, 3.2), 'red', 'smooth', name='MittFront')
		m.box((-2.75, 0.9, 0), (0.6, 3.6, 3.2), 'red', 'smooth', name='MittBack')
		m.box((2.15, 2.75, 0), (1.5, 1.5, 3.1), 'red', 'smooth', rot=euler(0, 0, 45), name='MittCorner')
		m.box((-2.15, 2.85, 0), (1.3, 1.3, 3.1), 'red', 'smooth', rot=euler(0, 0, 45), name='MittCorner')
		m.box((2.2, -1.25, 0), (1.3, 1.3, 3.1), 'red', 'smooth', rot=euler(0, 0, 45), name='MittCorner')
		# Thumb: a raised bulge on the near side running toward the knuckles.
		m.box((1.0, -0.55, -2.0), (3.2, 1.35, 0.9), 'red', 'smooth', rot=euler(0, 0, 14), name='Thumb')
		m.box((2.5, -0.15, -1.85), (0.9, 1.25, 0.9), 'red', 'smooth', rot=euler(0, 0, 14), name='ThumbTip')
		m.box((-0.6, 1.85, -1.85), (2.6, 0.4, 0.14), 'white', 'smooth', bevel=0.03, name='Stripe')
		m.box((-0.8, -2.6, 0), (3.6, 2.4, 3.3), 'white', 'smooth', name='Cuff')
		m.box((-0.8, -1.6, 0), (3.7, 0.45, 3.4), 'reddark', 'smooth', name='CuffBand')
		m.box((-0.8, -3.6, 0), (3.7, 0.45, 3.4), 'reddark', 'smooth', name='CuffBand')
	return m


def trophy():
	m = Model('Trophy', 'Trophy', UNIT, kind='icon')
	m.prism((0, 1.5, 0), 2.6, 4.8, 'gold', 'gold', sides=8, axis='y', spin=22.5, name='Cup')
	m.prism((0, 3.05, 0), 0.6, 5.4, 'gold', 'gold', sides=8, axis='y', spin=22.5, name='Rim')
	m.prism((0, 3.32, 0), 0.08, 4.5, 'golddark', 'gold', sides=8, axis='y', spin=22.5, bevel=0.0, name='Inside')
	m.prism((0, -0.25, 0), 1.0, 3.4, 'gold', 'gold', sides=8, axis='y', spin=22.5, name='Bowl')
	m.cyl((0, -1.35, 0), 1.4, 1.1, 'golddark', 'gold', axis='y', name='Stem')
	for sx in (-1, 1):
		m.box((sx * 2.95, 2.5, 0), (1.4, 0.55, 0.7), 'gold', 'gold', name='Handle')
		m.box((sx * 3.45, 1.5, 0), (0.55, 2.4, 0.76), 'gold', 'gold', name='Handle')
		m.box((sx * 2.85, 0.5, 0), (1.3, 0.55, 0.7), 'gold', 'gold', name='Handle')
	m.box((0, 1.5, -2.45), (1.25, 1.25, 0.45), 'red', 'glass', rot=euler(0, 0, 45), name='Gem')
	stem = lambda x, z: abs(x) < 0.8 and abs(z) < 0.8
	m.box((0, -2.4, 0), (3.6, 0.7, 3.0), 'gold', 'gold', studs=True, skip=stem, name='Foot')
	m.box((0, -3.5, 0), (4.8, 1.5, 3.8), 'wooddark', 'smooth', name='Plinth')
	m.box((0, -3.5, -1.92), (2.6, 0.7, 0.12), 'gold', 'gold', bevel=0.02, name='Plate')
	return m


def gun():
	m = Model('Gun', 'Gun', UNIT, kind='icon')
	with m.at((0, 0, 0), mat_mul(rot_z(-14), rot_y(90))):
		guns.pistol(slide='chrome', frame='gun', grip='wood', rust=False, into=m)
	m.meta['view'] = (-0.25, 0.22, -1.0)
	return m


def muscle():
	"""The reference's Power icon: a flexed arm, the fist up at screen-left, the bicep bulging at screen-right."""
	m = Model('Muscle', 'Muscle', UNIT, kind='icon')
	# (screen-right is world -x) the upper arm along the bottom from the elbow (screen-left) to the shoulder
	m.cyl((-0.6, -2.5, 0), 6.0, 2.9, ARM, 'smooth', axis='x', name='UpperArm')
	m.ball((-3.6, -2.5, 0), 2.9, ARM, 'smooth', name='Shoulder')
	m.ball((2.4, -2.5, 0), 3.0, ARM_DARK, 'smooth', name='Elbow')
	# the bicep: a big ball bulging up over the upper arm, a lighter one for its shine
	m.ball((-1.3, -1.1, 0.05), 4.3, ARM, 'smooth', name='Bicep')
	m.ball((-1.7, -0.5, -0.9), 2.1, ARM_LIGHT, 'smooth', name='BicepShine')
	# the forearm standing up from the elbow, leaning a little toward the bicep
	with m.at((2.25, 0.2, 0), euler(0, 0, -8)):
		m.cyl((0, 0, 0), 5.0, 2.7, ARM, 'smooth', axis='y', name='Forearm')
	# the fist on top: a round back of the hand and the knuckles facing the bicep
	m.ball((2.0, 3.3, 0.1), 3.7, ARM, 'smooth', name='Fist')
	m.ball((0.75, 3.15, 0.0), 2.7, ARM, 'smooth', name='Knuckles')
	m.box((0.95, 2.05, -0.55), (2.6, 0.55, 1.9), ARM_DARK, 'smooth', rot=euler(0, 0, 10), name='Thumb')
	m.ball((2.3, 4.1, -0.9), 1.4, ARM_LIGHT, 'smooth', name='FistShine')
	return m


def basket(iid, body=(255, 150, 28), light=(255, 200, 70), dark=(222, 108, 14), handle=(120, 150, 184)):
	"""The reference's Store basket: a tapered tub with a studded rim and a steel handle arching over it."""
	def build():
		m = Model(iid, iid, UNIT, kind='icon')
		m.box((0, -2.2, 0), (5.6, 2.6, 4.2), dark, 'smooth', name='Bottom')
		m.box((0, -0.3, 0), (6.6, 2.2, 4.9), body, 'smooth', name='Tub')
		m.box((0, 1.1, 0), (7.4, 0.9, 5.5), light, 'smooth', studs=True, skip=lambda x, z: abs(z) < 1.2 and abs(x) < 2.6, name='Rim')
		m.box((0, 1.12, 0), (5.2, 0.95, 3.4), dark, 'smooth', name='Inside')
		# square holes on the front, like the reference's basket weave
		for i, x in enumerate((-2.0, 0.0, 2.0)):
			for y in (-0.5, -2.1):
				m.box((x, y, -2.47 if y > -1 else -2.12), (1.1, 0.9, 0.12), light, 'smooth', bevel=0.02, name='Hole')
		# the handle: two posts and a bar over the top
		for sx in (-1, 1):
			m.box((sx * 2.6, 2.8, 0), (0.7, 3.0, 0.7), handle, 'metal', name='Handle')
		m.box((0, 4.35, 0), (6.04, 0.7, 0.72), handle, 'metal', name='Handle')
		return m
	return build


def quest():
	"""The reference's Quest scroll: a rolled parchment lying across, tied with a red band."""
	m = Model('Quest', 'Quest', UNIT, kind='icon')
	with m.at((0, 0, 0), euler(0, 0, 32)):
		m.cyl((0, 0, 0), 7.8, 3.4, PARCHMENT, 'smooth', axis='x', name='Roll')
		m.cyl((-3.95, 0, 0), 0.2, 3.0, PARCHMENT_END, 'smooth', axis='x', bevel=0.02, name='End')
		m.cyl((-4.06, 0, 0), 0.1, 1.6, PARCHMENT_DARK, 'smooth', axis='x', bevel=0.0, name='Core')
		m.cyl((3.95, 0, 0), 0.2, 3.0, PARCHMENT_END, 'smooth', axis='x', bevel=0.02, name='End')
		m.cyl((0.4, 0, 0), 1.6, 3.6, 'red', 'smooth', axis='x', name='Band')
		m.box((0.4, 0, -1.85), (1.0, 1.0, 0.2), 'reddark', 'smooth', bevel=0.02, name='Knot')
		# the loose sheet curling out of the roll
		m.box((-1.6, -1.95, -0.6), (4.2, 0.35, 2.2), PARCHMENT, 'smooth', rot=euler(0, 0, -6), name='Sheet')
	# ribbon tails hanging from the band
	m.box((0.9, -2.1, -1.4), (0.7, 2.0, 0.25), 'red', 'smooth', rot=euler(0, 0, 18), name='Tail')
	m.box((0.1, -2.3, -1.45), (0.7, 2.2, 0.25), 'reddark', 'smooth', rot=euler(0, 0, -12), name='Tail')
	return m


ICONS = [
	('Shop', shop),
	('Rebirth', rebirth),
	('Rewards', rewards),
	('PVP', pvp),
	('Evolve', evolve),
	('Cash', cash),
	('Power', power),
	('Trophy', trophy),
	('Gun', gun),
	('Muscle', muscle),
	('Basket', basket('Basket')),
	('BasketRed', basket('BasketRed', body=(232, 52, 80), light=(255, 110, 130), dark=(186, 30, 58), handle=(170, 180, 196))),
	('Quest', quest),
]


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
