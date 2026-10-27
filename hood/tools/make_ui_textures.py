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
  stud_tile.png     64x64   the same recessed stud as stud_bevel, GREYSCALE (lit walls white, shaded walls dark grey): for
                            ImageColor3 tinting
  stud_bevel.png    64x64   the HUD blocks' stud (ref22): one RECESSED rounded stud lit from the top left (shaded top/left
                            walls, lit bottom/right), low contrast, PRE-SHADED: ImageColor3 = white
  stud_checker.png  128x128 2x2 studs, raised/recessed alternating, pre-shaded: TileSize = 2 x pitch
  gloss_band.png    512x128 two diagonal white bands in alpha: ScaleType Stretch over a small block face
  gloss_stripes.png 128x128 one seamless 45-degree light stripe: ScaleType Tile (TileSize ~3 x pitch) over headers/cards
  splat.png         256x256 a white paint splat (tint with ImageColor3 = the rarity colour), behind shoes/pets
  splat_rainbow.png 256x256 the same splat in rainbow hues round the edge (Secret)
  splat_black.png   256x256 the same splat in dark translucent grey (the "+n" buy-a-slot splat; the UI draws "+n")
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


def stud_parts(u, v, stud=None):
	"""For a point (u, v) in a one-stud cell (0..1, v down), which part of the stud it is on:
	'L' (the left/bottom rim), 'T' (the top/right rim), 'F' (the face inside the rim), or None (outside)."""
	h = (stud or STUD) / 2
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


def inset_parts(u, v):
	"""The HUD blocks' stud (ref22_hud_buttons, the Store pack cards): a RECESSED rounded square lit from the top left,
	so its top and left inner walls are in shade ('D') and its bottom and right walls catch the light ('B'), ~47% of the
	pitch; 'F' face, None outside."""
	h = 0.47 / 2
	x, y = u - 0.5, v - 0.5
	if _sd_round_box(x, y, h, CORNER) > 0:
		return None
	if _sd_round_box(x, y, h - LINE, max(CORNER - LINE, 0.004)) < 0:
		return 'F'
	if abs(x) >= abs(y):
		return 'D' if x < 0 else 'B'
	return 'D' if y < 0 else 'B'


def inset_pixels(n, mode='bevel'):
	"""Pre-shaded overlay of inset_parts: low contrast like the reference (about +-10% of the fill once UIKit draws it
	at ImageTransparency ~0.3). mode 'grey': the tintable version (dark grey walls / white walls, for ImageColor3)."""
	look = {None: (0.0, 0.0, 0.0, 0.0), 'F': (0.0, 0.0, 0.0, 0.02), 'D': (0.36, 0.14, 0.0, 0.16), 'B': (1.0, 1.0, 0.9, 0.3)}  # warm shade (UICRITIC2: the ref's walls stay saturated)
	if mode == 'grey':
		look = {None: (1.0, 1.0, 1.0, 0.0), 'F': (1.0, 1.0, 1.0, 0.0), 'D': (0.22, 0.22, 0.22, 1.0), 'B': (1.0, 1.0, 1.0, 0.9)}
	rows = []
	for py in range(n):
		row = []
		for px in range(n):
			acc = [0.0, 0.0, 0.0, 0.0]
			for sy in range(SS):
				for sx in range(SS):
					r, g, b, a = look[inset_parts((px + (sx + 0.5) / SS) / n, (py + (sy + 0.5) / SS) / n)]
					acc[0] += r * a
					acc[1] += g * a
					acc[2] += b * a
					acc[3] += a
			a = acc[3] / (SS * SS)
			rgb = [acc[i] / acc[3] for i in range(3)] if acc[3] > 0 else [0.0, 0.0, 0.0]
			row.append(tuple(int(round(c * 255)) for c in rgb) + (int(round(a * 255)),))
		rows.append(row)
	return rows


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


# ------------------------------------------------------------------------------------------------- paint splats
# (brief 22, ref22_pets_window / store_limited) the flat paint splat behind every pet: one big blob with 5-7 round lobes
# and a few loose drops around it. Flat colour, no outline, like the reference.
SPLAT_SEED = 7


