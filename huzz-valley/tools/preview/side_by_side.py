# One side-by-side picture for the owner: the mockup's window on top, our render of the same window under it, both
# scaled to the same width (same framing: each crop is the window's outer edge).
# Usage (from huzz-valley/): python3 tools/preview/side_by_side.py <screen> <our render.png> [out.jpg]
#   screens: coins, dances, how-to-play, knife-cards, winner, daily-quests. Our render comes from shots.sh (SCALE=2,
#   the window centred in the shot). winner: the top half of his Oct 19 picture a (the JOURNEY half below is a paid
#   season pass we don't have) vs Screens/Results (701 x 334); daily-quests: his picture d vs Screens/DailyQuests
#   (520 x 452; his Robux Refresh / Auto Complete row is left out on purpose). knife-cards: the owner's five knife Game Pass cards (Oct 18) vs the card row of Shop > PASSES
#   (shots.sh shop-passes), both cropped to the cards with the same margin.
import sys
from PIL import Image, ImageDraw, ImageFont

# mockup file and the window's outer box in it; our shot's size (the window is 701 x 320 at 2x, centred)
SCREENS = {
    'coins': ('design/ui-oct17/shop-items-coins-dances.png', (12, 398, 936, 812), 'docs/previews/coins-vs-mockup.jpg'),
    'dances': ('design/ui-oct17/shop-items-coins-dances.png', (960, 398, 1872, 812), 'docs/previews/dances-vs-mockup.jpg'),
    'how-to-play': ('design/ui-oct17/how-to-play.png', (12, 6, 1370, 898), 'docs/previews/how-to-play-vs-mockup.jpg'),
    # the cards span x 16-2096, y 14-729 in his file; ours x 40-664, y 95-309 of the window (Shop.lua KNIFE_CARD)
    'knife-cards': ('design/knives/Five_Elemental_Knife_Cards.png', (6, 4, 2106, 739), 'docs/previews/knife-cards-vs-mockup.jpg', (37, 92, 667, 312)),
    # 5th: our window's size in points when it isn't 701 x 320
    'winner': ('design/owner-oct19/pic-a-winner-page.png', (281, 106, 1370, 614), 'docs/previews/winner-vs-pic-a.jpg', None, (701, 334)),
    'daily-quests': ('design/owner-oct19/pic-d-quests.png', (92, 44, 799, 802), 'docs/previews/daily-quests-vs-pic-d.jpg', None, (520, 452)),
}
WIDTH, LABEL = 1200, 44


def font(size):
    try:
        f = ImageFont.truetype('tools/preview/fonts/Montserrat-Variable.ttf', size)
        f.set_variation_by_axes([800])
        return f
    except (OSError, AttributeError):
        pass
    return ImageFont.load_default()


def ours_box(im, size=(701, 320)):
    # the window: 701 x 320 points (or `size`) at 2x, centred in the shot
    w, h = 2 * size[0], 2 * size[1]
    x, y = (im.width - w) // 2, (im.height - h) // 2
    return (x, y, x + w, y + h)


def main():
    name, render = sys.argv[1], sys.argv[2]
    mock_file, box, out = SCREENS[name][:3]
    part = SCREENS[name][3] if len(SCREENS[name]) > 3 else None
    size = SCREENS[name][4] if len(SCREENS[name]) > 4 else (701, 320)
    out = sys.argv[3] if len(sys.argv) > 3 else out
    mock = Image.open(mock_file).convert('RGB').crop(box)
    ours = Image.open(render).convert('RGB')
    ours = ours.crop(ours_box(ours, size))
    if part:  # a part of the window, in window points (2x in the shot)
        ours = ours.crop(tuple(2 * v for v in part))
    rows = []
    for label, im in (('Your picture' if name in ('winner', 'daily-quests') else 'Your mockup', mock), ('Ours (game screen)', ours)):
        im = im.resize((WIDTH, round(im.height * WIDTH / im.width)), Image.LANCZOS)
        rows.append((label, im))
    total = sum(LABEL + im.height for _, im in rows)
    sheet = Image.new('RGB', (WIDTH, total), (22, 22, 30))
    d = ImageDraw.Draw(sheet)
    y = 0
    for label, im in rows:
        d.text((12, y + 8), label, fill=(255, 255, 255), font=font(26))
        sheet.paste(im, (0, y + LABEL))
        y += LABEL + im.height
    sheet.save(out, quality=88)
    print('wrote', out, sheet.size)


main()
