# cut_mockup.py: cuts the owner's UI mockup (hood/docs/refs/ui/owner_ui_windows_oct27.png, Oct 27) into clean pieces the
# game draws as its windows (the owner, Oct 27: "directly import the images of the ui ... the ones you make aren't the
# same"). Writes hood/art/ui_owner/<name>.png and hood/art/ui_owner/slices.json.
#
# Words and numbers are never kept: a piece is cut from the clean parts of a button / tab / tile / card (its left and
# right ends, which hold the owner's own outline, corners, rim and shading) and joined, so the middle stretches from the
# seam (9-slice, SliceCenter) and our live Montserrat text goes on top. The header bar and the window body are fills
# only (the header's ends sit under the icon and the X): Kit draws their outline and corners. Every piece is upscaled 3x
# (Lanczos) so Roblox doesn't magnify a tiny image with its blurrier bilinear filter.
#
# slices.json[name] = { w, h, mode: 'slice' | 'tile' | 'whole', center: [x0, y0, x1, y1] (slice: the stretched middle,
# in the piece's pixels), src: the box in the mockup }. Usage (from the repo root):
#   python3 -I hood/tools/ui/cut_mockup.py [--debug out.png]     (--debug draws every box on the mockup)
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
HOOD = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(HOOD, 'docs', 'refs', 'ui', 'owner_ui_windows_oct27.png')
OUT = os.path.join(HOOD, 'art', 'ui_owner')
UP = 3

# name: (mode, (x0, y0, x1, y1) in the mockup, cap px). Modes:
#   join   the left and right `cap` px of the box, side by side (the words in the middle dropped)
#   mirror the right `cap` px and its mirror image (the left end is covered by an icon)
#   fill   the box as it is, stretched from its middle (a plain strip: the header's yellow)
#   tile   the box as a repeating patch (the body's square tile): the box spans whole squares of it
#   whole  the box as it is, not stretched (the red X)
PIECES = {
    # the window: header fill (inside its outline), the body's tile, the X
    'header': ('tile', (300, 19, 337, 57), 0),
    'body_tile': ('tile', (1133, 84, 1170, 121), 0),  # (two of its ~18.5 px squares each way)
    'close': ('whole', (543, 16, 585, 58), 0),
    # tabs: on (the Shop's yellow, the Backpack's blue), off (navy)
    'tab_on_yellow': ('join', (39, 66, 141, 97), 12),
    'tab_on_blue': ('join', (731, 403, 811, 428), 11),
    'tab_off': ('join', (146, 66, 258, 97), 12),
    # buttons and pills
    'btn_green': ('join', (735, 293, 982, 339), 16),
    'btn_yellow': ('join', (309, 227, 421, 260), 13),
    'btn_red': ('join', (637, 592, 704, 619), 11),
    'btn_grey': ('join', (332, 810, 393, 841), 11),
    'price_pill': ('join', (51, 337, 145, 367), 13),
    'price_green': ('join', (398, 977, 471, 1003), 11),
    # the progress bar: its green fill and its dark trough
    'bar_fill': ('join', (642, 257, 837, 284), 12),
    'bar_trough': ('mirror', (1000, 257, 1076, 284), 12),
    # cards and rows
    'stat_card': ('join', (915, 136, 1076, 235), 14),
    'row_side': ('mirror', (22, 480, 136, 526), 12),
    'row_side_on': ('mirror', (22, 438, 136, 476), 8),
    'search': ('mirror', (723, 591, 894, 620), 13),
    # item tiles by colour (the Backpack's grid; grey and the red-pink Secret from Shoe Boxes)
    'tile_blue': ('join', (482, 912, 570, 970), 9),
    'tile_yellow': ('join', (665, 912, 754, 970), 9),
    'tile_purple': ('join', (572, 912, 661, 970), 9),
    'tile_grey': ('join', (390, 912, 479, 970), 9),
    'tile_secret': ('join', (757, 912, 846, 970), 9),
}


