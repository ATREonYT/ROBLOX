"""alpha_bleed.py: the edge-colour fill ("alpha bleed") for the game's PNG pictures. Standard library only (the owner
runs hood/tools/upload_assets.py on a Mac with no pip installs), so it reads and writes PNGs itself.

Why: a fully see-through pixel still has a colour, usually black or white. When Roblox (or any GPU) scales a picture,
it blends each drawn pixel with its neighbours, see-through ones included, so that hidden colour leaks in as a dark or
light rim round the picture ("badly cut out", OUR_UI_AUDIT A5). The fill gives every see-through pixel the colour of
the nearest solid pixel; it stays fully see-through, so the picture looks the same, but its edges blend clean.

  read_png(data) -> (w, h, bytearray RGBA)       8-bit grey / grey+alpha / RGB / RGBA / palette (+tRNS), not interlaced
  write_png(w, h, rgba) -> bytes                 RGBA, each row with the PNG filter that packs it best, zlib level 9
  bleed(w, h, rgba) -> filled count              in place: alpha-0 pixels take the nearest solid pixel's RGB
  bleed_png_bytes(data) -> bytes                 all three; the same PNG back (unchanged) if it can't be read
Usage on its own: python3 alpha_bleed.py in.png out.png
"""
import struct
import sys
import zlib
from collections import deque

SIG = b'\x89PNG\r\n\x1a\n'
SOLID = 200  # (a pixel at least this opaque gives its colour to the see-through ones round it)


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def read_png(data):
    if data[:8] != SIG:
        raise ValueError('not a PNG')
    pos, idat, plte, trns = 8, bytearray(), None, None
    w = h = depth = ctype = interlace = None
    while pos < len(data):
        n, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        pos += 12 + n
        if kind == b'IHDR':
            w, h, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', body)
        elif kind == b'PLTE':
            plte = body
        elif kind == b'tRNS':
            trns = body
        elif kind == b'IDAT':
            idat += body
        elif kind == b'IEND':
            break
    if depth != 8 or interlace != 0:
        raise ValueError('only 8-bit, non-interlaced PNGs (this one: %s bit, interlace %s)' % (depth, interlace))
    chans = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(ctype)
    if not chans:
        raise ValueError('colour type %s not supported' % ctype)
    raw = zlib.decompress(bytes(idat))
    stride = w * chans
    px = bytearray(h * stride)
    prev = bytearray(stride)
    i = 0
    for y in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        if f == 1:
            for x in range(chans, stride):
                line[x] = (line[x] + line[x - chans]) & 255
        elif f == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                left = line[x - chans] if x >= chans else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                left = line[x - chans] if x >= chans else 0
                ul = prev[x - chans] if x >= chans else 0
                line[x] = (line[x] + _paeth(left, prev[x], ul)) & 255
        elif f != 0:
            raise ValueError('bad filter %d' % f)
        px[y * stride:(y + 1) * stride] = line
        prev = line
    if ctype == 6:
        return w, h, px
    out = bytearray(w * h * 4)
    for k in range(w * h):
        if ctype == 2:
            r, g, b = px[3 * k:3 * k + 3]
            a = 255
        elif ctype == 0:
            r = g = b = px[k]
            a = 255
        elif ctype == 4:
            r = g = b = px[2 * k]
            a = px[2 * k + 1]
        else:
            j = px[k]
            r, g, b = plte[3 * j:3 * j + 3]
            a = trns[j] if trns is not None and j < len(trns) else 255
        out[4 * k:4 * k + 4] = bytes((r, g, b, a))
    return w, h, out


def _chunk(kind, body):
    return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)


def write_png(w, h, rgba):
    stride = w * 4
    rows = bytearray()
    prev = bytearray(stride)
    for y in range(h):
        line = rgba[y * stride:(y + 1) * stride]
        # the filter with the smallest sum of signed byte values (the PNG spec's own heuristic)
        best = None
        for f in (0, 1, 2, 4):
            if f == 0:
                cand = bytes(line)
            elif f == 1:
                cand = bytes(line[x] if x < 4 else (line[x] - line[x - 4]) & 255 for x in range(stride))
            elif f == 2:
                cand = bytes((line[x] - prev[x]) & 255 for x in range(stride))
            else:
                cand = bytes((line[x] - _paeth(line[x - 4] if x >= 4 else 0, prev[x], prev[x - 4] if x >= 4 else 0)) & 255 for x in range(stride))
            score = sum(v if v < 128 else 256 - v for v in cand)
            if best is None or score < best[0]:
                best = (score, f, cand)
        rows.append(best[1])
        rows += best[2]
        prev = line
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    return SIG + _chunk(b'IHDR', ihdr) + _chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + _chunk(b'IEND', b'')


def bleed(w, h, rgba):
    """Every fully see-through pixel takes the RGB of the nearest solid pixel (breadth first, 8 neighbours); its alpha
    stays 0. A picture with no solid pixel is left as it is. Returns how many pixels were filled."""
    n = w * h
    done = bytearray(n)
    q = deque()
    for k in range(n):
        a = rgba[4 * k + 3]
        if a >= SOLID:
            done[k] = 1
            q.append(k)
        elif a > 0:
            done[k] = 1  # (a soft edge pixel keeps its own colour; it does not spread)
    if not q:
        return 0
    filled = 0
    while q:
        k = q.popleft()
        x, y = k % w, k // w
        r, g, b = rgba[4 * k], rgba[4 * k + 1], rgba[4 * k + 2]
        for dy in (-1, 0, 1):
            yy = y + dy
            if yy < 0 or yy >= h:
                continue
            for dx in (-1, 0, 1):
                xx = x + dx
                if xx < 0 or xx >= w or (dx == 0 and dy == 0):
                    continue
                j = yy * w + xx
                if not done[j]:
                    done[j] = 1
                    rgba[4 * j], rgba[4 * j + 1], rgba[4 * j + 2] = r, g, b
                    filled += 1
                    q.append(j)
    return filled


def bleed_png_bytes(data):
    try:
        w, h, rgba = read_png(data)
    except (ValueError, zlib.error, struct.error):
        return data
    if not bleed(w, h, rgba):
        return data
    return write_png(w, h, rgba)


if __name__ == '__main__':
    with open(sys.argv[1], 'rb') as fh:
        src = fh.read()
    with open(sys.argv[2], 'wb') as fh:
        fh.write(bleed_png_bytes(src))
