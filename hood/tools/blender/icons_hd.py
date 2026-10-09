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
import numpy as np  # noqa: E402

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


@icon('DoublePower', view=(-0.3, -1.0, 0.42), fill=0.9, sparkles=3, seed=4, glow=((1.0, 0.82, 0.3), 0.4))
def double_power():
	"""The 2x Power card art (UICRITIC P2-7): a hard, detailed object like the reference's studded punching bags: a gold
	dumbbell with octagonal studded plates, riveted faces, steel collars and a knurled grip. No text (UI3 adds the
	sticker)."""
	dumbbell_parts()


def dumbbell_parts(rot=(0, -16, 40), loc=(0, 0, 0), scale=1.0):
	gold = mat(GOLD, tiles=0.85, tile_rgb=GOLD_TILE, density=6.0, rough=0.26, coat=0.5, dark=(214, 110, 18), light=(255, 222, 96))
	rim = mat((232, 136, 18), light=(255, 196, 64), dark=(196, 96, 14), rough=0.3, coat=0.4)
	steel = mat((196, 206, 222), light=(246, 250, 255), dark=(112, 124, 150), rough=0.24, coat=0.6)
	knurl = mat((70, 74, 96), tiles=0.6, tile_rgb=(120, 126, 150), density=14.0, light=(120, 126, 150))
	piv = bpy.data.objects.new('Dumbbell', None)
	bpy.context.scene.collection.objects.link(piv)
	parts = []
	parts.append(cyl((0, 0, 0), 0.13, 2.7, steel, rot=(0, 90, 0), r=0.03, group=K.C.new_group(), name='Bar'))
	parts.append(cyl((0, 0, 0), 0.18, 0.9, knurl, rot=(0, 90, 0), r=0.04, group=K.C.new_group(), name='Grip'))
	for sx in (-1, 1):
		parts.append(cyl((sx * 0.56, 0, 0), 0.27, 0.16, steel, rot=(0, 90, 0), r=0.05, group=K.C.new_group(), name='Collar'))
		g = K.C.new_group()
		parts.append(cyl((sx * 0.82, 0, 0), 0.86, 0.36, gold, rot=(0, 90, 22.5), r=0.07, sides=8, group=g, name='PlateBig'))
		parts.append(cyl((sx * 0.82, 0, 0), 0.9, 0.14, rim, rot=(0, 90, 22.5), r=0.05, sides=8, group=g, name='Rim'))
		g2 = g
		parts.append(cyl((sx * 1.16, 0, 0), 0.66, 0.3, gold, rot=(0, 90, 22.5), r=0.06, sides=8, group=g2, name='PlateSmall'))
		face = sx * (1.16 + 0.155)
		for k in range(8):
			a = math.radians(22.5 + 45 * k)
			parts.append(ball((face, 0.47 * math.cos(a), 0.47 * math.sin(a)), 0.065, steel, group=g2, name='Rivet', seg=16))
		parts.append(cyl((sx * 1.38, 0, 0), 0.24, 0.14, steel, rot=(0, 90, 0), r=0.05, group=g, name='Cap'))
	for o in parts:
		o.parent = piv
	place(piv, loc, rot, (scale, scale, scale))


# ------------------------------------------------------------------ Rebirth: the red and white circular arrows
def ring_arrow(a0, ah, a1, col, tile, rin=0.4, rout=1.0, depth=0.46, tiles=0.75, group=None, density=4.4, barb_out=0.24,
		barb_in=0.0):
	"""One thick curved arrow of the Rebirth icon (the reference's "hollow ring of two arrows"): a flat ring band
	clockwise from a0 to ah, then the head from ah to a1. The head's base is wider than the band (a barb outside, a tab
	in the hole); its leading edge runs from the tab across the band to the tip on the OUTER edge, so the boundary with
	the other arrow is one clean diagonal, as in the reference."""
	g = group or K.C.new_group()
	m = mat(col, tiles=tiles, tile_rgb=tile, density=density, rough=0.32, coat=0.35)
	K.arc_band(a0, ah, rin, rout, rin, rout, depth, m, steps=40, corner=0.1, group=g, name='Arc')
	K.arc_band(ah, a1, rin - barb_in, rout + barb_out, rout - 0.1, rout + 0.02, depth + 0.04, m, steps=24, corner=0.1, group=g,
		name='Head', y=-0.03)
	return g


def rebirth_icon(col, tile):
	# Reference (user_26/27): red over the top, its head at ~1-2 o'clock with the tip at ~4 on the outer edge; white
	# underneath, its head at ~7-8 o'clock with the tip at ~10. Each head covers the start of the other arrow, which
	# leaves the S-shaped dark gap in the hole.
	# (UICRITIC2 r2) two separate arrows with a ~20 deg gap at each head, the hole kept open (small tabs):
	# red from ~10:30 over the top, head at ~1:30-3 o'clock; white from ~4 o'clock under, head at ~7:30-9 pointing up-left
	ring_arrow(170, 60, 5, col, tile, rin=0.47)
	ring_arrow(-10, -120, -175, WHITE, WHITE_TILE, tiles=0.45, rin=0.47)


@icon('Rebirth', view=(-0.32, -1.0, 0.26), fill=0.84)
def rebirth():
	rebirth_icon(RED, RED_TILE)


@icon('RebirthSkip', view=(-0.32, -1.0, 0.26), fill=0.84)
def rebirth_skip():
	rebirth_icon(GREEN, GREEN_TILE)


