# The worn-knife picture (docs/previews/knife-on-back.jpg): knife_wear_scene.luau's two stills (from behind, from the
# front) next to the reference, a sword worn on the back in Huss Valley (their video f1c7bb86, the far-left player
# in docs/previews/knife-study-back.jpg: no back-sheath picture of his own exists in design/references).
# Usage (from huzz-valley/): python3 -I tools/preview/motion3d/knife_wear_sheet.py <dir with still_0.png, still_1.png>
import os
import sys
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def font(n):
    try:
        return ImageFont.truetype(FONT, n)
    except OSError:
        return ImageFont.load_default()


def main(src, out='docs/previews/knife-on-back.jpg'):
    # (cropped to the six bodies and scaled up 1.5x: the stills are framed wide)
    def still(n, box):
        im = Image.open(os.path.join(src, n)).convert('RGB').crop(box)
        return im.resize((im.width * 3 // 2, im.height * 3 // 2), Image.LANCZOS)
    back = still('still_0.png', (290, 170, 1490, 590))
    front = still('still_1.png', (230, 165, 1430, 585))
    ref = Image.open('docs/previews/knife-study-back.jpg').convert('RGB').crop((0, 105, 300, 480))
    h = back.height
    ref = ref.resize((round(ref.width * h / ref.height), h), Image.LANCZOS)
    bar = 56
    W = ref.width + back.width
    sheet = Image.new('RGB', (W, bar * 2 + h * 2), '#141418')
    d = ImageDraw.Draw(sheet)
    sheet.paste(ref, (0, bar))
    sheet.paste(back, (ref.width, bar))
    sheet.paste(front, (ref.width, bar * 2 + h))
    d.text((12, 12), 'Reference: a sword on the back', fill='#ffd27a', font=font(26))
    d.text((ref.width + 12, 12), 'Ours, from behind: long blades across the back (blue), short knives at the right hip (yellow)',
           fill='#ffffff', font=font(26))
    d.text((ref.width + 12, bar + h + 12), 'Ours, from the front (a little from their right): handles and the scythe head over the shoulder',
           fill='#ffffff', font=font(26))
    notes = ['Where each knife goes:', 'Config/CoinShop, Wear', '(Back / Side, one per knife,', 'the owner can change it).',
             '', 'Picked from his .glb:', '3.0+ studs = Back (16),', 'shorter = Side (37).', '',
             'Same on R15 and R6.', 'Checked offline: nothing', 'inside the body or arms,', 'flat against the body.', '',
             'Over a cape or long hair;', 'big wings: at the hip', '(tested with boxes; real', 'avatars: Studio only).']
    y = bar * 2 + h
    for line in notes:
        d.text((16, y), line, fill='#d8d8e0', font=font(24))
        y += 34
    sheet.save(out, quality=86)
    print('wrote', out, sheet.size)


if __name__ == '__main__':
    main(sys.argv[1], *(sys.argv[2:3]))