# (hue turns, of 256, from the blue tile)
RECOLOR = {'tile_red': 115, 'tile_green': 170}


def cut(src, mode, box, cap):
    x0, y0, x1, y1 = box
    h = y1 - y0
    if mode in ('fill', 'whole', 'tile'):
        # (tile: the box is cut to whole squares of the pattern, measured on the mockup, so it repeats seamlessly)
        return src.crop(box), None
    if mode == 'join':
        left = src.crop((x0, y0, x0 + cap, y1))
        right = src.crop((x1 - cap, y0, x1, y1))
    else:  # mirror
        right = src.crop((x1 - cap, y0, x1, y1))
        left = right.transpose(Image.FLIP_LEFT_RIGHT)
    piece = Image.new('RGBA', (2 * cap, h))
    piece.paste(left, (0, 0))
    piece.paste(right, (cap, 0))
    return piece, cap


def alpha_corners(piece, radius):
    """Clears the mockup's background out of the piece's four corners (outside a rounded rectangle of `radius`)."""
    w, h = piece.size
    mask = Image.new('L', (w * 4, h * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w * 4 - 1, h * 4 - 1), radius=radius * 4, fill=255)
    mask = mask.resize((w, h), Image.LANCZOS)
    a = piece.getchannel('A')
    piece.putalpha(Image.composite(a, Image.new('L', (w, h), 0), mask))
    return piece


def main():
    src = Image.open(SRC).convert('RGBA')
    os.makedirs(OUT, exist_ok=True)
    meta = {}
    for name, (mode, box, cap) in PIECES.items():
        piece, c = cut(src, mode, box, cap)
        w, h = piece.size
        if mode in ('join', 'mirror', 'whole'):
            # (the mockup's rounded ends: what lies outside them is the backdrop, not the piece)
            radius = max(3, min(h // 3, 10)) if mode != 'whole' else 6
            piece = alpha_corners(piece, radius)
        big = piece.resize((w * UP, h * UP), Image.LANCZOS)
        W, H = big.size
        if mode in ('join', 'mirror'):
            cy = min(c, h // 2 - 1) * UP
            center = [c * UP - 1, cy, c * UP + 1, H - cy]
        elif mode == 'fill':
            center = [UP * 2, UP * 2, W - UP * 2, H - UP * 2]
        else:
            center = [0, 0, W, H]
        big.save(os.path.join(OUT, name + '.png'))
        meta[name] = {'w': W, 'h': H, 'mode': 'tile' if mode == 'tile' else ('whole' if mode == 'whole' else 'slice'), 'center': center, 'src': list(box)}
    # The mockup's red and green item tiles all have an item over their ends, so those two are the clean blue tile with
    # its hue turned (the owner's shading and rim kept).
    for name, hue in RECOLOR.items():
        blue = Image.open(os.path.join(OUT, 'tile_blue.png')).convert('RGBA')
        a = blue.getchannel('A')
        h_, s_, v_ = blue.convert('RGB').convert('HSV').split()
        h_ = h_.point(lambda v: (v + hue) % 256)
        out = Image.merge('HSV', (h_, s_, v_)).convert('RGB').convert('RGBA')
        out.putalpha(a)
        out.save(os.path.join(OUT, name + '.png'))
        meta[name] = dict(meta['tile_blue'], src='tile_blue, hue turned')
    with open(os.path.join(OUT, 'slices.json'), 'w') as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)
    print('cut', len(meta), 'pieces into', OUT)
    if '--debug' in sys.argv:
        dbg = src.convert('RGB')
        d = ImageDraw.Draw(dbg)
        for name, (mode, box, cap) in PIECES.items():
            d.rectangle(box, outline=(255, 0, 255), width=1)
            d.text((box[0] + 1, box[1] - 10), name, fill=(255, 0, 255))
        dbg.save(sys.argv[sys.argv.index('--debug') + 1])


main()