# ------------------------------------------------------------------ Store: the baskets
def basket(body, tile, inside, handle=STEEL, holes=False, dark=None, inside_light=None, streak=False, corner_streak=False,
		top=(2.2, 1.6), bottom=(1.42, 1.02), height=1.27, handle_tilt=-28, handle_lift=0.0):
	g = K.C.new_group()
	m_out = mat(body, tiles=1.0 if holes else 0.0, tile_rgb=tile, density=1.8, rough=0.36, coat=0.3, dark=dark)
	m_in = mat(inside, tiles=1.0 if holes else 0.0, tile_rgb=tile, density=1.8, rough=0.4, coat=0.15, light=inside_light)
	tub(top, bottom, height, 0.14, m_out, m_in, loc=(0, 0, -0.62), r=0.07, group=g, name='Tub')
	if streak:  # the reference's white specular streak down the front-left corner
		tube([(-0.78, -0.57, -0.42), (-0.98, -0.72, 0.28)], 0.035, flat((255, 255, 255)), group=g, name='Streak')
	if corner_streak:  # down the front-left corner, which faces the camera once the basket is turned
		tube([(-0.62, -0.58, -0.45), (-0.9, -0.85, 0.82)], 0.045, flat((255, 255, 255)), group=g, name='Streak')
	mh = mat(handle, rough=0.32, coat=0.4)
	pts = [(-0.96, 0.0, -0.1), (-0.96, 0.0, 0.56), (0.96, 0.0, 0.56), (0.96, 0.0, -0.1)]
	h = bar(pts, 0.22, 0.22, mh, rr=0.35, corner=0.2, group=K.C.new_group(), name='Handle')
	h.location = (0, 0.05, 0.62 + handle_lift)
	h.rotation_euler = (math.radians(handle_tilt), 0, 0)


@icon('Basket', view=(-0.2, -1.0, 0.6), fill=0.88)
def basket_orange():
	# (brief 22, ref22_hud_buttons) the HUD Store basket is turned ~40 deg so a front corner (with the white streak)
	# points at the camera, seen from ~30 deg above
	xform(basket, (0, 0, 0), (0, 0, 38), 1.0, (252, 140, 24), (255, 196, 80), (255, 200, 70), handle=(130, 162, 200), dark=(240, 108, 26), inside_light=(255, 226, 110),
		streak=False, corner_streak=True, top=(1.9, 1.8), bottom=(1.3, 1.2), height=1.62, handle_tilt=-8, handle_lift=0.35)


@icon('Shop', view=(-0.2, -1.0, 0.6), fill=0.88)
def shop_legacy():
	"""Legacy id (only a fallback of Basket): the same orange basket."""
	basket_orange()


@icon('BasketRed', view=(0.45, -1.0, 0.38), fill=0.88)
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
def bills(at=(0, 0, 0), rz=0.0, n=4, one_group=False):
	"""A stack of n bills; one_group: the seal, $ and band share the stack's line group (piles: fewer inner lines)."""
	g = K.C.new_group()
	bill = mat((88, 200, 78), tiles=0.45, tile_rgb=(150, 236, 120), density=3.0, light=(170, 246, 140), dark=(48, 150, 60))
	edge = mat((44, 146, 62), light=(90, 196, 90))
	for kk in range(n):
		z = at[2] + kk * 0.13
		rbox((at[0] + (kk % 2) * 0.03, at[1], z), (2.0, 1.02, 0.1), 0.035, bill if kk == n - 1 else edge, rot=(0, 0, rz + (kk - n / 2) * 2.5), group=g, name='Bill')
	top = at[2] + (n - 1) * 0.13 + 0.06
	ge = g if one_group else K.C.new_group()
	ball((at[0] - 0.2, at[1], top), (0.42, 0.34, 0.04), mat((50, 156, 64), light=(80, 190, 90)), rot=(0, 0, rz), group=ge, name='Seal')
	t = text('$', mat((236, 255, 220), light=(255, 255, 255)), loc=(at[0] - 0.2, at[1], top + 0.02), size=0.6, depth=0.03, rot=(0, 0, rz), bev=0.012, group=g if one_group else K.C.new_group(), name='Dollar')
	gb = g if one_group else K.C.new_group()
	rbox((at[0] + 0.55, at[1], at[2] + (n - 1) * 0.065), (0.34, 1.08, (n - 1) * 0.13 + 0.16), 0.03, mat((250, 236, 200)), rot=(0, 0, rz), group=gb, name='Band')
	return t


def coin(at, rot, r=0.42, dollar=True, flat_face=False, group=None):
	g = group or K.C.new_group()
	gold = mat(GOLD, light=(255, 230, 120), dark=(220, 120, 20))
	ob = cyl((0, 0, 0), r, 0.14, gold, r=0.045, group=g, name='Coin')
	parts = [ob]
	if dollar:
		parts.append(cyl((0, 0, 0.075), r * 0.74, 0.02, mat((236, 140, 20), light=(255, 196, 70)), r=0.0, group=g, name='Face'))
		parts.append(text('$', mat((255, 232, 120), light=(255, 250, 210)), loc=(0, 0, 0.1), size=r * 1.35, depth=0.03, rot=(0, 0, 0), bev=0.012, group=g if flat_face else K.C.new_group(), name='CoinDollar'))
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
	g = K.C.new_group()  # one line group per stack: no navy rings between its coins
	for kk in range(n):
		coin((at[0] + 0.03 * (kk % 2), at[1], at[2] + kk * 0.15), (0, 0, 20 * kk), r=r, dollar=(kk == n - 1), flat_face=True, group=g)


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


@icon('Evolve', view=(-0.22, -1.0, 0.72), fill=0.86)
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


