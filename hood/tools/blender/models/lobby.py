"""Brief 30 (B30 LOBBY): the lobby's product-stand items, the 3D things that turn over each stand's pedestal like the
reference game's in-world sells (the soldier game's limited-item pedestals: a big 3D item floating over a round
pedestal, its name and an "ONLY <price>" floating over it).

Same kit and look as the guns, icons and props (chunky toy proportions, one main colour per model, smooth plastic).
Axes are Roblox axes: x right, y up, front toward -z. Every item is centred on the origin (it turns about its own
middle) and fits a 10 DU cube, which is 3.6 studs at this module's unit (0.36): the stands build them at scale 1.
Several reuse the HUD icons' BoxKit twins (models/icons.py), so a stand shows the same thing as its Store card.
  StandCrown      VIP: a gold crown with a ruby and two sapphires (icons.vip2)
  StandDumbbell   2x Power: a gold dumbbell with octagon plates (icons.dumbbell)
  StandCash       2x Cash: a stack of bills under a band, a gold coin (icons.cash2)
  StandCrosshair  Auto Fight: a red coin with a white crosshair (icons.autofight)
  StandSneaker    +1 Shoe Slot: the red high-top (icons.sneaker)
  StandClover     Lucky: a four-leaf clover on a stem, a gold stud in the middle
  StandBoxes      Triple Open: three shoe boxes stacked two-and-one, orange, pink, blue
  StandTarget     Pro Bay: a teal bullseye with three rings on a short post, a "x100" pip of three studs
  StandTargetGold Gold Bay: a gold bullseye with a little crown on top
  StandGift       Group reward / daily rewards: the pink present with an orange ribbon (icons.rewards2)
  StandSkull      the World Boss stand's emblem (icons.skull)
"""
import math

from boxkit import Model, euler
from models import icons

UNIT = 0.36  # 10 DU = 3.6 studs
FIT = 10.0


def _from_icon(fn, iid, name):
	m = fn()
	m.id, m.name, m.unit, m.kind = iid, name, UNIT, 'prop'
	return m


def crown():
	return _from_icon(icons.vip2, 'StandCrown', 'VIP Crown')


def dumbbell():
	return _from_icon(icons.dumbbell, 'StandDumbbell', 'Gold Dumbbell')


def cash():
	return _from_icon(icons.cash2, 'StandCash', 'Cash Stack')


def crosshair():
	return _from_icon(icons.autofight, 'StandCrosshair', 'Crosshair Coin')


def sneaker():
	return _from_icon(icons.sneaker, 'StandSneaker', 'Red Sneaker')


def gift():
	return _from_icon(icons.rewards2, 'StandGift', 'Present')


def skull():
	return _from_icon(icons.skull, 'StandSkull', 'Skull')


def clover():
	"""A four-leaf clover facing -z: four round-ended leaves (a square body and a disc each) round a gold stud."""
	m = Model('StandClover', 'Four-Leaf Clover', UNIT, kind='prop')
	leaf, dark, light = (52, 196, 84), (30, 150, 62), (120, 232, 120)
	for k in range(4):
		a = 45 + 90 * k
		ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
		with m.at((ca * (2.1 + 0.04 * k), sa * (2.1 + 0.04 * k) + 0.6, 0), euler(0, 0, a - 45)):
			m.box((0, 0, 0), (3.0, 3.0, 1.2 + 0.05 * k), leaf, 'smooth', name='Leaf')
			m.cyl((0.9, 0.9, 0.02), 1.22, 2.6, leaf, 'smooth', axis='z', name='LeafLobe')
			m.box((0.1, 0.1, -0.66), (1.6, 0.36, 0.14), light, 'smooth', rot=euler(0, 0, 45), name='Vein')
	m.cyl((0, 0.6, -0.1), 1.6, 1.8, (255, 204, 48), 'smooth', axis='z', name='Middle')
	m.cyl((0, 0.6, -0.95), 0.2, 1.0, (255, 236, 140), 'smooth', axis='z', name='MiddleShine')
	with m.at((0.5, -3.0, 0.05), euler(0, 0, -16)):
		m.box((0, 0, 0), (0.8, 3.6, 0.8), dark, 'smooth', name='Stem')
	return m


def _mini_box(m, at, body, lid, emblem, s=1.0, yaw=0.0):
	with m.at(at, euler(0, yaw, 0)):
		m.box((0, -0.55 * s, 0), (4.4 * s, 2.1 * s, 2.9 * s), body, 'smooth', name='Box')
		m.box((0, 0.78 * s, 0), (4.62 * s, 0.62 * s, 3.12 * s), lid, 'smooth', name='Lid')
		m.box((0, -0.6 * s, -1.47 * s), (2.3 * s, 0.85 * s, 0.1 * s), emblem, 'smooth', name='Emblem')


def boxes():
	"""Triple Open: three shoe boxes, two side by side and one on top, each a body, a deeper lid and a pale emblem."""
	m = Model('StandBoxes', 'Three Shoe Boxes', UNIT, kind='prop')
	_mini_box(m, (2.5, -1.6, 0.1), (255, 140, 30), (240, 100, 26), (255, 236, 200), yaw=4)
	_mini_box(m, (-2.5, -1.64, -0.1), (236, 70, 150), (214, 46, 128), (255, 220, 240), yaw=-5)
	_mini_box(m, (0.1, 1.15, 0.02), (50, 150, 255), (30, 110, 230), (220, 240, 255), yaw=-8)
	return m


def _target(m, rings, post):
	"""A bullseye disc facing -z, rings from the outside in, on a short post under it."""
	d = 8.4
	for k, col in enumerate(rings):
		# (every ring a little thicker than the one round it, both faces proud: no shared plane, a bullseye both ways round)
		m.cyl((0, 0.7, 0), 1.0 + 0.12 * k, d - 1.8 * k, col, 'smooth', axis='z', name='Ring')
	m.box((0, -3.95, 0.3), (0.9, 1.5, 0.9), post, 'smooth', name='Post')
	m.box((0, -4.55, 0.3), (3.0, 0.5, 1.6), post, 'smooth', name='Foot')


def target():
	m = Model('StandTarget', 'Pro Target', UNIT, kind='prop')
	_target(m, [(20, 120, 130), (240, 250, 250), (36, 200, 200), (240, 250, 250), (255, 70, 90)], (40, 60, 80))
	return m


def target_gold():
	m = Model('StandTargetGold', 'Gold Target', UNIT, kind='prop')
	_target(m, [(214, 140, 20), (255, 248, 220), (255, 200, 40), (255, 248, 220), (230, 40, 60)], (150, 96, 20))
	# a little crown over the disc
	gold = (255, 200, 40)
	m.box((0, 5.3, 0.2), (3.6, 0.8, 1.0), gold, 'smooth', name='CrownBand')
	for x in (-1.3, 0.0, 1.3):
		m.tri((x, 5.7, 0.2), (0, 1, 0), (1, 0, 0), 1.3 if x == 0 else 1.0, 1.1, 0.9, gold, 'smooth', name='CrownPoint')
	return m


ITEMS = [crown, dumbbell, cash, crosshair, sneaker, clover, boxes, target, target_gold, gift, skull]


def build_all():
	out = []
	for fn in ITEMS:
		m = fn()
		m.recentre()
		lo, hi = m.bounds()
		extent = max(hi[i] - lo[i] for i in range(3))
		if extent > FIT:
			m.unit = UNIT * FIT / extent  # keep the 3.6-stud contract
		m.meta.pop('muzzle', None)
		out.append(m)
	return out
