# sketch.py: a labelled top-down sketch of World 1 drawn from the built place file (Oct 28, the owner: "make me a
# sketch of the first world map"). Every visible part is drawn as its footprint, lowest first, the lobby roof left off.
# Usage (from the repo root):
#   lune run hood/tools/map/sketch_dump.luau hood/places/HoodEvolution.rbxl <tmp>/parts.json
#   python3 -I hood/tools/map/sketch.py <tmp>/parts.json [out dir]     (default: hood/art/renders/map-sketch)
# Writes world1_all.jpg (the whole map, north up: the lobby at the bottom, the Boss Yard at the top) and world1_lobby.jpg.
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
HOOD = os.path.abspath(os.path.join(HERE, '..', '..'))
FONT = os.path.join(HOOD, 'tools', 'preview', 'render14', 'fonts', 'Montserrat-Variable.ttf')


def font(size):
	f = ImageFont.truetype(FONT, size)
	try:
		f.set_variation_by_axes([900])
	except Exception:
		pass
	return f


def keep(p):
	path, name = p[13], p[12]
	if 'Roof' in path or name.startswith('Roof') or name == 'Glass':
		return False
	return p[3] * p[5] >= 0.6


def draw(parts, box, scale, out, labels, title, outline_min=6):
	x0, z0, x1, z1 = box
	w, h = int((x1 - x0) * scale), int((z1 - z0) * scale)
	im = Image.new('RGB', (w, h + 70), (122, 190, 96))
	d = ImageDraw.Draw(im)

	def at(x, z):
		return ((x - x0) * scale, (z - z0) * scale + 70)

	for p in parts:
		x, y, z, sx, sy, sz, rx, ry, rz = p[:9]
		r = max(sx, sz)
		if x + r < x0 or x - r > x1 or z + r < z0 or z - r > z1:
			continue
		hx, hz = sx / 2, sz / 2
		if abs(rx) > 0.3 or abs(rz) > 0.3:  # a tilted part: its projected size, roughly
			hx, hz = max(sx, sy) / 2, max(sz, sy) / 2
		c, s = math.cos(ry), math.sin(ry)
		pts = [at(x + ax * c + az * s, z - ax * s + az * c) for ax, az in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz))]
		col = tuple(min(255, int(v * 0.9 + 25)) for v in p[9:12])
		d.polygon(pts, fill=col, outline=(60, 52, 80) if r * scale > outline_min else None)
	d.rectangle([0, 0, w, 70], fill=(36, 30, 58))
	d.text((16, 14), title, fill='white', font=font(34))
	for txt, x, z, size in labels:
		px, py = at(x, z)
		f = font(size)
		d.text((px - d.textlength(txt, font=f) / 2, py - size / 2), txt, fill='white', font=f,
			stroke_width=max(3, size // 6), stroke_fill=(30, 24, 48))
	im.save(out, quality=90)


def main(src, out_dir):
	parts = sorted((p for p in json.load(open(src)) if keep(p)), key=lambda p: p[1] + p[4] / 2)
	os.makedirs(out_dir, exist_ok=True)
	labels = [('LOBBY (spawn)', 2400, 90, 30), ('BOSS YARD', 2400, -1010, 30), ('Ring road', 2266, -540, 16)]
	labels += [('Stage %d' % i, 2305, -32 - 64 * (i - 1), 20) for i in range(1, 16)]
	draw(parts, (2240, -1100, 2560, 180), 1.6, os.path.join(out_dir, 'world1_all.jpg'), labels, 'World 1: the whole map', 10)
	labels = [('SPAWN', 2400, 62, 26), ('Stage 1 gate', 2400, -6, 26), ('Training ranges', 2346, 55, 24),
		('Gun shop', 2436, 55, 24), ('Shoe boxes', 2400, 104, 24), ('Robux pads', 2400, 36, 18), ('World 2 door', 2344, 100, 16),
		('Leaderboards', 2457, 96, 16), ('Codes', 2452, 23, 14), ('Spin wheel', 2470, 28, 14), ('Group chest', 2338, 20, 14)]
	draw(parts, (2285, -20, 2515, 145), 6, os.path.join(out_dir, 'world1_lobby.jpg'), labels, 'World 1: the lobby (roof off)')


if __name__ == '__main__':
	main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else os.path.join(HOOD, 'art', 'renders', 'map-sketch'))