@icon('Robux', view=(-0.12, -1.0, 0.12), fill=0.86, inner=1.2, ink=(11, 42, 0))
def robux():
	# (UICRITIC P2-7) the reference's mark: a pure white face with dark-green linework, so the white price buttons read
	# right; gold/lime tints still work since the ink stays dark
	white = mat((250, 251, 252), light=(255, 255, 255), dark=(232, 236, 240), spec=0.1, coat=0.1)
	slab(hexagon(1.0), 0.3, white, r=0.2, group=K.C.new_group(), name='Outer')
	slab(hexagon(0.64), 0.32, white, loc=(0, -0.02, 0), r=0.08, group=K.C.new_group(), name='Inner')
	slab([(-0.11, -0.11), (0.11, -0.11), (0.11, 0.11), (-0.11, 0.11)], 0.05, flat((11, 42, 0)), loc=(0, -0.18, 0), r=0.0, group=K.C.new_group(), name='Hole')


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
	sneaker_parts()


def sneaker_parts(col=(232, 40, 56), tile=(255, 108, 120), tongue=(248, 76, 92), stripe=(255, 204, 34)):
	upper = mat(col, tiles=0.6, tile_rgb=tile, density=3.0)
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
	slab([(-0.5, 1.5), (-0.18, 1.48), (-0.08, 1.9), (-0.42, 1.94)], 0.6, mat(tongue, tiles=0.5, tile_rgb=tile, density=3.0),
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
	slab(sw, 0.06, mat(stripe, light=(255, 246, 170)), loc=(0, -W / 2 - 0.015, 0.05), r=0.02, group=K.C.new_group(), name='Stripe')
	ball((-0.62, -W / 2 - 0.01, 1.28), (0.2, 0.04, 0.2), mat((250, 250, 252), light=(255, 255, 255)), group=K.C.new_group(), name='Patch')
	rbox((-1.15, 0, 1.45), (0.14, 0.36, 0.44), 0.05, mat(stripe), group=K.C.new_group(), name='HeelTab')


# ================================================================== brief 22 (ref22): World, inventory, Store art
def xform(fn, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0, *args, **kw):
	"""Build fn(*args) and move everything it made (meshes and helper empties) as one piece."""
	before = set(bpy.data.objects)
	fn(*args, **kw)
	piv = bpy.data.objects.new('Group', None)
	bpy.context.scene.collection.objects.link(piv)
	for ob in set(bpy.data.objects) - before:
		if ob is not piv and ob.parent is None:
			ob.parent = piv
	place(piv, loc, rot, (scale, scale, scale))
	return piv


# Very rough continent outlines (lon, lat in degrees), enough for a toy globe that reads as Earth at icon size.
CONTINENTS = [
	# North America
	[(-165, 65), (-140, 70), (-110, 72), (-80, 70), (-62, 58), (-55, 48), (-70, 42), (-76, 35), (-81, 25), (-90, 29),
	(-97, 26), (-97, 18), (-87, 15), (-80, 8), (-84, 10), (-92, 15), (-105, 20), (-112, 30), (-118, 34), (-124, 42),
	(-126, 50), (-140, 59), (-160, 58), (-166, 62)],
	# Greenland
	[(-55, 60), (-42, 60), (-20, 72), (-25, 82), (-50, 82), (-60, 76)],
	# South America
	[(-80, 8), (-62, 11), (-50, 2), (-35, -6), (-38, -15), (-48, -26), (-58, -38), (-66, -55), (-72, -50), (-74, -40),
	(-71, -18), (-81, -5)],
	# Africa
	[(-17, 21), (-10, 33), (10, 37), (32, 31), (43, 12), (51, 11), (40, -10), (35, -25), (20, -35), (12, -18), (9, 4),
	(-8, 5), (-17, 14)],
	# Europe + Asia
	[(-10, 36), (-9, 44), (-2, 48), (5, 58), (20, 70), (60, 70), (100, 77), (140, 72), (180, 68), (170, 60), (142, 50),
	(130, 40), (122, 30), (110, 20), (105, 10), (98, 16), (92, 22), (80, 10), (73, 20), (57, 25), (50, 30), (36, 36),
	(28, 41), (20, 38), (12, 44), (3, 43)],
	# Arabia + India bulge, Indochina handled by the polygon above; Australia
	[(114, -22), (122, -18), (135, -12), (145, -15), (153, -27), (147, -38), (138, -35), (130, -32), (115, -34)],
	# Madagascar, UK, Japan (small)
	[(44, -15), (50, -15), (49, -25), (44, -24)],
	[(-6, 50), (2, 51), (0, 58), (-6, 58)],
	[(130, 32), (141, 36), (142, 44), (137, 38)],
]


def land_mask(w=1024, h=512):
	"""Equirectangular land mask (1 = land) from CONTINENTS, as a float array (rows from the north pole down)."""
	ys, xs = np.mgrid[0:h, 0:w]
	lon = xs / w * 360.0 - 180.0
	lat = 90.0 - ys / h * 180.0
	mask = np.zeros((h, w), bool)
	for poly in CONTINENTS:
		inside = np.zeros((h, w), bool)
		n = len(poly)
		for k in range(n):
			x1, y1 = poly[k]
			x2, y2 = poly[(k + 1) % n]
			cond = (y1 > lat) != (y2 > lat)
			xint = (x2 - x1) * (lat - y1) / ((y2 - y1) if y2 != y1 else 1e-9) + x1
			inside ^= cond & (lon < xint)
		mask |= inside
	return mask.astype(np.float32)


def globe_mat():
	"""The reference's glossy globe: light-blue sea and green continents (an equirectangular land mask on a sphere
	projection), each with its own toon ramp, the land raised a little by bump."""
	key = ('globe',)
	if key in K.C.mats:
		return K.C.mats[key]
	m = bpy.data.materials.new('Globe')
	nt = m.node_tree
	bs = nt.nodes.get('Principled BSDF')
	bs.inputs['Roughness'].default_value = 0.3
	bs.inputs['Coat Weight'].default_value = 0.3
	bs.inputs['Specular IOR Level'].default_value = 0.4
	mask = land_mask()
	img = bpy.data.images.new('Land', mask.shape[1], mask.shape[0], alpha=False, float_buffer=True)
	img.colorspace_settings.name = 'Non-Color'
	flipped = mask[::-1]  # Blender images start at the bottom row
	img.pixels.foreach_set(np.dstack([flipped, flipped, flipped, np.ones_like(flipped)]).astype(np.float32).ravel())
	img.pack()
	tc = nt.nodes.new('ShaderNodeTexCoord')
	mp = nt.nodes.new('ShaderNodeMapping')
	mp.inputs['Rotation'].default_value = (0, 0, math.radians(GLOBE_SPIN))
	mp.inputs['Location'].default_value = (0.5, 0.5, 0.5)  # the SPHERE projection is centred on (0.5, 0.5, 0.5)
	nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])
	tex = nt.nodes.new('ShaderNodeTexImage')
	tex.image = img
	tex.projection = 'SPHERE'
	tex.interpolation = 'Linear'
	nt.links.new(mp.outputs['Vector'], tex.inputs['Vector'])
	cr = nt.nodes.new('ShaderNodeValToRGB')
	cr.color_ramp.elements[0].position = 0.45
	cr.color_ramp.elements[0].color = (0, 0, 0, 1)
	cr.color_ramp.elements[1].position = 0.55
	cr.color_ramp.elements[1].color = (1, 1, 1, 1)
	nt.links.new(tex.outputs['Color'], cr.inputs['Fac'])
	geo = nt.nodes.new('ShaderNodeNewGeometry')
	dot = nt.nodes.new('ShaderNodeVectorMath')
	dot.operation = 'DOT_PRODUCT'
	K.C.ldots.append(dot)
	nt.links.new(geo.outputs['Normal'], dot.inputs[0])
	mr = nt.nodes.new('ShaderNodeMapRange')
	mr.inputs['From Min'].default_value = -1.0
	nt.links.new(dot.outputs['Value'], mr.inputs['Value'])

	def ramp(dark, mid, light):
		r = nt.nodes.new('ShaderNodeValToRGB')
		e = r.color_ramp.elements
		e[0].position, e[0].color = 0.25, K.lin(dark)
		e[1].position, e[1].color = 1.0, K.lin(light)
		e.new(0.7).color = K.lin(mid)
		nt.links.new(mr.outputs['Result'], r.inputs['Fac'])
		return r
	sea = ramp((44, 120, 214), (96, 180, 242), (150, 212, 252))
	land = ramp((46, 150, 44), (76, 192, 58), (140, 226, 96))
	mix = nt.nodes.new('ShaderNodeMix')
	mix.data_type = 'RGBA'
	nt.links.new(cr.outputs['Color'], mix.inputs['Factor'])
	nt.links.new(sea.outputs['Color'], mix.inputs['A'])
	nt.links.new(land.outputs['Color'], mix.inputs['B'])
	nt.links.new(mix.outputs['Result'], bs.inputs['Base Color'])
	bump = nt.nodes.new('ShaderNodeBump')
	bump.inputs['Strength'].default_value = 0.3
	bump.inputs['Distance'].default_value = 0.03
	nt.links.new(cr.outputs['Color'], bump.inputs['Height'])
	nt.links.new(bump.outputs['Normal'], bs.inputs['Normal'])
	K.C.mats[key] = m
	return m


