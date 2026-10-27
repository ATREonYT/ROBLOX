# pack_images.py: packs the game's pictures into Luau modules, so the game draws them itself (Shared/ImageLoader, with
# EditableImage) and nothing has to be uploaded first. Ported from the owner's Huzz Valley (tools/icons/pack_images.py).
#   hood/art/icons3d/<Name>.png  -> Shared/Images/Icons/<Name>.lua
#   hood/art/ui_owner/<name>.png -> Shared/Images/Ui/<name>.lua      (the owner's UI pieces, cut_mockup.py; as cut, plus
#                                                                      Slice = { x0, y0, x1, y1 } and Mode from slices.json)
#   Shared/Images/Uploads.lua                                         which uploaded pictures are current (below)
#
# (Oct 27, round 7, OUR_UI_AUDIT A1/A2/A5: "make the ui not be blurry and badly cut out") The icons and item pictures are
# packed in FULL COLOUR now (no 256-colour palette, no dithering), their PNG's own compressed rows (Z = base64 of the zlib stream of the
# PNG-filtered RGBA rows; the colours rounded to 6 bits, below), decoded in game by Shared/Inflate. Before packing, every see-through pixel takes the colour
# of the nearest solid pixel (the alpha bleed, so scaling never blends a dark rim into an edge). Sizes: item pictures
# (shoes, boxes, guns, the spin wheel) MAX_ITEM px, other icons MAX_ICON px: a Shop card shows a picture at up to ~160
# canvas px, ~240 px on a 1080p PC and ~340 px on a phone. Each module returns { W, H, Z }.
# The owner's UI pieces keep the old palette format { W, H, P = base64 palette (RGBA), Data = base64 (count, index)
# runs, Slice?, Mode? } (they are switched off: UIKit.UseOwnerSkins = false).
#
# Not packed: the featured-card backgrounds and the box lid / base / open pictures (only their uploads are drawn), and
# any picture whose upload is CURRENT: hood/art/asset_ids.json has its file's sha256, it went up through the edge-colour
# fill (prep 'bleed1', upload_assets.py) and Roblox approved it (upload_assets.py --status). Uploads.lua lists those as
# Fresh; the game shows every other picture from its packed pixels, never an old upload of an older drawing.
# So: after the owner's upload run is approved, run this again and the place file shrinks by those pictures.
#
# Usage (from the repo root; re-run whenever a picture changes): python3 -I hood/tools/ui/pack_images.py
import base64
import hashlib
import io
import json
import os
import struct

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
HOOD = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HOOD, 'src', 'ReplicatedStorage', 'Shared', 'Images')
ITEM_PREFIX = ('Shoe_', 'Box_', 'Gun_', 'SpinWheel')
SKIP_PREFIX = ('FeaturedBg_', 'BoxLid_', 'BoxBase_', 'BoxOpen_')
MAX_ITEM, MAX_ICON = 320, 224
# (the colour channels are rounded to 64 levels: at most 2 of 255 off, which no eye sees and which no dithering noise
# comes with, and they pack ~30% smaller; alpha stays exact). The sizes, in the place file (base64), for the 165
# pictures: 8 bit at 384 / 256 px ~17 MB, at 320 / 224 ~13 MB; 6 bit at 320 / 224 ~9 MB (the palette format was 3.3 MB).
RGB_BITS = 6
SOLID = 200
RING = 8  # (px of edge-colour fill round the picture; 0 fills every see-through pixel)


def bleed(im):
    """The edge-colour fill: every fully see-through pixel takes the RGB of the nearest solid pixel (alpha stays 0)."""
    a = np.asarray(im, dtype=np.uint8).copy()
    alpha = a[:, :, 3]
    solid = alpha >= SOLID
    if not solid.any():
        return im
    # nearest solid pixel of every pixel (Euclidean), then copy its colour into the see-through ones
    dist, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    clear = alpha == 0
    a[clear, :3] = a[iy[clear], ix[clear], :3]
    if RING:
        # (only a ring RING px wide round the picture is filled; the see-through pixels further out are plain black,
        # which packs far smaller and is never blended into an edge at the sizes the game draws)
        far = clear & (dist > RING)
        a[far, :3] = 0
    return Image.fromarray(a, 'RGBA')


def round_rgb(im):
    if RGB_BITS >= 8:
        return im
    a = np.asarray(im).copy()
    mask = 256 - (1 << (8 - RGB_BITS))
    a[:, :, :3] = (a[:, :, :3].astype(np.int32) + (1 << (7 - RGB_BITS))).clip(0, 255) & mask
    return Image.fromarray(a, 'RGBA')


def zrows(im):
    """The zlib stream of the picture's PNG-filtered rows (Pillow picks each row's filter), from its IDAT chunks."""
    b = io.BytesIO()
    im.save(b, 'PNG', optimize=True)
    d = b.getvalue()
    pos, idat = 8, b''
    while pos < len(d):
        n, kind = struct.unpack('>I4s', d[pos:pos + 8])
        if kind == b'IDAT':
            idat += d[pos + 8:pos + 8 + n]
        pos += 12 + n
    return idat


