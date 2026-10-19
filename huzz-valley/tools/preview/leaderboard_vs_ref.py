# One side-by-side for the leaderboards, same size and framing: Huss Valley's HIGHEST LEVEL board up close in his
# Oct 19 daylight screenshot (design/lobby-ref/oct19-lighting-ref.png) on the left; on the right the same shot with
# OUR board face (Shared/LeaderboardLook drawn by the preview, the same names and numbers) put exactly where his board
# is, through the board's perspective (a homography from four points read off his screenshot: the slab's top-left
# and bottom-left corners and the left edge of "LEVEL" in rows 1 and 12, which sits at x 508 of the 700 x 900 face in
# the straight-on clip lb_f1.jpg). Ours gets the game's colour grade on top (Config/Look ColorCorrection Saturation /
# Contrast and the Lighting's ExposureCompensation; Roblox puts it on SurfaceGuis too), so it is the colour Studio
# shows. Under each half: the median colour of the slab between the headshots and the names (rows 1 to 12), taken at
# the same face positions in both. The robot and the board on the right in his shot stand in front of his board, so
# on our side our face covers them. Headshots are Roblox thumbnails: Studio only (grey heads here).
# Usage (from huzz-valley/): python3 tools/preview/leaderboard_vs_ref.py <our board.png> [out.jpg]
#   our board.png: tools/preview/leaderboard_preview.luau (with __previewStat = "Level") exported by harness.luau and
#   drawn by shoot.js at 700 x 900.
import re
import statistics
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

REF = 'design/lobby-ref/oct19-lighting-ref.png'
FACE = [(0, 0), (0, 900), (508, 152), (508, 867)]
SHOT = [(2430, 222), (2337.5, 770), (2819, 288), (2702, 778)]
CROP = (2250, 100, 3024, 950)
LABEL, GAP, FOOT = 54, 24, 44


def font(size):
    try:
        f = ImageFont.truetype('tools/preview/fonts/Montserrat-Variable.ttf', size)
        f.set_variation_by_axes([800])
        return f
    except (OSError, AttributeError):
        return ImageFont.load_default()


def homography(src, dst):
    a = []
    for (x, y), (u, v) in zip(src, dst):
        a.append([x, y, 1, 0, 0, 0, -u * x, -u * y, -u])
        a.append([0, 0, 0, x, y, 1, -v * x, -v * y, -v])
    _, _, vt = np.linalg.svd(np.array(a, float))
    return (vt[-1] / vt[-1][-1]).reshape(3, 3)


def grade():
    """Saturation, Contrast and ExposureCompensation from Config/Look (read from the file, so a change shows here)."""
    src = open('src/ReplicatedStorage/Shared/Config/Look.lua').read()
    cc = re.search(r'ColorCorrection\s*=\s*\{([^}]*)\}', src).group(1)
    sat = float(re.search(r'Saturation\s*=\s*(-?[\d.]+)', cc).group(1))
    con = float(re.search(r'Contrast\s*=\s*(-?[\d.]+)', cc).group(1))
    exp = float(re.search(r'ExposureCompensation\s*=\s*(-?[\d.]+)', src).group(1))
    return sat, con, exp


def graded(img, sat, con, exp):
    a = np.asarray(img, float)
    l = (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2])[..., None]
    s = l + (a - l) * (1 + sat)
    s = ((s - 128) * (1 + con) + 128) * 2 ** exp
    return Image.fromarray(np.clip(np.round(s), 0, 255).astype(np.uint8))


def slab_colour(img, h, ox, oy):
    px = []
    for r in range(12):
        cy = 152 + 65 * r
        for x in range(70, 125, 3):
            for y in range(cy - 14, cy + 15, 3):
                q = h @ np.array([x, y, 1.0])
                px.append(img.getpixel((int(q[0] / q[2]) - ox, int(q[1] / q[2]) - oy)))
    return tuple(int(statistics.median(p[i] for p in px)) for i in range(3))


def main():
    sat, con, exp = grade()
    ours = graded(Image.open(sys.argv[1]).convert('RGB').resize((700, 900)), sat, con, exp)
    out_path = sys.argv[2] if len(sys.argv) > 2 else 'docs/previews/leaderboard-vs-ref.jpg'
    h = homography(FACE, SHOT)
    ref = Image.open(REF).convert('RGB').crop(CROP)
    w, hh = ref.size
    # output pixel (crop) -> face pixel: the inverse homography, shifted by the crop's corner
    inv = np.linalg.inv(h) @ np.array([[1, 0, CROP[0]], [0, 1, CROP[1]], [0, 0, 1]], float)
    inv = inv / inv[2, 2]
    coeffs = tuple(inv.flatten()[:8])
    warped = ours.transform((w, hh), Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    mask = Image.new('L', (700, 900), 255).transform((w, hh), Image.PERSPECTIVE, coeffs, Image.BILINEAR)
    mine = ref.copy()
    mine.paste(warped, (0, 0), mask)
    sheet = Image.new('RGB', (w * 2 + GAP * 3, hh + LABEL + GAP + FOOT), (24, 22, 30))
    sheet.paste(ref, (GAP, LABEL))
    sheet.paste(mine, (GAP * 2 + w, LABEL))
    d = ImageDraw.Draw(sheet)
    d.text((GAP, 14), 'REFERENCE (his Oct 19 screenshot, daylight)', fill=(235, 235, 240), font=font(22))
    d.text((GAP * 2 + w, 14), 'OURS (game code + grade, same spot)', fill=(235, 235, 240), font=font(22))
    y = LABEL + hh + 10
    d.text((GAP, y), 'slab %s' % (slab_colour(ref, h, CROP[0], CROP[1]),), fill=(200, 200, 210), font=font(18))
    d.text((GAP * 2 + w, y), 'slab %s   headshots, pumpkin, candle: Studio only' % (slab_colour(mine, h, CROP[0], CROP[1]),),
           fill=(200, 200, 210), font=font(18))
    sheet.save(out_path, quality=90)
    print('saved', out_path, 'ref slab', slab_colour(ref, h, CROP[0], CROP[1]), 'ours', slab_colour(mine, h, CROP[0], CROP[1]))


main()
