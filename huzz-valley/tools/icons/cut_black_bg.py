# Cuts the flat black background off one of the owner's pictures sent without transparency (Oct 22: his Inventory
# backpack tile, design/owner-oct22/inv1.png): flood fill from the edges over pixels darker than LO (the background),
# soft alpha up to HI (the anti-aliased edge of his dark outline), crop, then resize to the width given (aspect kept).
# The picture itself is not touched. Usage (from huzz-valley/):
#   python3 -I tools/icons/cut_black_bg.py design/owner-oct22/inv1.png assets/icons/inventory-backpack.png 256
import sys
from collections import deque
from PIL import Image
src, out, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
LO, HI = 6, 13
im = Image.open(src).convert("RGBA")
W, H = im.size
px = im.load()
def lum(p): return max(p[0], p[1], p[2])
seen = bytearray(W * H)
q = deque()
for x in range(W):
    q.append((x, 0)); q.append((x, H - 1))
for y in range(H):
    q.append((0, y)); q.append((W - 1, y))
while q:
    x, y = q.popleft()
    i = y * W + x
    if seen[i]: continue
    seen[i] = 1
    p = px[x, y]
    v = lum(p)
    if v <= LO:
        px[x, y] = (p[0], p[1], p[2], 0)
        for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0 <= nx < W and 0 <= ny < H and not seen[ny*W+nx]: q.append((nx, ny))
    elif v < HI:
        px[x, y] = (p[0], p[1], p[2], int(255 * (v - LO) / (HI - LO)))
bbox = im.getchannel("A").getbbox()
im = im.crop(bbox)
w, h = im.size
im.resize((size, round(size * h / w)), Image.LANCZOS).save(out)
print("bbox", bbox, "->", size, round(size * h / w))
