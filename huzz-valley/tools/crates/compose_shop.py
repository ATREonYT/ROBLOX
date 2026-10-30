# The crate shop side by side with the owner's picture (Oct 20, design/owner-oct20/0348-crate-shop-mockup.png): since
# Oct 20, 07:23 ("Just put the ui picture i sent you, no need to try recreate") Shop > CRATES shows his picture itself,
# cut into its three cards, with our kid-safe line under each. Top: his picture; bottom: the Shop > CRATES shot
# (tools/preview shots.sh shop-crates, drawn at 2x) cropped to the row, at the same width, labelled.
# Usage (from huzz-valley/): python3 -I tools/crates/compose_shop.py <shop-crates.png> <out.jpg>
import sys
from PIL import Image, ImageDraw, ImageFont

ROW = (103 + 2 * 39, 235, 103 + 2 * (39 + 587), 235 + 2 * 210)  # the row in the shot: x 39, y 1, 587 x 210 UI px at 2x (Screens/Shop ROW)
MOCKUP = 'design/owner-oct20/0348-crate-shop-mockup.png'


def label(im, text):
    d = ImageDraw.Draw(im)
    try:
        f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 28)
    except OSError:
        f = ImageFont.load_default()
    d.rectangle((0, 0, im.size[0], 44), fill=(0, 0, 0))
    d.text((14, 8), text, fill=(255, 255, 255), font=f)


def main(shot, out):
    im = Image.open(shot).convert('RGB')
    ours = im.crop((ROW[0] - 8, ROW[1] - 8, ROW[2] + 8, ROW[3] + 8))
    his = Image.open(MOCKUP).convert('RGB')
    w = his.size[0]
    ours = ours.resize((w, round(ours.size[1] * w / ours.size[0])), Image.LANCZOS)
    top = Image.new('RGB', (w, his.size[1] + 44))
    top.paste(his, (0, 44))
    label(top, "HIS PICTURE (Oct 20, 03:48)")
    bot = Image.new('RGB', (w, ours.size[1] + 44))
    bot.paste(ours, (0, 44))
    label(bot, "OURS, offline: Shop > CRATES at the same width (his picture cut in three, our OPEN / pity / i line under it)")
    sheet = Image.new('RGB', (w, top.size[1] + bot.size[1]))
    sheet.paste(top, (0, 0))
    sheet.paste(bot, (0, top.size[1]))
    sheet = sheet.resize((1600, round(sheet.size[1] * 1600 / w)), Image.LANCZOS)
    sheet.save(out, quality=90)
    print('wrote', out)


if __name__ == '__main__':
    main(*sys.argv[1:3])