GLOBE_SPIN = float(os.environ.get('BK_GLOBE_SPIN', '135'))  # the Atlantic: the Americas left, Africa right


@icon('World', view=(-0.2, -1.0, 0.25), fill=0.84)
def world_globe():
	ball((0, 0, 0), 1.0, globe_mat(), name='Globe', seg=96)


BACKPACK, BACKPACK_TILE, BACKPACK_DARK = (224, 90, 69), (250, 140, 112), (184, 58, 42)


def backpack_parts():
	"""ref22's Items backpack: a puffy rounded red-orange pack (studded), a domed flap with two dark straps and gold
	buckles, a front pocket, a top handle; seen 3/4 so a side pocket shows."""
	body = mat(BACKPACK, tiles=0.75, tile_rgb=BACKPACK_TILE, density=3.2, dark=(176, 50, 36), light=(246, 118, 88))
	dark = mat(BACKPACK_DARK, tiles=0.5, tile_rgb=(230, 96, 80), density=3.2, light=(232, 88, 70))
	g = K.C.new_group()
	rbox((0, 0, -0.1), (1.7, 1.2, 1.6), 0.55, body, seg=8, group=g, name='Body')
	ball((0, -0.04, 0.5), (0.86, 0.62, 0.5), body, group=g, name='Dome')
	gf = K.C.new_group()
	ball((0, -0.12, 0.42), (0.88, 0.6, 0.38), body, group=gf, name='Flap')
	gp = K.C.new_group()
	rbox((0, -0.6, -0.42), (1.12, 0.36, 0.72), 0.2, body, seg=6, group=gp, name='Pocket')
	gs = K.C.new_group()
	for sx in (-1, 1):
		rbox((sx * 0.32, -0.62, 0.12), (0.2, 0.1, 0.8), 0.045, dark, rot=(-12, 0, 0), group=gs, name='Strap')
		rbox((sx * 0.32, -0.7, -0.16), (0.26, 0.1, 0.2), 0.04, mat((255, 214, 80), light=(255, 240, 160)), group=K.C.new_group(), name='Buckle')
	gh = K.C.new_group()
	tube(K.fillet([(-0.3, 0.05, 0.86), (-0.25, 0.05, 1.12), (0.25, 0.05, 1.12), (0.3, 0.05, 0.86)], 0.12), 0.075, dark, group=gh, name='Handle')
	for sx in (-1, 1):
		rbox((sx * 0.86, 0.0, -0.3), (0.26, 0.76, 0.82), 0.12, dark, group=K.C.new_group(), name='SidePocket')


