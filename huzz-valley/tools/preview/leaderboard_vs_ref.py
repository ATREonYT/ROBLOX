# One side-by-side for the leaderboards: Huss Valley's MOST WINS board from the owner's clip (straightened from its
# four corners, design/lobby-ref/lb_f1.jpg) next to ours (Shared/LeaderboardLook drawn by the preview), same size.
# Ours gets the game's colour grade on top (Config/Look: Saturation +0.35, Contrast +0.12, Exposure -0.1; Roblox puts
# it on SurfaceGuis too), so the right half is the colour his Studio shows, not the raw colour we set: the Oct 18
# board looked fine here but magenta in his game because this step was missing. The two numbers under each half are
# the median colour of a stud-free patch of slab (header, right of the title).
# Usage (from huzz-valley/): python3 tools/preview/leaderboard_vs_ref.py <our board.png> [out.jpg]
#   our board.png: tools/preview/leaderboard_preview.luau exported by harness.luau and drawn by shoot.js at 700 x 900.
import re
import statistics
import sys
from PIL import Image, ImageDraw, ImageFont

REF = 'design/lobby-ref/lb_f1.jpg'
# the board's corners in the clip frame: top-left, bottom-left, bottom-right, top-right (bottom-right is hidden by a
# player: the parallelogram's fourth corner)
QUAD = (727, 175, 734, 758, 1185, 736, 1178, 153)
W, H, LABEL, GAP, FOOT = 700, 900, 54, 24, 40
PATCH = (520, 40, 560, 70)  # header, right of "MOST WINS" (the ref's caption covers x 330..520 there)


def font(size):
    try:
        f = ImageFont.truetype('tools/preview/fonts/Montserrat-Variable.ttf', size)
        f.set_variation_by_axes([800])
        return f
    except (OSError, AttributeError):
        return ImageFont.load_default()


def grade():
    """Saturation, Contrast and ExposureCompensation from Config/Look (read from the file, so a change shows here)."""
    src = open('src/ReplicatedStorage/Shared/Config/Look.lua').read()
    cc = re.search(r'ColorCorrection\s*=\s*\{([^}]*)\}', src).group(1)
    sat = float(re.search(r'Saturation\s*=\s*(-?[\d.]+)', cc).group(1))
    con = float(re.search(r'Contrast\s*=\s*(-?[\d.]+)', cc).group(1))
    exp = float(re.search(r'ExposureCompensation\s*=\s*(-?[\d.]+)', src).group(1))
    return sat, con, exp


def graded(img, sat, con, exp):
    gain = 2 ** exp

    def px(c):
        l = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
        out = []
        for v in c:
            s = l + (v - l) * (1 + sat)
            s = (s - 128) * (1 + con) + 128
            out.append(max(0, min(255, int(round(s * gain)))))
        return tuple(out)
    data = [px(c) for c in img.getdata()]
    out = Image.new('RGB', img.size)
    out.putdata(data)
    return out


def median(img, box):
    px = list(img.crop(box).getdata())
    return tuple(int(statistics.median(p[i] for p in px)) for i in range(3))


def main():
    sat, con, exp = grade()
    ours = graded(Image.open(sys.argv[1]).convert('RGB').resize((W, H)), sat, con, exp)
    out_path = sys.argv[2] if len(sys.argv) > 2 else 'docs/previews/leaderboard-vs-ref.jpg'
    ref = Image.open(REF).convert('RGB').transform((W, H), Image.QUAD, QUAD, Image.BICUBIC)
    sheet = Image.new('RGB', (W * 2 + GAP * 3, H + LABEL + GAP + FOOT), (24, 22, 30))
    sheet.paste(ref, (GAP, LABEL))
    sheet.paste(ours, (GAP * 2 + W, LABEL))
    d = ImageDraw.Draw(sheet)
    d.text((GAP, 14), 'HUSS VALLEY (owner\'s clip, straightened)', fill=(235, 235, 240), font=font(22))
    d.text((GAP * 2 + W, 14), 'OURS (game code, with the game\'s colour grade)', fill=(235, 235, 240), font=font(22))
    y = LABEL + H + 10
    d.text((GAP, y), 'slab %s' % (median(ref, PATCH),), fill=(200, 200, 210), font=font(18))
    d.text((GAP * 2 + W, y), 'slab %s   (3D pumpkin, candle and glow: Studio only)' % (median(ours, PATCH),), fill=(200, 200, 210), font=font(18))
    sheet.save(out_path, quality=90)
    print('saved', out_path, 'ref slab', median(ref, PATCH), 'ours', median(ours, PATCH))


main()
