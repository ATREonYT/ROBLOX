#!/usr/bin/env python3
"""Make the tileable UI textures in hood/art/ui/ (brief 19): the reference game's stud pattern and gloss band.

Plain python3, no packages:  python3 hood/tools/make_ui_textures.py [--out DIR] [--preview FILE]

Measured on brief/ref17/user_26-28 (stud pitch 22 ref px on the HUD, 42 px on the window headers):
  - a stud is a rounded square ring ~55% of the pitch (corners ~3/64 of the pitch), its rim ~1/12 of the pitch;
  - light comes from the top right: a raised stud has a dark left + bottom edge (an "L") and a light top + right edge;
    a recessed one (the windows alternate them in a checkerboard) is the opposite, with a face ~12% darker; both rims
    show strongly enough (light ~0x70, dark ~0x6B alpha) that every stud reads as a whole square on gold, cyan, red, green;
  - the Store header and the big cards carry two soft diagonal light bands.

Files (all RGBA, transparent where there is no stud):
  stud_tile.png     64x64   one raised stud, GREYSCALE (light edge white, dark edge dark grey): for ImageColor3 tinting
  stud_bevel.png    64x64   one raised stud PRE-SHADED (white highlight + black shadow in alpha): ImageColor3 = white
  stud_checker.png  128x128 2x2 studs, raised/recessed alternating, pre-shaded: TileSize = 2 x pitch
  gloss_band.png    512x128 two diagonal white bands in alpha: ScaleType Stretch over a small block face
  gloss_stripes.png 128x128 one seamless 45-degree light stripe: ScaleType Tile (TileSize ~3 x pitch) over headers/cards
"""
import argparse
import math
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'art', 'ui')

STUD = 0.55    # ring outer size / pitch (the reference's studs are ~55% of the pitch)
LINE = 1 / 12  # ring line width / pitch
CORNER = 3 / 64  # outer corner radius / pitch (3 px on the 64 px tile)
SS = 4         # subsamples per axis (antialiasing)


def write_png(path, w, h, rows):
	"""rows: list of h lists of (r, g, b, a) 0-255 tuples."""
	raw = bytearray()
	for row in rows:
		raw.append(0)
		for (r, g, b, a) in row:
			raw += bytes((r, g, b, a))

	def chunk(tag, data):
		c = struct.pack('>I', len(data)) + tag + data
		return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
	png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
	png += chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, 'wb') as f:
		f.write(png)


def _sd_round_box(x, y, h, r):
	"""Signed distance to a square of half-size h with corners rounded by r (negative inside)."""
	qx, qy = abs(x) - h + r, abs(y) - h + r
	return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - r


def stud_parts(u, v):
	"""For a point (u, v) in a one-stud cell (0..1, v down), which part of the stud it is on:
	'L' (the left/bottom rim), 'T' (the top/right rim), 'F' (the face inside the rim), or None (outside)."""
	h = STUD / 2
	x, y = u - 0.5, v - 0.5
	if _sd_round_box(x, y, h, CORNER) > 0:
		return None
	if _sd_round_box(x, y, h - LINE, max(CORNER - LINE, 0.004)) < 0:
		return 'F'
	# on the rim: split along the two diagonals; the left and bottom sides are the 'L', top and right the 'T'
	if abs(x) >= abs(y):
		return 'L' if x < 0 else 'T'
	return 'L' if y > 0 else 'T'


def shade(part, raised, mode):
	"""(r, g, b, a) floats for one part. mode 'grey' (tintable) or 'bevel' (pre-shaded overlay)."""
	if part is None:
		return (0, 0, 0, 0)
	dark_edge = (part == 'L') if raised else (part == 'T')
	if mode == 'grey':
		if part == 'F':
			return (0.7, 0.7, 0.7, 0.0)
		return (0.22, 0.22, 0.22, 1.0) if dark_edge else (1.0, 1.0, 1.0, 0.9)
	if part == 'F':
		return (1.0, 1.0, 1.0, 0.04) if raised else (0.0, 0.0, 0.0, 0.12)  # recessed face ~12% darker
	return (0.0, 0.0, 0.0, 0.42) if dark_edge else (1.0, 1.0, 1.0, 0.44)  # light rim ~0x70: both rims read


