# One side-by-side for the leaderboards: Huss Valley's MOST WINS board from the owner's clip (straightened from its
# four corners, design/lobby-ref/lb_f1.jpg) next to ours (Shared/LeaderboardLook drawn by the preview), same size.
# Usage (from huzz-valley/): python3 tools/preview/leaderboard_vs_ref.py <our board.png> [out.jpg]
#   our board.png: tools/preview/leaderboard_preview.luau exported by harness.luau and drawn by shoot.js at 700 x 900.
import sys
from PIL import Image, ImageDraw, ImageFont

REF = 'design/lobby-ref/lb_f1.jpg'
# the board's corners in the clip frame: top-left, bottom-left, bottom-right, top-right (bottom-right is hidden by a
# player: the parallelogram's fourth corner)
QUAD = (727, 175, 734, 758, 1185, 736, 1178, 153)
W, H, LABEL, GAP = 700, 900, 54, 24


def font(size):
    try:
        f = ImageFont.truetype('tools/preview/fonts/Montserrat-Variable.ttf', size)
        f.set_variation_by_axes([800])
        return f
    except (OSError, AttributeError):
        return ImageFont.load_default()


def main():
    ours = Image.open(sys.argv[1]).convert('RGB').resize((W, H))
    out_path = sys.argv[2] if len(sys.argv) > 2 else 'docs/previews/leaderboard-vs-ref.jpg'
    ref = Image.open(REF).convert('RGB').transform((W, H), Image.QUAD, QUAD, Image.BICUBIC)
    sheet = Image.new('RGB', (W * 2 + GAP * 3, H + LABEL + GAP), (24, 22, 30))
    sheet.paste(ref, (GAP, LABEL))
    sheet.paste(ours, (GAP * 2 + W, LABEL))
    d = ImageDraw.Draw(sheet)
    d.text((GAP, 14), 'HUSS VALLEY (owner\'s clip, straightened)', fill=(235, 235, 240), font=font(22))
    d.text((GAP * 2 + W, 14), 'OURS (game code, offline preview)', fill=(235, 235, 240), font=font(22))
    sheet.save(out_path, quality=90)
    print('saved', out_path)


main()
