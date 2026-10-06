"""Render BoxKit models with Cycles.

Usage (Blender as a Python module):
  blenv/bin/python hood/tools/blender/render.py guns [ids...] [--res 1024] [--samples 96] [--out DIR]
  blenv/bin/python hood/tools/blender/render.py icons [ids...] [--res 512]
  blenv/bin/python hood/tools/blender/render.py turntable [--res 384]
  blenv/bin/python hood/tools/blender/render.py sheets          (contact sheets from finished renders)

Default outputs: hood/art/renders/guns/<Id>.png, hood/art/icons3d/<Id>.png, hood/art/renders/*.png.
`compare` renders also write <out>.cam.json (camera in model space, DU) for compare.sh to replay.
"""
import argparse
import json
import math
import os
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
tempfile.tempdir = os.environ.get('BK_TMP') or None  # where intermediate render passes go

import bk_blender as bb  # noqa: E402
from models import guns, icons  # noqa: E402

HOOD = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT_GUNS = os.path.join(HOOD, 'art', 'renders', 'guns')
OUT_ICONS = os.path.join(HOOD, 'art', 'icons3d')
OUT_SHEETS = os.path.join(HOOD, 'art', 'renders')

# View directions point from the model toward the camera, in Roblox space.
GUN_VIEW = (1.0, 0.42, -0.42)    # right side, a little above and in front: muzzle points screen-right
ICON_VIEW = (-0.32, 0.36, -1.0)  # front (-z) with a little top and side showing


# Render-only rarity bling for the top tiers: (halo colour, halo strength, sparkle count).
BLING = {
	7: ((1.0, 0.78, 0.25), 0.45, 3),
	8: ((1.0, 0.3, 0.25), 0.45, 3),
	9: ((0.75, 0.4, 1.0), 0.55, 4),
	10: ((0.45, 0.9, 1.0), 0.65, 6),
}


def render_model(model, out_png, res, samples, view, fill=0.84, lens=70.0, outline=None, glow=1.0, roll=0.0, rim=1.0, shadow=0.35, bling=None, cam_json=False):
	t0 = time.time()
	sc = bb.reset_scene()
	bb.setup_render(sc, res, samples)
	bb.world(sc, 0.85)
	objs = bb.build(model)
	pts = bb.scene_bounds(objs)
	cam, centre, dist = bb.camera_fit(sc, pts, view, fill, lens, roll=roll)
	bb.light_rig(sc, cam, centre, dist, rim=rim)
	tmp = tempfile.mkdtemp(prefix='bk_')
	raw = os.path.join(tmp, 'beauty.png')
	bb.compositor_emission(sc, os.path.join(tmp, 'em_'))
	bb.render_to(sc, raw)
	px = outline if outline is not None else max(4, int(res / 100))
	os.makedirs(os.path.dirname(out_png), exist_ok=True)
	extra = {}
	if bling:
		col, strength, n = bling
		extra = dict(backglow=(*col, strength), sparkles=n, seed=sum(map(ord, model.id)))
	bb.finish(raw, os.path.join(tmp, 'em_emit.png'), out_png, outline_px=px, glow=glow, shadow=shadow, **extra)
	# Camera in Roblox model space (DU) for side-by-side checks against the Luau build.
	loc_b = cam.matrix_world.translation
	look_b = centre
	inv = bb.R2B.inverted()
	up_b = cam.matrix_world.to_3x3().col[1]
	cam_info = {
		'pos': list(inv @ loc_b), 'look': list(inv @ look_b), 'up': list(inv @ up_b), 'fov': math.degrees(cam.data.angle),
		'unit': model.unit, 'res': res,
	}
	if cam_json:
		with open(out_png[:-4] + '.cam.json', 'w') as f:
			json.dump(cam_info, f, indent=1)
	print('rendered %s in %.1fs' % (out_png, time.time() - t0), flush=True)
	return cam_info


def gun_roll(m):
	"""Tilt long guns diagonally (muzzle up) so they fill a square frame."""
	lo, hi = m.bounds()
	ratio = (hi[2] - lo[2]) / (hi[1] - lo[1])
	return -max(6.0, min(28.0, (ratio - 1.2) * 13.0))


def pick(models, ids):
	return [m for m in models if not ids or m.id in ids]


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('what', choices=['guns', 'icons', 'turntable', 'sheets', 'compare', 'all'])
	ap.add_argument('ids', nargs='*')
	ap.add_argument('--res', type=int)
	ap.add_argument('--samples', type=int, default=96)
	ap.add_argument('--out')
	ap.add_argument('--look', help='tuning: key=value,... for bk_blender.LOOK')
	args = ap.parse_args()
	if args.look:
		for kv in args.look.split(','):
			k, v = kv.split('=')
			bb.LOOK[k] = v if k in ('view', 'contrast') else float(v)
	if args.what in ('guns', 'all'):
		out = args.out or OUT_GUNS
		for m in pick(guns.build_all(), args.ids):
			render_model(m, os.path.join(out, m.id + '.png'), args.res or 1024, args.samples, GUN_VIEW, fill=0.84, outline=None, glow=1.0, roll=gun_roll(m), bling=BLING.get(m.meta['tier']))
	if args.what in ('icons', 'all'):
		out = args.out or OUT_ICONS
		for m in pick(icons.build_all(), args.ids):
			render_model(m, os.path.join(out, m.id + '.png'), args.res or 512, args.samples, m.meta.get('view', ICON_VIEW), fill=0.80, lens=60.0, outline=None, glow=0.8)
	if args.what in ('turntable', 'all'):
		# Four angles per gun into a temp folder; only the assembled sheet lands in hood/art/renders.
		import sheets
		out = args.out or tempfile.mkdtemp(prefix='bk_turntable_')
		yaws = [-150, -90, -35, 35]
		for m in pick(guns.build_all(), args.ids):
			for k, yaw in enumerate(yaws):
				a = math.radians(yaw)
				view = (math.cos(a), 0.45, math.sin(a))
				render_model(m, os.path.join(out, '%s_%d.png' % (m.id, k)), args.res or 320, min(args.samples, 48), view, fill=0.84, outline=3, shadow=0.0)
		sheets.turntable(tempfile.mkdtemp(prefix='bk_sheets_'), out)
	if args.what == 'compare':
		# Plain shots (no tilt, outline or glow) whose cameras verify/compare.sh replays in three.js.
		out = args.out or os.path.join(OUT_SHEETS, 'compare', 'blender')
		for m in pick(guns.build_all(), args.ids):
			render_model(m, os.path.join(out, m.id + '.png'), args.res or 400, min(args.samples, 32), GUN_VIEW, fill=0.8, outline=0, glow=0, shadow=0, cam_json=True)
		for m in pick(icons.build_all(), args.ids):
			render_model(m, os.path.join(out, m.id + '.png'), args.res or 400, min(args.samples, 32), m.meta.get('view', ICON_VIEW), fill=0.8, lens=60.0, outline=0, glow=0, shadow=0, cam_json=True)
	if args.what in ('sheets', 'all'):
		import sheets
		sheets.make_all()


if __name__ == '__main__':
	main()