@icon('Backpack', view=(0.5, -1.0, 0.3), fill=0.88)
def backpack():
	backpack_parts()


@icon('ShoePile', view=(-0.34, -1.0, 0.3), fill=0.9)
def shoe_pile():
	"""Your Shoes tab: three sneakers in a heap (the reference's paw pile)."""
	# two sneakers, the same way round: a blue one behind and above, the red one in front (a readable stack: three
	# overlapping shoes turned into dark clutter at tab size)
	xform(sneaker_parts, (0.55, 0.9, 0.75), (0, 6, 0), 0.82, (40, 130, 245), (120, 190, 255), (80, 160, 250), (255, 255, 255))
	xform(sneaker_parts, (-0.3, -0.5, -0.35), (0, -4, 0), 0.95)


@icon('ShoeBox', view=(-0.42, -1.0, 0.5), fill=0.88)
def shoe_box():
	"""Boxes tab: a sneaker box, its lid ajar (the reference's egg slot)."""
	body = mat((255, 140, 30), tiles=0.7, tile_rgb=(255, 196, 90), density=3.4, dark=(236, 104, 20))
	lid = mat((250, 104, 30), tiles=0.6, tile_rgb=(255, 160, 80), density=3.4)
	g = K.C.new_group()
	rbox((0, 0, -0.3), (2.0, 1.25, 0.95), 0.1, body, group=g, name='Box')
	gl = K.C.new_group()
	rbox((0, 0, 0.26), (2.12, 1.37, 0.32), 0.1, lid, rot=(0, -6, 0), group=gl, name='Lid')
	slab([(-0.55, -0.05), (0.5, -0.05), (0.62, 0.05), (0.6, 0.18), (0.25, 0.22), (0.0, 0.42), (-0.3, 0.48), (-0.55, 0.42)], 0.04,
		mat((255, 236, 200), light=(255, 250, 235)), loc=(0, -0.64, -0.38), r=0.01, group=g, name='Emblem')


def x_block(col, tile):
	m = mat(col, tiles=0.85, tile_rgb=tile, density=4.6, rough=0.3, coat=0.4)
	g = K.C.new_group()
	for a, d in ((45, 0.72), (-45, 0.76)):  # different depths: the crossing faces never coincide
		rbox((0, 0, 0), (2.2, d, 0.72), 0.12, m, rot=(0, a, 0), group=g, name='Bar')


@icon('Delete', view=(-0.3, -1.0, 0.35), fill=0.86)
def delete_x():
	x_block((236, 52, 92), (255, 128, 158))


def star_pts(r_out, r_in, n=5, rot=90):
	pts = []
	for k in range(2 * n):
		r = r_out if k % 2 == 0 else r_in
		a = math.radians(rot + 180 * k / n)
		pts.append((r * math.cos(a), r * math.sin(a)))
	return pts


@icon('Favorite', view=(-0.3, -1.0, 0.3), fill=0.86)
def favorite_star():
	slab(star_pts(1.0, 0.47), 0.5, mat(GOLD, tiles=0.8, tile_rgb=GOLD_TILE, density=4.6, rough=0.3, coat=0.4,
		dark=(222, 118, 20), light=(255, 222, 90)), r=0.12, seg=4, name='Star')


@icon('Search', view=(-0.25, -1.0, 0.3), fill=0.86)
def search_glass():
	rim = mat((60, 66, 90), light=(120, 128, 160))
	g = K.C.new_group()
	prof = [(0.11 * math.cos(2 * math.pi * k / 16), 0.11 * math.sin(2 * math.pi * k / 16)) for k in range(16)]
	sweep(arc_frames((0.25, 0, 0.25), 0.62, 0, 360, 64), prof, rim, group=g, name='Ring', caps=False)
	cyl((0.25, 0.02, 0.25), 0.6, 0.06, mat((170, 226, 250), light=(236, 250, 255), spec=0.6, coat=0.8), rot=(90, 0, 0), group=K.C.new_group(), name='Lens')
	rbox((-0.55, 0, -0.55), (0.3, 0.3, 0.95), 0.1, mat((255, 176, 40), light=(255, 220, 110)), rot=(0, -45, 0), group=K.C.new_group(), name='Handle')


def clip_below(poly, zmax):
	"""Sutherland-Hodgman: the part of a 2D polygon (x, z) with z <= zmax."""
	out = []
	n = len(poly)
	for i in range(n):
		a, b = poly[i], poly[(i + 1) % n]
		ina, inb = a[1] <= zmax, b[1] <= zmax
		if ina:
			out.append(a)
		if ina != inb:
			t = (zmax - a[1]) / (b[1] - a[1])
			out.append((a[0] + (b[0] - a[0]) * t, zmax))
	return out


