"""The Store's weekly Featured pack backgrounds (brief 30, round 2): one low-poly, blocky, soft-lit scene per pack, rendered as a
wide banner (the card is 752 x 196, so 1504 x 392) with the item tiles' room left calm in the middle:
  FeaturedBg_Street   Street Pack:     a dusk street of blocky buildings with lit windows, a lamp, crates and a shoe box
  FeaturedBg_Grail    Grail Pack:      a gold vault: a glowing round door, stacked cash, a shoe box on a plinth, gold bars
  FeaturedBg_Sneaker  Sneaker Pack:    a bright sneaker shop wall: shelves of colourful shoe boxes, a neon ring
Usage (Blender as a Python module, see README):  blenv/bin/python hood/tools/blender/featured_bg.py [ids] [--out DIR] [--samples 48]
Default output: hood/art/icons3d/<Id>.png (opaque PNG). The Store draws them with ImageLabels and, until they are uploaded, paints
the same themes with flat shapes (Store.client.lua paintTheme).
"""
import argparse
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import icons_store as S  # noqa: E402
import hdkit as K  # noqa: E402
from hdkit import ball, cyl, mat, rbox  # noqa: E402
from mathutils import Vector  # noqa: E402

W, H = 1536, 576  # (the AI-picture size in AI_ICONS.md; the card crops its centre)
GOLD, GOLD_L, GOLD_D = S.GOLD, S.GOLD_L, S.GOLD_D


def glow(at, r, rgb, strength=3.0, y_depth=0.2):
	"""An emissive disc facing the camera (a soft sun / lamp / portal)."""
	m = mat(rgb, emit=strength, ramp=False, rough=1.0, coat=0.0)
	return cyl(at, r, y_depth, m, rot=(90, 0, 0), r=0.0, group=K.C.new_group(), name='Glow', segs=48)


def floor_wall(wall, floor, tiles=0.45, wy=6.0):
	rbox((0, wy, 3.5), (44, 0.6, 12), 0.0, mat(wall, tiles=tiles, tile_rgb=tuple(min(255, c + 25) for c in wall), density=1.1, bump=0.25, rough=0.7, coat=0.05), name='Wall')
	rbox((0, 1.5, -0.25), (44, 14, 0.5), 0.0, mat(floor, tiles=0.3, tile_rgb=tuple(min(255, c + 18) for c in floor), density=1.1, bump=0.2, rough=0.6, coat=0.1), name='Floor')


def bars_pyramid(x, y, rows=3, z0=0.0):
	for r in range(rows):
		n = rows - r
		for k in range(n):
			rbox((x + (k - (n - 1) / 2) * 1.15, y, z0 + 0.2 + r * 0.38), (1.1, 0.55, 0.36), 0.07, mat(GOLD, light=GOLD_L, dark=GOLD_D, coat=0.6), taper=(0.85, 0.8), name='Bar')


def scene_grail():
	floor_wall((232, 184, 84), (246, 232, 190))
	gold = mat(GOLD, light=GOLD_L, dark=GOLD_D, coat=0.55)
	dark = mat((120, 78, 30), light=(190, 130, 60), dark=(70, 40, 16))
	cx, cz = -0.4, 2.1
	cyl((cx, 5.5, cz), 3.1, 0.5, gold, rot=(90, 0, 0), r=0.05, name='VaultRing', segs=64)
	cyl((cx, 5.2, cz), 2.6, 0.3, dark, rot=(90, 0, 0), r=0.04, name='VaultInner', segs=64)
	glow((cx, 5.0, cz), 2.1, (255, 236, 150), 2.2)
	for k in range(14):
		a = 2 * math.pi * k / 14
		cyl((cx + 2.85 * math.cos(a), 5.2, cz + 2.85 * math.sin(a)), 0.13, 0.2, mat((255, 240, 170), light=(255, 255, 220)), rot=(90, 0, 0), name='Bolt', segs=16)
	for k in range(3):
		S.bundle((-6.1, 1.8, k * 0.8), rz=4 * (k - 1), n=4, s=1.0)
	S.coin_pile((-4.9, 0.6, 0.05), rows=3)
	rbox((2.05, 1.8, 0.55), (2.0, 2.0, 1.1), 0.1, mat((250, 236, 190), tiles=0.3, tile_rgb=(255, 248, 215), density=2.0, dark=(190, 160, 100)), name='Plinth')
	rbox((2.05, 1.8, 1.2), (2.2, 2.2, 0.2), 0.05, gold, name='PlinthTop')
	S.shoe_box((2.05, 1.8, 1.85), (128, 52, 200), (255, 196, 40), s=0.95)
	bars_pyramid(0.0, 0.2, rows=3)
	S.coin_pile((4.4, 0.4, 0.05), rows=3)
	return dict(cam=(0, -20, 3.4), look=(0, 0, 1.7))


