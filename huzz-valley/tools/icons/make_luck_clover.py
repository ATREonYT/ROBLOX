# The owner's luck clover (design/owner-oct23/luck-clover-ref.png, Oct 23 17:53: "make this used for the button to buy
# the luck, and make the number be matched to the server luck"). His picture as it is, with two changes only:
#   1. the white around it becomes transparent (flood-filled from the edges, a soft 1 px rim);
#   2. its baked-in "5x" is taken out (filled from the green around it), so the game writes the server's own number
#      on top (Screens/LobbyHud). A copy from him without the number would be sharper there.
# Writes assets/art/luck-clover.png; then run tools/icons/pack_images.py. Usage (from huzz-valley/):
#   python3 tools/icons/make_luck_clover.py
from collections import deque
import numpy as np
from PIL import Image, ImageFilter

SRC, DST = 'design/owner-oct23/luck-clover-ref.png', 'assets/art/luck-clover.png'
im = Image.open(SRC).convert('RGBA')
a = np.array(im).astype(np.float32)
h, w = a.shape[:2]
rgb = a[..., :3]

# 1. the background: near-white pixels joined to the edge
white = (rgb.min(axis=2) > 235)
bg = np.zeros((h, w), bool)
q = deque([(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)])
while q:
    x, y = q.popleft()
    if x < 0 or y < 0 or x >= w or y >= h or bg[y, x] or not white[y, x]:
        continue
    bg[y, x] = True
    q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

# 2. the number: inside its box, every pixel that isn't clover green (its white fill, black outline, grey edges)
x0, y0, x1, y1 = 138, 122, 352, 290
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
notGreen = (g - np.maximum(r, b)) < 35
box = np.zeros((h, w), bool)
box[y0:y1, x0:x1] = True
hole = notGreen & box & ~bg
hole = np.array(Image.fromarray((hole * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))) > 0
hole &= box
known = ~hole & ~bg
fill = rgb.copy()
fill[hole] = 0
weight = known.astype(np.float32)
for _ in range(600):  # (spread the green inwards: each hole pixel becomes the mean of its known neighbours)
    s = np.zeros_like(fill)
    n = np.zeros((h, w), np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        s += np.roll(np.roll(fill * weight[..., None], dy, 0), dx, 1)
        n += np.roll(np.roll(weight, dy, 0), dx, 1)
    upd = hole & (n > 0)
    fill[upd] = s[upd] / n[upd][:, None]
    weight = np.where(upd, 1.0, weight)
out = a.copy()
out[..., :3] = np.where(hole[..., None], fill, rgb)
alpha = np.where(bg, 0, 255).astype(np.uint8)
alpha = np.array(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.6)))
out[..., 3] = alpha
Image.fromarray(out.clip(0, 255).astype(np.uint8), 'RGBA').save(DST)
print('wrote', DST, w, h)
