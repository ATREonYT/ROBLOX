"""HUD and window icons in the reference game's style (brief 19): smooth chunky cartoon 3D, glossy, a square-tile
pattern on the surfaces, a thick navy outline baked in, transparent 512x512 PNGs ready to upload.

Usage (Blender as a Python module, see README):
  blenv/bin/python hood/tools/blender/icons_hd.py [ids...] [--res 512] [--ss 2] [--samples 40] [--out DIR] [--list]
Default output: hood/art/icons3d/<Id>.png. The modelling/post kit is hdkit.py; the live in-game fallback for each id
is still the BoxKit part model in models/icons.py (IconModels.build), so nothing breaks before the uploads.
Space: Blender axes, x = screen right, z = up, the camera looks toward +y from the front (-y).
"""
import argparse
import math
import os
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import hdkit as K  # noqa: E402
from hdkit import arc_frames, ball, bar, cyl, flat, lathe, mat, metaball, place, rbox, round_rect, slab, sweep, text, tub, tube  # noqa: E402,F401
from mathutils import Vector  # noqa: E402

# ------------------------------------------------------------------------------------------- icons
ICONS = {}


def icon(iid, view=(-0.3, -1.0, 0.35), fill=0.86, lens=85.0, roll=0.0, **opts):
	def deco(fn):
		ICONS[iid] = dict(fn=fn, view=view, fill=fill, lens=lens, roll=roll, opts=opts)
		return fn
	return deco


# Colours measured on the reference (sRGB).
ORANGE = (252, 164, 28)
RED, RED_TILE = (240, 50, 82), (255, 130, 160)
WHITE, WHITE_TILE = (238, 246, 250), (178, 214, 236)
GREEN, GREEN_TILE = (52, 186, 74), (124, 228, 124)
GOLD, GOLD_TILE = (250, 166, 22), (255, 214, 72)
STEEL = (150, 176, 204)
PINK, PINK_TILE = (232, 50, 120), (255, 120, 176)
RIBBON, RIBBON_TILE = (255, 164, 18), (255, 214, 70)
PARCH, PARCH_TILE, PARCH_END = (236, 138, 94), (252, 192, 150), (196, 92, 62)
BLUE, BLUE_DEEP = (30, 140, 250), (10, 36, 196)
NAVY = K.NAVY


def stick(points_xz, radius, material, group, lift=0.004, dirn=(0, 1, 0), origin_y=-50):
	"""A line drawn on the surface seen from -y: each (x, z) is projected onto the first surface hit."""
	bpy.context.view_layer.update()
	dg = bpy.context.evaluated_depsgraph_get()
	sc = bpy.context.scene
	pts = []
	for q in points_xz:
		x, z = q[0], q[-1]
		hit, loc, nor, *_ = sc.ray_cast(dg, (x, origin_y, z), dirn)
		if hit:
			pts.append((loc.x - dirn[0] * lift, loc.y - dirn[1] * lift, loc.z - dirn[2] * lift))
	if len(pts) >= 2:
		return tube(pts, radius, material, group=group, name='line')


def surface_y(x, z):
	bpy.context.view_layer.update()
	dg = bpy.context.evaluated_depsgraph_get()
	hit, loc, *_ = bpy.context.scene.ray_cast(dg, (x, -50, z), (0, 1, 0))
	return loc.y if hit else 0.0


# ------------------------------------------------------------------ Power: the flexed arm (+ packs, offer)
def arm(group=None, col=ORANGE, crease=True, at=(0, 0, 0), size=1.0, flip=False):
	"""The reference's flexed arm: forearm up on the left, fist curling right, bicep bulging at the right."""
	k = 1.95 * size  # metaball radius for a visible radius of 1 at threshold 0.8 (less blending: crisp notch)
	sx = -1 if flip else 1
	ox, oy, oz = at

	def P(x, z):
		return (ox + sx * (x - 0.5) * size, oy, oz + (z - 0.5) * size)
	els = [
		('BALL', P(0.2, 0.17), 0.165 * k),  # elbow
		('BALL', P(0.2, 0.33), 0.165 * k),  # forearm
		('BALL', P(0.25, 0.48), 0.145 * k),
		('BALL', P(0.31, 0.6), 0.13 * k),   # wrist
		('BALL', P(0.38, 0.78), 0.18 * k),  # fist
		('BALL', P(0.3, 0.86), 0.12 * k),
		('BALL', P(0.5, 0.83), 0.12 * k),
		('BALL', P(0.6, 0.765), 0.105 * k),  # knuckles, overhanging toward the bicep
		('BALL', P(0.45, 0.19), 0.16 * k),  # upper arm
		('BALL', P(0.75, 0.4), 0.2 * k),    # bicep: a narrow notch under the knuckles makes the "L" read
		('BALL', P(0.88, 0.31), 0.15 * k),  # shoulder end
	]

	g = group or K.C.new_group()
	m = mat(col, rough=0.4, coat=0.35, dark=(238, 112, 26), light=(255, 180, 36))
	ob = metaball([(t, c, r, (1, 1, 1), (0, 0, 0)) for (t, c, r) in els], m, res=0.02 * size, group=g, name='Arm%d' % g, threshold=0.8)
	ob.scale = (1, 0.62, 0.94)
	if crease:
		line = flat(NAVY)
		stick([P(0.6, 0.705), P(0.53, 0.675), P(0.45, 0.67)], 0.018 * size, line, g)
		stick([P(0.585, 0.47), P(0.6, 0.4), P(0.6, 0.33)], 0.018 * size, line, g)
	return ob


