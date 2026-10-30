# Cuts the owner's six crates out of their own pictures (owner, Oct 20 20:34: "make all of the crate pictures have the
# same background so they all look the same, but just the crate is different"): his Dojo, Storm and Beast crates from
# his crate shop cards (assets/art/crate-card-*.png, the crate area above his BUY bar) and his three Halloween crates
# from design/owner-oct20/2034-chests77-halloween-crates.png (candy coffin, witch cauldron, Halloween chest). Nothing is
# redrawn: rembg (isnet-general-use) finds each crate's outline, the crate's own pixels are kept as they are, and the
# result is trimmed to the crate with a small margin. The Shop draws one shared backdrop behind every crate.
# Output: assets/art/crate-card-cut-<name>.png (packed at 448 px by tools/icons/pack_images.py, as his crate cards;
# the CrateCard name also gives them the crate stand-in glyph where pictures can't be drawn).
# Needs: python3 -m pip install "rembg[cpu]" (downloads its model once). Usage (from huzz-valley/):
#   python3 tools/crates/cut_crates.py
from PIL import Image, ImageChops, ImageDraw
from rembg import remove, new_session

session = new_session('isnet-general-use')
OUT = 'assets/art/crate-card-cut-%s.png'

jobs = []
# his crate shop cards: the crate sits in the top (x 30-685, y 25-535) above his BUY bar
for name in ('dojo', 'storm', 'beast'):
    im = Image.open('assets/art/crate-card-%s.png' % name).convert('RGB')
    jobs.append((name, im.crop((30, 25, min(im.width - 30, 685), 535))))
# his Halloween sheet: three crates side by side, each about a third of it
sheet = Image.open('design/owner-oct20/2034-chests77-halloween-crates.png').convert('RGB')
third = sheet.width // 3
for i, name in enumerate(('candy', 'witch', 'halloween')):
    jobs.append((name, sheet.crop((i * third, 0, (i + 1) * third, sheet.height))))

def fill_holes(cut):
    # holes inside the crate (the model reads a bright glow inside an open crate as background): any see-through
    # spot not reached from the picture's edge is part of the crate, so it gets the crate's own pixels back
    a = cut.getchannel('A')
    solid = a.point(lambda v: 255 if v > 24 else 0)
    pad = Image.new('L', (solid.width + 2, solid.height + 2), 0)
    pad.paste(solid, (1, 1))
    ImageDraw.floodfill(pad, (0, 0), 128)
    holes = pad.crop((1, 1, pad.width - 1, pad.height - 1)).point(lambda v: 255 if v == 0 else 0)
    cut.putalpha(ImageChops.lighter(a, holes))
    return cut


for name, im in jobs:
    cut = remove(im, session=session, post_process_mask=True).convert('RGBA')
    cut = fill_holes(Image.merge('RGBA', (*im.split(), cut.getchannel('A'))))
    box = cut.getchannel('A').point(lambda a: 255 if a > 24 else 0).getbbox()
    cut = cut.crop(box)
    # a square canvas with a small margin, the crate centred at the bottom (so they stand on the same line)
    side = int(max(cut.size) * 1.06)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(cut, ((side - cut.width) // 2, side - cut.height - int(side * 0.03)), cut)
    canvas.save(OUT % name)
    print(name, im.size, '->', canvas.size)
