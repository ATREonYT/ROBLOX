# The owner's crate shop picture, used as it is (Oct 20, 07:23: "Just put the ui picture i sent you, no need to try
# recreate" / "For the crates"): design/owner-oct20/0348-crate-shop-mockup.png (2172 x 724) cut into its three cards,
# Shinobi Dojo Chest, Elemental Storm Vault, Void Beast Chest, at full resolution. Each cut runs down the middle of the
# dark gap between two cards (measured: the cards span x 31-726, 747-1428, 1449-2143 and y 11-693), so every card keeps
# its own rounded edge and the three side by side make his picture again. Nothing is redrawn or cleaned up.
# Usage (from huzz-valley/): python3 -I tools/crates/cut_mockup_cards.py && python3 tools/icons/pack_images.py
from PIL import Image

SRC = 'design/owner-oct20/0348-crate-shop-mockup.png'
CUTS = {  # name: (left, top, right, bottom) in his picture
    'dojo': (20, 1, 737, 703),
    'storm': (737, 1, 1439, 703),
    'beast': (1439, 1, 2154, 703),
}

im = Image.open(SRC).convert('RGBA')
for name, box in CUTS.items():
    card = im.crop(box)
    card.save(f'assets/art/crate-card-{name}.png')
    print(name, card.size)