def bolt(at, size, rot=0.0, col=(255, 214, 40), group=None):
	pts = [(0.1, 0.5), (-0.28, -0.04), (-0.02, -0.04), (-0.14, -0.5), (0.3, 0.08), (0.04, 0.08), (0.18, 0.5)]
	pts = [(x * size, z * size) for (x, z) in pts]
	return slab(pts, 0.12 * size, mat(col, tiles=0.0, light=(255, 250, 200)), loc=at, rot=(0, rot, 0), r=0.025 * size, group=group, name='Bolt')


@icon('Muscle', view=(-0.15, -1.0, 0.18), fill=0.84)
def muscle():
	arm()


@icon('PowerPack1', view=(-0.15, -1.0, 0.18), fill=0.84)
def power_pack1():
	arm()


@icon('Power', view=(-0.15, -1.0, 0.18), fill=0.84)
def power_legacy():
	"""Legacy id (was the boxing glove): the game's Power is the flexed arm now."""
	arm()


@icon('PowerPack2', view=(-0.15, -1.0, 0.18), fill=0.86, sparkles=2, seed=5)
def power_pack2():
	arm(at=(0.05, 0, -0.03), size=0.94)
	bolt((-0.36, 0.25, 0.22), 0.5, rot=-12)


@icon('PowerPack3', view=(-0.15, -1.0, 0.18), fill=0.86, sparkles=4, seed=9, glow=((1.0, 0.85, 0.3), 0.55))
def power_pack3():
	arm(at=(0.06, 0, -0.05), size=0.9)
	bolt((-0.4, 0.25, 0.22), 0.5, rot=-12)
	bolt((0.47, 0.25, 0.38), 0.36, rot=18)


@icon('DoublePower', view=(-0.15, -1.0, 0.18), fill=0.88, sparkles=3, seed=4, glow=((1.0, 0.8, 0.3), 0.45))
def double_power():
	# (the HUD card and the Store card both print "2x Power" already: no text in the art)
	arm(at=(0.04, 0, -0.02), size=0.96)
	bolt((0.5, 0.25, 0.42), 0.44, rot=16)
	bolt((-0.44, 0.25, 0.3), 0.36, rot=-14)


# ------------------------------------------------------------------ Rebirth: the red and white circular arrows
def ring_arrow(a0, a1, col, tile, R=0.84, w=0.9, d=0.5, head=0.78, hin=0.52, hout=0.9, bend=32, group=None):
	"""One circular arrow, clockwise from angle a0 to a1 (degrees, a0 > a1), with a big arrowhead at a1."""
	g = group or K.C.new_group()
	m = mat(col, tiles=0.7, tile_rgb=tile, density=2.6, rough=0.34, coat=0.3)
	prof = round_rect(w, d, 0.15, 5)
	sweep(arc_frames((0, 0, 0), R, a0, a1, 40), prof, m, group=g, name='Arc')
	e = math.radians(a1)
	t0 = (math.sin(e), -math.cos(e))  # clockwise travel
	rad = (math.cos(e), math.sin(e))
	cb, sb = math.cos(math.radians(bend)), math.sin(math.radians(bend))
	tip = (t0[0] * cb - rad[0] * sb, t0[1] * cb - rad[1] * sb)  # bent toward the centre, following the ring
	bx, bz = R * rad[0] + tip[0] * 0.02, R * rad[1] + tip[1] * 0.02
	pts = [(bx - rad[0] * hin, bz - rad[1] * hin), (bx + rad[0] * hout, bz + rad[1] * hout),
		(bx + tip[0] * head + rad[0] * 0.12, bz + tip[1] * head + rad[1] * 0.12)]
	slab(pts, d + 0.06, m, loc=(0, -0.05, 0), r=0.12, seg=4, group=g, name='Head')
	return g


