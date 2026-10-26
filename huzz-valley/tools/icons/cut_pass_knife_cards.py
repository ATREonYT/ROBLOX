# Cuts the knife pictures for Shop > PASSES out of the owner's mockup design/knives/Five_Elemental_Knife_Cards.png
# (owner, Oct 18: "please add the knifes into the ui for the gamepass menu"): each card's art panel (the knife and its
# element glow, inside the card's rim, down to just above the name) as assets/art/pass-knife-<name>.png, 240 px wide
# (the card shows it at about 118 points, 236 px on his Retina screen). The name, KNIFE and BUY are drawn by the game.
# Cropped unchanged (the owner's art as drawn); his mockup is the only source, so they're as sharp as the mockup is.
# Usage (from huzz-valley/): python3 tools/icons/cut_pass_knife_cards.py, then python3 tools/icons/pack_images.py
from PIL import Image

SRC = 'design/knives/Five_Elemental_Knife_Cards.png'
NAMES = ['hunter', 'moonlit', 'sunrise', 'inferno', 'frost']
LEFT = [16, 436, 856, 1276, 1696]  # each card's outer left edge (measured; cards are 403 x 715, top at y 14)
INSET, TOP, BOTTOM, WIDTH = 5, 19, 508, 393  # the art panel inside the 3 px rim, ending 12 px above the name
OUT_W = 240

im = Image.open(SRC).convert('RGBA')
for name, x0 in zip(NAMES, LEFT):
    art = im.crop((x0 + INSET, TOP, x0 + INSET + WIDTH, BOTTOM))
    h = round(art.height * OUT_W / art.width)
    art = art.resize((OUT_W, h), Image.LANCZOS)
    art.save('assets/art/pass-knife-%s.png' % name)
    print(name, art.size)
