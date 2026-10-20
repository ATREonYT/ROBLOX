# The Shop next to the owner's reference video (Oct 20 14:25: "make our ui shop and in general make it like that"):
# each row is his frame on the left and ours on the right at the same size (1280 x 704, his video's size; our shots
# are 2560 x 1408 at SCALE=2.5 and halved, so the window is the same size as his on screen).
# Usage (from huzz-valley/):
#   cd tools/preview && NODE_PATH=$(npm root -g) LUNE=/root/bin/lune HUZZ_FRESH=1 \
#     sh shots.sh <shots> shop-top shop-coins shop-passes shop-crates && cd ../..
#   python3 tools/preview/shop_vs_video.py <shots> docs/previews/shop-oct20-1425-vs-video.jpg
import sys
from PIL import Image, ImageDraw, ImageFont

VIDEO = 'design/owner-oct20/1425-shop-ref-{}.jpg'
# his frame (seconds into the video) -> our shot at the same spot of the page
ROWS = [
    ('0.3', 'shop-top', 'the top: featured banner'),
    ('1.3', 'shop-coins', 'a row of 3 cards (his POTIONS, our COINS)'),
    ('2.5', 'shop-passes', 'a section header (his GAMEPASSES, our PASSES)'),
    ('4.5', 'shop-crates', 'our CRATES (his MONEY cards for the size)'),
]
W, H, LABEL, GAP = 1280, 704, 44, 8


def font(size):
    for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 'DejaVuSans-Bold.ttf'):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    shots, out = sys.argv[1], sys.argv[2]
    sheet = Image.new('RGB', (2 * W + GAP, len(ROWS) * (H + LABEL)), (18, 18, 22))
    d = ImageDraw.Draw(sheet)
    for i, (t, name, what) in enumerate(ROWS):
        y = i * (H + LABEL)
        his = Image.open(VIDEO.format(t)).convert('RGB').resize((W, H), Image.LANCZOS)
        ours = Image.open(f'{shots}/{name}.png').convert('RGB').resize((W, H), Image.LANCZOS)
        sheet.paste(his, (0, y + LABEL))
        sheet.paste(ours, (W + GAP, y + LABEL))
        d.text((12, y + 8), f'HIS VIDEO at {t} s: {what}', fill=(255, 255, 255), font=font(26))
        d.text((W + GAP + 12, y + 8), f'OURS ({name})', fill=(120, 255, 140), font=font(26))
    sheet.save(out, quality=88)
    print('saved', out, sheet.size)


if __name__ == '__main__':
    main()