def rebirth_icon(col, tile):
	# (the reference splits red/white on a 10-to-4 o'clock diagonal; each head hides the other arrow's tail)
	ring_arrow(155, -20, col, tile)
	ring_arrow(-30, -205, WHITE, WHITE_TILE)


@icon('Rebirth', view=(-0.2, -1.0, 0.2), fill=0.86)
def rebirth():
	rebirth_icon(RED, RED_TILE)


@icon('RebirthSkip', view=(-0.2, -1.0, 0.2), fill=0.86)
def rebirth_skip():
	rebirth_icon(GREEN, GREEN_TILE)


# ------------------------------------------------------------------ Store: the baskets
def basket(body, tile, inside, handle=STEEL, holes=False, dark=None, inside_light=None):
	g = K.C.new_group()
	m_out = mat(body, tiles=1.0 if holes else 0.0, tile_rgb=tile, density=1.8, rough=0.36, coat=0.3, dark=dark)
	m_in = mat(inside, tiles=1.0 if holes else 0.0, tile_rgb=tile, density=1.8, rough=0.4, coat=0.15, light=inside_light)
	tub((2.2, 1.6), (1.42, 1.02), 1.1, 0.14, m_out, m_in, loc=(0, 0, -0.5), r=0.07, group=g, name='Tub')
	mh = mat(handle, rough=0.32, coat=0.4)
	pts = [(-0.96, 0.0, -0.1), (-0.96, 0.0, 0.56), (0.96, 0.0, 0.56), (0.96, 0.0, -0.1)]
	h = bar(pts, 0.22, 0.22, mh, rr=0.35, corner=0.2, group=K.C.new_group(), name='Handle')
	h.location = (0, 0.05, 0.62)
	h.rotation_euler = (math.radians(-28), 0, 0)


@icon('Basket', view=(-0.5, -1.0, 0.75), fill=0.88)
def basket_orange():
	basket((252, 146, 28), (255, 196, 80), (255, 200, 70), handle=(130, 162, 200), dark=(244, 116, 30), inside_light=(255, 226, 110))


@icon('Shop', view=(-0.5, -1.0, 0.75), fill=0.88)
def shop_legacy():
	"""Legacy id (only a fallback of Basket): the same orange basket."""
	basket_orange()


@icon('BasketRed', view=(0.45, -1.0, 0.7), fill=0.88)
def basket_red():
	basket((222, 28, 76), (118, 0, 36), (240, 80, 124), handle=(176, 188, 206), holes=True)


# ------------------------------------------------------------------ Rewards: the gift
@icon('Rewards', view=(-0.3, -1.0, 0.5), fill=0.88)
def rewards():
	box = mat(PINK, tiles=0.8, tile_rgb=PINK_TILE, density=2.8)
	rib = mat(RIBBON, tiles=0.6, tile_rgb=RIBBON_TILE, density=2.8)
	gb = K.C.new_group()
	rbox((0, 0, -0.36), (1.9, 1.7, 1.15), 0.08, box, group=gb, name='Box')
	rbox((0, 0, 0.32), (2.08, 1.88, 0.42), 0.09, box, group=gb, name='Lid')
	gr = K.C.new_group()
	rbox((0, 0, -0.36), (0.5, 1.74, 1.17), 0.05, rib, group=gr, name='RibbonY')
	rbox((0, 0, -0.36), (1.94, 0.5, 1.17), 0.05, rib, group=gr, name='RibbonX')
	rbox((0, 0, 0.32), (0.52, 1.92, 0.46), 0.06, rib, group=gr, name='RibbonLidY')
	rbox((0, 0, 0.32), (2.12, 0.52, 0.46), 0.06, rib, group=gr, name='RibbonLidX')
	gw = K.C.new_group()
	for sx in (-1, 1):
		loop = [(0.05, 0, 0.62), (0.42, 0, 0.88), (0.88, 0, 1.06), (1.2, 0, 0.96), (1.16, 0, 0.72), (0.72, 0, 0.62), (0.1, 0, 0.6)]
		tube(K.fillet([(sx * x, -0.1 + y, z) for (x, y, z) in loop], 0.25), 0.2, rib, group=gw, name='Loop')
		ball((sx * 0.72, -0.08, 0.82), (0.5, 0.17, 0.17), rib, rot=(0, -sx * 16, 0), group=gw, name='LoopFill')
	ball((0, -0.12, 0.7), (0.26, 0.24, 0.22), rib, group=gw, name='Knot')
	for sx in (-1, 1):
		slab([(0, 0), (0.24, 0), (0.34, -0.5), (0.2, -0.4), (0.06, -0.54)], 0.08, rib, loc=(sx * 0.12, -1.0, 0.56),
			rot=(0, 0, 0) if sx > 0 else (0, 0, 180), r=0.025, group=gw, name='Tail')