def scene_street():
	floor_wall((70, 56, 120), (62, 62, 84), tiles=0.0, wy=9.0)
	rng = random.Random(7)
	x = -8.5
	while x < 8.5:
		h = rng.uniform(3.0, 6.2)
		w = rng.uniform(1.6, 2.4)
		col = rng.choice([(54, 48, 112), (74, 56, 128), (42, 52, 104), (90, 62, 130)])
		rbox((x, 6.4, h / 2), (w, 1.6, h), 0.05, mat(col, tiles=0.25, tile_rgb=tuple(min(255, c + 30) for c in col), density=2.0, rough=0.6, coat=0.1), name='Tower')
		for zz in range(1, int(h / 0.9)):
			for xx in (-0.45, 0.45):
				on = rng.random() > 0.35
				rbox((x + xx * w * 0.6, 5.55, zz * 0.9), (0.34, 0.1, 0.42), 0.02, mat((255, 214, 90) if on else (40, 44, 86), emit=1.1 if on else 0.0, ramp=False), name='Win')
		x += w + 0.15
	rbox((0, 2.2, 0.0), (44, 5, 0.3), 0.0, mat((52, 54, 76), rough=0.8, coat=0.05), name='Road')
	rbox((0, 4.9, 0.1), (44, 1.2, 0.5), 0.05, mat((150, 150, 176), tiles=0.3, density=1.5), name='Walk')
	for k in range(-7, 8):
		rbox((k * 1.4, 2.2, 0.16), (0.7, 0.2, 0.04), 0.0, mat((255, 214, 70), ramp=False), name='Dash')
	# lamp
	rbox((-6.4, 3.8, 1.9), (0.22, 0.22, 3.8), 0.04, mat((70, 70, 96)), name='Pole')
	rbox((-6.0, 3.8, 3.8), (1.0, 0.24, 0.2), 0.04, mat((70, 70, 96)), name='Arm')
	glow((-5.6, 3.7, 3.55), 0.4, (255, 226, 140), 4.0)
	# crates, graffiti, a shoe box
	wood = mat((176, 118, 62), tiles=0.35, tile_rgb=(212, 154, 90), density=2.0, dark=(110, 64, 28), light=(230, 170, 100))
	for (x0, z0) in ((2.4, 0.0), (3.7, 0.0), (3.05, 0.95)):
		rbox((x0, 3.3, 0.5 + z0), (1.25, 1.25, 0.95), 0.07, wood, name='Crate')
	S.shoe_box((3.05, 3.3, 2.0), (255, 90, 120), (255, 230, 90), s=0.7)
	rbox((-4.2, 3.6, 0.55), (1.3, 0.9, 0.9), 0.07, mat((40, 140, 240), light=(130, 200, 255), coat=0.5), name='Crate')
	rbox((-4.2, 3.6, 1.2), (1.1, 0.8, 0.45), 0.06, mat((255, 190, 40), light=(255, 240, 150), coat=0.5), name='Crate')
	S.coin_pile((5.6, 2.6, 0.2), rows=2)
	return dict(cam=(0, -20, 2.4), look=(0, 0, 2.3), sky=((0.28, 0.2, 0.5), (0.95, 0.5, 0.38), (0.36, 0.34, 0.72)))


