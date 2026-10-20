# Cuts the owner's 11 power pictures out of his sheet (owner, Oct 20 20:34: "for the power ups, bring back the old
# pictures for the powers. Right now this is a bare copy of huss valley. We want to stand out"):
# design/owner-oct20/2034-ablt1-powers-and-crates.png, top two rows: Random, Shield, Invisible, Glitchy, Body Double,
# Banana Peel / Smoke Bomb, Bear Trap, Slow Wave, Radar, Lasso, each a picture in a coloured rounded tile with its name.
# (The crates in the bottom half are the shop's, not cut here.)
# Each card in the game prints the power's name itself, so the picture is cut from inside his tile, from just under
# its top rim to just above his baked-in name, as a square centred on the tile: his art as it is (no redraw, no
# upscale), with the tile's own colour behind it. The game rounds its corners (UICorner on the picture) and rims it
# in the tile's border colour (printed below, in Config/Powers Tile). They come out about 172 px: under the 192 px
# that stays sharp on the owner's Retina screen, so a little soft there (his sheet is all we have at this size).
# Writes assets/icons/ability-<name>.png; then run tools/icons/pack_images.py.
# Usage (from huzz-valley/): python3 tools/icons/cut_power_tiles.py
from PIL import Image

SHEET = 'design/owner-oct20/2034-ablt1-powers-and-crates.png'
# his tiles on the sheet: left, top, right, bottom (outer edge of the rim), and the top of his name's letters
# (measured: the first row from the bottom with near-white text pixels)
TILES = {
    'random': ((32, 12, 258, 232), 193),
    'shield': ((281, 14, 507, 234), 195),
    'invisible': ((530, 14, 756, 234), 195),
    'glitchy': ((780, 14, 1006, 234), 195),
    'body-double': ((1030, 15, 1255, 234), 196),
    'banana-peel': ((1278, 16, 1501, 235), 197),
    'smoke-bomb': ((128, 252, 360, 469), 426),
    'bear-trap': ((394, 252, 629, 469), 428),
    'slow-wave': ((661, 252, 889, 470), 427),
    'radar': ((921, 252, 1150, 469), 429),
    'lasso': ((1179, 252, 1411, 469), 429),
}
RIM = 7  # his tile's rim and its inner shadow, px
GAP = 3  # left above his name's letters, px

sheet = Image.open(SHEET).convert('RGB')
for name, ((l, t, r, b), name_top) in TILES.items():
    top = t + RIM
    size = (name_top - GAP) - top
    cx = (l + r + 1) // 2
    left = cx - size // 2
    crop = sheet.crop((left, top, left + size, top + size)).convert('RGBA')
    crop.save(f'assets/icons/ability-{name}.png')
    rim = sheet.getpixel((l + 2, (t + b) // 2))
    print(f'ability-{name}.png {size}x{size}  rim colour {rim}')