# ------------------------------------------------------------------ Quest: the scroll
@icon('Quest', view=(-0.55, -1.0, -0.1), fill=0.9)
def quest():
	ang = 40  # the roll rises to the right

	def along(t, off=(0, 0)):
		a = math.radians(ang)
		return (t * math.cos(a) - off[1] * math.sin(a), off[0], t * math.sin(a) + off[1] * math.cos(a))
	rot = (0, 90 - ang, 0)
	paper = mat(PARCH, tiles=0.6, tile_rgb=PARCH_TILE, density=3.8)
	gp = K.C.new_group()
	cyl(along(-0.08), 0.48, 1.95, paper, rot=rot, r=0.08, group=gp, name='Roll')
	cyl(along(0.92), 0.5, 0.12, mat((250, 186, 146), tiles=0.0), rot=rot, r=0.05, group=K.C.new_group(), name='Lip')
	ge = K.C.new_group()
	cyl(along(-1.07), 0.4, 0.06, mat(PARCH_END), rot=rot, r=0.02, group=ge, name='End')
	# the spiral on the rolled end
	a = math.radians(ang)
	axis = Vector((math.cos(a), 0, math.sin(a)))
	u = Vector((0, -1, 0))
	v = axis.cross(u).normalized()
	c = Vector(along(-1.11))
	sp = []
	for kk in range(60):
		t = kk / 59
		rr = 0.05 + 0.29 * t
		th = t * 4.2 * math.pi
		sp.append(c + u * rr * math.cos(th) + v * rr * math.sin(th) - axis * 0.0)
	tube(sp, 0.028, flat(NAVY), group=ge, name='Spiral')
	band = mat(RED, tiles=0.6, tile_rgb=RED_TILE, density=3.4)
	gb = K.C.new_group()
	cyl(along(0.36), 0.53, 0.38, band, rot=rot, r=0.07, group=gb, name='Band')
	for k2, (dx, length, tilt) in enumerate(((0.1, 0.6, -8), (0.36, 0.5, 14))):
		p0 = Vector(along(0.36)) + Vector((dx - 0.1, -0.42, -0.4))
		slab([(-0.12, 0), (0.12, 0), (0.12, -length), (0.0, -length + 0.12), (-0.12, -length)], 0.07,
			mat((214, 30, 66)), loc=tuple(p0), rot=(0, tilt, 0), r=0.025, group=gb, name='Tail')


# ------------------------------------------------------------------ Cash: a bill stack and coins
def bills(at=(0, 0, 0), rz=0.0, n=4):
	g = K.C.new_group()
	bill = mat((88, 200, 78), tiles=0.45, tile_rgb=(150, 236, 120), density=3.0, light=(170, 246, 140), dark=(48, 150, 60))
	edge = mat((44, 146, 62), light=(90, 196, 90))
	for kk in range(n):
		z = at[2] + kk * 0.13
		rbox((at[0] + (kk % 2) * 0.03, at[1], z), (2.0, 1.02, 0.1), 0.035, bill if kk == n - 1 else edge, rot=(0, 0, rz + (kk - n / 2) * 2.5), group=g, name='Bill')
	top = at[2] + (n - 1) * 0.13 + 0.06
	ge = K.C.new_group()
	ball((at[0] - 0.2, at[1], top), (0.42, 0.34, 0.04), mat((50, 156, 64), light=(80, 190, 90)), rot=(0, 0, rz), group=ge, name='Seal')
	t = text('$', mat((236, 255, 220), light=(255, 255, 255)), loc=(at[0] - 0.2, at[1], top + 0.02), size=0.6, depth=0.03, rot=(0, 0, rz), bev=0.012, group=K.C.new_group(), name='Dollar')
	gb = K.C.new_group()
	rbox((at[0] + 0.55, at[1], at[2] + (n - 1) * 0.065), (0.34, 1.08, (n - 1) * 0.13 + 0.16), 0.03, mat((250, 236, 200)), rot=(0, 0, rz), group=gb, name='Band')
	return t