def scene_sneaker():
	"""A bright sneaker shop wall: three shelves of colourful shoe boxes, a neon ring, a display block."""
	floor_wall((118, 188, 246), (236, 240, 250), tiles=0.35)
	wood = mat((196, 140, 80), tiles=0.3, tile_rgb=(224, 170, 108), density=2.0, dark=(120, 70, 30), light=(236, 186, 124))
	cols = [((232, 60, 70), (255, 130, 130)), ((40, 130, 240), (120, 196, 255)), ((255, 160, 30), (255, 214, 100)), ((70, 200, 90), (150, 240, 150)), ((170, 70, 220), (222, 150, 255)), ((255, 220, 50), (255, 246, 150))]
	for row in range(3):
		z = 0.55 + row * 1.35
		rbox((0, 5.0, z), (34, 1.3, 0.16), 0.04, wood, name='Shelf')
		for k in range(-9, 10):
			c, l = cols[(k + row * 2) % len(cols)]
			S.shoe_box((k * 1.55 + (row % 2) * 0.7, 5.0, z + 0.6), c, l, s=0.62)
	ring = mat((255, 70, 170), emit=2.2, ramp=False, rough=1.0, coat=0.0)
	for k in range(36):
		a = 2 * math.pi * k / 36
		rbox((0.0 + 2.4 * math.cos(a), 4.2, 2.1 + 2.4 * math.sin(a)), (0.3, 0.25, 0.3), 0.0, ring, name='Neon')
	rbox((2.6, 2.6, 0.45), (2.4, 1.6, 0.9), 0.08, mat((250, 250, 255), tiles=0.3, tile_rgb=(220, 230, 250), density=2.0), name='Display')
	S.shoe_box((2.6, 2.6, 1.35), (232, 60, 70), (255, 130, 130), s=0.9)
	rbox((-3.0, 2.6, 0.45), (2.0, 1.4, 0.9), 0.08, mat((250, 250, 255), tiles=0.3, tile_rgb=(220, 230, 250), density=2.0), name='Display')
	S.shoe_box((-3.0, 2.6, 1.3), (40, 130, 240), (120, 196, 255), s=0.8)
	return dict(cam=(0, -20, 3.2), look=(0, 0, 1.8))


SCENES = {'FeaturedBg_Street': scene_street, 'FeaturedBg_Grail': scene_grail, 'FeaturedBg_Sneaker': scene_sneaker}


def render(name, out_dir, samples):
	sc = K.reset(W, samples)
	sc.render.resolution_x, sc.render.resolution_y = W, H
	sc.render.film_transparent = False
	sc.view_settings.exposure = 0.55
	K.world(sc)
	spec = SCENES[name]()
	cam_d = bpy.data.cameras.new('Cam')
	cam_d.lens = 50
	cam = bpy.data.objects.new('Cam', cam_d)
	sc.collection.objects.link(cam)
	cam.location = spec['cam']
	cam.rotation_euler = (Vector(spec['look']) - Vector(spec['cam'])).to_track_quat('-Z', 'Y').to_euler()
	sc.camera = cam
	K.lights(sc, cam, spec['look'], 20.0, 1.0)
	if spec.get('sky'):
		nt = sc.world.node_tree
		ramp = [n for n in nt.nodes if n.bl_idname == 'ShaderNodeValToRGB'][0].color_ramp
		for el, c in zip(ramp.elements, spec['sky']):
			el.color = (c[0], c[1], c[2], 1)
	out = os.path.join(out_dir, name + '.png')
	sc.render.filepath = out
	bpy.ops.render.render(write_still=True)
	print('rendered', out, flush=True)


def main(argv):
	ap = argparse.ArgumentParser()
	ap.add_argument('ids', nargs='*')
	ap.add_argument('--out', default=K.OUT)
	ap.add_argument('--samples', type=int, default=48)
	a = ap.parse_args(argv)
	os.makedirs(a.out, exist_ok=True)
	for n in a.ids or list(SCENES):
		render(n, a.out, a.samples)


if __name__ == '__main__':
	main(sys.argv[1:])
