# fit_icons.py <raw dir> <icons dir>: frames each raw render (a transparent PNG) like the other icons in hood/art/icons3d:
# a 512 x 512 canvas, the drawn content centred, its longer side 86% of the canvas. Writes <icons dir>/<name>.png.
import os
import sys

from PIL import Image

raw, out = sys.argv[1], sys.argv[2]
N, FILL = 512, 0.86
done = 0
for f in sorted(os.listdir(raw)):
    if not f.endswith('.png'):
        continue
    im = Image.open(os.path.join(raw, f)).convert('RGBA')
    box = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    if not box:
        print('empty render:', f)
        continue
    art = im.crop(box)
    k = N * FILL / max(art.size)
    art = art.resize((max(1, round(art.width * k)), max(1, round(art.height * k))), Image.LANCZOS)
    canvas = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    canvas.paste(art, ((N - art.width) // 2, (N - art.height) // 2), art)
    canvas.save(os.path.join(out, f))
    done += 1
print('framed', done)