def coin(at, rot, r=0.42, dollar=True):
	g = K.C.new_group()
	gold = mat(GOLD, light=(255, 230, 120), dark=(220, 120, 20))
	ob = cyl((0, 0, 0), r, 0.14, gold, r=0.045, group=g, name='Coin')
	parts = [ob]
	if dollar:
		parts.append(cyl((0, 0, 0.075), r * 0.74, 0.02, mat((236, 140, 20), light=(255, 196, 70)), r=0.0, group=g, name='Face'))
		parts.append(text('$', mat((255, 232, 120), light=(255, 250, 210)), loc=(0, 0, 0.1), size=r * 1.35, depth=0.03, rot=(0, 0, 0), bev=0.012, group=K.C.new_group(), name='CoinDollar'))
	piv = bpy.data.objects.new('CoinPivot', None)
	bpy.context.scene.collection.objects.link(piv)
	for o in parts:
		o.parent = piv
	place(piv, at, rot)
	return g


@icon('Cash', view=(-0.3, -1.0, 0.85), fill=0.9)
def cash():
	bills(rz=-6)
	coin((-0.66, -0.74, 0.36), (74, 0, -12))


def coin_stack(at, n=3, r=0.36):
	for kk in range(n):
		coin((at[0] + 0.03 * (kk % 2), at[1], at[2] + kk * 0.15), (0, 0, 20 * kk), r=r, dollar=(kk == n - 1))


@icon('DoubleCash', view=(-0.3, -1.0, 0.8), fill=0.9, sparkles=3, seed=7)
def double_cash():
	bills(at=(-0.3, 0.55, 0.0), rz=8, n=6)
	bills(at=(0.3, -0.2, 0.0), rz=-8, n=4)
	coin_stack((-0.45, -0.95, 0.07), n=4, r=0.4)


# ------------------------------------------------------------------ Trophy
@icon('Trophy', view=(-0.2, -1.0, 0.45), fill=0.88)
def trophy():
	gold = mat(GOLD, tiles=0.7, tile_rgb=GOLD_TILE, density=3.4, rough=0.34, coat=0.3, dark=(222, 118, 20), light=(255, 214, 80))
	g = K.C.new_group()
	lathe([(0, 0.55), (0.2, 0.56), (0.42, 0.66), (0.6, 0.86), (0.7, 1.08), (0.74, 1.32), (0.74, 1.4), (0, 1.4)], gold, group=g, name='Bowl')
	lathe([(0, 0.2), (0.17, 0.22), (0.12, 0.38), (0.13, 0.5), (0.24, 0.6), (0, 0.6)], gold, group=g, name='Stem')
	cyl((0, 0, 0.14), 0.52, 0.14, gold, r=0.04, group=g, name='Foot')
	cyl((0, 0, 0.02), 0.62, 0.14, gold, r=0.05, group=g, name='Base')
	gi = K.C.new_group()
	cyl((0, 0, 1.4), 0.62, 0.04, mat((232, 70, 34), light=(246, 104, 50), dark=(186, 38, 24)), r=0.0, group=gi, name='Inside')
	gh = K.C.new_group()
	for sx in (-1, 1):
		pts = [(sx * 0.62, 0, 1.2), (sx * 0.98, 0, 1.22), (sx * 1.02, 0, 0.98), (sx * 0.86, 0, 0.78), (sx * 0.56, 0, 0.72)]
		tube(K.fillet(pts, 0.18), 0.075, gold, group=gh, name='Handle')


# ------------------------------------------------------------------ the green arrow (Rebirth window)
def green_arrow(tilt):
	pts = [(-0.4, -0.85), (0.4, -0.85), (0.4, -0.05), (0.92, -0.05), (0.0, 0.95), (-0.92, -0.05), (-0.4, -0.05)]
	slab(pts, 0.7, mat(GREEN, tiles=0.75, tile_rgb=GREEN_TILE, density=2.8, dark=(22, 124, 50)), rot=(0, tilt, 0), r=0.13, seg=4)


@icon('Arrow', view=(-0.6, -1.0, -0.05), fill=0.86)
def arrow45():
	green_arrow(45)


@icon('Evolve', view=(-0.5, -1.0, 0.3), fill=0.86)
def evolve():
	green_arrow(0)


# ------------------------------------------------------------------ XP shield (Rebirth window)
def shield_pts(w, h, k=1.0):
	pts = [(-w / 2, h * 0.5), (w / 2, h * 0.5), (w / 2, -h * 0.05), (0.0, -h * 0.5), (-w / 2, -h * 0.05)]
	return [(x * k, z * k) for (x, z) in pts]


def shield():
	g = K.C.new_group()
	slab(shield_pts(1.6, 1.9), 0.34, mat(BLUE, light=(140, 210, 255), dark=(20, 96, 220)), rot=(0, -8, 0), r=0.14, group=g, name='Shield')
	gi = K.C.new_group()
	slab(shield_pts(1.6, 1.9, 0.74), 0.12, mat(BLUE_DEEP, light=(24, 70, 224), dark=(6, 20, 150)), loc=(0.02, -0.17, -0.02), rot=(0, -8, 0), r=0.05, group=gi, name='Inner')