def potion_parts(liquid, liquid_light):
	"""The reference's boost potion: a star-shaped glass bottle (light blue, studded), coloured liquid in its lower
	half, a short neck and a gold cork."""
	glass = mat((176, 228, 252), tiles=0.6, tile_rgb=(226, 246, 255), density=4.0, light=(236, 250, 255), dark=(120, 188, 236),
		rough=0.18, coat=0.7)
	g = K.C.new_group()
	star = [(x, z - 0.12) for (x, z) in star_pts(1.0, 0.58, rot=90)]
	slab(star, 0.62, glass, r=0.1, seg=3, group=g, name='Bottle')
	rbox((0, 0, 0.95), (0.5, 0.5, 0.42), 0.08, glass, group=g, name='Neck')
	liq = clip_below([(x * 0.86, z * 0.86 - 0.05) for (x, z) in star], -0.12)
	slab(liq, 0.66, mat(liquid, tiles=0.6, tile_rgb=liquid_light, density=4.0, light=liquid_light, rough=0.2, coat=0.6), r=0.06,
		seg=3, group=g, name='Liquid')
	rbox((0, 0, 1.25), (0.6, 0.6, 0.32), 0.08, mat((255, 196, 40), tiles=0.6, tile_rgb=(255, 236, 140), density=5.0,
		light=(255, 230, 120)), group=K.C.new_group(), name='Cork')


@icon('PotionRed', view=(-0.18, -1.0, 0.12), fill=0.88)
def potion_red():
	potion_parts((236, 44, 72), (255, 120, 140))


@icon('PotionGold', view=(-0.18, -1.0, 0.12), fill=0.88)
def potion_gold():
	potion_parts((255, 204, 30), (255, 238, 140))


@icon('BoostBundle', view=(-0.18, -1.0, 0.12), fill=0.84, sparkles=3, seed=11, glow=((1.0, 0.6, 0.95), 0.32))
def boost_bundle():
	"""ref42's Boost Bundle art: ONE big star potion tilted ~15 deg on a soft light (no hard burst)."""
	xform(potion_parts, (0, 0, 0), (0, 15, 0), 1.0, (236, 44, 72), (255, 120, 140))


# growing piles for the Cash and Power pack cards (ref41's trophy piles): MOUNDS that fill the art box (height ~75-85%
# of the width) and grow Tiny ~3 items -> Small ~6 -> Medium ~10 -> Large ~15 + sparkles. Cash piles are built round
# green money bags (tall, so the pile is a mound), bill stacks, coins and gold bars; inner lines are thinner (0.6).
CASH_VIEW = (-0.3, -1.0, 0.5)
PILE = dict(inner=0.6)


def money_bag(at=(0, 0, 0), s=1.0, rz=0.0):
	"""A green cash sack tied at the top with a gold cord, a big "$" on the front."""
	g = K.C.new_group()
	sack = mat((70, 176, 70), tiles=0.5, tile_rgb=(130, 220, 120), density=3.0, dark=(40, 128, 50), light=(150, 230, 130))
	x, y, z = at
	ball((x, y, z + 0.62 * s), (0.78 * s, 0.7 * s, 0.68 * s), sack, rot=(0, 0, rz), group=g, name='Sack')
	lathe([(0.18 * s, 0), (0.15 * s, 0.12 * s), (0.2 * s, 0.22 * s), (0.36 * s, 0.4 * s), (0.3 * s, 0.5 * s), (0, 0.52 * s)], sack,
		loc=(x, y, z + 1.18 * s), group=g, name='Neck')
	cord = mat(GOLD, light=(255, 236, 140), dark=(214, 120, 18))
	cyl((x, y, z + 1.24 * s), 0.22 * s, 0.1 * s, cord, r=0.03 * s, group=g, name='Cord')
	text('$', mat((236, 255, 220), light=(255, 255, 255), dark=(190, 236, 170)), loc=(x, y - 0.66 * s, z + 0.6 * s), size=0.72 * s,
		depth=0.06 * s, rot=(90, 0, rz), bev=0.02 * s, group=g, name='BagDollar')


def gold_bar(loc, rz, group=None):
	g = group or K.C.new_group()
	rbox(loc, (0.9, 0.42, 0.3), 0.06, mat(GOLD, light=(255, 236, 140), dark=(214, 120, 18), coat=0.5), rot=(0, 0, rz), taper=(0.82, 0.7),
		group=g, name='Bar')


def flat_coin(at, r=0.36, rz=0.0, tilt=0.0):
	coin(at, (tilt, 0, rz), r=r, flat_face=True)


@icon('CashTiny', view=CASH_VIEW, fill=0.84, **PILE)
def cash_tiny():
	money_bag((0.1, 0.25, 0.0), 1.25)
	bills(at=(-0.5, -0.6, 0.0), rz=-24, n=3, one_group=True)
	flat_coin((0.75, -0.75, 0.05), 0.36, tilt=-10)


@icon('CashSmall', view=CASH_VIEW, fill=0.86, **PILE)
def cash_small():
	money_bag((0.3, 0.45, 0.0), 1.25)
	bills(at=(-0.75, 0.15, 0.0), rz=12, n=4, one_group=True)
	bills(at=(-0.45, -0.75, 0.0), rz=-8, n=3, one_group=True)
	coin_stack((0.95, -0.7, 0.07), n=3, r=0.32)
	flat_coin((0.3, -1.05, 0.05), 0.32, rz=30, tilt=8)
	flat_coin((-1.25, -0.85, 0.05), 0.3, rz=60, tilt=-6)