def _splat_circles(seed=SPLAT_SEED):
	"""The splat as a union of circles (x, y, r) in -1..1, like ref22's: a big core, 4 lobes of mixed sizes that reach
	out mostly sideways (so the splat shows left and right of the item standing on it), and 4 loose droplets."""
	circles = [(0.0, -0.04, 0.6)]
	for (a, d, rad) in ((12, 0.48, 0.36), (168, 0.5, 0.33), (232, 0.46, 0.3), (305, 0.5, 0.27), (95, 0.42, 0.26)):
		t = math.radians(a)
		circles.append((d * math.cos(t), d * math.sin(t) - 0.04, rad))
	for (a, d, rad) in ((35, 0.93, 0.055), (150, 0.9, 0.065), (205, 0.92, 0.045), (330, 0.9, 0.06)):
		t = math.radians(a)
		circles.append((d * math.cos(t), d * math.sin(t), rad))
	return circles


def splat_pixels(n, kind='white'):
	"""kind 'white' (tint with ImageColor3), 'rainbow' (hue round the edge), 'black' (the "+n" slot)."""
	circles = _splat_circles()
	ss = 3
	rows = []
	for py in range(n):
		row = []
		for px in range(n):
			acc = 0
			cx = cy = 0.0
			rad_acc = 0.0
			for sy in range(ss):
				for sx in range(ss):
					x = ((px + (sx + 0.5) / ss) / n - 0.5) * 2 / 0.97
					y = -((py + (sy + 0.5) / ss) / n - 0.5) * 2 / 0.97
					for (qx, qy, qr) in circles:
						if (x - qx) ** 2 + (y - qy) ** 2 <= qr * qr:
							acc += 1
							cx += x
							cy += y
							rad_acc += math.hypot(x, y)
							break
			a = acc / (ss * ss)
			if acc == 0:
				row.append((255, 255, 255, 0) if kind != 'black' else (0, 0, 0, 0))
				continue
			if kind == 'white':
				row.append((255, 255, 255, int(round(a * 255))))
			elif kind == 'black':
				row.append((30, 30, 36, int(round(a * 0.86 * 255))))
			else:
				t = math.atan2(cy, cx)
				h = (t / (2 * math.pi)) % 1.0
				rad = rad_acc / acc
				r, g, b = _hsv(h, 0.9 if rad > 0.4 else 0.9 * rad / 0.4, 1.0)
				row.append((r, g, b, int(round(a * 255))))
		rows.append(row)
	return rows


def _hsv(h, s, v):
	i = int(h * 6) % 6
	f = h * 6 - int(h * 6)
	p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	r, g, b = [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)][i]
	return int(r * 255), int(g * 255), int(b * 255)


def make(out):
	write_png(os.path.join(out, 'stud_tile.png'), 64, 64, soften(inset_pixels(64, 'grey')))
	# (brief 22, UICRITIC2) StudBevel = the HUD blocks' recessed stud, lit from the top left, low contrast
	write_png(os.path.join(out, 'stud_bevel.png'), 64, 64, soften(inset_pixels(64)))
	a = cell_pixels(64, True, 'bevel')
	b = cell_pixels(64, False, 'bevel')
	rows = [a[y] + b[y] for y in range(64)] + [b[y] + a[y] for y in range(64)]
	write_png(os.path.join(out, 'stud_checker.png'), 128, 128, soften(rows))
	write_png(os.path.join(out, 'gloss_band.png'), 512, 128, gloss_pixels(512, 128))
	write_png(os.path.join(out, 'gloss_stripes.png'), 128, 128, stripes_pixels(128))
	for name, kind in (('splat.png', 'white'), ('splat_rainbow.png', 'rainbow'), ('splat_black.png', 'black')):
		write_png(os.path.join(out, name), 256, 256, splat_pixels(256, kind))
	return ['stud_tile.png', 'stud_bevel.png', 'stud_checker.png', 'gloss_band.png', 'gloss_stripes.png', 'splat.png',
		'splat_rainbow.png', 'splat_black.png']


if __name__ == '__main__':
	ap = argparse.ArgumentParser()
	ap.add_argument('--out', default=OUT)
	a = ap.parse_args()
	for f in make(os.path.abspath(a.out)):
		print('wrote', os.path.join(os.path.abspath(a.out), f))