@icon('Shield', view=(-0.25, -1.0, 0.2), fill=0.86)
def shield_empty():
	shield()


@icon('XP', view=(-0.25, -1.0, 0.2), fill=0.86)
def xp():
	shield()
	gt = K.C.new_group()
	text('XP', mat(WHITE, light=(255, 255, 255)), loc=(0.02, -0.25, 0.1), size=0.86, depth=0.06, rot=(90, -8, 0), bev=0.025, group=gt, name='XP')


# ------------------------------------------------------------------ Robux (white, so ImageColor3 can tint it)
def hexagon(rad, rr=0.0):
	return [(rad * math.cos(math.radians(90 + 60 * kk)), rad * math.sin(math.radians(90 + 60 * kk))) for kk in range(6)]


@icon('Robux', view=(-0.12, -1.0, 0.12), fill=0.86, inner=1.2)
def robux():
	white = mat((244, 246, 250), light=(255, 255, 255), dark=(196, 204, 216))
	slab(hexagon(1.0), 0.3, white, r=0.2, group=K.C.new_group(), name='Outer')
	slab(hexagon(0.64), 0.32, white, loc=(0, -0.02, 0), r=0.08, group=K.C.new_group(), name='Inner')
	slab([(-0.11, -0.11), (0.11, -0.11), (0.11, 0.11), (-0.11, 0.11)], 0.05, flat(NAVY), loc=(0, -0.18, 0), r=0.0, group=K.C.new_group(), name='Hole')


# ------------------------------------------------------------------ VIP: a gold crown
@icon('VIP', view=(-0.2, -1.0, 0.35), fill=0.88)
def vip():
	gold = mat(GOLD, tiles=0.7, tile_rgb=GOLD_TILE, density=3.4, dark=(222, 118, 20), light=(255, 214, 80))
	pts = [(-0.95, -0.45), (0.95, -0.45), (1.05, 0.62), (0.52, 0.12), (0.0, 0.78), (-0.52, 0.12), (-1.05, 0.62)]
	g = K.C.new_group()
	slab(pts, 0.42, gold, r=0.1, group=g, name='Crown')
	for (x, z) in ((-1.05, 0.62), (0.0, 0.78), (1.05, 0.62)):
		ball((x, 0, z + 0.06), 0.16, gold, group=g, name='Tip')
	gb = K.C.new_group()
	rbox((0, -0.05, -0.33), (2.0, 0.55, 0.36), 0.1, mat((236, 140, 20), tiles=0.6, tile_rgb=GOLD_TILE, density=4.0), group=gb, name='Band')
	ball((0, -0.32, 0.12), (0.2, 0.08, 0.26), mat((230, 30, 70), rough=0.15, coat=0.8, light=(255, 140, 170)), rot=(0, 0, 0), group=K.C.new_group(), name='Ruby')
	for sx in (-1, 1):
		ball((sx * 0.6, -0.33, -0.33), (0.13, 0.06, 0.13), mat((40, 150, 255), rough=0.15, coat=0.8), group=K.C.new_group(), name='Sapphire')


# ------------------------------------------------------------------ Auto Fight: a red coin with crossed pistols
@icon('AutoFight', view=(-0.2, -1.0, 0.25), fill=0.86)
def autofight():
	g = K.C.new_group()
	cyl((0, 0, 0), 1.0, 0.32, mat((226, 40, 66), tiles=0.6, tile_rgb=(250, 104, 126), density=3.0), rot=(90, 0, 0), r=0.12, group=g, name='Coin')
	gi = K.C.new_group()
	cyl((0, -0.03, 0), 0.78, 0.34, mat((240, 64, 88), tiles=0.6, tile_rgb=(255, 126, 146), density=3.0), rot=(90, 0, 0), r=0.06, group=gi, name='Face')
	wh = mat((248, 250, 252), dark=(200, 210, 226))
	gx = K.C.new_group()
	prof = [(0.07 * math.cos(2 * math.pi * k / 16), 0.07 * math.sin(2 * math.pi * k / 16)) for k in range(16)]
	sweep(arc_frames((0, -0.24, 0), 0.46, 0, 360, 64), prof, wh, group=gx, name='Ring', caps=False)
	for a in (0, 90, 180, 270):
		ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
		rbox((ca * 0.5, -0.24, sa * 0.5), (0.13 if a % 180 else 0.42, 0.13, 0.42 if a % 180 else 0.13), 0.05, wh, group=gx, name='Tick')
	ball((0, -0.26, 0), (0.11, 0.08, 0.11), wh, group=gx, name='Dot')


