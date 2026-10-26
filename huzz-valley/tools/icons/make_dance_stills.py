# Cuts the white dance figures (tools/preview/motion3d/dance_stills.luau, filmed on a green screen) into
# assets/art/dance-still-<id>.png: the Dances cards' stand-in picture, tinted with each card's colour, shown while your
# own avatar's picture (UI/DancePose) can't be made. Made by us (a plain blocky body in our own dances' poses).
# Usage (from the repo root):
#   mkdir -p /tmp/stills && MOTION3D_KEEP=/tmp/stills sh huzz-valley/tools/preview/motion3d/video.sh \
#     huzz-valley/tools/preview/motion3d/dance_stills.luau /tmp/stills/stills.mp4
#   cd huzz-valley && python3 tools/icons/make_dance_stills.py /tmp/stills && python3 tools/icons/pack_images.py
import re
import sys
import numpy as np
from PIL import Image

SRC = sys.argv[1]
SIZE = 128  # px square (the card shows it about 70 points tall: sharp enough at 2x, small in the game)
ids = sorted(re.findall(r'(\w+) = [\d.]+', open('src/ReplicatedStorage/Shared/Config/DancePoses.lua').read()))


def kebab(name):
    return re.sub(r'([a-z])([A-Z])', r'\1-\2', name).lower()


for i, key in enumerate(ids):
    rgb = np.asarray(Image.open('%s/still_%d.png' % (SRC, i + 1)).convert('RGB'), np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green = np.clip((g - np.maximum(r, b) - 20) / 90, 0, 1)  # the screen and its shadow are green; the body is grey
    alpha = 1 - green
    grey = np.minimum(np.maximum(r, b), 255)  # despill: drop the green cast on the edges
    light = np.clip(grey * 1.45, 0, 255)  # the body is lit grey; make it read as white (the game tints it)
    out = np.dstack([light, light, light, alpha * 255]).astype(np.uint8)
    im = Image.fromarray(out, 'RGBA')
    box = im.getchannel('A').point(lambda v: 255 if v > 40 else 0).getbbox()
    im = im.crop(box)
    im.thumbnail((SIZE - 8, SIZE - 8), Image.LANCZOS)
    canvas = Image.new('RGBA', (SIZE, SIZE), (255, 255, 255, 0))
    canvas.alpha_composite(im, ((SIZE - im.width) // 2, SIZE - 4 - im.height))  # standing on the bottom edge
    canvas.save('assets/art/dance-still-%s.png' % kebab(key))
print('cut %d dance stills' % len(ids))
