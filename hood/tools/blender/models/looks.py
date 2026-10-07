"""The 15 looks (Config/Skins.lua) as Cycles cards: hood/art/looks/<Id>.png, 512 px, transparent.

The looks are authored in Luau (Shared/SkinArt.lua), so this goes the other way round from guns/icons:
the preview harness builds every look's posed display figure exactly as the game does and exports the
parts to JSON; each figure's parts become BoxKit primitives here and render with the BoxKit look
(bk_blender: materials, light rig, outline, rarity halo). What the card shows is what the podium builds.

Usage (Blender as a Python module, Lune 0.10.5 on PATH or in $LUNE):
  blenv/bin/python hood/tools/blender/models/looks.py [ids...] [--res 512] [--samples 96] [--out DIR]
  blenv/bin/python hood/tools/blender/models/looks.py --scene scene.json ...   (reuse an export)
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = os.path.dirname(HERE)
sys.path.insert(0, BLENDER_DIR)
HOOD = os.path.abspath(os.path.join(BLENDER_DIR, '..', '..'))

import boxkit as bk  # noqa: E402

tempfile.tempdir = os.environ.get('BK_TMP') or None  # where intermediate render passes go

PITCH = 10  # studs between figures in the export
IDS = ['CornerKid', 'Pickpocket', 'Lookout', 'Bandit', 'Hustler', 'Crook', 'GetawayDriver', 'Enforcer', 'StreetBoss',
	'Gangster', 'Capo', 'Consigliere', 'Underboss', 'TheDon', 'Kingpin']
# SkinArt's gold is bright SmoothPlastic in game; the cards render it as polished gold.
GOLD = {(255, 200, 40), (232, 150, 20)}
# Rarity bands of three (the podium's COMMON..LEGENDARY): halo colour, strength, sparkles.
BANDS = [None, ((0.3, 0.95, 0.45), 0.35, 0), ((0.3, 0.6, 1.0), 0.45, 0), ((0.75, 0.4, 1.0), 0.55, 3), ((1.0, 0.78, 0.25), 0.65, 5)]
VIEW = (-0.55, 0.22, -1.0)  # from the figure toward the camera (Roblox space): front, its left side, a bit above

SNIPPET = '''
local Skins = require(game.ReplicatedStorage.Shared.Config.Skins)
local Art = require(game.ReplicatedStorage.Shared.SkinArt)
local root = Instance.new('Model'); root.Name = 'Looks'; root.Parent = workspace
for i, s in Skins.List do Art.posed(root, CFrame.new((i - 1) * %d, 0, 0), s, 1, s.Pose) end
return #Skins.List
''' % PITCH


def export_scene(path):
	"""Build the posed figures with the preview harness and write the parts JSON."""
	lune = os.environ.get('LUNE') or shutil.which('lune')
	if not lune:
		raise SystemExit('looks.py: set LUNE to the lune 0.10.5 binary (or pass --scene)')
	preview = os.path.join(HOOD, 'tools', 'preview')
	subprocess.run([lune, 'run', 'harness.luau', os.path.join(HOOD, 'src'), path, SNIPPET], cwd=preview, check=True)


def kind_of(p, rgb):
	m = p.get('m')
	if m == 'Neon':
		return 'neon'
	if m == 'Glass':
		return 'glass'
	if m in ('Metal', 'DiamondPlate'):
		return 'metal'
	if m == 'Fabric':
		return 'plastic'
	if rgb in GOLD:
		return 'gold'
	return 'plastic'  # matte: clear-coated flat faces flare white under the rim lights


def model_for(parts, index, look_id):
	"""BoxKit model of figure `index` (1-based) from the exported parts, origin at its feet."""
	m = bk.Model(look_id, unit=1.0, kind='look')
	x0 = (index - 1) * PITCH
	for p in parts:
		cf = p['cf']
		if abs(cf[0] - x0) > PITCH / 2 or p.get('t', 0) >= 0.99:
			continue
		rgb = tuple(int(round(c * 255)) for c in p['c'])
		rot = ((cf[3], cf[4], cf[5]), (cf[6], cf[7], cf[8]), (cf[9], cf[10], cf[11]))
		pos = (cf[0] - x0, cf[1], cf[2])
		size = tuple(p['s'])
		kind = kind_of(p, rgb)
		if p['k'] == 'WedgePart' or p.get('mesh') == 'Wedge':
			prim = bk.Prim('wedge', size, pos, rot, rgb, kind, bevel=0.02, name=p['n'])
		elif p.get('sh') == 'Ball' or p.get('mesh') == 'Sphere':
			d = min(size)
			prim = bk.Prim('ball', (d, d, d), pos, rot, rgb, kind, name=p['n'])
		elif p.get('sh') == 'Cylinder':
			d = min(size[1], size[2])
			prim = bk.Prim('cyl', (size[0], d, d), pos, rot, rgb, kind, bevel=0.02, name=p['n'])
		else:
			prim = bk.Prim('box', size, pos, rot, rgb, kind, bevel=min(0.035, min(size) * 0.3), name=p['n'])
		m.prims.append(prim)
	return m


def render_look(bb, model, index, out_png, res, samples):
	t0 = time.time()
	sc = bb.reset_scene()
	bb.setup_render(sc, res, samples)
	bb.world(sc, 0.85)
	objs = bb.build(model)
	pts = bb.scene_bounds(objs)
	cam, centre, dist = bb.camera_fit(sc, pts, VIEW, 0.9, 70.0)
	bb.light_rig(sc, cam, centre, dist)
	tmp = tempfile.mkdtemp(prefix='looks_')
	raw = os.path.join(tmp, 'beauty.png')
	bb.compositor_emission(sc, os.path.join(tmp, 'em_'))
	bb.render_to(sc, raw)
	band = BANDS[min(len(BANDS), (index + 2) // 3) - 1]
	extra = {}
	if band:
		col, strength, n = band
		extra = dict(backglow=(*col, strength), sparkles=n, seed=index * 7)
	bb.finish(raw, os.path.join(tmp, 'em_emit.png'), out_png, outline_px=max(4, res // 100), glow=0.8, shadow=0.3, **extra)
	shutil.rmtree(tmp, ignore_errors=True)
	print('rendered %s in %.1fs' % (out_png, time.time() - t0), flush=True)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('ids', nargs='*')
	ap.add_argument('--res', type=int, default=512)
	ap.add_argument('--samples', type=int, default=96)
	ap.add_argument('--out', default=os.path.join(HOOD, 'art', 'looks'))
	ap.add_argument('--scene', help='an existing harness export of the posed figures')
	args = ap.parse_args()
	scene = args.scene
	if not scene:
		scene = os.path.join(tempfile.mkdtemp(prefix='looks_scene_'), 'looks.json')
		export_scene(scene)
	parts = json.load(open(scene))['parts']
	import bk_blender as bb  # needs bpy: imported only when rendering
	os.makedirs(args.out, exist_ok=True)
	for i, look_id in enumerate(IDS, 1):
		if args.ids and look_id not in args.ids:
			continue
		render_look(bb, model_for(parts, i, look_id), i, os.path.join(args.out, look_id + '.png'), args.res, args.samples)


if __name__ == '__main__':
	main()
