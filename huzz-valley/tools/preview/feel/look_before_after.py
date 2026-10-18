"""A before/after estimate of a Config/Look change on one frame (owner, Oct 18: "give the lobby that brighter
contrast ... tune it a bit to make it feel and look better, but not too much contrast so it looks normal to look at").

Uses look_estimate.py's rough model (undo the old grade, relight, apply the new grade): not a render, only Studio
shows the real look. The frame must have been recorded with the look in FROM (the owner's Oct 17 recording, our_5,
ran the Oct 17 look, look_estimate.OLD); it is first moved to BEFORE (today's look), then to AFTER.
Usage: python3 -I look_before_after.py <frame.png> <out.jpg>
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look_estimate as L

FROM = L.OLD
BEFORE = dict(bright=2.0, expo=-0.1, cc_b=0.0, cc_c=0.12, cc_s=0.35, shift=(255, 250, 240))   # Oct 17 feel study
AFTER = dict(bright=2.2, expo=-0.05, cc_b=0.0, cc_c=0.16, cc_s=0.4, shift=(255, 250, 240))   # Oct 18 (2.3 / 0 / 0.18 / 0.42 clipped a third of the floor)
VIEW = (0.13, 0.14, 0.85, 0.92)  # the game view inside a Studio screen recording (left, top, right, bottom)


def main(src, out):
    a = np.asarray(Image.open(src).convert('RGB')).astype(float) / 255
    h, w, _ = a.shape
    a = a[int(VIEW[1] * h):int(VIEW[3] * h), int(VIEW[0] * w):int(VIEW[2] * w)]
    before = L.relight(a, FROM, BEFORE)
    after = L.relight(before, BEFORE, AFTER)
    for name, im in (('before', before), ('after', after)):
        s = L.stats(im)
        print('%-6s ' % name + ' '.join('%s=%.3f' % kv for kv in s.items()))
    h, w, _ = a.shape
    img = Image.fromarray((np.concatenate([before, after], 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    font_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'fonts', 'Montserrat-Variable.ttf')
    font = ImageFont.truetype(font_path, max(16, h // 26))
    for i, t in enumerate(('BEFORE: Brightness 2.0, Exposure -0.1, Contrast 0.12, Saturation 0.35',
                           'AFTER: Brightness 2.2, Exposure -0.05, Contrast 0.16, Saturation 0.4')):
        x = 12 + i * w
        d.rectangle([x - 6, 8, x + d.textlength(t, font=font) + 6, 14 + font.size + 6], fill=(20, 14, 26))
        d.text((x, 10), t, font=font, fill=(255, 255, 255))
    note = 'Estimate on the owner\'s recorded lobby frame (look_estimate.py model), not a Roblox render.'
    d.rectangle([6, h - font.size - 18, 12 + d.textlength(note, font=font), h - 4], fill=(20, 14, 26))
    d.text((10, h - font.size - 14), note, font=font, fill=(230, 230, 230))
    img = img.resize((1800, int(img.height * 1800 / img.width)), Image.LANCZOS)
    img.save(out, quality=88)
    print('saved', out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