def cell_pixels(n, raised, mode):
	"""n x n pixels of one stud cell, antialiased by SS x SS subsamples (premultiplied average)."""
	rows = []
	for py in range(n):
		row = []
		for px in range(n):
			acc = [0.0, 0.0, 0.0, 0.0]
			for sy in range(SS):
				for sx in range(SS):
					u = (px + (sx + 0.5) / SS) / n
					v = (py + (sy + 0.5) / SS) / n
					r, g, b, a = shade(stud_parts(u, v), raised, mode)
					acc[0] += r * a
					acc[1] += g * a
					acc[2] += b * a
					acc[3] += a
			k = SS * SS
			a = acc[3] / k
			if a > 0:
				rgb = [acc[i] / acc[3] for i in range(3)]
			else:
				rgb = [1.0, 1.0, 1.0] if mode == 'grey' else [0.0, 0.0, 0.0]
			row.append(tuple(int(round(c * 255)) for c in rgb) + (int(round(a * 255)),))
		rows.append(row)
	return rows


def soften(rows, passes=1):
	"""3x3 box blur on premultiplied colour (the reference's studs are slightly soft); wraps (tiles stay seamless)."""
	h, w = len(rows), len(rows[0])
	for _ in range(passes):
		out = []
		for y in range(h):
			row = []
			for x in range(w):
				acc = [0.0, 0.0, 0.0, 0.0]
				for dy in (-1, 0, 1):
					for dx in (-1, 0, 1):
						r, g, b, a = rows[(y + dy) % h][(x + dx) % w]
						acc[0] += r * a
						acc[1] += g * a
						acc[2] += b * a
						acc[3] += a
				if acc[3] > 0:
					row.append(tuple(int(round(acc[i] / acc[3])) for i in range(3)) + (int(round(acc[3] / 9)),))
				else:
					row.append(rows[y][x][:3] + (0,))
			out.append(row)
		rows = out
	return rows


def stripes_pixels(n):
	"""A seamless 45-degree light stripe ('\\' direction): one band per n x n tile."""
	rows = []
	for py in range(n):
		row = []
		for px in range(n):
			t = ((px - py) % n) / n  # 0..1 across the period; constant along x - y: the '\\' direction
			d = abs(t - 0.5) / 0.2
			a = 0.0
			if d < 1:
				a = 0.16 * min(1.0, (1 - d) * 4)
			row.append((255, 255, 255, int(round(a * 255))))
		rows.append(row)
	return rows


def gloss_pixels(w, h):
	"""Two soft diagonal light bands ('\\' direction, like the reference's headers), white in alpha."""
	bands = ((0.30, 0.13, 0.20), (0.62, 0.06, 0.13))  # (centre along the diagonal, half width, alpha)
	rows = []
	for py in range(h):
		row = []
		for px in range(w):
			# coordinate along the block's diagonal, in units of the width (bands keep their angle when stretched)
			t = (px - py * 0.9 + h * 0.9) / (w + h * 0.9)
			a = 0.0
			for (c, hw, al) in bands:
				d = abs(t - c) / hw
				if d < 1:
					edge = min(1.0, (1 - d) * 6)  # soft but crisp edges
					a = max(a, al * edge)
			row.append((255, 255, 255, int(round(a * 255))))
		rows.append(row)
	return rows


def make(out):
	write_png(os.path.join(out, 'stud_tile.png'), 64, 64, soften(cell_pixels(64, True, 'grey')))
	write_png(os.path.join(out, 'stud_bevel.png'), 64, 64, soften(cell_pixels(64, True, 'bevel')))
	a = cell_pixels(64, True, 'bevel')
	b = cell_pixels(64, False, 'bevel')
	rows = [a[y] + b[y] for y in range(64)] + [b[y] + a[y] for y in range(64)]
	write_png(os.path.join(out, 'stud_checker.png'), 128, 128, soften(rows))
	write_png(os.path.join(out, 'gloss_band.png'), 512, 128, gloss_pixels(512, 128))
	write_png(os.path.join(out, 'gloss_stripes.png'), 128, 128, stripes_pixels(128))
	return ['stud_tile.png', 'stud_bevel.png', 'stud_checker.png', 'gloss_band.png', 'gloss_stripes.png']


if __name__ == '__main__':
	ap = argparse.ArgumentParser()
	ap.add_argument('--out', default=OUT)
	a = ap.parse_args()
	for f in make(os.path.abspath(a.out)):
		print('wrote', os.path.join(os.path.abspath(a.out), f))
