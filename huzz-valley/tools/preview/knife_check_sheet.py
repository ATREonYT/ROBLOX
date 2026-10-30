# The knife check's one picture (Oct 19): the lobby stands at rest next to the owner's reference, before and after,
# with his meshes and with the plain-part stand-ins Studio shows until his import, plus the catcher's long knife in
# hand (before / after, tools/preview/motion3d/hand_floor_scene.luau). Every panel is the same size and framing as
# the reference crop (stand_knives_vs_ref.sh: x 230..1270, y 60..450 of his video, 960 x 360).
# Usage: python3 -I tools/preview/knife_check_sheet.py <ref.png> <hand.png> <before.png> <after.png>
#        <standin_before.png> <standin_after.png> <out.jpg>
import sys
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
W, H, BAR = 960, 360, 34


def panel(path, title, colour):
    im = Image.open(path).convert('RGB')
    if im.size != (W, H):  # (the hand still is 2:1: fit it in, centred on dark)
        k = min(W / im.width, H / im.height)
        im2 = im.resize((int(im.width * k), int(im.height * k)))
        im = Image.new('RGB', (W, H), (24, 20, 36))
        im.paste(im2, ((W - im2.width) // 2, (H - im2.height) // 2))
    out = Image.new('RGB', (W, H + BAR), (24, 20, 36))
    out.paste(im, (0, BAR))
    d = ImageDraw.Draw(out)
    d.text((10, 6), title, font=ImageFont.truetype(FONT, 20), fill=colour)
    return out


def main(ref, hand, before, after, sbefore, safter, out):
    cells = [
        panel(ref, 'REFERENCE (his video, at rest)', (255, 255, 255)),
        panel(hand, 'IN HAND: a long knife in the walk (before / after)', (255, 255, 255)),
        panel(before, 'BEFORE: his meshes', (255, 140, 140)),
        panel(after, 'AFTER: his meshes', (125, 255, 160)),
        panel(sbefore, 'BEFORE: stand-ins (Studio today, until his import)', (255, 140, 140)),
        panel(safter, 'AFTER: stand-ins (Studio today, until his import)', (125, 255, 160)),
    ]
    sheet = Image.new('RGB', (W * 2 + 8, (H + BAR) * 3 + 16), (12, 10, 20))
    for i, c in enumerate(cells):
        sheet.paste(c, ((i % 2) * (W + 8), (i // 2) * (H + BAR + 8)))
    sheet.save(out, quality=82)
    print(out)


if __name__ == '__main__':
    main(*sys.argv[1:8])
