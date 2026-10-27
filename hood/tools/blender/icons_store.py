"""The Exclusive Shop's glossy icons (brief 30, SHOP): the reference's cash bundles with orange bands, brown $ sacks, a
treasure chest, a heaped gold pile, a studded Lego clover and an "x2" bolt, in the icons_hd look (glossy plastic, light
ramp, dark outline) with a THINNER outline in the picture's own dark colour, like the reference (its outlines are ~half
the weight of the HUD icons').

Usage (Blender as a Python module, see README):
  blenv/bin/python hood/tools/blender/icons_store.py [ids...] [--res 512] [--ss 2] [--samples 40] [--out DIR] [--list]
Default output: hood/art/icons3d/<Id>.png. Ids that replace an existing icon (CashTiny..CashLarge, Lucky, DoubleCash) keep
their id: upload the new PNG with tools/upload_assets.py and the Store shows it; until then the old upload stays.
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import icons_hd as H  # noqa: E402  (registers nothing here; gives the helpers and render_icon)
import hdkit as K  # noqa: E402
from hdkit import ball, cyl, mat, rbox, slab, text, tube  # noqa: E402

ICONS = H.ICONS  # (render_icon reads this registry)
INK = (8, 52, 20)  # dark green outline for the cash art
OUTLINE = 0.55
GOLD = (252, 176, 24)
GOLD_L, GOLD_D = (255, 232, 120), (214, 112, 14)
BAND, BAND_L, BAND_D = (255, 150, 24), (255, 206, 80), (206, 92, 8)
CASH_VIEW = (-0.3, -1.0, 0.5)


def icon(iid, view=CASH_VIEW, fill=0.86, lens=85.0, roll=0.0, **opts):
	opts.setdefault('ink', INK)
	opts.setdefault('outline', OUTLINE)
	opts.setdefault('inner', 0.6)
	return H.icon(iid, view=view, fill=fill, lens=lens, roll=roll, **opts)


def bundle(at=(0, 0, 0), rz=0.0, n=4, s=1.0):
	"""A stack of n bills tied with an orange band (the reference's cash): the top bill has the seal and the $."""
	g = K.C.new_group()
	bill = mat((92, 206, 76), tiles=0.4, tile_rgb=(156, 240, 120), density=3.0, light=(176, 248, 140), dark=(40, 144, 56))
	edge = mat((44, 150, 60), light=(96, 200, 90))
	x0, y0, z0 = at
	for k in range(n):
		rbox((x0 + (k % 2) * 0.04 * s, y0, z0 + k * 0.14 * s), (2.0 * s, 1.04 * s, 0.11 * s), 0.04 * s, bill if k == n - 1 else edge, rot=(0, 0, rz + (k - n / 2) * 2.5), group=g, name='Bill')
	top = z0 + (n - 1) * 0.14 * s + 0.06 * s
	ball((x0 - 0.3 * s, y0, top), (0.4 * s, 0.32 * s, 0.04 * s), mat((52, 160, 66), light=(90, 196, 92)), rot=(0, 0, rz), group=g, name='Seal')
	text('$', mat((236, 255, 220), light=(255, 255, 255)), loc=(x0 - 0.3 * s, y0, top + 0.02 * s), size=0.55 * s, depth=0.03 * s, rot=(0, 0, rz), bev=0.012 * s, group=g, name='Dollar')
	rbox((x0 + 0.42 * s, y0, z0 + (n - 1) * 0.07 * s), (0.36 * s, 1.1 * s, ((n - 1) * 0.14 + 0.2) * s), 0.04 * s, mat(BAND, light=BAND_L, dark=BAND_D), rot=(0, 0, rz), group=g, name='Band')


def gold_coin(at, tilt=0.0, rz=0.0, r=0.34, group=None, dollar=True):
	return H.coin(at, (tilt, 0, rz), r=r, dollar=dollar, flat_face=True, group=group)


def coin_pile(at, rows=3):
	"""A heaped mound of gold coins, rows x (rows..1), lying flat and a little tilted."""
	g = K.C.new_group()
	x0, y0, z0 = at
	for row in range(rows):
		n = rows - row
		for k in range(n):
			gold_coin((x0 + (k - (n - 1) / 2) * 0.62, y0 + 0.05 * row, z0 + row * 0.14), tilt=(-6, 5, 0)[(k + row) % 3], rz=(k * 47 + row * 31) % 90, r=0.32, group=g, dollar=(k + row) % 2 == 0)


def brown_bag(at=(0, 0, 0), s=1.0, rz=0.0):
	"""A tan-brown sack tied with a gold cord and a big green $ (the reference's Small Pack bag)."""
	g = K.C.new_group()
	sack = mat((200, 132, 62), tiles=0.35, tile_rgb=(236, 184, 108), density=3.0, dark=(122, 70, 28), light=(240, 190, 116))
	x, y, z = at
	ball((x, y, z + 0.62 * s), (0.8 * s, 0.7 * s, 0.7 * s), sack, rot=(0, 0, rz), group=g, name='Sack')
	K.lathe([(0.2 * s, 0), (0.16 * s, 0.12 * s), (0.22 * s, 0.24 * s), (0.4 * s, 0.44 * s), (0.34 * s, 0.54 * s), (0, 0.56 * s)], sack, loc=(x, y, z + 1.2 * s), group=g, name='Neck')
	cyl((x, y, z + 1.24 * s), 0.26 * s, 0.11 * s, mat(GOLD, light=GOLD_L, dark=GOLD_D), r=0.035 * s, group=g, name='Cord')
	text('$', mat((70, 200, 70), light=(150, 240, 120), dark=(30, 130, 40)), loc=(x, y - 0.68 * s, z + 0.58 * s), size=0.9 * s, depth=0.08 * s, rot=(90, 0, rz), bev=0.025 * s, group=g, name='BagDollar')


def gem(at, col=(70, 170, 255), s=0.3, rz=20.0):
	rbox(at, (s, s, s), s * 0.12, mat(col, light=(190, 232, 255), dark=(20, 80, 200), coat=0.6, spec=0.8), rot=(40, 0, rz + 45), group=K.C.new_group(), name='Gem')


@icon('CashTiny', fill=0.84)
def cash_tiny():
	bundle((0.0, 0.0, 0.0), rz=-8, n=5, s=1.15)
	gold_coin((0.95, -0.85, 0.06), tilt=-8, rz=20, r=0.38)


@icon('CashSmall', fill=0.86)
def cash_small():
	brown_bag((0.35, 0.5, 0.0), 1.2)
	bundle((-0.85, -0.05, 0.0), rz=10, n=5)
	coin_pile((0.9, -0.95, 0.04), rows=2)
	gold_coin((0.1, -1.1, 0.05), tilt=6, rz=30, r=0.34)


@icon('CashMedium', fill=0.88, sparkles=3, seed=21)
def cash_medium():
	"""A treasure chest, lid open, brimming with cash, coins and gems."""
	g = K.C.new_group()
	wood = mat((170, 96, 44), tiles=0.3, tile_rgb=(206, 132, 70), density=2.5, dark=(104, 54, 22), light=(224, 150, 84))
	gold = mat(GOLD, light=GOLD_L, dark=GOLD_D, coat=0.5)
	rbox((0, 0.3, 0.45), (3.0, 1.7, 0.9), 0.1, wood, group=g, name='Chest')
	for x in (-1.2, 1.2):
		rbox((x, 0.3, 0.46), (0.3, 1.78, 0.96), 0.06, gold, group=K.C.new_group(), name='Strap')
	rbox((0, 0.3, 0.9), (3.04, 1.74, 0.14), 0.05, gold, group=K.C.new_group(), name='Rim')
	rbox((0, -0.55, 0.52), (0.42, 0.14, 0.5), 0.05, gold, group=K.C.new_group(), name='Lock')
	rbox((0, 1.25, 1.4), (3.0, 0.4, 1.3), 0.1, wood, rot=(-12, 0, 0), group=K.C.new_group(), name='Lid')
	bundle((-0.55, 0.3, 0.95), rz=6, n=3, s=0.8)
	bundle((0.6, 0.35, 0.95), rz=-8, n=3, s=0.8)
	coin_pile((0.0, -0.25, 1.0), rows=3)
	for k, (x, y) in enumerate(((-1.0, 0.0), (0.95, -0.2), (0.3, 0.55))):
		gem((x, y, 1.18), col=((70, 170, 255), (255, 80, 130), (110, 230, 150))[k], rz=20 * k)


@icon('CashLarge', fill=0.84, sparkles=5, seed=23, glow=((1.0, 0.85, 0.3), 0.3))
def cash_large():
	"""The Mega pile: heaped gold coins, sacks and bundles, up to the top."""
	brown_bag((-1.15, 0.9, 0.0), 1.2)
	brown_bag((1.15, 0.95, 0.0), 1.1, rz=-10)
	brown_bag((0.0, 1.25, 0.35), 1.35)
	bundle((-1.35, -0.35, 0.0), rz=14, n=4, s=0.9)
	bundle((1.35, -0.35, 0.0), rz=-14, n=4, s=0.9)
	bundle((0.0, -0.1, 0.5), rz=2, n=4, s=0.95)
	coin_pile((0.0, -0.95, 0.04), rows=4)
	gold_coin((-1.45, -1.25, 0.05), tilt=8, rz=30, r=0.34)
	gold_coin((1.5, -1.2, 0.05), tilt=-8, rz=60, r=0.34)


def heart(k=0.06, n=64):
	pts = []
	for i in range(n):
		t = 2 * math.pi * i / n
		x = 16 * math.sin(t) ** 3
		z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
		pts.append((x * k, (z + 17) * k))  # tip at the origin, lobes up
	return pts


def inside(pt, poly):
	x, z = pt
	c = False
	j = len(poly) - 1
	for i in range(len(poly)):
		xi, zi = poly[i]
		xj, zj = poly[j]
		if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
			c = not c
		j = i
	return c


@icon('Lucky', view=(-0.08, -1.0, 0.3), fill=0.86, sparkles=3, seed=5)
def lucky():
	"""A studded Lego clover: four heart lobes meeting in the middle, a stem, studs on every lobe."""
	leaf = mat((74, 206, 62), tiles=0.0, light=(180, 246, 110), dark=(24, 128, 48), coat=0.45)
	stud = mat((96, 224, 76), light=(196, 250, 130), dark=(36, 150, 54), coat=0.45)
	base = heart(0.056)
	for i, ang in enumerate((45, 135, 225, 315)):
		phi = math.radians(ang - 90)  # rotate the upright heart so its lobes point along `ang`
		c, s = math.cos(phi), math.sin(phi)
		rot = lambda p: (p[0] * c - p[1] * s, p[0] * s + p[1] * c)  # noqa: E731
		depth = 0.5 if i % 2 == 0 else 0.44
		g = K.C.new_group()
		slab([rot(p) for p in base], depth, leaf, loc=(0.0, 0.0, 0.0), r=0.09, seg=5, group=g, name='Lobe', y0=-depth / 2 + (0.0 if i % 2 == 0 else 0.03))
		shrunk = [(p[0] * 0.78, p[1] * 0.78 + 0.2) for p in base]
		step = 0.36
		for gx in range(-4, 5):
			for gz in range(0, 7):
				p = (gx * step, 0.3 + gz * step)
				if inside(p, shrunk):
					q = rot(p)
					cyl((q[0], -depth / 2 - 0.03 + (0.0 if i % 2 == 0 else 0.03), q[1]), 0.115, 0.1, stud, rot=(90, 0, 0), r=0.025, group=g, name='Stud', segs=24)
	tube([(0.0, 0.12, -0.9), (0.05, 0.12, -1.3), (0.4, 0.12, -1.7), (0.62, 0.12, -2.05)], 0.13, leaf, group=K.C.new_group(), name='Stem')


@icon('DoubleCash', fill=0.88, sparkles=3, seed=7)
def double_cash():
	bundle((-0.35, 0.5, 0.0), rz=8, n=5, s=1.0)
	bundle((0.3, -0.2, 0.0), rz=-8, n=4, s=1.0)
	text('x2', mat((255, 196, 40), light=(255, 246, 150), dark=(226, 110, 12), coat=0.5), loc=(0.55, -1.0, 0.5), size=1.2, depth=0.3, rot=(70, 0, 0), bev=0.04, group=K.C.new_group(), name='X2')



# ------------------------------------------------------------------------------------------- voxel kit (the reference's Lego look)
GLYPHS = {
	'1': ['.#.', '##.', '.#.', '.#.', '###'],
	'0': ['###', '#.#', '#.#', '#.#', '###'],
	'2': ['###', '..#', '###', '#..', '###'],
	'3': ['###', '..#', '###', '..#', '###'],
	'5': ['###', '#..', '###', '..#', '###'],
	'x': ['...', '#.#', '.#.', '#.#', '...'],
	'+': ['...', '.#.', '###', '.#.', '...'],
}
GOLDM = lambda: mat((255, 204, 40), light=(255, 246, 150), dark=(226, 120, 14), coat=0.55)  # noqa: E731


def voxels(rows, at=(0, 0, 0), c=0.5, colors=None, studs=True, group=None, flip_rows=True):
	"""Rows of '#' / '.' (top row first) as glossy rounded cubes with a stud on the front face. colors: one material per
	row (or a single one). Returns nothing; everything shares one line group so the outline is one clean silhouette."""
	g = group or K.C.new_group()
	n = len(rows)
	w = max(len(r) for r in rows)
	for i, row in enumerate(rows):
		m = colors[min(i, len(colors) - 1)] if isinstance(colors, (list, tuple)) else (colors or GOLDM())
		for j, ch in enumerate(row):
			if ch != '#':
				continue
			x = at[0] + (j - (w - 1) / 2) * c
			z = at[2] + ((n - 1) / 2 - i) * c
			rbox((x, at[1], z), (c * 0.97, c * 0.97, c * 0.97), c * 0.14, m, group=g, name='Vox', seg=3)
			if studs:
				cyl((x, at[1] - c * 0.52, z), c * 0.27, c * 0.14, m, rot=(90, 0, 0), r=c * 0.03, group=g, name='VoxStud', segs=20)


def vtext(s, at=(0, 0, 0), c=0.3, color=None, gap=0.5):
	"""A voxel string ('x2', '10x') from GLYPHS, left to right, centred on `at`."""
	m = color or GOLDM()
	width = sum(3 * c + gap * c for _ in s) - gap * c
	x = at[0] - width / 2 + 1.5 * c
	g = K.C.new_group()
	for ch in s:
		voxels(GLYPHS[ch], (x, at[1], at[2]), c, m, True, g)
		x += 3 * c + gap * c


def gradient_rows(n, top, bottom):
	return [mat(tuple(int(top[k] + (bottom[k] - top[k]) * i / max(1, n - 1)) for k in range(3)), light=(255, 250, 190), dark=(200, 90, 10), coat=0.55) for i in range(n)]


@icon('ServerBoost', view=(-0.08, -1.0, 0.18), fill=0.88, sparkles=4, seed=9, glow=((1.0, 0.8, 0.2), 0.3), ink=(60, 24, 0), outline=0.7)
def server_boost():
	"""A blocky voxel lightning bolt (studs on every cube) with a voxel x2: x2 Power for the whole server."""
	rows = ['..###.', '.###..', '###...', '######', '..###.', '.###..', '###...', '##....', '#.....']
	voxels(rows, (-0.2, 0.2, 0.3), 0.58, gradient_rows(len(rows), (255, 242, 110), (255, 150, 20)))
	vtext('x2', (1.15, -0.55, -1.7), 0.3, mat((255, 120, 24), light=(255, 214, 120), dark=(190, 50, 8), coat=0.55))


def dumbbell(at=(0, 0, 0), rz=0.0, s=1.0, col=(232, 52, 64), light=(255, 140, 150), dark=(150, 20, 40), gold=False, group=None):
	g = group or K.C.new_group()
	if gold:
		col, light, dark = (252, 176, 24), (255, 232, 120), (214, 112, 14)
	plate = mat(col, light=light, dark=dark, coat=0.5)
	bar = mat((176, 190, 210), light=(240, 246, 255), dark=(80, 96, 124), metal=0.3, coat=0.5)
	x0, y0, z0 = at
	with_rot = (0, rz, 0)
	cyl((x0, y0, z0), 0.2 * s, 3.0 * s, bar, rot=(0, 90, 0), group=g, name='Bar', r=0.03 * s)
	for sx in (-1, 1):
		for k, (w, h, off) in enumerate(((0.5, 1.7, 1.05), (0.4, 1.3, 1.5))):
			rbox((x0 + sx * off * s, y0, z0), (w * s, 1.0 * s, h * s), 0.1 * s, plate, group=g, name='Plate')
			cyl((x0 + sx * (off + w / 2 + 0.03) * s, y0, z0), 0.2 * s, 0.1 * s, mat((250, 250, 255), light=(255, 255, 255)), rot=(0, 90, 0), r=0.02 * s, group=g, name='Cap', segs=24)
	return g


@icon('DoublePower', view=(-0.12, -1.0, 0.3), fill=0.88, sparkles=3, seed=4)
def double_power():
	dumbbell((0.0, 0.0, 0.0), s=1.0)
	vtext('x2', (1.35, -0.7, 1.35), 0.28, GOLDM())


@icon('VIP', view=(-0.1, -1.0, 0.3), fill=0.86, sparkles=3, seed=6)
def vip():
	"""A chunky gold crown: a studded band, five prongs with balls on top, a big ruby on the front."""
	gold = mat((252, 186, 28), light=(255, 240, 140), dark=(214, 112, 14), coat=0.55)
	g = K.C.new_group()
	rbox((0, 0, 0), (3.2, 0.8, 0.8), 0.12, gold, group=g, name='Band')
	for i, x in enumerate((-1.3, -0.65, 0.0, 0.65, 1.3)):
		h = 1.5 if i % 2 == 0 else 1.15
		if i == 2:
			h = 1.8
		rbox((x, 0, 0.4 + h / 2), (0.52, 0.8, h), 0.1, gold, group=g, name='Prong')
		ball((x, 0, 0.4 + h + 0.12), 0.24, mat(((255, 84, 110), (86, 190, 255), (255, 84, 110), (86, 190, 255), (255, 84, 110))[i], light=(255, 230, 240), dark=(120, 20, 60), coat=0.7), group=K.C.new_group(), name='Jewel')
	for x in (-1.1, -0.55, 0.0, 0.55, 1.1):
		cyl((x, -0.44, -0.0), 0.14, 0.1, gold, rot=(90, 0, 0), r=0.02, group=g, name='Stud', segs=20)
	rbox((0, -0.5, 0.05), (0.8, 0.2, 0.5), 0.07, mat((255, 60, 96), light=(255, 190, 210), dark=(150, 10, 50), coat=0.7, spec=0.8), rot=(0, 0, 0), group=K.C.new_group(), name='Ruby')


@icon('AutoFight', view=(-0.2, -1.0, 0.35), fill=0.86, sparkles=2, seed=8)
def auto_fight():
	"""A blocky pistol inside a green arrow ring: it fires on its own."""
	steel = mat((150, 170, 204), light=(240, 248, 255), dark=(70, 86, 120), metal=0.25, coat=0.5)
	grip = mat((46, 70, 150), light=(120, 160, 240), dark=(20, 30, 90), coat=0.5)
	g = K.C.new_group()
	rbox((0.15, 0, 0.35), (2.6, 0.9, 0.9), 0.1, steel, group=g, name='Slide')
	rbox((1.7, 0, 0.3), (0.6, 0.55, 0.5), 0.08, steel, group=K.C.new_group(), name='Muzzle')
	rbox((-0.5, 0, -0.55), (0.75, 0.7, 1.4), 0.1, grip, rot=(0, 14, 0), group=K.C.new_group(), name='Grip')
	rbox((0.3, 0, -0.2), (0.9, 0.5, 0.2), 0.05, steel, group=K.C.new_group(), name='Guard')
	for k in range(4):
		rbox((-0.6 + k * 0.42, -0.4, 0.5), (0.2, 0.1, 0.34), 0.03, grip, group=K.C.new_group(), name='Rib')
	pts = []
	for k in range(0, 17):
		a = math.radians(40 + k * 17)
		pts.append((1.95 * math.cos(a), 0.55, 0.15 + 1.75 * math.sin(a)))
	tube(pts, 0.17, mat((70, 206, 62), light=(190, 250, 120), dark=(24, 128, 48), coat=0.5), group=K.C.new_group(), name='Ring')
	e = pts[-1]
	rbox((e[0] - 0.05, e[1], e[2] + 0.12), (0.7, 0.3, 0.5), 0.06, mat((70, 206, 62), light=(190, 250, 120), dark=(24, 128, 48), coat=0.5), rot=(0, -50, 0), group=K.C.new_group(), name='Head')


def shoe_box(at, col, lid, rz=0.0, s=1.0, group=None):
	g = group or K.C.new_group()
	x, y, z = at
	rbox((x, y, z), (2.0 * s, 1.2 * s, 0.9 * s), 0.1 * s, mat(col, light=tuple(min(255, c + 70) for c in col), dark=tuple(int(c * 0.5) for c in col), coat=0.5), rot=(0, 0, rz), group=g, name='BoxBase')
	rbox((x, y, z + 0.55 * s), (2.1 * s, 1.3 * s, 0.28 * s), 0.08 * s, mat(lid, light=tuple(min(255, c + 70) for c in lid), dark=tuple(int(c * 0.5) for c in lid), coat=0.5), rot=(0, 0, rz), group=K.C.new_group(), name='BoxLid')
	rbox((x, y - 0.62 * s, z + 0.1 * s), (0.9 * s, 0.06 * s, 0.34 * s), 0.02 * s, mat((250, 250, 255), light=(255, 255, 255)), rot=(0, 0, rz), group=K.C.new_group(), name='Label')


@icon('TripleOpen', view=(-0.2, -1.0, 0.55), fill=0.88, sparkles=3, seed=3)
def triple_open():
	shoe_box((-1.1, 0, 0.0), (232, 60, 70), (255, 120, 120), rz=4)
	shoe_box((1.1, 0, 0.0), (40, 130, 240), (110, 190, 255), rz=-4)
	shoe_box((0.0, 0.1, 1.25), (255, 150, 30), (255, 206, 90))
	vtext('x3', (1.55, -0.85, -0.75), 0.26, GOLDM())


@icon('AutoOpen', view=(-0.2, -1.0, 0.5), fill=0.88, sparkles=3, seed=12)
def auto_open():
	shoe_box((0.0, 0, 0.0), (40, 130, 240), (110, 190, 255), s=1.1)
	pts = []
	for k in range(0, 17):
		a = math.radians(30 + k * 18)
		pts.append((2.0 * math.cos(a), 0.9, 0.3 + 1.7 * math.sin(a)))
	grn = mat((70, 206, 62), light=(190, 250, 120), dark=(24, 128, 48), coat=0.5)
	tube(pts, 0.17, grn, group=K.C.new_group(), name='Ring')
	e = pts[-1]
	rbox((e[0] - 0.05, e[1], e[2] + 0.1), (0.7, 0.3, 0.5), 0.06, grn, rot=(0, -50, 0), group=K.C.new_group(), name='Head')


@icon('ExtraEquip', view=(-0.35, -1.0, 0.35), fill=0.86, sparkles=3, seed=14)
def extra_equip():
	"""A blocky sneaker and a studded green plus: one more shoe slot."""
	blue = mat((40, 120, 240), light=(130, 190, 255), dark=(16, 50, 150), coat=0.55)
	white = mat((250, 250, 255), light=(255, 255, 255), dark=(190, 200, 225), coat=0.5)
	g = K.C.new_group()
	rbox((0, 0, -0.4), (3.2, 1.3, 0.4), 0.14, white, group=g, name='Sole')
	rbox((-0.7, 0, 0.35), (1.6, 1.2, 1.2), 0.2, blue, group=K.C.new_group(), name='Heel')
	rbox((0.55, 0, 0.0), (1.7, 1.15, 0.7), 0.2, blue, group=K.C.new_group(), name='Toe')
	rbox((-0.1, 0, 0.75), (0.9, 1.0, 0.4), 0.1, white, rot=(0, -20, 0), group=K.C.new_group(), name='Tongue')
	rbox((0.0, -0.62, 0.0), (2.4, 0.06, 0.18), 0.02, mat((255, 210, 40), light=(255, 246, 150)), group=K.C.new_group(), name='Stripe')
	for k in range(3):
		rbox((0.3 + k * 0.38, -0.45, 0.55 - k * 0.12), (0.26, 0.12, 0.08), 0.02, white, rot=(0, -25, 0), group=K.C.new_group(), name='Lace')
	voxels(GLYPHS['+'], (1.6, -0.4, 1.35), 0.46, mat((70, 214, 62), light=(190, 250, 120), dark=(24, 140, 48), coat=0.55))


@icon('TenXCash', view=CASH_VIEW, fill=0.88, sparkles=3, seed=15)
def ten_x_cash():
	bundle((-0.2, 0.55, 0.0), rz=8, n=5)
	bundle((0.35, -0.15, 0.0), rz=-8, n=4)
	vtext('10x', (0.2, -1.05, 0.4), 0.28, GOLDM())


def target(at, rings, legs=True, s=1.0):
	g = K.C.new_group()
	x, y, z = at
	if legs:
		for sx in (-1, 1):
			rbox((x + sx * 0.8 * s, y + 0.5, z - 1.1 * s), (0.3 * s, 0.3, 1.8 * s), 0.06, mat((120, 82, 50), light=(190, 140, 90), dark=(70, 40, 20)), rot=(0, sx * 10, 0), group=K.C.new_group(), name='Leg')
	for k, (r, col) in enumerate(rings):
		cyl((x, y - 0.05 * k, z), r * s, 0.26 * s, mat(col, light=tuple(min(255, c + 80) for c in col), dark=tuple(int(c * 0.5) for c in col), coat=0.55), rot=(90, 0, 0), r=0.03 * s, group=g, name='Ring%d' % k, segs=48)


@icon('ProBay', view=(-0.15, -1.0, 0.3), fill=0.86, sparkles=2, seed=16)
def pro_bay():
	target((0, 0, 0.3), [(1.6, (30, 190, 170)), (1.25, (250, 250, 255)), (0.9, (30, 190, 170)), (0.55, (250, 250, 255)), (0.25, (232, 52, 64))])
	vtext('x100', (0.0, -0.7, -1.55), 0.24, mat((255, 255, 255), light=(255, 255, 255), dark=(160, 200, 220), coat=0.55))


@icon('GoldBay', view=(-0.15, -1.0, 0.3), fill=0.86, sparkles=4, seed=17, glow=((1.0, 0.85, 0.3), 0.25))
def gold_bay():
	target((0, 0, 0.2), [(1.6, (252, 176, 24)), (1.25, (255, 240, 170)), (0.9, (252, 176, 24)), (0.55, (255, 240, 170)), (0.25, (232, 52, 64))])
	gold = mat((252, 186, 28), light=(255, 240, 140), dark=(214, 112, 14), coat=0.55)
	g = K.C.new_group()
	rbox((0, -0.3, 2.0), (1.6, 0.4, 0.4), 0.07, gold, group=g, name='CrownBand')
	for x in (-0.6, 0, 0.6):
		rbox((x, -0.3, 2.45), (0.34, 0.4, 0.7 if x == 0 else 0.5), 0.06, gold, group=g, name='CrownProng')
	vtext('x250', (0.0, -0.7, -1.55), 0.24, mat((255, 255, 255), light=(255, 255, 255), dark=(160, 200, 220), coat=0.55))


@icon('Speed2x', view=(-0.1, -1.0, 0.2), fill=0.86, sparkles=3, seed=18)
def speed2x():
	"""Two studded voxel chevrons (go faster) and a voxel x2."""
	chev = ['##..', '.##.', '..##', '.##.', '##..']
	voxels(chev, (-1.15, 0.1, 0.35), 0.5, gradient_rows(5, (150, 244, 100), (40, 170, 60)))
	voxels(chev, (0.95, 0.1, 0.35), 0.5, gradient_rows(5, (150, 244, 100), (40, 170, 60)))
	vtext('x2', (1.0, -0.5, -1.45), 0.3, GOLDM())


@icon('CashBig', fill=0.86, sparkles=3, seed=22, glow=((1.0, 0.85, 0.3), 0.2))
def cash_big():
	brown_bag((-0.9, 0.7, 0.0), 1.15)
	brown_bag((0.85, 0.75, 0.0), 1.05, rz=-10)
	bundle((-1.3, -0.5, 0.0), rz=14, n=4, s=0.9)
	bundle((1.3, -0.45, 0.0), rz=-14, n=4, s=0.9)
	coin_pile((0.0, -0.95, 0.04), rows=3)


@icon('CashMega', fill=0.86, sparkles=6, seed=24, glow=((1.0, 0.85, 0.3), 0.35))
def cash_mega():
	"""The biggest: a chest of gold behind, bags on both sides, gold bars stacked, a tall coin heap."""
	wood = mat((170, 96, 44), tiles=0.3, tile_rgb=(206, 132, 70), density=2.5, dark=(104, 54, 22), light=(224, 150, 84))
	gold = mat(GOLD, light=GOLD_L, dark=GOLD_D, coat=0.5)
	rbox((0, 1.7, 0.7), (3.0, 1.5, 1.4), 0.12, wood, group=K.C.new_group(), name='Chest')
	rbox((0, 1.7, 1.45), (3.04, 1.54, 0.16), 0.05, gold, group=K.C.new_group(), name='Rim')
	for x in (-1.2, 1.2):
		rbox((x, 1.7, 0.72), (0.3, 1.58, 1.46), 0.06, gold, group=K.C.new_group(), name='Strap')
	coin_pile((0.0, 1.2, 1.5), rows=3)
	brown_bag((-1.7, 0.4, 0.0), 1.2)
	brown_bag((1.7, 0.4, 0.0), 1.1, rz=-12)
	bars = K.C.new_group()
	for k, (x, z) in enumerate(((-0.65, 0.15), (0.65, 0.15), (0.0, 0.5))):
		rbox((x, -0.35, z), (1.1, 0.5, 0.34), 0.07, mat(GOLD, light=GOLD_L, dark=GOLD_D, coat=0.6), rot=(0, 0, (4, -4, 0)[k]), taper=(0.84, 0.8), group=bars, name='Bar')
	bundle((-1.55, -0.5, 0.0), rz=14, n=4, s=0.85)
	bundle((1.55, -0.45, 0.0), rz=-14, n=4, s=0.85)
	coin_pile((0.0, -1.25, 0.04), rows=4)


def power_pile(n, gold=False):
	"""Dumbbells that grow tier by tier: 1, 2, 3, 4, 6 and a gold pile."""
	spots = {
		1: [((0, 0, 0.1), 0, 1.0)],
		2: [((-0.5, 0.2, 0.1), 0, 0.85), ((0.5, -0.5, 0.1), 0, 0.85)],
		3: [((0, 0.7, 0.1), 0, 0.8), ((0, -0.1, 0.3), 0, 0.8), ((0, -0.9, 0.1), 0, 0.8)],
		4: [((-0.5, 0.7, 0.1), 0, 0.75), ((0.5, 0.7, 0.1), 0, 0.75), ((-0.5, -0.1, 0.1), 0, 0.75), ((0.5, -0.9, 0.1), 0, 0.75)],
		5: [((-0.5, 0.9, 0.1), 0, 0.72), ((0.5, 0.9, 0.1), 0, 0.72), ((-0.5, 0.1, 0.1), 0, 0.72), ((0.5, 0.1, 0.1), 0, 0.72), ((0, -0.7, 0.1), 0, 0.8), ((0, -1.3, 0.1), 0, 0.8)],
		6: [((-0.95, 1.2, 0.1), 0, 0.6), ((0.95, 1.2, 0.1), 0, 0.6), ((-0.95, 0.2, 0.1), 0, 0.6), ((0.95, 0.2, 0.1), 0, 0.6), ((-0.95, -0.8, 0.1), 0, 0.6), ((0.95, -0.8, 0.1), 0, 0.6)],
	}[n]
	for k, (at, rz, s) in enumerate(spots):
		dumbbell(at, rz, s, gold=(gold or n == 6 or (n == 5 and k >= 4)))


for _n, _id, _fill in ((1, 'PowerTiny', 0.8), (2, 'PowerSmall', 0.84), (3, 'PowerMedium', 0.86), (4, 'PowerBig', 0.86), (5, 'PowerLarge', 0.86), (6, 'PowerMega', 0.86)):
	icon(_id, view=(-0.2, -1.0, 0.6), fill=_fill, sparkles=(0 if _n < 3 else _n), seed=30 + _n, ink=(70, 10, 20))((lambda n: (lambda: power_pile(n)))(_n))


def main(argv):
	ap = argparse.ArgumentParser()
	ap.add_argument('ids', nargs='*')
	ap.add_argument('--res', type=int, default=512)
	ap.add_argument('--ss', type=int, default=2)
	ap.add_argument('--samples', type=int, default=40)
	ap.add_argument('--out', default=K.OUT)
	ap.add_argument('--list', action='store_true')
	a = ap.parse_args(argv)
	mine = ['CashTiny', 'CashSmall', 'CashMedium', 'CashBig', 'CashLarge', 'CashMega', 'Lucky', 'ServerBoost', 'DoubleCash', 'DoublePower', 'VIP', 'AutoFight', 'TripleOpen', 'AutoOpen', 'ExtraEquip', 'TenXCash', 'ProBay', 'GoldBay', 'Speed2x', 'PowerTiny', 'PowerSmall', 'PowerMedium', 'PowerBig', 'PowerLarge', 'PowerMega']
	if a.list:
		print(' '.join(mine))
		return
	os.makedirs(a.out, exist_ok=True)
	for iid in a.ids or mine:
		H.render_icon(iid, a.out, a.res, a.ss, a.samples)


if __name__ == '__main__':
	main(sys.argv[1:])