@icon('CashMedium', view=CASH_VIEW, fill=0.88, sparkles=2, seed=21, **PILE)
def cash_medium():
	money_bag((-0.5, 0.6, 0.0), 1.2)
	money_bag((0.6, 0.75, 0.0), 1.05)
	bills(at=(0.0, -0.05, 0.0), rz=4, n=5, one_group=True)
	bills(at=(-1.15, -0.45, 0.0), rz=14, n=3, one_group=True)
	bills(at=(1.15, -0.4, 0.0), rz=-12, n=3, one_group=True)
	gold_bar((0.0, -0.95, 0.15), 8)
	coin_stack((-0.85, -1.15, 0.07), n=3, r=0.3)
	coin_stack((0.85, -1.1, 0.07), n=2, r=0.3)
	flat_coin((-0.05, -1.45, 0.05), 0.3, rz=20, tilt=6)


@icon('CashLarge', view=CASH_VIEW, fill=0.84, sparkles=4, seed=23, glow=((1.0, 0.85, 0.3), 0.3), **PILE)
def cash_large():
	money_bag((0.0, 1.05, 0.25), 1.35)
	money_bag((-1.05, 0.7, 0.0), 1.1)
	money_bag((1.1, 0.75, 0.0), 1.05)
	for (x, y, z, rz, n) in ((-0.6, 0.0, 0.0, 10, 5), (0.6, 0.05, 0.0, -8, 5), (0.0, -0.3, 0.62, 2, 3), (-1.5, -0.55, 0.0, 16, 3),
			(1.5, -0.5, 0.0, -16, 3)):
		bills(at=(x, y, z), rz=rz, n=n, one_group=True)
	gb = K.C.new_group()
	gold_bar((-0.55, -0.95, 0.15), 14, gb)
	gold_bar((0.55, -1.0, 0.15), -10, gb)
	gold_bar((0.0, -0.95, 0.45), 2, gb)
	coin_stack((-1.25, -1.2, 0.07), n=4, r=0.3)
	coin_stack((1.25, -1.2, 0.07), n=3, r=0.3)
	for k, (x, y) in enumerate(((-0.45, -1.55), (0.4, -1.6))):
		flat_coin((x, y, 0.05), 0.3, rz=25 * k, tilt=(-8, 8)[k])


def kettlebell(loc, s=1.0, group=None):
	g = group or K.C.new_group()
	gold = mat(GOLD, tiles=0.8, tile_rgb=GOLD_TILE, density=6.0, rough=0.26, coat=0.5, dark=(214, 110, 18), light=(255, 222, 96))
	ball((loc[0], loc[1], loc[2] + 0.5 * s), (0.62 * s, 0.6 * s, 0.56 * s), gold, group=g, name='Bell')
	tube(K.fillet([(loc[0] - 0.36 * s, loc[1], loc[2] + 0.8 * s), (loc[0] - 0.3 * s, loc[1], loc[2] + 1.35 * s),
		(loc[0] + 0.3 * s, loc[1], loc[2] + 1.35 * s), (loc[0] + 0.36 * s, loc[1], loc[2] + 0.8 * s)], 0.25 * s), 0.11 * s, gold,
		group=g, name='Handle')


def plate(loc, s=1.0, tilt=0.0):
	g = K.C.new_group()
	gold = mat((236, 140, 20), tiles=0.6, tile_rgb=GOLD_TILE, density=6.0, light=(255, 200, 70), dark=(196, 96, 14))
	cyl(loc, 0.62 * s, 0.18 * s, gold, rot=(tilt, 0, 22.5), r=0.05 * s, sides=8, group=g, name='Plate')
	cyl((loc[0], loc[1], loc[2] + 0.1 * s), 0.16 * s, 0.04 * s, mat((70, 74, 96)), rot=(tilt, 0, 0), group=g, name='Hole')


POWER_VIEW = (-0.3, -1.0, 0.5)


@icon('PowerTiny', view=POWER_VIEW, fill=0.84, **PILE)
def power_tiny():
	kettlebell((0.35, 0.3, 0.0), 1.0)
	xform(dumbbell_parts, (-0.2, -0.55, 0.3), (0, 0, 0), 0.62, (0, -6, 16))
	plate((-0.95, 0.1, 0.1), 0.8)


@icon('PowerSmall', view=POWER_VIEW, fill=0.86, **PILE)
def power_small():
	kettlebell((-0.5, 0.45, 0.0), 0.95)
	kettlebell((0.6, 0.55, 0.0), 0.8)
	xform(dumbbell_parts, (0.0, -0.45, 0.3), (0, 0, 0), 0.62, (0, -6, 10))
	xform(dumbbell_parts, (0.05, -0.15, 0.82), (0, 0, 0), 0.55, (0, 4, -14))
	plate((-1.2, -0.6, 0.1), 0.7)
	plate((1.2, -0.55, 0.1), 0.65)


@icon('PowerMedium', view=POWER_VIEW, fill=0.88, sparkles=2, seed=31, **PILE)
def power_medium():
	kettlebell((0.0, 0.85, 0.3), 1.0)
	kettlebell((-1.0, 0.6, 0.0), 0.85)
	kettlebell((1.0, 0.65, 0.0), 0.8)
	for (x, y, z, rz) in ((-0.5, -0.35, 0.3, 14), (0.55, -0.3, 0.3, -12), (0.0, -0.2, 0.85, 4)):
		xform(dumbbell_parts, (x, y, z), (0, 0, 0), 0.55, (0, -4, rz))
	plate((-1.35, -0.7, 0.1), 0.65)
	plate((1.35, -0.65, 0.1), 0.6)
	plate((0.0, -1.1, 0.1), 0.6)


