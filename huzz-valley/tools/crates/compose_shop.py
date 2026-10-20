# The crate shop side by side with the owner's mockup (Oct 20, design/owner-oct20/0348-crate-shop-mockup.png):
# the Shop > CRATES shot (tools/preview shots.sh shop-crates: drawn at 2x, where the cards fall back to the plain crate
# because the HTML renderer draws no ViewportFrames) gets each card's 3D picture pasted where UI/Crate3D puts it (the
# card's top 214 x 150 px), from the motion3d stills (crate_open_scene.luau MODE=cards: his crates' parts as STAND-IN
# boxes, framed by the game's camera; the card's navy keyed out). The sparkles and the "i" sit over the crate in the
# game (ZIndex 4 and 5 over its ViewportFrame's 3), so the shot's bright pixels round it go back on top. Then ours over
# his mockup at the same width, labelled.
# Usage (from huzz-valley/): python3 -I tools/crates/compose_shop.py <shop-crates.png> <cards dir with still_0..2.png> <out.jpg>
import sys
from PIL import Image, ImageDraw, ImageFont

SCALE = 2  # the shot's pixels per UI pixel
CARD0 = (111, 235)  # card 1's top left in the shot (found by its rim: tools/preview shots at 1536 x 730)
PITCH = 444  # (214 + 8) * 2
STAGE = (428, 300)  # the card's 3D picture, 214 x 150 at 2x
BG = (0x1e, 0x28, 0x52)  # the card's navy, the stills' background
MOCKUP = 'design/owner-oct20/0348-crate-shop-mockup.png'


def keyed(path):
    im = Image.open(path).convert('RGBA').resize(STAGE, Image.LANCZOS)
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            d = abs(r - BG[0]) + abs(g - BG[1]) + abs(b - BG[2])
            if d < 16:  # (only the plain navy: his dark parts stay)
                px[x, y] = (r, g, b, int(255 * max(0, d - 6) / 10))
    return im


def label(im, text):
    d = ImageDraw.Draw(im)
    try:
        f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 28)
    except OSError:
        f = ImageFont.load_default()
    d.rectangle((0, 0, im.size[0], 44), fill=(0, 0, 0))
    d.text((14, 8), text, fill=(255, 255, 255), font=f)


PLAIN = (110, 84, 318, 258)  # the plain crate the renderer draws in the stage (UI/CrateArt, 100 px at (107, 74))


def over(shot, x, y):
    # the shot's sparkles and "i" in this card's stage (anything bright outside the plain crate), soft edged
    top = shot.crop((x, y, x + STAGE[0], y + STAGE[1]))
    px = top.load()
    for yy in range(STAGE[1]):
        for xx in range(STAGE[0]):
            r, g, b, a = px[xx, yy]
            inside = PLAIN[0] <= xx < PLAIN[2] and PLAIN[1] <= yy < PLAIN[3]
            lum = 0.3 * r + 0.59 * g + 0.11 * b
            px[xx, yy] = (r, g, b, 0 if inside else int(255 * min(1, max(0, (lum - 85) / 50))))
    return top


def main(shot, cards, out):
    im = Image.open(shot).convert('RGBA')
    orig = im.copy()
    for i in range(3):
        st = keyed(f'{cards}/still_{i}.png')
        x, y = CARD0[0] + i * PITCH, CARD0[1]
        # the plain crate the renderer drew in its place goes (the card's navy), then the 3D picture, then what the
        # game draws over it
        ImageDraw.Draw(im).rectangle((x + PLAIN[0], y + PLAIN[1], x + PLAIN[2], y + PLAIN[3]), fill=BG + (255,))
        im.alpha_composite(st, (x, y))
        im.alpha_composite(over(orig, x, y), (x, y))
    ours = im.crop((CARD0[0] - 8, CARD0[1] - 8, CARD0[0] + 2 * PITCH + 428 + 8, CARD0[1] + 418 + 8)).convert('RGB')
    his = Image.open(MOCKUP).convert('RGB')
    w = his.size[0]
    ours = ours.resize((w, round(ours.size[1] * w / ours.size[0])), Image.LANCZOS)
    top = Image.new('RGB', (w, 44 + his.size[1]), (0, 0, 0))
    top.paste(his, (0, 44))
    label(top, "HIS MOCKUP (Oct 20, 03:48)")
    bot = Image.new('RGB', (w, 44 + ours.size[1]), (0, 0, 0))
    bot.paste(ours, (0, 44))
    label(bot, "OURS, offline: Shop > CRATES at the same width. His crates drawn as STAND-IN boxes (real meshes only in Studio)")
    sheet = Image.new('RGB', (w, top.size[1] + bot.size[1]), (0, 0, 0))
    sheet.paste(top, (0, 0))
    sheet.paste(bot, (0, top.size[1]))
    sheet = sheet.resize((1600, round(sheet.size[1] * 1600 / w)), Image.LANCZOS)
    sheet.save(out, quality=88)
    im.convert('RGB').save(out.rsplit('.', 1)[0] + '-window.png')
    print('wrote', out)


if __name__ == '__main__':
    main(*sys.argv[1:4])