# ------------------------------------------------------------------ Skull (FightUI's "N LEFT" pill)
@icon('Skull', view=(-0.2, -1.0, 0.15), fill=0.86, inner=1.1)
def skull():
	bone = mat((242, 244, 250), light=(255, 255, 255), dark=(186, 196, 218))
	g = K.C.new_group()
	ball((0, 0, 0.18), (0.98, 0.9, 0.9), bone, group=g, name='Cranium')
	rbox((0, -0.08, -0.62), (1.0, 0.86, 0.62), 0.24, bone, group=g, name='Jaw')
	ink = flat(K.NAVY)
	ge = K.C.new_group()
	for sx in (-1, 1):
		ball((sx * 0.38, -0.78, 0.0), (0.28, 0.2, 0.3), ink, rot=(0, sx * -12, 0), group=ge, name='Eye')
	slab([(-0.1, -0.26), (0.1, -0.26), (0.0, -0.1)], 0.1, ink, loc=(0, -0.86, 0), r=0.02, group=ge, name='Nose')
	for x in (-0.3, -0.1, 0.1, 0.3):
		rbox((x, -0.5, -0.72), (0.05, 0.12, 0.34), 0.0, ink, group=ge, name='Tooth')


# ------------------------------------------------------------------ Guns: a chunky cartoon pistol (the Items slot)
@icon('Gun', view=(-0.3, -1.0, 0.25), fill=0.9)
def gun():
	steel = mat((122, 136, 164), tiles=0.5, tile_rgb=(166, 182, 210), density=3.6, light=(186, 202, 230), dark=(80, 92, 122))
	dark = mat((64, 68, 86), light=(120, 126, 150))
	wood = mat((168, 92, 46), tiles=0.6, tile_rgb=(206, 132, 76), density=4.5)
	gs = K.C.new_group()
	rbox((0.15, 0, 0.38), (1.9, 0.46, 0.52), 0.09, steel, group=gs, name='Slide')
	rbox((0.98, 0, 0.38), (0.12, 0.38, 0.42), 0.04, steel, group=gs, name='Nose')
	gf = K.C.new_group()
	rbox((0.05, 0, 0.06), (1.5, 0.38, 0.24), 0.06, dark, group=gf, name='Frame')
	cyl((1.06, -0.0, 0.42), 0.12, 0.05, flat(NAVY), rot=(0, 90, 0), group=K.C.new_group(), name='Muzzle')
	gg = K.C.new_group()
	slab([(-0.62, 0.1), (-0.1, 0.1), (-0.28, -0.85), (-0.86, -0.85)], 0.4, wood, r=0.1, group=gg, name='Grip')
	gt = K.C.new_group()
	tube(K.fillet([(0.18, 0, -0.04), (0.2, 0, -0.32), (-0.18, 0, -0.32), (-0.2, 0, -0.06)], 0.1), 0.055, dark, group=gt, name='Guard')
	slab([(-0.02, -0.04), (0.06, -0.04), (0.0, -0.24), (-0.06, -0.22)], 0.1, mat(GOLD), r=0.02, group=K.C.new_group(), name='Trigger')
	gx = K.C.new_group()
	rbox((-0.72, 0, 0.62), (0.18, 0.16, 0.14), 0.04, dark, group=gx, name='Sight')
	rbox((0.96, 0, 0.62), (0.1, 0.12, 0.12), 0.03, dark, group=gx, name='Sight')
	rbox((-0.84, 0, 0.52), (0.14, 0.2, 0.22), 0.04, mat(GOLD), rot=(0, -20, 0), group=K.C.new_group(), name='Hammer')
	rbox((0.25, -0.22, 0.46), (0.5, 0.06, 0.16), 0.03, mat((60, 64, 82)), group=K.C.new_group(), name='Port')