@icon('PowerLarge', view=POWER_VIEW, fill=0.84, sparkles=4, seed=33, glow=((1.0, 0.8, 0.3), 0.3), **PILE)
def power_large():
	arm(at=(0.0, 1.0, 1.95), size=0.95)
	kettlebell((0.0, 0.85, 0.3), 1.05)
	kettlebell((-1.1, 0.6, 0.0), 0.9)
	kettlebell((1.1, 0.65, 0.0), 0.85)
	for (x, y, z, rz) in ((-0.65, -0.35, 0.3, 14), (0.65, -0.3, 0.3, -12), (0.0, -0.25, 0.85, 4), (-1.4, -0.75, 0.25, 20),
			(1.4, -0.7, 0.25, -18)):
		xform(dumbbell_parts, (x, y, z), (0, 0, 0), 0.52, (0, -4, rz))
	for (x, y) in ((-0.7, -1.2), (0.0, -1.3), (0.7, -1.2)):
		plate((x, y, 0.1), 0.55)


# ------------------------------------------------------------------ shoes and boxes from the game's Luau part models
# The 22 World 1 shoes (ShoeModels) and their 4 boxes (BoxModels), exported by export_luau_parts.luau, re-rendered in
# the icon style. PARTS_JSON is made on demand (see load_parts).
PARTS_JSON = os.environ.get('BK_PARTS_JSON') or os.path.join(tempfile.gettempdir(), 'hood_w1_parts.json')
_PARTS = {}


def load_parts():
	if not _PARTS:
		if not os.path.exists(PARTS_JSON):
			raise SystemExit('missing %s: export it first (see export_luau_parts.luau) or set BK_PARTS_JSON' % PARTS_JSON)
		import json
		for m in json.load(open(PARTS_JSON))['models']:
			_PARTS[m['id']] = m
	return _PARTS


# per-icon colour help for the part models (UICRITIC2 r2: Box_Exclusive read as a near-black block on the blue card)
PART_LOOK = {'Box_Exclusive': dict(lift=0.8, neon=2.2), 'Shoe_MidnightChrome': dict(lift=0.2), 'Shoe_BlackHole': dict(lift=0.2)}


def luau_icon(iid, kind):
	def build():
		m = load_parts()[iid]
		before = set(bpy.data.objects)
		K.import_parts(m['parts'], **PART_LOOK.get(iid, {}))
		piv = bpy.data.objects.new('Pivot', None)
		bpy.context.scene.collection.objects.link(piv)
		for ob in set(bpy.data.objects) - before:
			if ob is not piv and ob.parent is None:
				ob.parent = piv
		if kind == 'shoe':
			# the right shoe, turned so the toe points to the screen-left and the outer side faces the camera a little:
			# the game's own shoe view (ShoeModels.View: front, a little to the side, above) gives the same read
			place(piv, (0, 0, 0), (0, 0, SHOE_YAW))
	return build


SHOE_IDS = ['FreshCanvas', 'RedRocket', 'Checkmate', 'ChromeKicks', 'StreetAngel', 'BlockRoyalty',
	'SprayTag', 'DripTag', 'PaintSplash', 'NeonBomb', 'WildStyle', 'Masterpiece',
	'SilverStreak', 'MidnightChrome', 'RainbowDrip', 'Hologram', 'PlatinumWings',
	'GoldenHour', 'Starlight', 'SolarFlare', 'AstroCrown', 'TheGrail']
SHOE_YAW = float(os.environ.get('BK_SHOE_YAW', '-15'))
SHOE_VIEW = (0.45, -0.8, 0.3)  # ShoeModels.View (Roblox (-0.45, 0.38, -0.8)) in Blender axes
SHOE_GLOW = {'Mythic': ((1.0, 0.35, 0.45), 0.35), 'Secret': ((1.0, 0.9, 0.5), 0.45)}
# the other worlds' shoes and boxes (rendered when time allows; same look)
MORE_SHOE_IDS = os.environ.get('BK_MORE_SHOES', '').split(',') if os.environ.get('BK_MORE_SHOES') else []
MORE_BOX_IDS = ['Frost', 'Lava', 'Toxic', 'Candy', 'Ocean', 'Gem', 'Galaxy', 'Gold']
for _sid in SHOE_IDS + MORE_SHOE_IDS:
	icon('Shoe_' + _sid, view=SHOE_VIEW, fill=0.9, inner=0.6)(luau_icon('Shoe_' + _sid, 'shoe'))
for _bid in ['Street', 'Graffiti', 'Exclusive', 'Grail'] + MORE_BOX_IDS:
	icon('Box_' + _bid, view=(-0.4, -1.0, 0.3), fill=0.9, inner=0.55, sparkles=(3 if _bid in ('Exclusive', 'Grail') else 0),
		seed=7)(luau_icon('Box_' + _bid, 'box'))


def render_icon(iid, out_dir, res, ss, samples):
	t0 = time.time()
	spec = ICONS[iid]
	sc = K.reset(res * ss, samples)
	K.world(sc)
	spec['fn']()
	# LOOK['frame'] shrinks every icon a little to make room for the brief-22 outline weight (4.6% of the canvas)
	cam, centre, dist = K.frame_camera(sc, spec['view'], spec['fill'] * K.LOOK['frame'], spec['lens'], spec['roll'])
	K.lights(sc, cam, centre, dist, spec['opts'].get('key', 1.0))
	tmp = tempfile.mkdtemp(prefix='hd_')
	raw = os.path.join(tmp, 'beauty.png')
	K.compositor_index(sc, os.path.join(tmp, 'ix_'))
	sc.render.filepath = raw
	bpy.ops.render.render(write_still=True)
	ix = [f for f in os.listdir(tmp) if f.startswith('ix_idx')]  # (the depth pass is ix_depth*, read by finish)
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