def encode_palette(im):
    q = im.quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG)
    pal = q.getpalette(rawmode='RGBA') or []
    used = max(q.tobytes()) + 1 if q.width * q.height else 1
    palette = bytes(pal[:used * 4]).ljust(used * 4, b'\0')
    idx = q.tobytes()
    out = bytearray()
    i, n = 0, len(idx)
    while i < n:
        v, j = idx[i], i + 1
        while j < n and j - i < 255 and idx[j] == v:
            j += 1
        out += bytes((j - i, v))
        i = j
    return base64.b64encode(palette).decode(), base64.b64encode(bytes(out)).decode()


def fresh_uploads():
    """The icons whose upload is current: same file, cleaned edges, approved."""
    try:
        with open(os.path.join(HOOD, 'art', 'asset_ids.json')) as fh:
            manifest = json.load(fh)
    except (OSError, ValueError):
        return set()
    fresh = set()
    for key, rec in manifest.items():
        if not key.startswith('icons3d/') or not key.endswith('.png'):
            continue
        path = os.path.join(HOOD, 'art', key)
        if not os.path.exists(path) or rec.get('prep') != 'bleed1' or rec.get('moderation') != 'approved':
            continue
        with open(path, 'rb') as fh:
            if hashlib.sha256(fh.read()).hexdigest() == rec.get('sha256'):
                fresh.add(key[len('icons3d/'):-4])
    return fresh


def clear(kind):
    dst = os.path.join(OUT, kind)
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(dst):
        os.remove(os.path.join(dst, f))
    return dst


def pack_icons(src):
    dst = clear('Icons')
    fresh = fresh_uploads()
    total, count, skipped = 0, 0, []
    for name in sorted(os.listdir(src)):
        if not name.endswith('.png'):
            continue
        stem = name[:-4]
        if stem.startswith(SKIP_PREFIX):
            continue
        if stem in fresh:
            skipped.append(stem)
            continue
        im = bleed(Image.open(os.path.join(src, name)).convert('RGBA'))
        limit = MAX_ITEM if stem.startswith(ITEM_PREFIX) else MAX_ICON
        if max(im.size) > limit:
            im.thumbnail((limit, limit), Image.LANCZOS)
            im = bleed(im)  # (again at the final size: the resize mixes edge pixels)
        z = base64.b64encode(zrows(round_rgb(im))).decode()
        text = ('-- Generated by hood/tools/ui/pack_images.py from hood/art/icons3d/%s (full colour, edge-colour filled). Do not edit.\n'
                'return { W = %d, H = %d, Z = "%s" }\n') % (name, im.width, im.height, z)
        with open(os.path.join(dst, stem + '.lua'), 'w') as fh:
            fh.write(text)
        total += len(text)
        count += 1
    lines = ''.join('\t%s = true,\n' % s for s in sorted(fresh))
    with open(os.path.join(OUT, 'Uploads.lua'), 'w') as fh:
        fh.write('-- Generated by hood/tools/ui/pack_images.py. Do not edit.\n'
                 '-- Fresh: the icons whose upload (IconModels.Images) is the current drawing, edge-filled and approved: they are\n'
                 '-- not packed. Every other icon with a packed picture shows that, never an older upload.\n'
                 'return {\n\tFresh = {\n%s\t},\n}\n' % lines)
    print('packed Icons: %d pictures, %d KB (%d skipped: their upload is current)' % (count, total // 1024, len(skipped)))


def pack_ui(src, meta):
    dst = clear('Ui')
    total = 0
    for name in sorted(os.listdir(src)):
        if not name.endswith('.png'):
            continue
        stem = name[:-4]
        im = Image.open(os.path.join(src, name)).convert('RGBA')
        pal, data = encode_palette(im)
        fields = 'W = %d, H = %d, P = "%s", Data = "%s"' % (im.width, im.height, pal, data)
        m = meta.get(stem)
        if m:
            k = im.width / m['w']
            c = [round(v * k) for v in m['center']]
            fields += ', Mode = "%s", Slice = { %d, %d, %d, %d }' % (m['mode'], c[0], c[1], c[2], c[3])
        text = '-- Generated by hood/tools/ui/pack_images.py from hood/art/ui_owner/%s. Do not edit.\nreturn { %s }\n' % (name, fields)
        with open(os.path.join(dst, stem + '.lua'), 'w') as fh:
            fh.write(text)
        total += len(text)
    print('packed Ui: %d KB' % (total // 1024))


pack_icons(os.path.join(HOOD, 'art', 'icons3d'))
with open(os.path.join(HOOD, 'art', 'ui_owner', 'slices.json')) as fh:
    SLICES = json.load(fh)
pack_ui(os.path.join(HOOD, 'art', 'ui_owner'), SLICES)