# ------------------------------------------------------------------ Shoes: a chunky sneaker (the Pets slot)
@icon('Sneaker', view=(-0.34, -1.0, 0.3), fill=0.9)
def sneaker():
	"""A red high-top: rounded side profile, thick white sole, white toe cap, laces up the slope, yellow side stripe."""
	upper = mat((232, 40, 56), tiles=0.6, tile_rgb=(255, 108, 120), density=3.0)
	W = 0.94
	prof = [(-1.0, 0.32), (0.95, 0.32), (1.2, 0.46), (1.12, 0.68), (0.8, 0.8), (0.35, 0.93), (-0.15, 1.45), (-0.3, 1.72),
		(-0.95, 1.7), (-1.14, 1.35), (-1.14, 0.6)]
	slab(prof, W, upper, r=0.2, seg=5, group=K.C.new_group(), name='Upper')
	sole = mat((246, 247, 250), light=(255, 255, 255), dark=(186, 200, 222))
	slab([(-1.2, 0.0), (1.08, 0.0), (1.36, 0.14), (1.32, 0.42), (1.0, 0.44), (-1.22, 0.44), (-1.3, 0.22)], W + 0.12, sole, r=0.13, seg=4,
		group=K.C.new_group(), name='Sole')
	slab([(-1.18, -0.08), (1.08, -0.08), (1.3, 0.04), (-1.26, 0.04)], W + 0.08, mat((84, 100, 140)), r=0.05, group=K.C.new_group(), name='Outsole')
	slab([(0.5, 0.36), (1.0, 0.36), (1.24, 0.48), (1.16, 0.7), (0.86, 0.8), (0.55, 0.7)], W + 0.05, sole, r=0.15, seg=4,
		group=K.C.new_group(), name='ToeCap')
	slab([(-0.5, 1.5), (-0.18, 1.48), (-0.08, 1.9), (-0.42, 1.94)], 0.6, mat((248, 76, 92), tiles=0.5, tile_rgb=(255, 140, 150), density=3.0),
		r=0.1, group=K.C.new_group(), name='Tongue')
	ball((-0.66, 0.0, 1.73), (0.3, 0.33, 0.06), mat((80, 24, 44)), group=K.C.new_group(), name='Opening')
	lace = mat((250, 250, 252), light=(255, 255, 255), dark=(196, 206, 226))
	gl = K.C.new_group()
	a = math.atan2(1.45 - 0.93, 0.35 + 0.15)
	nrm = (math.sin(a), math.cos(a))
	for kk in range(4):
		t = 0.12 + 0.25 * kk
		x, z = 0.35 - 0.5 * t, 0.93 + 0.52 * t
		rbox((x + nrm[0] * 0.05, 0, z + nrm[1] * 0.05), (0.15, W + 0.08, 0.11), 0.045, lace, rot=(0, math.degrees(a), 0), group=gl, name='Lace')
	sw = [(-0.85, 0.62), (-0.2, 0.5), (0.4, 0.52), (0.78, 0.66), (0.4, 0.64), (-0.15, 0.68), (-0.7, 0.86)]
	slab(sw, 0.06, mat((255, 204, 34), light=(255, 246, 170)), loc=(0, -W / 2 - 0.015, 0.05), r=0.02, group=K.C.new_group(), name='Stripe')
	ball((-0.62, -W / 2 - 0.01, 1.28), (0.2, 0.04, 0.2), mat((250, 250, 252), light=(255, 255, 255)), group=K.C.new_group(), name='Patch')
	rbox((-1.15, 0, 1.45), (0.14, 0.36, 0.44), 0.05, mat((255, 204, 34)), group=K.C.new_group(), name='HeelTab')


def render_icon(iid, out_dir, res, ss, samples):
	t0 = time.time()
	spec = ICONS[iid]
	sc = K.reset(res * ss, samples)
	K.world(sc)
	spec['fn']()
	cam, centre, dist = K.frame_camera(sc, spec['view'], spec['fill'], spec['lens'], spec['roll'])
	K.lights(sc, cam, centre, dist, spec['opts'].get('key', 1.0))
	tmp = tempfile.mkdtemp(prefix='hd_')
	raw = os.path.join(tmp, 'beauty.png')
	K.compositor_index(sc, os.path.join(tmp, 'ix_'))
	sc.render.filepath = raw
	bpy.ops.render.render(write_still=True)
	ix = [f for f in os.listdir(tmp) if f.startswith('ix_')]
	out_png = os.path.join(out_dir, iid + '.png')
	K.finish(raw, os.path.join(tmp, ix[0]) if ix else '', out_png, ss, spec['opts'])
	for f in os.listdir(tmp):
		os.remove(os.path.join(tmp, f))
	os.rmdir(tmp)
	print('rendered %s in %.1fs' % (out_png, time.time() - t0), flush=True)


def main(argv):
	ap = argparse.ArgumentParser()
	ap.add_argument('ids', nargs='*')
	ap.add_argument('--res', type=int, default=512)
	ap.add_argument('--ss', type=int, default=2)
	ap.add_argument('--samples', type=int, default=40)
	ap.add_argument('--out', default=K.OUT)
	ap.add_argument('--list', action='store_true')
	a = ap.parse_args(argv)
	if a.list:
		print(' '.join(ICONS))
		return
	for iid in a.ids or list(ICONS):
		render_icon(iid, a.out, a.res, a.ss, a.samples)


if __name__ == '__main__':
	main(sys.argv[1:])
